#--
# Copyright (c) 2010 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Locations

    class Twitter

      # Execute the plugin.
      # This method has to add the stats and errors to the proxy.
      # It can filter only objects and categories given.
      # It has access to its configuration.
      #
      # Parameters::
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iConf* (<em>map<Symbol,Object></em>): The configuration associated to this plugin
      # * *iLstObjects* (<em>list<String></em>): List of objects to filter (can be empty for all)
      # * *iLstCategories* (<em>list<String></em>): List of categories to filter (can be empty for all)
      def execute(oStatsProxy, iConf, iLstObjects, iLstCategories)
        if ((oStatsProxy.is_object_included?('Global')) and
            ((oStatsProxy.is_category_included?('Following')) or
             (oStatsProxy.is_category_included?('Followers')) or
             (oStatsProxy.is_category_included?('Lists followers')) or
             (oStatsProxy.is_category_included?('Tweets'))))
          require 'mechanize'
          lMechanizeAgent = Mechanize.new
          lProfilePage = lMechanizeAgent.get("http://twitter.com/#{iConf[:Name]}")
          lNbrFollowing = Integer(lProfilePage.root.css('span#following_count').first.content.strip)
          lNbrFollowers = Integer(lProfilePage.root.css('span#follower_count').first.content.strip)
          lNbrLists = Integer(lProfilePage.root.css('span#lists_count').first.content.strip)
          lNbrTweets = Integer(lProfilePage.root.css('span#update_count').first.content.strip)
          oStatsProxy.add_stat('Global', 'Following', lNbrFollowing)
          oStatsProxy.add_stat('Global', 'Followers', lNbrFollowers)
          oStatsProxy.add_stat('Global', 'Lists followers', lNbrLists)
          oStatsProxy.add_stat('Global', 'Tweets', lNbrTweets)
        end
      end

    end

  end

end
