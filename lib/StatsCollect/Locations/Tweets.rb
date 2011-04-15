#--
# Copyright (c) 2010 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Locations

    class Tweets

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
        # Get the number of likes from Facebook
        if (oStatsProxy.isCategoryIncluded?('Tweets'))
          lFailedObjects = []
          iConf[:Objects].each do |iObject|
            if (oStatsProxy.isObjectIncluded?(iObject))
              lTweetsData = lMechanizeAgent.get_file("http://urls.api.twitter.com/1/urls/count.json?url=#{iObject}").gsub(/:/,'=>')
              if (lTweetsData.match(/Unable to access URL counting services/) != nil)
                # An error occurred: we can try again
                logErr "Error while fetching Tweets for #{iObject}: #{lTweetsData}"
                lFailedObjects << iObject
              else
                lNbrTweets = eval(lTweetsData)['count']
                oStatsProxy.addStat(iObject, 'Tweets', lNbrTweets)
              end
            end
          end
          if (!lFailedObjects.empty?)
            oStatsProxy.addRecoverableOrder(lFailedObjects, ['Tweets'])
          end
        end
      end

    end

  end

end
