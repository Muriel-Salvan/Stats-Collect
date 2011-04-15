#--
# Copyright (c) 2010 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Locations

    class RB

      # Execute the plugin.
      # This method has to add the stats and errors to the proxy.
      # It can filter only objects and categories given.
      # It has access to its configuration.
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iConf* (<em>map<Symbol,Object></em>): The configuration associated to this plugin
      # * *iLstObjects* (<em>list<String></em>): List of objects to filter (can be empty for all)
      # * *iLstCategories* (<em>list<String></em>): List of categories to filter (can be empty for all)
      def execute(oStatsProxy, iConf, iLstObjects, iLstCategories)
        if (!iConf[:Files].empty?)
          # Get the list of categories, locations and objects
          lCategories = oStatsProxy.getCategories
          lObjects = oStatsProxy.getObjects
          lLocations = oStatsProxy.getLocations
          iConf[:Files].each do |iFileName|
            lLstStats = nil
            File.open(iFileName, 'r') do |iFile|
              lLstStats = eval(iFile.read)
            end
            lMissingIDs = false
            logInfo "Read #{lLstStats.size} stats from RB file."
            lLstStats.each do |ioStatInfo|
              iCheckExistenceBeforeAdd, iTimeStamp, iLocationName, iObjectName, iCategoryName, iValue = ioStatInfo
              ioStatInfo[1] = DateTime.strptime(iTimeStamp, iConf[:DateTimeFormat])
              if (iConf[:IDsMustExist])
                if (lLocations[iLocationName] == nil)
                  logWarn "Unknown location from RB file #{iFileName}: #{iLocationName}"
                  lMissingIDs = true
                end
                if (lObjects[iObjectName] == nil)
                  logWarn "Unknown object from RB file #{iFileName}: #{iObjectName}"
                  lMissingIDs = true
                end
                if (lCategories[iCategoryName] == nil)
                  logWarn "Unknown category from RB file #{iFileName}: #{iCategoryName}"
                  lMissingIDs = true
                end
              end
            end
            if (!lMissingIDs)
              oStatsProxy.addStatsList(lLstStats)
            end
          end
        end
      end
      
    end

  end

end
