#--
# Copyright (c) 2010 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Locations

    class ReverbNation

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
        lLoginForm = lMechanizeAgent.get('http://www.reverbnation.com/user/login').forms[2]
        lLoginForm.field_with(:name => 'user[login]').value = iConf[:LoginEMail]
        lLoginForm.field_with(:name => 'user[password]').value = iConf[:LoginPassword]
        # Submit to get to the home page
        lHomePage = lMechanizeAgent.submit(lLoginForm, lLoginForm.buttons.first)
        # Get the user id, as it will be necessary for further requests
        lUserID = lHomePage.uri.to_s.match(/^http:\/\/www\.reverbnation\.com\/artist\/control_room\/(\d*)$/)[1]
        if ((oStatsProxy.is_category_included?('Song plays')) or
            (oStatsProxy.is_category_included?('Song downloads')) or
            (oStatsProxy.is_category_included?('Song play ratio')) or
            (oStatsProxy.is_category_included?('Song likes')) or
            (oStatsProxy.is_category_included?('Song dislikes')))
          getPlays(oStatsProxy, lMechanizeAgent, lUserID)
        end
        if (oStatsProxy.is_category_included?('Video plays'))
          getVideos(oStatsProxy, lMechanizeAgent, lUserID)
        end
        if ((oStatsProxy.is_object_included?('Global')) and
            ((oStatsProxy.is_category_included?('Chart position genre')) or
             (oStatsProxy.is_category_included?('Chart position global')) or
             (oStatsProxy.is_category_included?('Band equity')) or
             (oStatsProxy.is_category_included?('Friends'))))
          getReport(oStatsProxy, lMechanizeAgent, lUserID)
        end
      end

      # Get the plays statistics
      #
      # Parameters::
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      # * *iUserID* (_String_): The ReverbNation user ID
      def getPlays(oStatsProxy, iMechanizeAgent, iUserID)
        # Get the Ajax stats table
        lStatsTable = iMechanizeAgent.get("http://www.reverbnation.com/artist/new_stats_song_plays_table/#{iUserID}?all_time=true")
        lStatsTableNode = Nokogiri::HTML(lStatsTable.content[36..-4].gsub(/\\"/,'"').gsub(/\\n/,"\n").gsub(/\\r/,''))
        # Screen scrap it
        lLstSongsRead = []
        lStatsTableNode.css('table.statstable_full tr')[1..-3].each do |iSongNode|
          lNodeContents = iSongNode.css('td')
          lSongTitle = lNodeContents[1].content
          lNbrSongPlays = Integer(lNodeContents[3].content)
          lNbrSongDownloads = Integer(lNodeContents[4].content)
          lPlayRatio = Integer(lNodeContents[5].content.match(/^(\d*)%$/)[1])
          lMatch = lNodeContents[6].content.match(/^(\d*)\/(\d*)$/)
          lNbrLikes = Integer(lMatch[1])
          lNbrDislikes = Integer(lMatch[2])
          oStatsProxy.add_stat(lSongTitle, 'Song plays', lNbrSongPlays)
          oStatsProxy.add_stat(lSongTitle, 'Song downloads', lNbrSongDownloads)
          oStatsProxy.add_stat(lSongTitle, 'Song play ratio', lPlayRatio)
          oStatsProxy.add_stat(lSongTitle, 'Song likes', lNbrLikes)
          oStatsProxy.add_stat(lSongTitle, 'Song dislikes', lNbrDislikes)
          lLstSongsRead << lSongTitle
        end
        log_debug "#{lLstSongsRead.size} songs read: #{lLstSongsRead.join(', ')}"
      end

      # Get the videos statistics
      #
      # Parameters::
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      # * *iUserID* (_String_): The ReverbNation user ID
      def getVideos(oStatsProxy, iMechanizeAgent, iUserID)
        # Get the Ajax stats table
        lStatsTable = iMechanizeAgent.get("http://www.reverbnation.com/artist/new_stats_video_plays_table/#{iUserID}?all_time=true")
        lStatsTableNode = Nokogiri::HTML(lStatsTable.content[37..-4].gsub(/\\"/,'"').gsub(/\\n/,"\n").gsub(/\\r/,''))
        # Screen scrap it
        lLstVideosRead = []
        lStatsTableNode.css('table.statstable_full tr')[1..-3].each do |iSongNode|
          lNodeContents = iSongNode.css('td')
          lVideoTitle = lNodeContents[1].children[0].content
          lNbrVideoPlays = Integer(lNodeContents[3].content)
          oStatsProxy.add_stat(lVideoTitle, 'Video plays', lNbrVideoPlays)
          lLstVideosRead << lVideoTitle
        end
        log_debug "#{lLstVideosRead.size} videos read: #{lLstVideosRead.join(', ')}"
      end

      # Get the report statistics
      #
      # Parameters::
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      # * *iUserID* (_String_): The ReverbNation user ID
      def getReport(oStatsProxy, iMechanizeAgent, iUserID)
        # Get the report page
        lReportPage = iMechanizeAgent.get("http://www.reverbnation.com/artist/artist_report_printable/#{iUserID}")
        lChartPositionGenre = nil
        lChartPositionGlobal = nil
        lReportPage.root.css('body div#mainwrap div div div.control_room_graph_column').each do |iStatsSectionNode|
          lChildrenNodes = iStatsSectionNode.children
          lChildrenNodes.each_with_index do |iNode, iIdx|
            if (iNode.content == 'Genre:')
              lChartPositionGenre = Integer(lChildrenNodes[iIdx+1].content.strip.gsub(',',''))
            elsif (iNode.content == 'Global:')
              lChartPositionGlobal = Integer(lChildrenNodes[iIdx+1].content.strip.gsub(',',''))
            end
          end
          if ((lChartPositionGenre != nil) and
              (lChartPositionGlobal != nil))
            break
          end
        end
        if (lChartPositionGenre == nil)
          log_err "Unable to get the chart positions: #{lReportPage.root}"
        else
          lBandEquityScore = nil
          lNbrFriends = nil
          lReportPage.root.css('body div#mainwrap div div div.printable_pane').each do |iPaneNode|
            lChildrenNodes = iPaneNode.children
            lChildrenNodes.each_with_index do |iNode, iIdx|
              if (iNode.content == 'Band Equity Score: ')
                lBandEquityScore = Integer(lChildrenNodes[iIdx+1].content.strip.gsub(',',''))
              elsif (iNode.content == 'Total Fans: ')
                lNbrFriends = Integer(lChildrenNodes[iIdx+1].content.strip.gsub(',',''))
              end
            end
            if ((lBandEquityScore != nil) and
                (lNbrFriends != nil))
              break
            end
          end
          if (lBandEquityScore == nil)
            log_err "Unable to get the band equity score: #{lReportPage.root}"
          elsif (lNbrFriends == nil)
            log_err "Unable to get the number of friends: #{lReportPage.root}"
          else
            oStatsProxy.add_stat('Global', 'Chart position genre', lChartPositionGenre)
            oStatsProxy.add_stat('Global', 'Chart position global', lChartPositionGlobal)
            oStatsProxy.add_stat('Global', 'Band equity', lBandEquityScore)
            oStatsProxy.add_stat('Global', 'Friends', lNbrFriends)
          end
        end
      end

    end

  end

end
