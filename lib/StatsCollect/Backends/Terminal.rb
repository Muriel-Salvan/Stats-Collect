#--
# Copyright (c) 2010 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Backends

    class Terminal

      # Initialize a session of this backend
      #
      # Parameters::
      # * *iConf* (<em>map<Symbol,Object></em>): Configuration of this backend
      def init_session(iConf)
        @IdxID = 0
        log_msg 'Session initialized.'
      end

      # Get the next stats orders.
      #
      # Parameters::
      # * *oStatsOrdersProxy* (_StatsOrdersProxy_): The stats orders proxy to be used to give stats orders
      def get_stats_orders(oStatsOrdersProxy)
        oStatsOrdersProxy.add_stats_order(0, DateTime.now, [], [], [], STATS_ORDER_STATUS_TOBEPROCESSED)
#        oStatsOrdersProxy.add_stats_order(0, DateTime.now, ['MySpace'], [], ['Friends list'], STATS_ORDER_STATUS_TOBEPROCESSED)
        log_msg 'Added stats order 0.'
      end

      # Dequeue the given stat orders IDs.
      # Code to begin a new transaction can be set in this method too. In this case, the dequeue should be part of the transaction, or it will have to be re-enqueued during rollback method call (otherwise orders will be lost).
      #
      # Parameters::
      # * *iLstStatsOrderIDs* (<em>list<Integer></em>): The list of stats order IDs to dequeue
      def dequeue_stats_orders(iLstStatsOrderIDs)
        log_msg "Transaction started and stats orders dequeued: #{iLstStatsOrderIDs.join(', ')}"
      end

      # Get the list of known locations
      #
      # Return::
      # * <em>map<String,Integer></em>: Each location with its associated ID
      def get_known_locations
        rKnownLocations = {}

        return rKnownLocations
      end

      # Get the list of known categories
      #
      # Return::
      # * <em>map<String,[Integer,Integer]></em>: Each category with its associated ID and value type
      def get_known_categories
        rKnownCategories = {}

        return rKnownCategories
      end

      # Get the list of known objects
      #
      # Return::
      # * <em>map<String,Integer></em>: Each object with its associated ID
      def get_known_objects
        rKnownObjects = {}

        return rKnownObjects
      end

      # Add a new location
      #
      # Parameters::
      # * *iLocation* (_String_): The location
      # Return::
      # * _Integer_: Its resulting ID
      def add_location(iLocation)
        log_msg "Added location: #{iLocation} (#{@IdxID})"
        @IdxID += 1

        return @IdxID-1
      end

      # Add a new category
      #
      # Parameters::
      # * *iCategory* (_String_): The category
      # * *iValueType* (_Integer_): Its value type
      # Return::
      # * _Integer_: Its resulting ID
      def add_category(iCategory, iValueType)
        log_msg "Added category: #{iCategory}, #{iValueType} (#{@IdxID})"
        @IdxID += 1

        return @IdxID-1
      end

      # Add a new object
      #
      # Parameters::
      # * *iObject* (_String_): The object
      # Return::
      # * _Integer_: Its resulting ID
      def add_object(iObject)
        log_msg "Added object: #{iObject} (#{@IdxID})"
        @IdxID += 1

        return @IdxID-1
      end

      # Add a new stat
      #
      # Parameters::
      # * *iTimeStamp* (_DateTime_): The time stamp
      # * *iLocationID* (_Integer_): Location ID
      # * *iObjectID* (_Integer_): Object ID
      # * *iCategoryID* (_Integer_): Category ID
      # * *iValue* (_Object_): The value to store
      # * *iValueType* (_Integer_): The value type
      def add_stat(iTimeStamp, iLocationID, iObjectID, iCategoryID, iValue, iValueType)
        log_msg "Added stat: #{iTimeStamp} | Location: #{iLocationID} | Object: #{iObjectID} | Category: #{iCategoryID} (value type: #{iValueType}) | Value: #{iValue}"
      end

      # Get an existing stat value
      #
      # Parameters::
      # * *iTimeStamp* (_DateTime_): The timestamp
      # * *iLocationID* (_Integer_): The location ID
      # * *iObjectID* (_Integer_): The object ID
      # * *iCategoryID* (_Integer_): The category ID
      # * *iValueType* (_Integer_): The value type
      # Return::
      # * _Object_: The corresponding value, or nil if none
      def get_stat(iTimeStamp, iLocationID, iObjectID, iCategoryID, iValueType)
        log_msg "Get stat: #{iTimeStamp} | Location: #{iLocationID} | Object: #{iObjectID} | Category: #{iCategoryID} (value type: #{iValueType})"

        return nil
      end

      # Add a new stats order
      #
      # Parameters::
      # * *iTimeStamp* (_DateTime_): The time stamp
      # * *iLstLocations* (<em>list<String></em>): List of locations
      # * *iLstObjects* (<em>list<String></em>): List of objects
      # * *iLstCategories* (<em>list<String></em>): List of categories
      # * *iStatus* (_Integer_): The order status
      def put_new_stats_order(iTimeStamp, iLstLocations, iLstObjects, iLstCategories, iStatus)
        log_msg "Added new stats order: #{iTimeStamp} | Locations: #{iLstLocations.join(', ')} | Objects: #{iLstObjects.join(', ')} | Categories: #{iLstCategories.join(', ')} | Status: #{iStatus}"
      end

      # Commit the current stats order transaction
      def commit
        log_msg 'Transaction committed'
      end

      # Rollback the current stats order transaction
      def rollback
        log_msg 'Transaction rollbacked'
      end

      # Close a session of this backend
      def close_session
      end
      
    end

  end

end