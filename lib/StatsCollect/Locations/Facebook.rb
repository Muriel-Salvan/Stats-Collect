#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Locations

    class Facebook

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
            (oStatsProxy.isCategoryIncluded?('Friends')))
          getProfile(oStatsProxy, lMechanizeAgent)
        end
      end

      # Get the profile statistics
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getProfile(oStatsProxy, iMechanizeAgent)
        lProfilePage = iMechanizeAgent.get('http://www.facebook.com/profile.php')
        lNbrFriends = nil
        lProfilePage.root.css('script').each do |iScriptNode|
          lMatch = iScriptNode.content.match(/sk=friends&amp;v=friends\\">Friends \((\d*)\)\\u003c\\\/a>/)
          #lMatch = iScriptNode.content.match(/>Friends \((\d*)\)/)
          # The following line is valid for old profiles only
          #lMatch = iScriptNode.content.match(/>(\d*) friends<\\\/a><\\\/span>/)
          if (lMatch != nil)
            lNbrFriends = Integer(lMatch[1])
            break
          end
        end
        if (lNbrFriends == nil)
          logErr "Unable to get number of friends: #{lProfilePage.root}"
        else
          oStatsProxy.addStat('Global', 'Friends', lNbrFriends)
        end
      end

    end

  end

end
