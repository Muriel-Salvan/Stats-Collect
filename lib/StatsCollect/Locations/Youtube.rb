#--
# Copyright (c) 2010 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Locations

    class Youtube

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
        lLoginForm = lMechanizeAgent.get('http://www.youtube.com').link_with(:text => 'Sign In').click.forms[0]
        lLoginForm.Email = iConf[:LoginEMail]
        lLoginForm.Passwd = iConf[:LoginPassword]
        lMechanizeAgent.submit(lLoginForm, lLoginForm.buttons.first).meta_refresh.first.click
        if ((oStatsProxy.isCategoryIncluded?('Video plays')) or
            (oStatsProxy.isCategoryIncluded?('Video likes')) or
            (oStatsProxy.isCategoryIncluded?('Video dislikes')) or
            (oStatsProxy.isCategoryIncluded?('Video comments')) or
            (oStatsProxy.isCategoryIncluded?('Video responses')))
          getVideos(oStatsProxy, lMechanizeAgent)
        end
        if ((oStatsProxy.isObjectIncluded?('Global')) and
            ((oStatsProxy.isCategoryIncluded?('Visits')) or
             (oStatsProxy.isCategoryIncluded?('Followers'))))
          getOverview(oStatsProxy, lMechanizeAgent)
        end
        if ((oStatsProxy.isObjectIncluded?('Global')) and
            (oStatsProxy.isCategoryIncluded?('Friends')))
          getFriends(oStatsProxy, lMechanizeAgent)
        end
        if ((oStatsProxy.isObjectIncluded?('Global')) and
            (oStatsProxy.isCategoryIncluded?('Following')))
          getSubscriptions(oStatsProxy, lMechanizeAgent)
        end
      end

      # Get the videos statistics
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getVideos(oStatsProxy, iMechanizeAgent)
        lVideosPage = iMechanizeAgent.get('http://www.youtube.com/my_videos')
        # List of videos read (used for display)
        lLstVideosRead = []
        lVideosPage.root.css('li.vm-video-item').each do |iVideoNode|
          lVideoTitle = iVideoNode.css('div.vm-video-title a').first.content
          lMetricNodes = iVideoNode.css('div.vm-video-metrics dl dd')
          lNbrPlays = Integer(lMetricNodes[0].css('a').first.content.strip)
          lNbrComments = Integer(lMetricNodes[1].content.strip)
          lNbrResponses = Integer(lMetricNodes[2].content.strip)
          lNbrLikes = Integer(lMetricNodes[3].content[0..-2].strip)
          lNbrDislikes = Integer(lMetricNodes[4].content.strip)
          oStatsProxy.addStat(lVideoTitle, 'Video plays', lNbrPlays)
          oStatsProxy.addStat(lVideoTitle, 'Video comments', lNbrComments)
          oStatsProxy.addStat(lVideoTitle, 'Video responses', lNbrResponses)
          oStatsProxy.addStat(lVideoTitle, 'Video likes', lNbrLikes)
          oStatsProxy.addStat(lVideoTitle, 'Video dislikes', lNbrDislikes)
          lLstVideosRead << lVideoTitle
        end
        logDebug "#{lLstVideosRead.size} videos read: #{lLstVideosRead.join(', ')}"
      end

      # Get the overview statistics
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getOverview(oStatsProxy, iMechanizeAgent)
        lOverviewPage = iMechanizeAgent.get('http://www.youtube.com/account_overview')
        lNbrVisits = nil
        lNbrFollowers = nil
        lOverviewPage.root.css('div.statBlock div').each do |iStatsSectionNode|
          lChildrenNodes = iStatsSectionNode.children
          lChildrenNodes.each_with_index do |iNode, iIdx|
            if (iNode.content == 'Channel Views:')
              lNbrVisits = Integer(lChildrenNodes[iIdx+1].content.strip.gsub(/,/,''))
            elsif (iNode.content == 'Subscribers:')
              lNbrFollowers = Integer(lChildrenNodes[iIdx+1].content.strip.gsub(/,/,''))
            end
          end
          if ((lNbrVisits != nil) and
              (lNbrFollowers != nil))
            break
          end
        end
        if (lNbrVisits == nil)
          logErr "Unable to get number of visits: #{lOverviewPage.content}"
        elsif (lNbrFollowers == nil)
          logErr "Unable to get number of followers: #{lOverviewPage.content}"
        else
          oStatsProxy.addStat('Global', 'Visits', lNbrVisits)
          oStatsProxy.addStat('Global', 'Followers', lNbrFollowers)
        end
      end

      # Get the friends statistics
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getFriends(oStatsProxy, iMechanizeAgent)
        lOverviewPage = iMechanizeAgent.get('http://www.youtube.com/profile?view=friends')
        lNbrFriends = Integer(lOverviewPage.root.xpath('//span[@name="channel-box-item-count"]').first.content)
        oStatsProxy.addStat('Global', 'Friends', lNbrFriends)
      end

      # Get the friends statistics
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getSubscriptions(oStatsProxy, iMechanizeAgent)
        lOverviewPage = iMechanizeAgent.get('http://www.youtube.com/profile?view=subscriptions')
        lNbrFollowing = Integer(lOverviewPage.root.xpath('//span[@name="channel-box-item-count"]').first.content)
        oStatsProxy.addStat('Global', 'Following', lNbrFollowing)
      end

    end

  end

end
