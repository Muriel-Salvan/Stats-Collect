#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
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
      # Parameters:
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
        if ((oStatsProxy.isCategoryIncluded?('Song plays')) or
            (oStatsProxy.isCategoryIncluded?('Song downloads')) or
            (oStatsProxy.isCategoryIncluded?('Video plays')) or
            (oStatsProxy.isCategoryIncluded?('Song play ratio')) or
            (oStatsProxy.isCategoryIncluded?('Song likes')) or
            (oStatsProxy.isCategoryIncluded?('Song dislikes')))
          getPlays(oStatsProxy, lMechanizeAgent, lUserID)
        end
        if ((oStatsProxy.isObjectIncluded?('Global')) and
            ((oStatsProxy.isCategoryIncluded?('Chart position genre')) or
             (oStatsProxy.isCategoryIncluded?('Chart position global')) or
             (oStatsProxy.isCategoryIncluded?('Band equity')) or
             (oStatsProxy.isCategoryIncluded?('Friends'))))
          getReport(oStatsProxy, lMechanizeAgent, lUserID)
        end
      end

      # Get the plays statistics
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      # * *iUserID* (_String_): The ReverbNation user ID
      def getPlays(oStatsProxy, iMechanizeAgent, iUserID)
        # Get the Ajax stats table
        lStatsTable = iMechanizeAgent.get("http://www.reverbnation.com/artist/new_stats_plays_table/#{iUserID}?all_time=true")
        lStatsTableNode = Nokogiri::HTML(lStatsTable.content[31..-4].gsub(/\\"/,'"').gsub(/\\n/,"\n").gsub(/\\r/,''))
        # Screen scrap it
        lLstSongsRead = []
        lStatsTableNode.css('table.statstable_full tr')[1..-3].each do |iSongNode|
          lNodeContents = iSongNode.css('td')
          lSongTitle = lNodeContents[1].content
          lNbrSongPlays = Integer(lNodeContents[3].content)
          lNbrSongDownloads = Integer(lNodeContents[4].content)
          lNbrVideoPlays = Integer(lNodeContents[5].content)
          lPlayRatio = Integer(lNodeContents[6].content.match(/^(\d*)%$/)[1])
          lMatch = lNodeContents[7].content.match(/^(\d*)\/(\d*)$/)
          lNbrLikes = Integer(lMatch[1])
          lNbrDislikes = Integer(lMatch[2])
          oStatsProxy.addStat(lSongTitle, 'Song plays', lNbrSongPlays)
          oStatsProxy.addStat(lSongTitle, 'Song downloads', lNbrSongDownloads)
          oStatsProxy.addStat(lSongTitle, 'Video plays', lNbrVideoPlays)
          oStatsProxy.addStat(lSongTitle, 'Song play ratio', lPlayRatio)
          oStatsProxy.addStat(lSongTitle, 'Song likes', lNbrLikes)
          oStatsProxy.addStat(lSongTitle, 'Song dislikes', lNbrDislikes)
          lLstSongsRead << lSongTitle
        end
        logDebug "#{lLstSongsRead.size} songs read: #{lLstSongsRead.join(', ')}"
      end

      # Get the report statistics
      #
      # Parameters:
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
              lChartPositionGenre = Integer(lChildrenNodes[iIdx+1].content.strip)
            elsif (iNode.content == 'Global:')
              lChartPositionGlobal = Integer(lChildrenNodes[iIdx+1].content.strip)
            end
          end
          if ((lChartPositionGenre != nil) and
              (lChartPositionGlobal != nil))
            break
          end
        end
        if (lChartPositionGenre == nil)
          logErr "Unable to get the chart positions: #{lReportPage.root}"
        else
          lBandEquityScore = nil
          lNbrFriends = nil
          lReportPage.root.css('body div#mainwrap div div div.printable_pane').each do |iPaneNode|
            lChildrenNodes = iPaneNode.children
            lChildrenNodes.each_with_index do |iNode, iIdx|
              if (iNode.content == 'Band Equity Score: ')
                lBandEquityScore = Integer(lChildrenNodes[iIdx+1].content.strip)
              elsif (iNode.content == 'Total Fans: ')
                lNbrFriends = Integer(lChildrenNodes[iIdx+1].content.strip)
              end
            end
            if ((lBandEquityScore != nil) and
                (lNbrFriends != nil))
              break
            end
          end
          if (lBandEquityScore == nil)
            logErr "Unable to get the band equity score: #{lReportPage.root}"
          elsif (lNbrFriends == nil)
            logErr "Unable to get the number of friends: #{lReportPage.root}"
          else
            oStatsProxy.addStat('Global', 'Chart position genre', lChartPositionGenre)
            oStatsProxy.addStat('Global', 'Chart position global', lChartPositionGlobal)
            oStatsProxy.addStat('Global', 'Band equity', lBandEquityScore)
            oStatsProxy.addStat('Global', 'Friends', lNbrFriends)
          end
        end
      end

    end

  end

end
