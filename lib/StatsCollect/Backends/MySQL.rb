#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

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

      # Initialize a session of this backend
      #
      # Parameters:
      # * *iConf* (<em>map<Symbol,Object></em>): Configuration of this backend
      def initSession(iConf)
        require 'mysql'
        @MySQLConnection = Mysql.new(iConf[:DBHost], iConf[:DBUser], iConf[:DBPassword], iConf[:DBName])
        @StatementSelectFromStatsOrders = @MySQLConnection.prepare('SELECT id, timestamp, objects_list, categories_list, locations_list, status FROM stats_orders WHERE (status = 0 OR status = 1) AND timestamp < ? ORDER BY timestamp DESC')
        @StatementDeleteFromStatsOrders = @MySQLConnection.prepare('DELETE FROM stats_orders WHERE id=?')
        @StatementInsertIntoStatsLocations = @MySQLConnection.prepare('INSERT INTO stats_locations (name) VALUES (?)')
        @StatementInsertIntoStatsCategories = @MySQLConnection.prepare('INSERT INTO stats_categories (name, value_type) VALUES (?, ?)')
        @StatementInsertIntoStatsObjects = @MySQLConnection.prepare('INSERT INTO stats_objects (name) VALUES (?)')
        @StatementInsertIntoStatsValues = @MySQLConnection.prepare('INSERT INTO stats_values (timestamp, stats_object_id, stats_category_id, stats_location_id, value) VALUES (?, ?, ?, ?, ?)')
        @StatementInsertIntoStatsOrders = @MySQLConnection.prepare('INSERT INTO stats_orders (timestamp, locations_list, objects_list, categories_list, status) VALUES (?, ?, ?, ?, ?)')
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
          @LstStatsOrders = []
          @StatementSelectFromStatsOrders.execute(DateTime.now.to_MySQLTime)
          @StatementSelectFromStatsOrders.each do |iRow|
            @LstStatsOrders << iRow.clone
          end
        end
        if (!@LstStatsOrders.empty?)
          lID, lMySQLTimeStamp, lStrLocations, lStrObjects, lStrCategories, rStatus = @LstStatsOrders.pop
          rTimeStamp = DateTime.civil(
            lMySQLTimeStamp.year,
            lMySQLTimeStamp.month,
            lMySQLTimeStamp.day,
            lMySQLTimeStamp.hour,
            lMySQLTimeStamp.minute,
            lMySQLTimeStamp.second)
          rLstLocations = lStrLocations.split('|')
          rLstObjects = lStrObjects.split('|')
          rLstCategories = lStrCategories.split('|')
          @MySQLConnection.query('start transaction')
          @StatementDeleteFromStatsOrders.execute(lID)
        end

        return rTimeStamp, rLstLocations, rLstObjects, rLstCategories, rStatus
      end

      # Get the list of known locations
      #
      # Return:
      # * <em>map<String,Integer></em>: Each location with its associated ID
      def getKnownLocations
        rKnownLocations = {}

        @MySQLConnection.query('SELECT name, id FROM stats_locations').each do |iRow|
          iLocationName, iLocationID = iRow
          rKnownLocations[iLocationName] = iLocationID.to_i
        end

        return rKnownLocations
      end

      # Get the list of known categories
      #
      # Return:
      # * <em>map<String,[Integer,Integer]></em>: Each category with its associated ID and value type
      def getKnownCategories
        rKnownCategories = {}

        @MySQLConnection.query('SELECT name, id, value_type FROM stats_categories').each do |iRow|
          iCategoryName, iCategoryID, iValueType = iRow
          rKnownCategories[iCategoryName] = [ iCategoryID.to_i, iValueType.to_i ]
        end

        return rKnownCategories
      end

      # Get the list of known objects
      #
      # Return:
      # * <em>map<String,Integer></em>: Each object with its associated ID
      def getKnownObjects
        rKnownObjects = {}

        @MySQLConnection.query('SELECT name, id FROM stats_objects').each do |iRow|
          iObjectName, iObjectID = iRow
          rKnownObjects[iObjectName] = iObjectID.to_i
        end

        return rKnownObjects
      end

      # Add a new location
      #
      # Parameters:
      # * *iLocation* (_String_): The location
      # Return:
      # * _Integer_: Its resulting ID
      def addLocation(iLocation)
        @StatementInsertIntoStatsLocations.execute(iLocation)

        return @StatementInsertIntoStatsLocations.insert_id
      end

      # Add a new category
      #
      # Parameters:
      # * *iCategory* (_String_): The category
      # * *iValueType* (_Integer_): Its value type
      # Return:
      # * _Integer_: Its resulting ID
      def addCategory(iCategory, iValueType)
        @StatementInsertIntoStatsCategories.execute(iCategory, iValueType)

        return @StatementInsertIntoStatsCategories.insert_id
      end

      # Add a new object
      #
      # Parameters:
      # * *iObject* (_String_): The object
      # Return:
      # * _Integer_: Its resulting ID
      def addObject(iObject)
        @StatementInsertIntoStatsObjects.execute(iObject)

        return @StatementInsertIntoStatsObjects.insert_id
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
        else
          logErr "Unknown category value type: #{iValueType}. It will be treated as Unknown."
          lStrValue = iValue.to_s
        end
        # Add the new stat in the DB for real
        @StatementInsertIntoStatsValues.execute(iTimeStamp.to_MySQLTime, iObjectID, iCategoryID, iLocationID, lStrValue)
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
      def closeSession
        @StatementSelectFromStatsOrders.close
        @StatementDeleteFromStatsOrders.close
        @StatementInsertIntoStatsLocations.close
        @StatementInsertIntoStatsCategories.close
        @StatementInsertIntoStatsObjects.close
        @StatementInsertIntoStatsValues.close
        @StatementInsertIntoStatsOrders.close
      end

    end

  end

end