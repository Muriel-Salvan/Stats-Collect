#--
# Copyright (c) 2010 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'date'
require 'optparse'
require 'StatsCollect/StatsProxy'
require 'StatsCollect/StatsOrdersProxy'

module StatsCollect

  # Stats orders statuses
  STATS_ORDER_STATUS_TOBEPROCESSED = 0
  STATS_ORDER_STATUS_RECOVERABLE_ERROR = 1
  STATS_ORDER_STATUS_UNRECOVERABLE_ERROR = 2
  # Value types
  STATS_VALUE_TYPE_INTEGER = 0
  STATS_VALUE_TYPE_FLOAT = 1
  STATS_VALUE_TYPE_PERCENTAGE = 2
  STATS_VALUE_TYPE_UNKNOWN = 3
  STATS_VALUE_TYPE_MAP = 4
  STATS_VALUE_TYPE_STRING = 5

  class Stats

    # Constructor
    def initialize
      # Parse for available Locations
      require 'rUtilAnts/Plugins'
      RUtilAnts::Plugins::install_plugins_on_object
      parse_plugins_from_dir('Locations', "#{File.expand_path(File.dirname(__FILE__))}/Locations", 'StatsCollect::Locations')
      parse_plugins_from_dir('Backends', "#{File.expand_path(File.dirname(__FILE__))}/Backends", 'StatsCollect::Backends')
      parse_plugins_from_dir('Notifiers', "#{File.expand_path(File.dirname(__FILE__))}/Notifiers", 'StatsCollect::Notifiers')

      @Backend = nil
      @BackendInit = false
      @Notifier = nil
      @ConfigFile = nil
      @DisplayHelp = false

      # The command line parser
      @Options = OptionParser.new
      @Options.banner = 'StatsCollect.rb [--help] [--debug] --backend <Backend> --notifier <Notifier> --config <ConfigFile>'
      @Options.on( '--backend <Backend>', String,
        "<Backend>: Backend to be used. Available backends are: #{get_plugins_names('Backends').join(', ')}",
        'Specify the backend to be used') do |iArg|
        @Backend = iArg
      end
      @Options.on( '--notifier <Notifier>', String,
        "<Notifier>: Notifier used to send notifications. Available notifiers are: #{get_plugins_names('Notifiers').join(', ')}",
        'Specify the notifier to be used') do |iArg|
        @Notifier = iArg
      end
      @Options.on( '--config <ConfigFile>', String,
        '<ConfigFile>: The configuration file',
        'Specify the configuration file') do |iArg|
        @ConfigFile = iArg
      end
      @Options.on( '--help',
        'Display help') do
        @DisplayHelp = true
      end
      @Options.on( '--debug',
        'Activate debug logs') do
        activate_log_debug(true)
      end

    end

    # Check that the environment is correctly set.
    # This has to be called prior to calling collect, and exit should be made if error code is not 0.
    #
    # Parameters::
    # * *iParams* (<em>list<String></em>): The parameters, as given in the command line
    # Return::
    # * _Integer_: Error code (given to exit) (0 = no error)
    def setup(iParams)
      rErrorCode = 0

      lRemainingArgs = nil
      begin
        lRemainingArgs = @Options.parse(iParams)
        if (!lRemainingArgs.empty?)
          log_err "Unknown arguments: #{lRemainingArgs.join(' ')}"
          log_err @Options
          rErrorCode = 1
        end
      rescue Exception
        log_err "Exception: #{$!}.\n#{$!.backtrace.join("\n")}"
        rErrorCode = 2
      end
      if (rErrorCode == 0)
        if (@DisplayHelp)
          log_msg @Options
          rErrorCode = 3
        elsif (@Backend == nil)
          log_err 'You must specify a backend.'
          log_err @Options
          rErrorCode = 4
        elsif (@Notifier == nil)
          log_err 'You must specify a notifier.'
          log_err @Options
          rErrorCode = 5
        elsif (@ConfigFile == nil)
          log_err 'You must specify a config file.'
          log_err @Options
          rErrorCode = 6
        else
          @Conf = nil
          # Read the configuration file
          begin
            File.open(@ConfigFile, 'r') do |iFile|
              @Conf = eval(iFile.read)
            end
          rescue
            log_err "Invalid configuration file: #{@ConfigFile}"
            rErrorCode = 7
          end
          if (rErrorCode == 0)
            # Get the corresponding notifier
            if (@Conf[:Notifiers][@Notifier] == nil)
              log_err "Notifier #{@Notifier} has no configuration set up in configuration file #{@ConfigFile}"
              rErrorCode = 8
            else
              @NotifierInstance, lError = get_plugin_instance('Notifiers', @Notifier)
              if (@NotifierInstance == nil)
                log_err "Unable to instantiate notifier #{@Notifier}: #{lError}"
                rErrorCode = 9
              else
                # Will we notify the user of the script execution ?
                @NotifyUser = true
                # Get the corresponding backend
                if (@Conf[:Backends][@Backend] == nil)
                  log_err "Backend #{@Backend} has no configuration set up in configuration file #{@ConfigFile}"
                  rErrorCode = 10
                else
                  @BackendInstance, lError = get_plugin_instance('Backends', @Backend)
                  if (@BackendInstance == nil)
                    log_err "Unable to instantiate backend #{@Backend}: #{lError}"
                    rErrorCode = 11
                  end
                end
              end
            end
          end
        end
      end

      return rErrorCode
    end

    # Execute the stats collection
    #
    # Return::
    # * _Integer_: Error code (given to exit)
    def collect
      rErrorCode = 0

      require 'rUtilAnts/Misc'
      RUtilAnts::Misc::install_misc_on_object
      lMutexErrorCode = file_mutex('StatsCollect') do
        begin
          # The list of errors
          lLstErrors = []
          set_log_errors_stack(lLstErrors)
          # Collect statistics
          log_info "[#{DateTime.now.strftime('%Y-%m-%d %H:%M:%S')}] - Begin collecting stats (PID #{Process.pid})..."
          lFoundOrder = false
          lNbrErrors = 0
          setupBackend do
            # Get the stats orders to process
            lStatsOrdersProxy = StatsOrdersProxy.new
            @BackendInstance.get_stats_orders(lStatsOrdersProxy)
            lFoundOrder = (!lStatsOrdersProxy.StatsOrders.empty?)
            # Process each stats order
            lStatsOrdersProxy.StatsOrders.each do |iLstIDs, iStatsOrderInfo|
              iTimeStamp, iLstLocations, iLstObjects, iLstCategories, iStatus = iStatsOrderInfo
              @BackendInstance.dequeue_stats_orders(iLstIDs)
              log_info "Dequeued stats order: IDs: #{iLstIDs.join('|')}, Time: #{iTimeStamp}, Locations: #{iLstLocations.join('|')}, Objects: #{iLstObjects.join('|')}, Categories: #{iLstCategories.join('|')}, Status: #{iStatus}"
              begin
                lRecoverableOrders, lUnrecoverableOrders = processOrder(iLstObjects, iLstCategories, iLstLocations)
                # Add recoverable orders back
                lRecoverableOrders.each do |iOrderInfo|
                  lNbrErrors += 1
                  iLstRecoverableObjects, iLstRecoverableCategories, iLstRecoverableLocations = iOrderInfo
                  log_info "Enqueue recoverable order: Locations: #{iLstRecoverableLocations.join('|')}, Objects: #{iLstRecoverableObjects.join('|')}, Categories: #{iLstRecoverableCategories.join('|')}"
                  @BackendInstance.put_new_stats_order(DateTime.now + @Conf[:RecoverableErrorsRetryDelay]/86400.0, iLstRecoverableLocations, iLstRecoverableObjects, iLstRecoverableCategories, STATS_ORDER_STATUS_RECOVERABLE_ERROR)
                end
                # Add unrecoverable orders back
                lUnrecoverableOrders.each do |iOrderInfo|
                  lNbrErrors += 1
                  iLstUnrecoverableObjects, iLstUnrecoverableCategories, iLstUnrecoverableLocations = iOrderInfo
                  log_info "Enqueue unrecoverable order: Locations: #{iLstUnrecoverableLocations.join('|')}, Objects: #{iLstUnrecoverableObjects.join('|')}, Categories: #{iLstUnrecoverableCategories.join('|')}"
                  @BackendInstance.put_new_stats_order(iTimeStamp, iLstUnrecoverableLocations, iLstUnrecoverableObjects, iLstUnrecoverableCategories, STATS_ORDER_STATUS_UNRECOVERABLE_ERROR)
                end
                @BackendInstance.commit
              rescue Exception
                lNbrErrors += 1
                @BackendInstance.rollback
                log_err "Exception while processing order #{iTimeStamp}, Locations: #{iLstLocations.join('|')}, Objects: #{iLstObjects.join('|')}, Categories: #{iLstCategories.join('|')}, Status: #{iStatus}: #{$!}.\n#{$!.backtrace.join("\n")}\n"
                rErrorCode = 14
              end
            end
          end
          if (!lFoundOrder)
            @NotifyUser = false
          end
          set_log_errors_stack(nil)
          if (lNbrErrors > 0)
            log_err "#{lNbrErrors} orders were put in error during processing. Please check logs."
          end
          if (!lLstErrors.empty?)
            log_err "#{lLstErrors.size} errors were reported. Check log for exact errors."
          end
          log_info "[#{DateTime.now.strftime('%Y-%m-%d %H:%M:%S')}] - Stats collection finished."
        rescue Exception
          log_err "Exception thrown while collecting stats: #{$!}.\n#{$!.backtrace.join("\n")}"
          rErrorCode = 15
          @NotifyUser = true
        end
      end
      if ((lMutexErrorCode != RUtilAnts::Misc::FILEMUTEX_NO_LOCK) and
          (lMutexErrorCode != RUtilAnts::Misc::FILEMUTEX_ZOMBIE_LOCK))
        rErrorCode = 12
      end

      return rErrorCode
    end

    # Send notifications of a file content if necessary
    #
    # Parameters::
    # * *iFileName* (_String_): The file containing notifications to be sent
    def notify(iFileName)
      if (@NotifyUser)
        lMessage = nil
        begin
          File.open(iFileName, 'r') do |iFile|
            lMessage = iFile.read
          end
        rescue Exception
          lMessage = "Error while reading log file #{iFileName}: #{$!}"
        end
        @NotifierInstance.send_notification(@Conf[:Notifiers][@Notifier], lMessage)
      end
    end

    # Enqueue a new stats order
    #
    # Parameters::
    # * *iLstLocations* (<em>list<String></em>): Locations list (can be empty for all locations)
    # * *iLstObjects* (<em>list<String></em>): Objects list (can be empty for all objects)
    # * *iLstCategories* (<em>list<String></em>): Categories list (can be empty for all categories)
    def pushStatsOrder(iLstLocations, iLstObjects, iLstCategories)
      setupBackend do
        @BackendInstance.put_new_stats_order(DateTime.now, iLstLocations, iLstObjects, iLstCategories, STATS_ORDER_STATUS_TOBEPROCESSED)
      end
    end

    private

    # Call some code initializing backend before and ensuring it will be closed after.
    # This method is re-entrant.
    #
    # Parameters::
    # * _CodeBlock_: the code to be called
    def setupBackend
      lBackendInitHere = false
      if (!@BackendInit)
        @BackendInstance.init_session(@Conf[:Backends][@Backend])
        @BackendInit = true
        lBackendInitHere = true
      end
      yield
      if (lBackendInitHere)
        @BackendInstance.close_session
        @BackendInit = false
      end
    end

    # Process an order
    #
    # Parameters::
    # * *iObjectsList* (<em>list<String></em>): List of objects to filter (can be empty for all)
    # * *iCategoriesList* (<em>list<String></em>): List of categories to filter (can be empty for all)
    # * *iLocationsList* (<em>list<String></em>): List of locations to filter (can be empty for all)
    # Return::
    # * <em>list< [list<String>,list<String>,list<String>] ></em>: The list of orders (objects, categories, locations) that could not be performed due to recoverable errors
    # * <em>list< [list<String>,list<String>,list<String>] ></em>: The list of orders (objects, categories, locations) that could not be performed due to unrecoverable errors
    def processOrder(iObjectsList, iCategoriesList, iLocationsList)
      rRecoverableOrders = []
      rUnrecoverableOrders = []

      # For each location, call the relevant plugin
      lPlugins = []
      if (iLocationsList.empty?)
        lPlugins = get_plugins_names('Locations')
      else
        lPlugins = iLocationsList
      end
      lErrorPlugins = []
      lPlugins.each do |iPluginName|
        lPluginConf = nil
        if (@Conf[:Locations] != nil)
          lPluginConf = @Conf[:Locations][iPluginName]
        end
        lPlugin, lError = get_plugin_instance('Locations', iPluginName)
        if (lError == nil)
          # Ask the plugin to perform the order
          lStatsProxy = StatsProxy.new(iObjectsList, iCategoriesList, @BackendInstance, iPluginName)
          log_info "===== Call Location plugin #{iPluginName} to perform order..."
          begin
            lPlugin.execute(lStatsProxy, lPluginConf, iObjectsList, iCategoriesList)
          rescue Exception
            log_err "Exception thrown during plugin #{iPluginName} execution: #{$!}.\n#{$!.backtrace.join("\n")}"
            lErrorPlugins << iPluginName
            lError = true
          end
          if (lError == nil)
            # Write the stats into the database
            writeStats(lStatsProxy.StatsToAdd, iObjectsList, iCategoriesList)
            # If the plugin failed on recoverable errors, note them
            lStatsProxy.RecoverableOrders.each do |iOrderInfo|
              iLstObjects, iLstCategories = iOrderInfo
              # Filter them: if we did not want them, do not add them back
              lObjectsToAdd = intersectLists(iLstObjects, iObjectsList)
              lCategoriesToAdd = intersectLists(iLstCategories, iCategoriesList)
              if ((lObjectsToAdd != nil) and
                  (lCategoriesToAdd != nil))
                rRecoverableOrders << [ lObjectsToAdd, lCategoriesToAdd, [iPluginName] ]
              end
            end
            # If the plugin failed on unrecoverable errors, note them
            lStatsProxy.UnrecoverableOrders.each do |iOrderInfo|
              iLstObjects, iLstCategories = iOrderInfo
              # Filter them: if we did not want them, do not add them back
              lObjectsToAdd = intersectLists(iLstObjects, iObjectsList)
              lCategoriesToAdd = intersectLists(iLstCategories, iCategoriesList)
              if ((lObjectsToAdd != nil) and
                  (lCategoriesToAdd != nil))
                rUnrecoverableOrders << [ lObjectsToAdd, lCategoriesToAdd, [iPluginName] ]
              end
            end
          end
          log_info ''
        else
          log_err "Error while instantiating Location plugin #{iPluginName}: #{$!}."
          lErrorPlugins << iPluginName
        end
      end
      if (!lErrorPlugins.empty?)
        rUnrecoverableOrders << [ iObjectsList, iCategoriesList, lErrorPlugins ]
      end

      return rRecoverableOrders, rUnrecoverableOrders
    end

    # Find names common to 2 different lists.
    # Both lists can be empty to indicate all possible names.
    # This method returns the intersection of both lists.
    #
    # Parameters::
    # * *iLst1* (<em>list<String></em>): The first list
    # * *iLst2* (<em>list<String></em>): The second list
    # Return::
    # * <em>list<String></em>: The resulting list. Can be empty for all possible names, or nil for no name.
    def intersectLists(iLst1, iLst2)
      rLstIntersection = nil

      if (iLst1.empty?)
        if (iLst2.empty?)
          # Add all
          rLstIntersection = []
        else
          rLstIntersection = iLst2
        end
      else
        if (iLst2.empty?)
          rLstIntersection = iLst1
        else
          # Filter
          rLstIntersection = []
          iLst1.each do |iObject|
            if (iLst2.include?(iObject))
              rLstIntersection << iObject
            end
          end
          if (rLstIntersection.empty?)
            rLstIntersection = nil
          end
        end
      end

      return rLstIntersection
    end

    # Write stats in the database.
    # Apply some filter before.
    #
    # Parameters::
    # * *iStatsToAdd* (<em>list< [TimeStamp,Object,Category,Value] ></em>): The stats to write in the DB
    # * *iLstObjects* (<em>list<String></em>): The filtering objects to write (can be empty for all)
    # * *iLstCategories* (<em>list<String></em>): The filtering categories to write (can be empty for all)
    def writeStats(iStatsToAdd, iLstObjects, iLstCategories)
      # Filter the stats we will really add
      lStatsToBeCommitted = nil
      if ((iLstObjects.empty?) and
          (iLstCategories.empty?))
        lStatsToBeCommitted = iStatsToAdd
      else
        # Filter
        lStatsToBeCommitted = []
        iStatsToAdd.each do |iStatsInfo|
          iTimeStamp, iObject, iCategory, iValue = iStatsInfo
          lOK = true
          if (!iLstObjects.empty?)
            lOK = iLstObjects.include?(iObject)
          end
          if ((lOK) and
              (!iLstCategories.empty?))
            lOK = iLstCategories.include?(iCategory)
          end
          if (lOK)
            lStatsToBeCommitted << iStatsInfo
          end
        end
      end

      # Write stats if there are some
      if (lStatsToBeCommitted.empty?)
        log_info 'No stats to be written after filtering.'
      else
        # Get the current locations from the DB to know if our location exists
        lKnownLocations = @BackendInstance.get_known_locations
        # Get the list of categories, sorted by category name
        lKnownCategories = @BackendInstance.get_known_categories
        # Get the list of objects, sorted by object name
        # This map will eventually be completed if new objects are found among the stats to write.
        lKnownObjects = @BackendInstance.get_known_objects
        # Use the following to generate a RB file that can be used with RB plugin.
        if false
          lStrStats = []
          lStatsToBeCommitted.each do |iStatsInfo|
            lCheckExistence, iTimeStamp, iLocation, iObject, iCategory, iValue = iStatsInfo
            lStrStats << [ lCheckExistence, iTimeStamp.strftime('%Y-%m-%d %H:%M:%S'), iLocation, iObject, iCategory, iValue ].inspect
          end
          File.open('__StatsToBeWritten.rb', 'w') do |oFile|
            oFile.write("[\n#{lStrStats.join(",\n")}\n]")
          end
        end
        # Add statistics
        lStatsToBeCommitted.each do |iStatsInfo|
          lCheckExistence, iTimeStamp, iLocation, iObject, iCategory, iValue = iStatsInfo
          lLocationID = lKnownLocations[iLocation]
          if (lLocationID == nil)
            # First create the new location and get its ID
            log_info "Creating new location: #{iLocation}"
            lLocationID = @BackendInstance.add_location(iLocation)
            lKnownLocations[iLocation] = lLocationID
            lCheckExistence = false
          end
          # Check that the category exists
          lValueType = nil
          lCategoryID = nil
          if (lKnownCategories[iCategory] == nil)
            log_warn "Unknown stats category given by location #{iLocation}: #{iCategory}. It will be created with an Unknown value type."
            lValueType = STATS_VALUE_TYPE_UNKNOWN
            lCategoryID = @BackendInstance.add_category(iCategory, lValueType)
            lKnownCategories[iCategory] = [ lCategoryID, lValueType ]
            lCheckExistence = false
          else
            lCategoryID, lValueType = lKnownCategories[iCategory]
          end
          # Check if we need to create the corresponding object
          lObjectID = lKnownObjects[iObject]
          if (lObjectID == nil)
            log_info "Creating new object: #{iObject}"
            lObjectID = @BackendInstance.add_object(iObject)
            lKnownObjects[iObject] = lObjectID
            lCheckExistence = false
          end
          # First, we ensure that this stats does not exist if we don't want duplicates
          lAdd = true
          if (lCheckExistence)
            lExistingValue = @BackendInstance.get_stat(iTimeStamp, lLocationID, lObjectID, lCategoryID, lValueType)
            if (lExistingValue != nil)
              log_warn "Stat value for #{iTimeStamp.strftime('%Y-%m-%d %H:%M:%S')}, Location: #{lLocationID}, Object: #{lObjectID}, Category: #{lCategoryID} already exists with value #{lExistingValue}. Will not duplicate it."
              lAdd = false
            end
          end
          if (lAdd)
            # Add the stat
            @BackendInstance.add_stat(iTimeStamp, lLocationID, lObjectID, lCategoryID, iValue, lValueType)
            log_debug "Added stat: Time: #{iTimeStamp}, Location: #{iLocation} (#{lLocationID}), Object: #{iObject} (#{lObjectID}), Category: #{iCategory} (#{lCategoryID}), Value: #{iValue}"
          end
        end
        log_info "#{lStatsToBeCommitted.size} stats added."
      end
    end

  end

end
