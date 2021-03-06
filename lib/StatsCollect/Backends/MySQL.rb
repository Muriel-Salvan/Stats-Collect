#--
# Copyright (c) 2010 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'zlib'

class DateTime

  # Convert this date time to a MySQL time
  def to_MySQLTime
    return Mysql::Time.new(
      self.year,
      self.month,
      self.day,
      self.hour,
      self.min,
      self.sec)
  end

end

module StatsCollect

  module Backends

    class MySQL

      # Constants used to represent differencial data storage
      DIFFDATA_KEY = 'K'
      DIFFDATA_MERGE = 'M'
      DIFFDATA_DELETE = 'D'
      DIFFDATA_MODIFY = 'O'
      DIFFDATA_SAME = 'S'
      # Number of maximal rows to store data differences before creating a new data key
      DIFFDATA_MAX_NUMBER_OF_ROWS = 20

      # Initialize a session of this backend
      #
      # Parameters::
      # * *iConf* (<em>map<Symbol,Object></em>): Configuration of this backend
      def init_session(iConf)
        require 'rUtilAnts/MySQLPool'
        RUtilAnts::MySQLPool::install_mysql_pool_on_object
        lError, @MySQLConnection = connect_to_mysql(iConf[:DBHost], iConf[:DBName], iConf[:DBUser], iConf[:DBPassword])
        if (lError != nil)
          raise lError
        end
        @StatementSelectFromStatsOrders = get_prepared_statement(@MySQLConnection, 'SELECT id, timestamp, locations_list, objects_list, categories_list, status FROM stats_orders WHERE (status = 0 OR status = 1) AND timestamp < ? ORDER BY timestamp DESC', :leave_open => true)
        @StatementDeleteFromStatsOrders = get_prepared_statement(@MySQLConnection, 'DELETE FROM stats_orders WHERE id=?', :leave_open => true)
        @StatementInsertIntoStatsLocations = get_prepared_statement(@MySQLConnection, 'INSERT INTO stats_locations (name) VALUES (?)', :leave_open => true)
        @StatementInsertIntoStatsCategories = get_prepared_statement(@MySQLConnection, 'INSERT INTO stats_categories (name, value_type) VALUES (?, ?)', :leave_open => true)
        @StatementInsertIntoStatsObjects = get_prepared_statement(@MySQLConnection, 'INSERT INTO stats_objects (name) VALUES (?)', :leave_open => true)
        @StatementInsertIntoStatsValues = get_prepared_statement(@MySQLConnection, 'INSERT INTO stats_values (timestamp, stats_location_id, stats_object_id, stats_category_id, value) VALUES (?, ?, ?, ?, ?)', :leave_open => true)
        @StatementSelectFromStatsValues = get_prepared_statement(@MySQLConnection, 'SELECT value FROM stats_values WHERE timestamp = ? AND stats_location_id = ? AND stats_object_id = ? AND stats_category_id = ?', :leave_open => true)
        @StatementInsertIntoStatsBinaryValues = get_prepared_statement(@MySQLConnection, 'INSERT INTO stats_binary_values (timestamp, stats_location_id, stats_object_id, stats_category_id, value) VALUES (?, ?, ?, ?, ?)', :leave_open => true)
        @StatementInsertIntoStatsOrders = get_prepared_statement(@MySQLConnection, 'INSERT INTO stats_orders (timestamp, locations_list, objects_list, categories_list, status) VALUES (?, ?, ?, ?, ?)', :leave_open => true)
        @StatementSelectFromStatsLastKeys = get_prepared_statement(@MySQLConnection, 'SELECT stats_value_id FROM stats_last_keys WHERE stats_location_id = ? AND stats_object_id = ? AND stats_category_id = ?', :leave_open => true)
        @StatementSelectFromStatsBinaryValues = get_prepared_statement(@MySQLConnection, 'SELECT id, value FROM stats_binary_values WHERE stats_location_id = ? AND stats_object_id = ? AND stats_category_id = ? AND id >= ? ORDER BY id', :leave_open => true)
        @StatementInsertIntoStatsLastKeys = get_prepared_statement(@MySQLConnection, 'INSERT INTO stats_last_keys (stats_location_id, stats_object_id, stats_category_id, stats_value_id) VALUES (?, ?, ?, ?)', :leave_open => true)
        @StatementUpdateStatsLastKeys = get_prepared_statement(@MySQLConnection, 'UPDATE stats_last_keys SET stats_value_id = ? WHERE stats_location_id = ? AND stats_object_id = ? AND stats_category_id = ?', :leave_open => true)
      end

      # Get the next stats orders.
      #
      # Parameters::
      # * *oStatsOrdersProxy* (_StatsOrdersProxy_): The stats orders proxy to be used to give stats orders
      def get_stats_orders(oStatsOrdersProxy)
        @StatementSelectFromStatsOrders.execute(DateTime.now.to_MySQLTime)
        @StatementSelectFromStatsOrders.each do |iRow|
          iID, iMySQLTimeStamp, iStrLocations, iStrObjects, iStrCategories, iStatus = iRow
          oStatsOrdersProxy.add_stats_order(
            iID,
            DateTime.civil(
              iMySQLTimeStamp.year,
              iMySQLTimeStamp.month,
              iMySQLTimeStamp.day,
              iMySQLTimeStamp.hour,
              iMySQLTimeStamp.minute,
              iMySQLTimeStamp.second),
            iStrLocations.split('|'),
            iStrObjects.split('|'),
            iStrCategories.split('|'),
            iStatus)
        end
      end

      # Dequeue the given stat orders IDs.
      # Code to begin a new transaction can be set in this method too. In this case, the dequeue should be part of the transaction, or it will have to be re-enqueued during rollback method call (otherwise orders will be lost).
      #
      # Parameters::
      # * *iLstStatsOrderIDs* (<em>list<Integer></em>): The list of stats order IDs to dequeue
      def dequeue_stats_orders(iLstStatsOrderIDs)
        @MySQLConnection.query('start transaction')
        iLstStatsOrderIDs.each do |iStatsOrderID|
          @StatementDeleteFromStatsOrders.execute(iStatsOrderID)
        end
      end

      # Get the list of known locations
      #
      # Return::
      # * <em>map<String,Integer></em>: Each location with its associated ID
      def get_known_locations
        rKnownLocations = {}

        @MySQLConnection.query('SELECT name, id FROM stats_locations').each do |iRow|
          iLocationName, iLocationID = iRow
          rKnownLocations[iLocationName] = iLocationID.to_i
        end

        return rKnownLocations
      end

      # Get the list of known categories
      #
      # Return::
      # * <em>map<String,[Integer,Integer]></em>: Each category with its associated ID and value type
      def get_known_categories
        rKnownCategories = {}

        @MySQLConnection.query('SELECT name, id, value_type FROM stats_categories').each do |iRow|
          iCategoryName, iCategoryID, iValueType = iRow
          rKnownCategories[iCategoryName] = [ iCategoryID.to_i, iValueType.to_i ]
        end

        return rKnownCategories
      end

      # Get the list of known objects
      #
      # Return::
      # * <em>map<String,Integer></em>: Each object with its associated ID
      def get_known_objects
        rKnownObjects = {}

        @MySQLConnection.query('SELECT name, id FROM stats_objects').each do |iRow|
          iObjectName, iObjectID = iRow
          rKnownObjects[iObjectName] = iObjectID.to_i
        end

        return rKnownObjects
      end

      # Add a new location
      #
      # Parameters::
      # * *iLocation* (_String_): The location
      # Return::
      # * _Integer_: Its resulting ID
      def add_location(iLocation)
        @StatementInsertIntoStatsLocations.execute(iLocation)

        return @StatementInsertIntoStatsLocations.insert_id
      end

      # Add a new category
      #
      # Parameters::
      # * *iCategory* (_String_): The category
      # * *iValueType* (_Integer_): Its value type
      # Return::
      # * _Integer_: Its resulting ID
      def add_category(iCategory, iValueType)
        @StatementInsertIntoStatsCategories.execute(iCategory, iValueType)

        return @StatementInsertIntoStatsCategories.insert_id
      end

      # Add a new object
      #
      # Parameters::
      # * *iObject* (_String_): The object
      # Return::
      # * _Integer_: Its resulting ID
      def add_object(iObject)
        @StatementInsertIntoStatsObjects.execute(iObject)

        return @StatementInsertIntoStatsObjects.insert_id
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
        # Do we need to store this value ID in the last keys ?
        lStoreInLastKeys = false
        lExistingLastKey = false
        lInsertStatement = @StatementInsertIntoStatsValues
        # Convert the value to its internal representation
        lStrValue = nil
        case iValueType
        when STATS_VALUE_TYPE_INTEGER
          lStrValue = iValue.to_s
        when STATS_VALUE_TYPE_FLOAT
          lStrValue = iValue.to_s
        when STATS_VALUE_TYPE_PERCENTAGE
          lStrValue = iValue.to_s
        when STATS_VALUE_TYPE_UNKNOWN
          lStrValue = iValue.to_s
        when STATS_VALUE_TYPE_MAP
          lInsertStatement = @StatementInsertIntoStatsBinaryValues
          # This is a special case:
          # We retrieve the last value of this statistic, and decide if we write it completely, or just write a diff.
          lLastKeyStatsValueID = nil
          @StatementSelectFromStatsLastKeys.execute(iLocationID, iObjectID, iCategoryID)
          # Should be only 1 row, or none
          @StatementSelectFromStatsLastKeys.each do |iRow|
            lLastKeyStatsValueID = iRow[0]
          end
          if (lLastKeyStatsValueID == nil)
            # First value to store: store a key
            lStrValue = "#{DIFFDATA_KEY}#{Zlib::Deflate.new.deflate(Marshal.dump(iValue), Zlib::FINISH)}"
            lStoreInLastKeys = true
          else
            # There was already a previous key for this value.
            lExistingLastKey = true
            # Reconstruct the value by getting all the stats_values since this key.
            lExistingValue = nil
            @StatementSelectFromStatsBinaryValues.execute(iLocationID, iObjectID, iCategoryID, lLastKeyStatsValueID)
            # If too much rows, we just create a new key
            lNbrRows = @StatementSelectFromStatsBinaryValues.num_rows
            if ((lNbrRows == 0) or
                (lNbrRows >= DIFFDATA_MAX_NUMBER_OF_ROWS))
              lStrValue = "#{DIFFDATA_KEY}#{Zlib::Deflate.new.deflate(Marshal.dump(iValue), Zlib::FINISH)}"
              lStoreInLastKeys = true
            else
              @StatementSelectFromStatsBinaryValues.each do |iRow|
                iID, iRowValue = iRow
                # Read the type of this diff data
                case iRowValue[0..0]
                when DIFFDATA_KEY
                  lExistingValue = Marshal.load(Zlib::Inflate.new.inflate(iRowValue[1..-1]))
                when DIFFDATA_MERGE
                  lExistingValue.merge!(Marshal.load(iRowValue[1..-1]))
                when DIFFDATA_DELETE
                  lValuesToDelete = Marshal.load(iRowValue[1..-1])
                  lExistingValue.delete_if do |iKey, iExistingValue|
                    next (lValuesToDelete.include?(iKey))
                  end
                when DIFFDATA_MODIFY
                  lValuesToDelete, lValuesToModify = Marshal.load(iRowValue[1..-1])
                  lExistingValue.delete_if do |iKey, iExistingValue|
                    next (lValuesToDelete.include?(iKey))
                  end
                  lExistingValue.merge!(lValuesToModify)
                when DIFFDATA_SAME
                  # Nothing to do
                else
                  log_err "Unknown diff value type: #{iRowValue[0..0]}"
                  raise RuntimeError.new("Unknown diff value type: #{iRowValue[0..0]}")
                end
              end
              # Now compute the difference between the existing value and the new one
              lValuesToDelete = []
              lValuesToMerge = {}
              iValue.each do |iKey, iNewValue|
                if (lExistingValue.has_key?(iKey))
                  if (iNewValue != lExistingValue[iKey])
                    # A modified value: add it
                    lValuesToMerge[iKey] = iNewValue
                  end
                else
                  # A new value: add it
                  lValuesToMerge[iKey] = iNewValue
                end
              end
              lExistingValue.each do |iKey, iExistingValue|
                if (!iValue.has_key?(iKey))
                  # A missing value: delete it
                  lValuesToDelete << iKey
                end
              end
              if (lValuesToDelete.empty?)
                if (lValuesToMerge.empty?)
                  lStrValue = DIFFDATA_SAME
                else
                  lStrValue = "#{DIFFDATA_MERGE}#{Marshal.dump(lValuesToMerge)}"
                end
              elsif (lValuesToMerge.empty?)
                lStrValue = "#{DIFFDATA_DELETE}#{Marshal.dump(lValuesToDelete)}"
              else
                lStrValue = "#{DIFFDATA_MODIFY}#{Marshal.dump([lValuesToDelete,lValuesToMerge])}"
              end
            end
          end
        when STATS_VALUE_TYPE_STRING
          lStrValue = iValue
        else
          log_err "Unknown category value type: #{iValueType}. It will be treated as Unknown."
          lStrValue = iValue.to_s
        end
        # Add the new stat in the DB for real
        lInsertStatement.execute(iTimeStamp.to_MySQLTime, iLocationID, iObjectID, iCategoryID, lStrValue)
        # Store the last key idf needed
        if (lStoreInLastKeys)
          lNewStatValueID = lInsertStatement.insert_id
          if (lExistingLastKey)
            @StatementUpdateStatsLastKeys.execute(lNewStatValueID, iLocationID, iObjectID, iCategoryID)
          else
            @StatementInsertIntoStatsLastKeys.execute(iLocationID, iObjectID, iCategoryID, lNewStatValueID)
          end
        end
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
        rValue = nil

        @StatementSelectFromStatsValues.execute(iTimeStamp.to_MySQLTime, iLocationID, iObjectID, iCategoryID)
        if (@StatementSelectFromStatsValues.num_rows > 0)
          @StatementSelectFromStatsValues.each do |iRow|
            lStrValue = iRow[0]
            case iValueType
            when STATS_VALUE_TYPE_INTEGER
              rValue = Integer(lStrValue)
            when STATS_VALUE_TYPE_FLOAT
              rValue = Float(lStrValue)
            when STATS_VALUE_TYPE_PERCENTAGE
              rValue = Float(lStrValue)
            when STATS_VALUE_TYPE_UNKNOWN
              rValue = lStrValue
            when STATS_VALUE_TYPE_MAP
              # TODO
              rValue = lStrValue
            when STATS_VALUE_TYPE_STRING
              rValue = lStrValue
            else
              log_err "Unknown category value type: #{iValueType}. It will be treated as Unknown."
              rValue = lStrValue
            end
            break
          end
        end

        return rValue
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
        lMySQLTime = Mysql::Time.new(
          iTimeStamp.year,
          iTimeStamp.month,
          iTimeStamp.day,
          iTimeStamp.hour,
          iTimeStamp.min,
          iTimeStamp.sec)
        @StatementInsertIntoStatsOrders.execute(lMySQLTime, iLstLocations.join('|'), iLstObjects.join('|'), iLstCategories.join('|'), iStatus)
      end

      # Commit the current stats order transaction
      def commit
        @MySQLConnection.query('commit')
      end

      # Rollback the current stats order transaction
      def rollback
        @MySQLConnection.query('rollback')
      end

      # Close a session of this backend
      def close_session
        close_prepared_statement(@MySQLConnection, @StatementSelectFromStatsOrders)
        close_prepared_statement(@MySQLConnection, @StatementDeleteFromStatsOrders)
        close_prepared_statement(@MySQLConnection, @StatementInsertIntoStatsLocations)
        close_prepared_statement(@MySQLConnection, @StatementInsertIntoStatsCategories)
        close_prepared_statement(@MySQLConnection, @StatementInsertIntoStatsObjects)
        close_prepared_statement(@MySQLConnection, @StatementInsertIntoStatsValues)
        close_prepared_statement(@MySQLConnection, @StatementSelectFromStatsValues)
        close_prepared_statement(@MySQLConnection, @StatementInsertIntoStatsBinaryValues)
        close_prepared_statement(@MySQLConnection, @StatementInsertIntoStatsOrders)
        close_prepared_statement(@MySQLConnection, @StatementSelectFromStatsLastKeys)
        close_prepared_statement(@MySQLConnection, @StatementSelectFromStatsBinaryValues)
        close_prepared_statement(@MySQLConnection, @StatementInsertIntoStatsLastKeys)
        close_prepared_statement(@MySQLConnection, @StatementUpdateStatsLastKeys)
        close_mysql(@MySQLConnection)
      end

    end

  end

end