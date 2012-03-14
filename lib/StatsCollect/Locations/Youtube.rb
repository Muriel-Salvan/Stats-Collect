#--
# Copyright (c) 2010 - 2012 Muriel Salvan (muriel@x-aeon.com)
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
      # Parameters::
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
        if (Mechanize::VERSION > '1.0.0')
          lMechanizeAgent.submit(lLoginForm, lLoginForm.buttons.first).meta_refresh.first.click
        else
          lMechanizeAgent.submit(lLoginForm, lLoginForm.buttons.first).meta.first.click
        end
        if ((oStatsProxy.is_category_included?('Video plays')) or
            (oStatsProxy.is_category_included?('Video likes')) or
            (oStatsProxy.is_category_included?('Video dislikes')) or
            (oStatsProxy.is_category_included?('Video comments')) or
            (oStatsProxy.is_category_included?('Video responses')))
          getVideos(oStatsProxy, lMechanizeAgent)
        end
        if ((oStatsProxy.is_object_included?('Global')) and
            ((oStatsProxy.is_category_included?('Visits')) or
             (oStatsProxy.is_category_included?('Followers'))))
          getOverview(oStatsProxy, lMechanizeAgent)
        end
        if ((oStatsProxy.is_object_included?('Global')) and
            (oStatsProxy.is_category_included?('Following')))
          getSubscriptions(oStatsProxy, lMechanizeAgent)
        end
      end

      # Get the videos statistics
      #
      # Parameters::
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getVideos(oStatsProxy, iMechanizeAgent)
        lVideosPage = iMechanizeAgent.get('http://www.youtube.com/my_videos')
        # List of videos read (used for display)
        lLstVideosRead = []
        lVideosPage.root.css('li.vm-video-item').each do |iVideoNode|
          lVideoTitle = iVideoNode.css('div.vm-video-title a').first.content
          lNbrPlays = Integer(iVideoNode.css('div.vm-video-metrics span.video-view-count span.vm-video-metric-value')[0].content.strip)
          lNbrLikes = Integer(iVideoNode.css('div.vm-video-metrics span.video-likes-count span.vm-video-metric-value')[0].content.strip)
          lNbrDislikes = Integer(iVideoNode.css('div.vm-video-metrics span.video-dislikes-count span.vm-video-metric-value')[0].content.strip)
          lNbrComments = Integer(iVideoNode.css('div.vm-video-metrics span.video-comments span.vm-video-metric-value')[0].content.strip)
          #lNbrResponses = Integer(lMetricNodes[2].content.strip)
          oStatsProxy.add_stat(lVideoTitle, 'Video plays', lNbrPlays)
          oStatsProxy.add_stat(lVideoTitle, 'Video comments', lNbrComments)
          #oStatsProxy.add_stat(lVideoTitle, 'Video responses', lNbrResponses)
          oStatsProxy.add_stat(lVideoTitle, 'Video likes', lNbrLikes)
          oStatsProxy.add_stat(lVideoTitle, 'Video dislikes', lNbrDislikes)
          lLstVideosRead << lVideoTitle
        end
        log_debug "#{lLstVideosRead.size} videos read: #{lLstVideosRead.join(', ')}"
      end

      # Get the overview statistics
      #
      # Parameters::
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
          log_err "Unable to get number of visits: #{lOverviewPage.content}"
        elsif (lNbrFollowers == nil)
          log_err "Unable to get number of followers: #{lOverviewPage.content}"
        else
          oStatsProxy.add_stat('Global', 'Visits', lNbrVisits)
          oStatsProxy.add_stat('Global', 'Followers', lNbrFollowers)
        end
      end

      # Get the friends statistics
      #
      # Parameters::
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getSubscriptions(oStatsProxy, iMechanizeAgent)
        lOverviewPage = iMechanizeAgent.get('http://www.youtube.com/profile')
        lNbrFollowing = Integer(lOverviewPage.root.css('div.header-stats span.stat-value').first.content.strip)
        oStatsProxy.add_stat('Global', 'Following', lNbrFollowing)
      end

    end

  end

end
