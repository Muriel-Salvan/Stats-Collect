#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Locations

    class MySpace

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
        # Set a specific user agent, as myspace will treat our agent as a mobile one
        lMechanizeAgent.user_agent = 'Mozilla/5.0 (Windows; U; Windows NT 6.1; fr; rv:1.9.2.13) Gecko/20101203 Firefox/3.6.13'
        # Get the login page
        lLoginForm = lMechanizeAgent.get('http://www.myspace.com/redirector?dest=/home').forms[2]
        lLoginForm.Email = iConf[:LoginEMail]
        lLoginForm.Password = iConf[:LoginPassword]
        # Submit to get to the home page
        lMechanizeAgent.submit(lLoginForm, lLoginForm.buttons.first)
        if (oStatsProxy.isObjectIncluded?('Global'))
          if (oStatsProxy.isCategoryIncluded?('Comments'))
            getProfile(oStatsProxy, lMechanizeAgent)
          end
          if ((oStatsProxy.isCategoryIncluded?('Friends')) or
              (oStatsProxy.isCategoryIncluded?('Visits')))
            getDashboard(oStatsProxy, lMechanizeAgent)
          end
          if (oStatsProxy.isCategoryIncluded?('Friends list'))
            getFriendsList(oStatsProxy, lMechanizeAgent)
          end
        end
        if (oStatsProxy.isCategoryIncluded?('Song plays'))
          getSongs(oStatsProxy, lMechanizeAgent)
        end
        if ((oStatsProxy.isCategoryIncluded?('Video plays')) or
            (oStatsProxy.isCategoryIncluded?('Video comments')) or
            (oStatsProxy.isCategoryIncluded?('Video likes')) or
            (oStatsProxy.isCategoryIncluded?('Video rating')))
          getVideos(oStatsProxy, lMechanizeAgent)
        end
        if ((oStatsProxy.isCategoryIncluded?('Blog reads')) or
            (oStatsProxy.isCategoryIncluded?('Blog likes')))
          getBlogs(oStatsProxy, lMechanizeAgent, iConf)
        end
      end

      # Get the profile statistics
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getProfile(oStatsProxy, iMechanizeAgent)
        # Click on the Profile link from the home page
        lProfilePage = iMechanizeAgent.get('http://www.myspace.com/home').link_with(:text => 'Profile').click
        # Screen scrap it
        lNbrComments = Integer(lProfilePage.root.css('div.commentsModule > div > div > div > div.moduleBody > div.genericComments > a.moreComments > span.cnt').first.content.match(/of (\d*)/)[1])
        oStatsProxy.addStat('Global', 'Comments', lNbrComments)
      end

      # Get the dashboard statistics
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getDashboard(oStatsProxy, iMechanizeAgent)
        # Get the dashboard page
        lJSonData = eval(iMechanizeAgent.get_file('http://www.myspace.com/stats/fans_json/profile_stats/en-US/x=0').gsub(':','=>'))
        lNbrVisits = lJSonData['data'].select { |iItem| next (iItem[0] == 'myspace_views') }.first[-1]
        lNbrFriends = lJSonData['data'].select { |iItem| next (iItem[0] == 'myspace_friends') }.first[-1]
        oStatsProxy.addStat('Global', 'Visits', lNbrVisits)
        oStatsProxy.addStat('Global', 'Friends', lNbrFriends)

        # OLD VERSION (keeping it as Myspace changes all the time
