#--
# Copyright (c) 2010 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  # The stats orders proxy, used by plugins to populate stats
  class StatsOrdersProxy

    # List of categories among the stats orders stats orders, by IDs
    #   map< list< Integer >, [ DateTime, list<String>, list<String>, list<String>, Integer ] >
    attr_reader :StatsOrders

    # Constructor
    def initialize
      # List of stats orders IDs
      @StatsOrders = {}
    end

    # Add a new stats order
    #
    # Parameters:
    # * *iID* (_Integer_): An ID identifying uniquely this stats order. It will be used to tell which stats orders have to be dequeued later.
    # * *iTimeStamp* (_DateTime_): Time stamp
    # * *iLstLocations* (<em>list<String></em>): List of locations
    # * *iLstObjects* (<em>list<String></em>): List of objects
    # * *iLstCategories* (<em>list<String></em>): List of categories
    # * *iStatus* (_Integer_): Status
    def addStatsOrder(iID, iTimeStamp, iLstLocations, iLstObjects, iLstCategories, iStatus)
      lLstSortedLocations = iLstLocations.sort.uniq
      lLstSortedObjects = iLstObjects.sort.uniq
      lLstSortedCategories = iLstCategories.sort.uniq
      # First, check if this stats order is not already present
      lFound = false
      @StatsOrders.each do |iIDs, iStatsOrderInfo|
        iExistingTimeStamp, iLstExistingLocations, iLstExistingObjects, iLstExistingCategories, iExistingStatus = iStatsOrderInfo
        if ((iLstExistingLocations == lLstSortedLocations) and
            (iLstExistingObjects == lLstSortedObjects) and
            (iLstExistingCategories == lLstSortedCategories))
          # Found already here
          iIDs << iID
          lFound = true
          break
        end
      end
      if (!lFound)
        @StatsOrders[[iID]] = [ iTimeStamp, lLstSortedLocations, lLstSortedObjects, lLstSortedCategories, iStatus ]
      end
    end

  end

end
