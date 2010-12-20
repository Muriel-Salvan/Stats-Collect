#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Backends

    class Terminal

      # Initialize a session of this backend
      #
      # Parameters:
      # * *iConf* (<em>map<Symbol,Object></em>): Configuration of this backend
      def initSession(iConf)
        @IdxID = 0
      end

      # Get the next stats order.
      # Code to begin a new transaction can be set in this method too.
      #
      # Return:
      # * _DateTime_: The time stamp, or nil if no new stats order
      # * <em>list<String></em>: List of locations
      # * <em>list<String></em>: List of objects
      # * <em>list<String></em>: List of categories
      # * _Integer_: The order status
      def getNextStatsOrder
        rTimeStamp = nil
        rLstLocations = nil
        rLstObjects = nil
        rLstCategories = nil
        rStatus = nil

        if (defined?(@LstStatsOrders) == nil)
          @LstStatsOrders = [
            [ DateTime.now, [], [], [], STATS_ORDER_STATUS_TOBEPROCESSED ]
          ]
        end
        if (!@LstStatsOrders.empty?)
          rTimeStamp, rLstLocations, rLstObjects, rLstCategories, rStatus = @LstStatsOrders.pop
        end

        return rTimeStamp, rLstLocations, rLstObjects, rLstCategories, rStatus
      end

      # Get the list of known locations
      #
      # Return:
      # * <em>map<String,Integer></em>: Each location with its associated ID
      def getKnownLocations
        rKnownLocations = {}

        return rKnownLocations
      end

      # Get the list of known categories
      #
      # Return:
      # * <em>map<String,[Integer,Integer]></em>: Each category with its associated ID and value type
      def getKnownCategories
        rKnownCategories = {}

        return rKnownCategories
      end

      # Get the list of known objects
      #
      # Return:
      # * <em>map<String,Integer></em>: Each object with its associated ID
      def getKnownObjects
        rKnownObjects = {}

        return rKnownObjects
      end

      # Add a new location
      #
      # Parameters:
      # * *iLocation* (_String_): The location
      # Return:
      # * _Integer_: Its resulting ID
      def addLocation(iLocation)
        logMsg "Added location: #{iLocation} (#{@IdxID})"
        @IdxID += 1

        return @IdxID-1
      end

      # Add a new category
      #
      # Parameters:
      # * *iCategory* (_String_): The category
      # * *iValueType* (_Integer_): Its value type
      # Return:
      # * _Integer_: Its resulting ID
      def addCategory(iCategory, iValueType)
        logMsg "Added category: #{iCategory}, #{iValueType} (#{@IdxID})"
        @IdxID += 1

        return @IdxID-1
      end

      # Add a new object
      #
      # Parameters:
      # * *iObject* (_String_): The object
      # Return:
      # * _Integer_: Its resulting ID
      def addObject(iObject)
        logMsg "Added object: #{iObject} (#{@IdxID})"
        @IdxID += 1

        return @IdxID-1
      end

      # Add a new stat
      #
      # Parameters:
      # * *iTimeStamp* (_DateTime_): The time stamp
      # * *iLocationID* (_Integer_): Location ID
      # * *iObjectID* (_Integer_): Object ID
      # * *iCategoryID* (_Integer_): Category ID
      # * *iValue* (_Object_): The value to store
      # * *iValueType* (_Integer_): The value type
      def addStat(iTimeStamp, iLocationID, iObjectID, iCategoryID, iValue, iValueType)
        logMsg "Added stat: #{iTimeStamp} | Location: #{iLocationID} | Object: #{iObjectID} | Category: #{iCategoryID} | Value: #{iValue}"
      end

      # Add a new stats order
      #
      # Parameters:
      # * *iTimeStamp* (_DateTime_): The time stamp
      # * *iLstLocations* (<em>list<String></em>): List of locations
      # * *iLstObjects* (<em>list<String></em>): List of objects
      # * *iLstCategories* (<em>list<String></em>): List of categories
      # * *iStatus* (_Integer_): The order status
      def putNewStatsOrder(iTimeStamp, iLstLocations, iLstObjects, iLstCategories, iStatus)
        logMsg "Added new stats order: #{iTimeStamp} | Locations: #{iLstLocations.join(', ')} | Objects: #{iLstObjects.join(', ')} | Categories: #{iLstCategories.join(', ')} | Status: #{iStatus}"
      end

      # Commit the current stats order transaction
      def commit
        logMsg 'Transaction committed'
      end

      # Rollback the current stats order transaction
      def rollback
        logMsg 'Transaction rollbacked'
      end

    end

  end

end