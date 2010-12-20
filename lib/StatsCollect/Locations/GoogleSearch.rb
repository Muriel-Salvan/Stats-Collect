#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Locations

    class GoogleSearch

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
        iConf[:Objects].each do |iObject|
          if ((oStatsProxy.isObjectIncluded?(iObject)) and
              (oStatsProxy.isCategoryIncluded?('Search results')))
            require 'mechanize'
            lMechanizeAgent = Mechanize.new
            lProfilePage = lMechanizeAgent.get("http://www.google.com/search?q=#{URI.escape(iObject)}")
            lNbrSearchResults = Integer(lProfilePage.root.css('div#resultStats').first.content.delete(',').strip.match(/ (\d*) /)[1])
            oStatsProxy.addStat(iObject, 'Search results', lNbrSearchResults)
          end
        end
      end

    end

  end

end
