#--
# Copyright (c) 2010 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Locations

    class CSV

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
          lCSVLocations = []
          lCSVObjects = []
          lCSVCategories = []
          require 'csv'
          iConf[:Files].each do |iFileName|
            lIdxLine = 0
            lMissingIDs = false
            ::CSV::open(iFileName, 'r', :col_sep => iConf[:ColumnSeparator], :quote_char => iConf[:QuoteChar], :row_sep => iConf[:RowSeparator]).each do |iRow|
              case lIdxLine
              when 0
                # We have locations in this line
                iRow[1..-1].each do |iLocationName|
                  if (lLocations[iLocationName] == nil)
                    logWarn "Unknown location from CSV file #{iFileName}: #{iLocationName}"
                    lMissingIDs = true
                  end
                  lCSVLocations << iLocationName
                end
              when 1
                # We have objects in this line
                iRow[1..-1].each do |iObjectName|
                  if (lObjects[iObjectName] == nil)
                    logWarn "Unknown object from CSV file #{iFileName}: #{iObjectName}"
                    lMissingIDs = true
                  end
                  lCSVObjects << iObjectName
                end
              when 2
                # We have categories in this line
                iRow[1..-1].each do |iCategoryName|
                  if (lCategories[iCategoryName] == nil)
                    logWarn "Unknown category from CSV file #{iFileName}: #{iCategoryName}"
                    lMissingIDs = true
                  end
                  lCSVCategories << iCategoryName
                end
              else
                if (lMissingIDs and
                    (iConf[:IDsMustExist]))
                  raise RuntimeError.new("Missing some IDs from CSV file #{iFileName}.")
                end
                # A line of data
                lTimestamp = DateTime.strptime(iRow[0], iConf[:DateTimeFormat])
                iRow[1..-1].each_with_index do |iStrValue, iIdx|
                  if (iStrValue != nil)
                    # Interpret the CSV value based on the value type of this column
                    lValueType = (lCategories[lCSVCategories[iIdx]] || STATS_VALUE_TYPE_UNKNOWN)
                    lValue = nil
                    case lValueType
                    when STATS_VALUE_TYPE_INTEGER
                      lValue = Integer(iStrValue)
                    when STATS_VALUE_TYPE_FLOAT
                      lValue = Float(iStrValue)
                    when STATS_VALUE_TYPE_PERCENTAGE
                      lValue = Float(iStrValue)
                    when STATS_VALUE_TYPE_UNKNOWN
                      lValue = iStrValue
                    when STATS_VALUE_TYPE_MAP
                      lValue = eval(iStrValue)
                    when STATS_VALUE_TYPE_STRING
                      lValue = iStrValue
                    else
                      raise RuntimeError.new("Unknown value type for category #{lCSVCategories[iIdx]}: #{lValueType}")
                    end
                    oStatsProxy.addStat(lCSVObjects[iIdx], lCSVCategories[iIdx], lValue, :Timestamp => lTimestamp, :Location => lCSVLocations[iIdx])
                  end
                end
              end
              lIdxLine += 1
            end
          end
        end
      end
      
    end

  end

end
