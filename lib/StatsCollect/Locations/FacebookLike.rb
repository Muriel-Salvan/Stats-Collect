#--
# Copyright (c) 2010 - 2012 Muriel Salvan (muriel@x-aeon.com)
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
      # Parameters::
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iConf* (<em>map<Symbol,Object></em>): The configuration associated to this plugin
      # * *iLstObjects* (<em>list<String></em>): List of objects to filter (can be empty for all)
      # * *iLstCategories* (<em>list<String></em>): List of categories to filter (can be empty for all)
      def execute(oStatsProxy, iConf, iLstObjects, iLstCategories)
        require 'mechanize'
        lMechanizeAgent = Mechanize.new
        # Get the number of likes from Facebook
        lErrorObjects = []
        if (oStatsProxy.is_category_included?('Likes'))
          iConf[:Objects].each do |iObject|
            if (oStatsProxy.is_object_included?(iObject))
              lLikesContent = lMechanizeAgent.get("http://www.facebook.com/plugins/like.php?href=#{iObject}").root.css('span.connect_widget_not_connected_text').first.content.delete(',')
              lMatch = lLikesContent.match(/^(\d*) likes./)
              if (lMatch == nil)
                log_err "Unable to parse FacebookLike output for object #{iObject}: #{lLikesContent}"
                lErrorObjects << iObject
              else
                lNbrLikes = Integer(lMatch[1])
                oStatsProxy.add_stat(iObject, 'Likes', lNbrLikes)
              end
            end
          end
        end
        if (!lErrorObjects.empty?)
          oStatsProxy.add_unrecoverable_order(lErrorObjects, ['Likes'])
        end
      end

    end

  end

end