#        lDashboardPage = iMechanizeAgent.get('http://www.myspace.com/music/dashboard')
#        # Get the variables used by the Ajax script
#        lMatch = lDashboardPage.root.css('section.moduleBody script').first.content.split("\n").join.match(/var appID = "([^"]*)".*var pkey = "([^"]*)";/)
#        lAppID, lPKey = lMatch[1..2]
#        lCoreUserID = nil
#        lDashboardPage.root.css('body script').each do |iScriptNode|
#          lMatch = iScriptNode.content.split("\n").join.match(/var coreUserId =(\d*)/)
#          if (lMatch != nil)
#            # Found it
#            lCoreUserID = lMatch[1]
#            break
#          end
#        end
#        if (lCoreUserID == nil)
#          logErr "Unable to find the core user ID: #{lDashboardPage.root}"
#        else
#          # Call the Ajax script
#          lStatsAjaxContent = iMechanizeAgent.get_file("http://www.myspace.com/Modules/Music/Handlers/Dashboard.ashx?sourceApplication=#{lAppID}&pkey=#{lPKey}&action=GETCORESTATS&userID=#{lCoreUserID}")
#          lStrVisits, lStrFriends = lStatsAjaxContent.match(/^\{'totalprofileviews':'([^']*)','totalfriends':'([^']*)'/)[1..2]
#          lNbrVisits = Integer(lStrVisits.delete(','))
#          lNbrFriends = Integer(lStrFriends.delete(','))
#          oStatsProxy.addStat('Global', 'Visits', lNbrVisits)
#          oStatsProxy.addStat('Global', 'Friends', lNbrFriends)
#        end
      end

      # Get the songs statistics
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getSongs(oStatsProxy, iMechanizeAgent)
        # Get the songs page
        lSongsPage = iMechanizeAgent.get('http://www.myspace.com/my/songs')
        # Screen scrap it
        # List of objects that can be tried again for the song plays category
        lLstRecoverableObjectsForSongPlays = []
        # List of songs read (used for display)
        lLstSongsPlayRead = []
        lSongsPage.root.css('div.UploadedSong').each do |iSongNode|
          lSongTitle = nil
          lNbrPlays = nil
          iSongNode.css('div#songTitle').each do |iSongTitleNode|
            lSongTitle = iSongTitleNode.content
          end
          lPlaysNode = iSongNode.children[11]
          if (lPlaysNode == nil)
            logErr "Unable to find plays node: #{iSongNode}"
          else
            begin
              lNbrPlays = Integer(lPlaysNode.content)
            rescue Exception
              logErr "Invalid number of plays content: #{lPlaysNode}"
            end
          end
          if (lSongTitle == nil)
            logErr "Unable to get the song title: #{iSongNode}"
          end
          if (lNbrPlays == nil)
            logErr "Unable to get the song number of plays: #{iSongNode}"
            if (lSongTitle != nil)
              # We can try this one again
              lLstRecoverableObjectsForSongPlays << lSongTitle
            end
          end
          if ((lSongTitle != nil) and
              (lNbrPlays != nil))
            oStatsProxy.addStat(lSongTitle, 'Song plays', lNbrPlays)
          end
          lLstSongsPlayRead << lSongTitle
        end
        logDebug "#{lLstSongsPlayRead.size} songs read for songs plays: #{lLstSongsPlayRead.join(', ')}"
        if (!lLstRecoverableObjectsForSongPlays.empty?)
          oStatsProxy.addRecoverableOrder(lLstRecoverableObjectsForSongPlays, ['Song plays'])
        end
      end
      
      # Get the videos statistics
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getVideos(oStatsProxy, iMechanizeAgent)
        # Get the videos page
        lVideosPage = iMechanizeAgent.get('http://www.myspace.com/my/videos')
        # Screen scrap it
        # List of videos read (used for display)
        lLstVideosRead = []
        lVideosPage.root.css('table.myUploadsList tr').each do |iVideoNode|
          lVideoTitle = iVideoNode.css('td.summary h2 a').first.content
          lStatsNodes = iVideoNode.css('td.controls div.text span')
          lNbrPlays = Integer(lStatsNodes[1].content)
          lNbrComments = Integer(lStatsNodes[2].content)
          lMatch = lStatsNodes[3].content.match(/^(\d*)% \((\d*) vote/)
          lRating = Integer(lMatch[1])
          lNbrLikes = Integer(lMatch[2])
          oStatsProxy.addStat(lVideoTitle, 'Video plays', lNbrPlays)
          oStatsProxy.addStat(lVideoTitle, 'Video comments', lNbrComments)
          oStatsProxy.addStat(lVideoTitle, 'Video likes', lNbrLikes)
          oStatsProxy.addStat(lVideoTitle, 'Video rating', lRating)
          lLstVideosRead << lVideoTitle
        end
        logDebug "#{lLstVideosRead.size} videos read: #{lLstVideosRead.join(', ')}"
      end

      # Get the blogs statistics
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      # * *iConf* (<em>map<Symbol,Object></em>): The configuration
      def getBlogs(oStatsProxy, iMechanizeAgent, iConf)
        # TODO: Be able to get the list of blogs using MySpace only, without config
        # Parse each blog ID given from the conf.
        lLstBlogsRead = []
        iConf[:BlogsID].each do |iBlogID|
          # Get the blog page
          lBlogPage = iMechanizeAgent.get("http://www.myspace.com/#{iConf[:MySpaceName]}/blog/#{iBlogID}")
          lBlogTitle = lBlogPage.root.css('h2.post-title').first.content
          lNbrLikes = 0
          lStrLikes = lBlogPage.root.css('span.like span.likeLabel').first.content
          if (!lStrLikes.empty?)
            lNbrLikes = Integer(lStrLikes.match(/\((\d*)\)/)[1])
          end
          lNbrReads = 0
          lStrReads = lBlogPage.root.css('li.blogCommentCnt span').first.content
          if (!lStrReads.empty?)
            lNbrReads = Integer(lStrReads.match(/\((\d*)\)/)[1])
          end
          oStatsProxy.addStat(lBlogTitle, 'Blog likes', lNbrLikes)
          oStatsProxy.addStat(lBlogTitle, 'Blog reads', lNbrReads)
          lLstBlogsRead << lBlogTitle
        end
        logDebug "#{lLstBlogsRead.size} blogs read: #{lLstBlogsRead.join(', ')}"
      end

      # Get the friends list
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getFriendsList(oStatsProxy, iMechanizeAgent)
        lLstFriends = []
        lLstIDS = []
        lFriendsPage = iMechanizeAgent.get('http://www.myspace.com/my/friends/grid/page/1')
        # Keep track of the last first friend of the page, as we will detect ending page thanks to it.
        lLastFirstFriend = nil
        lIdxPage = 2
        while (lFriendsPage != nil)
          lFirstFriend = nil
          lFriendsPage.root.css('ul.myDataList li').each do |iFriendNode|
            if (iFriendNode['data-id'] != nil)
              lLstIDS << iFriendNode['data-id']
            end
          end
          lFriendsPage.root.css('ul.myDataList li div div.vcard span.hcard a.nickname').each do |iFriendLinkNode|
            lFriendName = iFriendLinkNode['href'][1..-1]
            if (lFirstFriend == nil)
              # Check if the page has not changed
              if (lLastFirstFriend == lFriendName)
                # Finished
                break
              end
              lFirstFriend = lFriendName
            end
            lLstFriends << lFriendName
          end
          lLastFirstFriend = lFirstFriend
          # Get next page if we did not reach the end
          if (lLastFirstFriend == nil)
            lFriendsPage = nil
          else
            lFriendsPage = iMechanizeAgent.get("http://www.myspace.com/my/friends/grid/page/#{lIdxPage}")
            lIdxPage += 1
          end
        end
        # Map of stored information
        lStoredMap = {}
        lLstIDS.each_with_index do |iID, iIdx|
          lStoredMap[iID] = lLstFriends[iIdx]
        end
        oStatsProxy.addStat('Global', 'Friends list', lStoredMap)
      end

    end

  end

end
