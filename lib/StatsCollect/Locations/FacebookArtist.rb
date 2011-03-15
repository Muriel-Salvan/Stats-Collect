#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Locations

    class FacebookArtist

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
        # Set a specific user agent, as Facebook will treat our agent as a mobile one
        lMechanizeAgent.user_agent = 'Mozilla/5.0 (Windows; U; Windows NT 6.1; fr; rv:1.9.2.13) Gecko/20101203 Firefox/3.6.13'
        lLoginForm = lMechanizeAgent.get('http://www.facebook.com').forms[0]
        lLoginForm.email = iConf[:LoginEMail]
        lLoginForm.pass = iConf[:LoginPassword]
        # Submit to get to the home page
        lMechanizeAgent.submit(lLoginForm, lLoginForm.buttons.first)
        if ((oStatsProxy.isObjectIncluded?('Global')) and
            (oStatsProxy.isCategoryIncluded?('Likes')))
          getArtistProfile(oStatsProxy, lMechanizeAgent, iConf)
        end
      end

      # Get the artist profile statistics
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      # * *iConf* (<em>map<Symbol,Object></em>): The conf
      def getArtistProfile(oStatsProxy, iMechanizeAgent, iConf)
        lProfilePage = iMechanizeAgent.get("http://www.facebook.com/pages/#{iConf[:PageID]}")
        lNbrLikes = nil
        lProfilePage.root.css('script').each do |iScriptNode|
          lMatch = iScriptNode.content.match(/>\\u003cspan class=\\"uiNumberGiant fsxxl fwb\\">(\d*)\\u003c\\\/span>/)
          if (lMatch != nil)
            lNbrLikes = Integer(lMatch[1])
            break
          end
        end
        if (lNbrLikes == nil)
          logErr "Unable to get number of likes: #{lProfilePage.root}"
        else
          oStatsProxy.addStat('Global', 'Likes', lNbrLikes)
        end
      end

    end

  end

end
