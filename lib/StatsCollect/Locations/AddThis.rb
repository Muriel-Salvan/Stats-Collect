#--
# Copyright (c) 2010 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Locations

    class AddThis

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
        require 'mechanize'
        lMechanizeAgent = Mechanize.new
        # Get the number of shares
        if (oStatsProxy.isCategoryIncluded?('Monthly shares'))
          getDomains(oStatsProxy, lMechanizeAgent, iConf, 'month', 'Monthly shares')
        end
        if (oStatsProxy.isCategoryIncluded?('Weekly shares'))
          getDomains(oStatsProxy, lMechanizeAgent, iConf, 'week', 'Weekly shares')
        end
        if (oStatsProxy.isCategoryIncluded?('Daily shares'))
          getDomains(oStatsProxy, lMechanizeAgent, iConf, 'day', 'Daily shares')
        end
      end
      
      private

      # Get domains stats for a given period
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The mechanize agent
      # * *iConf* (<em>map<Symbol,Object></em>): The configuration associated to this plugin
      # * *iAddThisPeriod* (_String_): The period given to AddThis API
      # * *iCategory* (_String_): Corresponding category
      def getDomains(oStatsProxy, iMechanizeAgent, iConf, iAddThisPeriod, iCategory)
        iMechanizeAgent.auth(iConf[:Login], iConf[:Password])
        lData = eval(iMechanizeAgent.get_file("http://api.addthis.com/analytics/1.0/pub/shares/domain.json?period=#{iAddThisPeriod}").gsub(/:/,'=>'))
        iConf[:Objects].each do |iObject|
          lNbrShares = 0
          lData.each do |iDataInfo|
            if (iDataInfo['domain'] == iObject)
              lNbrShares = iDataInfo['shares']
            end
          end
          oStatsProxy.addStat(iObject, iCategory, lNbrShares)
        end
      end

    end

  end

end
