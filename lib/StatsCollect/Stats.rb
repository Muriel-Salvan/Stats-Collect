#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'date'
require 'optparse'
require 'StatsCollect/StatsProxy'

module StatsCollect

  # Stats orders statuses
  # !!! Those constants are also defined in the RoR website.
  STATS_ORDER_STATUS_TOBEPROCESSED = 0
  STATS_ORDER_STATUS_RECOVERABLE_ERROR = 1
  STATS_ORDER_STATUS_UNRECOVERABLE_ERROR = 2
  # Value types
  # !!! Those constants are also defined in the RoR website.
  STATS_VALUE_TYPE_INTEGER = 0
  STATS_VALUE_TYPE_FLOAT = 1
  STATS_VALUE_TYPE_PERCENTAGE = 2
  STATS_VALUE_TYPE_UNKNOWN = 3

  class Stats

    # Constructor
    def initialize
      # Parse for available Locations
      require 'rUtilAnts/Plugins'
      RUtilAnts::Plugins::initializePlugins
      parsePluginsFromDir('Locations', "#{File.expand_path(File.dirname(__FILE__))}/Locations", 'StatsCollect::Locations')
      parsePluginsFromDir('Backends', "#{File.expand_path(File.dirname(__FILE__))}/Backends", 'StatsCollect::Backends')
      parsePluginsFromDir('Notifiers', "#{File.expand_path(File.dirname(__FILE__))}/Notifiers", 'StatsCollect::Notifiers')

      @Backend = nil
      @Notifier = nil
      @ConfigFile = nil
      @DisplayHelp = false

      # The command line parser
      @Options = OptionParser.new
      @Options.banner = 'StatsCollect.rb [--help] [--debug] --backend <Backend> --notifier <Notifier> --config <ConfigFile>'
      @Options.on( '--backend <Backend>', String,
        "<Backend>: Backend to be used. Available backends are: #{getPluginNames('Backends').join(', ')}",
        'Specify the backend to be used') do |iArg|
        @Backend = iArg
      end
      @Options.on( '--notifier <Notifier>', String,
        "<Notifier>: Notifier used to send notifications. Available notifiers are: #{getPluginNames('Notifiers').join(', ')}",
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
        activateLogDebug(true)
      end

    end

    # Check that the environment is correctly set.
    # This has to be called prior to calling collect, and exit should be made if error code is not 0.
    #
    # Parameters:
    # * *iParams* (<em>list<String></em>): The parameters, as given in the command line
    # Return:
    # * _Integer_: Error code (given to exit) (0 = no error)
    def setup(iParams)
      rErrorCode = 0

      lRemainingArgs = nil
      begin
        lRemainingArgs = @Options.parse(iParams)
        if (!lRemainingArgs.empty?)
          logErr "Unknown arguments: #{lRemainingArgs.join(' ')}"
          logErr @Options
          rErrorCode = 1
        end
      rescue Exception
        logErr "Exception: #{$!}.\n#{$!.backtrace.join("\n")}"
        rErrorCode = 2
      end
      if (rErrorCode == 0)
        if (@DisplayHelp)
          logMsg @Options
          rErrorCode = 3
        elsif (@Backend == nil)
          logErr 'You must specify a backend.'
          logErr @Options
          rErrorCode = 4
        elsif (@Notifier == nil)
          logErr 'You must specify a notifier.'
          logErr @Options
          rErrorCode = 5
        elsif (@ConfigFile == nil)
          logErr 'You must specify a config file.'
          logErr @Options
          rErrorCode = 6
        else
          @Conf = nil
          # Read the configuration file
          begin
            File.open(@ConfigFile, 'r') do |iFile|
              @Conf = eval(iFile.read)
            end
          rescue
            logErr "Invalid configuration file: #{@ConfigFile}"
            rErrorCode = 7
          end
          if (rErrorCode == 0)
            # Get the corresponding notifier
            if (@Conf[:Notifiers][@Notifier] == nil)
              logErr "Notifier #{@Notifier} has no configuration set up in configuration file #{@ConfigFile}"
              rErrorCode = 8
            else
              @NotifierInstance, lError = getPluginInstance('Notifiers', @Notifier)
              if (@NotifierInstance == nil)
                logErr "Unable to instantiate notifier #{@Notifier}: #{lError}"
                rErrorCode = 9
              else
                # Will we notify the user of the script execution ?
                @NotifyUser = true
                # Get the corresponding backend
                if (@Conf[:Backends][@Backend] == nil)
                  logErr "Backend #{@Backend} has no configuration set up in configuration file #{@ConfigFile}"
                  rErrorCode = 10
                else
                  @BackendInstance, lError = getPluginInstance('Backends', @Backend)
                  if (@BackendInstance == nil)
                    logErr "Unable to instantiate backend #{@Backend}: #{lError}"
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
    # Return:
    # * _Integer_: Error code (given to exit)
    def collect
      rErrorCode = 0

      # Prevent concurrent execution
      require 'tmpdir'
      lLockFile = "#{Dir.tmpdir}/StatsCollect.lock"
      if (File.exists?(lLockFile))
        logErr "Another instance of stats collection is already running. Delete file #{lLockFile} if it is not."
        begin
          lDetails = nil
          File.open(lLockFile, 'r') do |iFile|
            lDetails = eval(iFile.read)
          end
          logErr "Details of the running instance: #{lDetails.inspect}"
          rErrorCode = 12
        rescue Exception
          logErr "Invalid lock file #{lLockFile}: #{$!}."
          rErrorCode = 13
        end
      else
        File.open(lLockFile, 'w') do |oFile|
          oFile << "
            {
              :ExecutionTime => '#{DateTime.now.strftime('%Y-%m-%d %H:%M:%S')}',
              :PID => '#{Process.pid}'
            }
          "
        end
        begin
          # Collect statistics
          logInfo "[#{DateTime.now.strftime('%Y-%m-%d %H:%M:%S')}] - Begin collecting stats..."
          @BackendInstance.initSession(@Conf[:Backends][@Backend])
          # Get the stats orders to process
          lFoundOrder = false
          lTimeStamp, lLstLocations, lLstObjects, lLstCategories, lStatus = @BackendInstance.getNextStatsOrder
          while (lTimeStamp != nil)
            lFoundOrder = true
            logInfo "Dequeued stats order: Time: #{lTimeStamp}, Locations: #{lLstLocations.join('|')}, Objects: #{lLstObjects.join('|')}, Categories: #{lLstCategories.join('|')}, Status: #{lStatus}"
            begin
              lRecoverableOrders, lUnrecoverableOrders = processOrder(lLstObjects, lLstCategories, lLstLocations)
              # Add recoverable orders back
              lRecoverableOrders.each do |iOrderInfo|
                iLstRecoverableObjects, iLstRecoverableCategories, iLstRecoverableLocations = iOrderInfo
                logInfo "Enqueue recoverable order: Locations: #{iLstRecoverableLocations.join('|')}, Objects: #{iLstRecoverableObjects.join('|')}, Categories: #{iLstRecoverableCategories.join('|')}"
                @BackendInstance.putNewStatsOrder(DateTime.now, iLstRecoverableLocations, iLstRecoverableObjects, iLstRecoverableCategories, STATS_ORDER_STATUS_RECOVERABLE_ERROR)
              end
              # Add unrecoverable orders back
              lUnrecoverableOrders.each do |iOrderInfo|
                iLstUnrecoverableObjects, iLstUnrecoverableCategories, iLstUnrecoverableLocations = iOrderInfo
                logInfo "Enqueue unrecoverable order: Locations: #{iLstUnrecoverableLocations.join('|')}, Objects: #{iLstUnrecoverableObjects.join('|')}, Categories: #{iLstUnrecoverableCategories.join('|')}"
                @BackendInstance.putNewStatsOrder(lTimeStamp, iLstUnrecoverableLocations, iLstUnrecoverableObjects, iLstUnrecoverableCategories, STATS_ORDER_STATUS_UNRECOVERABLE_ERROR)
              end
              @BackendInstance.commit
            rescue Exception
              @BackendInstance.rollback
              logErr "Exception while processing order #{lTimeStamp}, Locations: #{lLstLocations.join('|')}, Objects: #{lLstObjects.join('|')}, Categories: #{lLstCategories.join('|')}, Status: #{lStatus}: #{$!}.\n#{$!.backtrace.join("\n")}\n"
              rErrorCode = 14
            end
            lTimeStamp, lLstLocations, lLstObjects, lLstCategories, lStatus = @BackendInstance.getNextStatsOrder
          end
          if (!lFoundOrder)
            @NotifyUser = false
          end
          logInfo "[#{DateTime.now.strftime('%Y-%m-%d %H:%M:%S')}] - Stats collection finished."
          File.unlink(lLockFile)
        rescue Exception
          logErr "Exception thrown while collecting stats: #{$!}.\n#{$!.backtrace.join("\n")}"
          rErrorCode = 15
          @NotifyUser = true
        end
      end

      return rErrorCode
    end

    # Send notifications of a file content if necessary
    #
    # Parameters:
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
        @NotifierInstance.sendNotification(@Conf[:Notifiers][@Notifier], lMessage)
      end
    end

    private

    # Process an order
    #
    # Parameters:
    # * *iObjectsList* (<em>list<String></em>): List of objects to filter (can be empty for all)
    # * *iCategoriesList* (<em>list<String></em>): List of categories to filter (can be empty for all)
    # * *iLocationsList* (<em>list<String></em>): List of locations to filter (can be empty for all)
    # Return:
    # * <em>list<[list<String>,list<String>,list<String>]></em>: The list of orders (objects, categories, locations) that could not be performed due to recoverable errors
    # * <em>list<[list<String>,list<String>,list<String>]></em>: The list of orders (objects, categories, locations) that could not be performed due to unrecoverable errors
    def processOrder(iObjectsList, iCategoriesList, iLocationsList)
      rRecoverableOrders = []
      rUnrecoverableOrders = []

      # For each location, call the relevant plugin
      lPlugins = []
      if (iLocationsList.empty?)
        lPlugins = getPluginNames('Locations')
      else
        lPlugins = iLocationsList
      end
      lErrorPlugins = []
      lPlugins.each do |iPluginName|
        lPluginConf = nil
        if (@Conf[:Locations] != nil)
          lPluginConf = @Conf[:Locations][iPluginName]
        end
        lPlugin, lError = getPluginInstance('Locations', iPluginName)
        if (lError == nil)
          # Ask the plugin to perform the order
          lStatsProxy = StatsProxy.new(iObjectsList, iCategoriesList)
          logInfo "===== Call Location plugin #{iPluginName} to perform order..."
          begin
            lPlugin.execute(lStatsProxy, lPluginConf, iObjectsList, iCategoriesList)
          rescue Exception
            logErr "Exception thrown during plugin #{iPluginName} execution: #{$!}.\n#{$!.backtrace.join("\n")}"
            lErrorPlugins << iPluginName
            lError = true
          end
          if (lError == nil)
            # Write the stats into the database
            writeStats(lStatsProxy.StatsToAdd, iPluginName, iObjectsList, iCategoriesList)
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
          logInfo ''
        else
          logErr "Error while instantiating Location plugin #{iPluginName}: #{$!}."
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
    # Parameters:
    # * *iLst1* (<em>list<String></em>): The first list
    # * *iLst2* (<em>list<String></em>): The second list
    # Return:
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
    # Parameters:
    # * *iStatsToAdd* (<em>list<[TimeStamp,Object,Category,Value]></em>): The stats to write in the DB
    # * *iLocation* (_String_): The location of these stats
    # * *iLstObjects* (<em>list<String></em>): The filtering objects to write (can be empty for all)
    # * *iLstCategories* (<em>list<String></em>): The filtering categories to write (can be empty for all)
    def writeStats(iStatsToAdd, iLocation, iLstObjects, iLstCategories)
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
        logInfo 'No stats to be written after filtering.'
      else
        # Get the current locations from the DB to know if our location exists
        lKnownLocations = @BackendInstance.getKnownLocations
        lLocationID = lKnownLocations[iLocation]
        if (lLocationID == nil)
          # First create the new location and get its ID
          logInfo "Creating new location: #{iLocation}"
          lLocationID = @BackendInstance.addLocation(iLocation)
        end
        logDebug "Location used for those stats: #{iLocation} (#{lLocationID})"
        # Get the list of categories, sorted by category name
        lKnownCategories = @BackendInstance.getKnownCategories
        # Get the list of objects, sorted by object name
        # This map will eventually be completed if new objects are found among the stats to write.
        lKnownObjects = @BackendInstance.getKnownObjects
        # Add statistics
        lStatsToBeCommitted.each do |iStatsInfo|
          iTimeStamp, iObject, iCategory, iValue = iStatsInfo
          # Check that the category exists
          lValueType = nil
          lCategoryID = nil
          if (lKnownCategories[iCategory] == nil)
            logWarn "Unknown stats category given by location #{iLocation}: #{iCategory}. It will be created with an Unknown value type."
            lValueType = STATS_VALUE_TYPE_UNKNOWN
            lCategoryID = @BackendInstance.addCategory(iCategory, lValueType)
            lKnownCategories[iCategory] = [ lCategoryID, lValueType ]
          else
            lCategoryID, lValueType = lKnownCategories[iCategory]
          end
          # Check if we need to create the corresponding object
          lObjectID = lKnownObjects[iObject]
          if (lObjectID == nil)
            logInfo "Creating new object: #{iObject}"
            lObjectID = @BackendInstance.addObject(iObject)
            lKnownObjects[iObject] = lObjectID
          end
          # Add the stat
          @BackendInstance.addStat(iTimeStamp, lLocationID, lObjectID, lCategoryID, iValue, lValueType)
          logDebug "Added stat: Time: #{iTimeStamp}, Location: #{iLocation} (#{lLocationID}), Object: #{iObject} (#{lObjectID}), Category: #{iCategory} (#{lCategoryID}), Value: #{iValue}"
        end
      end
    end

  end

end
