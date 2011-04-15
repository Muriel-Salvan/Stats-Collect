#--
# Copyright (c) 2010 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  # The stats proxy, used by plugins to populate stats
  class StatsProxy

    # List of recoverable orders as stated by the plugin (objects, categories)
    #   list< [ list<String>, list<String> ] >
    attr_reader :RecoverableOrders

    # List of unrecoverable orders as stated by the plugin (objects, categories)
    #   list< [ list<String>, list<String> ] >
    attr_reader :UnrecoverableOrders

    # List of statistics to add
    #   list< CheckExistenceBeforeAdd?, Time, Location, Object, Category, Value >
    attr_reader :StatsToAdd

    # Constructor
    # 
    # Parameters:
    # * *iLstObjects* (<em>list<String></em>): List of objects to filter (can be empty for all)
    # * *iLstCategories* (<em>list<String></em>): List of categories to filter (can be empty for all)
    # * *iBackend* (_Object_): The backend
    # * *iLocation* (_String_): Name of the default location
    def initialize(iLstObjects, iLstCategories, iBackend, iLocation)
      @LstObjects, @LstCategories, @Backend, @Location = iLstObjects, iLstCategories, iBackend, iLocation
      @RecoverableOrders = []
      @UnrecoverableOrders = []
      @StatsToAdd = []
    end

    # Check if a specific object is included in the filter
    #
    # Parameters:
    # * *iObjectName* (_String_): The object to check
    # Return:
    # * _Boolean_: Is the object included in the filter ?
    def isObjectIncluded?(iObjectName)
      rIncluded = false

      if (@LstObjects.empty?)
        rIncluded = true
      else
        rIncluded = @LstObjects.include?(iObjectName)
      end

      return rIncluded
    end

    # Check if a specific category is included in the filter
    #
    # Parameters:
    # * *iCategoryName* (_String_): The category to check
    # Return:
    # * _Boolean_: Is the category included in the filter ?
    def isCategoryIncluded?(iCategoryName)
      rIncluded = false

      if (@LstCategories.empty?)
        rIncluded = true
      else
        rIncluded = @LstCategories.include?(iCategoryName)
      end

      return rIncluded
    end

    # Add a new stat
    #
    # Parameters:
    # * *iObject* (_String_): The object
    # * *iCategory* (_String_): The category
    # * *iValue* (_Object_): The value
    # * *iOptions* (<em>map<Symbol,Object></em>): Additional options [optional = {}]:
    # ** *:Timestamp* (_DateTime_): Time stamp of this stat [optional = DateTime.now]
    # ** *:Location* (_String_): Location of this stat [optional = <PluginName>]
    def addStat(iObject, iCategory, iValue, iOptions = {})
      lTimestamp = (iOptions[:Timestamp] || DateTime.now)
      lLocation = (iOptions[:Location] || @Location)
      @StatsToAdd << [
        (iOptions[:Timestamp] != nil),
        lTimestamp,
        lLocation,
        iObject,
        iCategory,
        iValue
      ]
    end

    # Add a stats list
    #
    # Parameters:
    # * *iLstStats* (<em>list<[...]></em>): List of stats. See :StatsToAdd property for internal fields to set.
    def addStatsList(iLstStats)
      @StatsToAdd.concat(iLstStats)
    end

    # Add a new recoverable order
    #
    # Parameters:
    # * *iLstObjects* (<em>list<String></em>): The failing objects
    # * *iLstCategories* (<em>list<String></em>): The failing categories
    def addRecoverableOrder(iLstObjects, iLstCategories)
      @RecoverableOrders << [ iLstObjects, iLstCategories ]
    end

    # Add a new unrecoverable order
    #
    # Parameters:
    # * *iLstObjects* (<em>list<String></em>): The failing objects
    # * *iLstCategories* (<em>list<String></em>): The failing categories
    def addUnrecoverableOrder(iLstObjects, iLstCategories)
      @UnrecoverableOrders << [ iLstObjects, iLstCategories ]
    end

    # Get the list of categories
    #
    # Return:
    # * <em>map<String,[Integer,Integer]></em>: The list of categories and their associated ID and value type
    def getCategories
      return @Backend.getKnownCategories
    end

    # Get the list of objects
    #
    # Return:
    # * <em>map<String,Integer></em>: The list of objects and their associated ID
    def getObjects
      return @Backend.getKnownObjects
    end

    # Get the list of locations
    #
    # Return:
    # * <em>map<String,Integer></em>: The list of locations and their associated ID
    def getLocations
      return @Backend.getKnownLocations
    end

  end

end
