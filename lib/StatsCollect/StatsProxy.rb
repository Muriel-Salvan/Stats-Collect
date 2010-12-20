#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
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
    #   list< Time, Object, Category, Value >
    attr_reader :StatsToAdd

    # Constructor
    # 
    # Parameters:
    # * *iLstObjects* (<em>list<String></em>): List of objects to filter (can be empty for all)
    # * *iLstCategories* (<em>list<String></em>): List of categories to filter (can be empty for all)
    def initialize(iLstObjects, iLstCategories)
      @LstObjects, @LstCategories = iLstObjects, iLstCategories
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
    def addStat(iObject, iCategory, iValue)
      @StatsToAdd << [
        DateTime.now,
        iObject,
        iCategory,
        iValue
      ]
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

  end

end
