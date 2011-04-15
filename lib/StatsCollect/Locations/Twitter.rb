#--
# Copyright (c) 2010 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
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
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iConf* (<em>map<Symbol,Object></em>): The configuration associated to this plugin
      # * *iLstObjects* (<em>list<String></em>): List of objects to filter (can be empty for all)
      # * *iLstCategories* (<em>list<String></em>): List of categories to filter (can be empty for all)
      def execute(oStatsProxy, iConf, iLstObjects, iLstCategories)
        if ((oStatsProxy.isObjectIncluded?('Global')) and
            ((oStatsProxy.isCategoryIncluded?('Following')) or
             (oStatsProxy.isCategoryIncluded?('Followers')) or
             (oStatsProxy.isCategoryIncluded?('Lists followers')) or
             (oStatsProxy.isCategoryIncluded?('Tweets'))))
          require 'mechanize'
          lMechanizeAgent = Mechanize.new
          lProfilePage = lMechanizeAgent.get("http://twitter.com/#{iConf[:Name]}")
          lNbrFollowing = Integer(lProfilePage.root.css('span#following_count').first.content.strip)
          lNbrFollowers = Integer(lProfilePage.root.css('span#follower_count').first.content.strip)
          lNbrLists = Integer(lProfilePage.root.css('span#lists_count').first.content.strip)
          lNbrTweets = Integer(lProfilePage.root.css('span#update_count').first.content.strip)
          oStatsProxy.addStat('Global', 'Following', lNbrFollowing)
          oStatsProxy.addStat('Global', 'Followers', lNbrFollowers)
          oStatsProxy.addStat('Global', 'Lists followers', lNbrLists)
          oStatsProxy.addStat('Global', 'Tweets', lNbrTweets)
        end
      end

    end

  end

end
