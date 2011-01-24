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
        logMsg 'Session initialized.'
      end

      # Get the next stats orders.
      #
      # Parameters:
      # * *oStatsOrdersProxy* (_StatsOrdersProxy_): The stats orders proxy to be used to give stats orders
      def getStatsOrders(oStatsOrdersProxy)
        oStatsOrdersProxy.addStatsOrder(0, DateTime.now, [], [], [], STATS_ORDER_STATUS_TOBEPROCESSED)
#        oStatsOrdersProxy.addStatsOrder(0, DateTime.now, ['MySpace'], [], ['Friends list'], STATS_ORDER_STATUS_TOBEPROCESSED)
        logMsg 'Added stats order 0.'
      end

      # Dequeue the given stat orders IDs.
      # Code to begin a new transaction can be set in this method too. In this case, the dequeue should be part of the transaction, or it will have to be re-enqueued during rollback method call (otherwise orders will be lost).
      #
      # Parameters:
      # * *iLstStatsOrderIDs* (<em>list<Integer></em>): The list of stats order IDs to dequeue
      def dequeueStatsOrders(iLstStatsOrderIDs)
        logMsg "Transaction started and stats orders dequeued: #{iLstStatsOrderIDs.join(', ')}"
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
        logMsg "Added stat: #{iTimeStamp} | Location: #{iLocationID} | Object: #{iObjectID} | Category: #{iCategoryID} (value type: #{iValueType}) | Value: #{iValue}"
      end

      # Get an existing stat value
      #
      # Parameters:
      # * *iTimeStamp* (_DateTime_): The timestamp
      # * *iLocationID* (_Integer_): The location ID
      # * *iObjectID* (_Integer_): The object ID
      # * *iCategoryID* (_Integer_): The category ID
      # * *iValueType* (_Integer_): The value type
      # Return:
      # * _Object_: The corresponding value, or nil if none
      def getStat(iTimeStamp, iLocationID, iObjectID, iCategoryID, iValueType)
        logMsg "Get stat: #{iTimeStamp} | Location: #{iLocationID} | Object: #{iObjectID} | Category: #{iCategoryID} (value type: #{iValueType})"

        return nil
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

      # Close a session of this backend
      def closeSession
      end
      
    end

  end

end