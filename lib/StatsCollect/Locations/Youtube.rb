#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
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
        lLoginForm = lMechanizeAgent.get('http://www.youtube.com').link_with(:text => 'Sign In').click.forms[1]
        lLoginForm.Email = 'Muriel.Esteban@GMail.com'
        lLoginForm.Passwd = 'M[K2LBVu0}xT|b<[<Q")'
        lMechanizeAgent.submit(lLoginForm, lLoginForm.buttons.first).meta.first.click
        if ((oStatsProxy.isCategoryIncluded?('Video plays')) or
            (oStatsProxy.isCategoryIncluded?('Video likes')) or
            (oStatsProxy.isCategoryIncluded?('Video dislikes')) or
            (oStatsProxy.isCategoryIncluded?('Video comments')) or
            (oStatsProxy.isCategoryIncluded?('Video responses')))
          getVideos(oStatsProxy, lMechanizeAgent)
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

    end

  end

end
