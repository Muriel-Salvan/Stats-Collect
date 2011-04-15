#--
# Copyright (c) 2010 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Locations

    class FacebookLike

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
        lErrorObjects = []
        if (oStatsProxy.isCategoryIncluded?('Likes'))
          iConf[:Objects].each do |iObject|
            if (oStatsProxy.isObjectIncluded?(iObject))
              lLikesContent = lMechanizeAgent.get("http://www.facebook.com/plugins/like.php?href=#{iObject}").root.css('span.connect_widget_not_connected_text').first.content.delete(',')
              lMatch = lLikesContent.match(/^(\d*) likes./)
              if (lMatch == nil)
                logErr "Unable to parse FacebookLike output for object #{iObject}: #{lLikesContent}"
                lErrorObjects << iObject
              else
                lNbrLikes = Integer(lMatch[1])
                oStatsProxy.addStat(iObject, 'Likes', lNbrLikes)
              end
            end
          end
        end
        if (!lErrorObjects.empty?)
          oStatsProxy.addUnrecoverableOrder(lErrorObjects, ['Likes'])
        end
      end

    end

  end

end
