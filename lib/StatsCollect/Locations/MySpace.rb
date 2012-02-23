#--
# Copyright (c) 2010 - 2012 Muriel Salvan (muriel@x-aeon.com)
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
      # Parameters::
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
        if (oStatsProxy.is_object_included?('Global'))
          if (oStatsProxy.is_category_included?('Comments'))
            getProfile(oStatsProxy, lMechanizeAgent)
          end
          if ((oStatsProxy.is_category_included?('Friends')) or
              (oStatsProxy.is_category_included?('Visits')))
            getDashboard(oStatsProxy, lMechanizeAgent)
          end
          if (oStatsProxy.is_category_included?('Friends list'))
            getFriendsList(oStatsProxy, lMechanizeAgent)
          end
        end
        if (oStatsProxy.is_category_included?('Song plays'))
          getSongs(oStatsProxy, lMechanizeAgent)
        end
        if ((oStatsProxy.is_category_included?('Video plays')) or
            (oStatsProxy.is_category_included?('Video comments')) or
            (oStatsProxy.is_category_included?('Video likes')) or
            (oStatsProxy.is_category_included?('Video rating')))
          getVideos(oStatsProxy, lMechanizeAgent)
        end
        if ((oStatsProxy.is_category_included?('Blog reads')) or
            (oStatsProxy.is_category_included?('Blog likes')))
          getBlogs(oStatsProxy, lMechanizeAgent, iConf)
        end
      end

      # Get the profile statistics
      #
      # Parameters::
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getProfile(oStatsProxy, iMechanizeAgent)
        # Click on the Profile link from the home page
        lProfilePage = iMechanizeAgent.get('http://www.myspace.com/home').link_with(:text => 'Profile').click
        # Screen scrap it
        lNbrComments = Integer(lProfilePage.root.css('article#module18 div.wrapper section.content div.commentContainer a.moreComments span.cnt').first.content.match(/of (\d*)/)[1])

        oStatsProxy.add_stat('Global', 'Comments', lNbrComments)
      end

      # Get the dashboard statistics
      #
      # Parameters::
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getDashboard(oStatsProxy, iMechanizeAgent)
        # Get the dashboard page
        lJSonData = eval(iMechanizeAgent.get_file('http://www.myspace.com/stats/fans_json/profile_stats/en-US/x=0').gsub(':','=>'))
        lNbrVisits = Integer(lJSonData['data'].select { |iItem| next (iItem[0] == 'myspace_views') }.first[-1].gsub(',',''))
        lNbrFriends = Integer(lJSonData['data'].select { |iItem| next (iItem[0] == 'myspace_friends') }.first[-1].gsub(',',''))
        oStatsProxy.add_stat('Global', 'Visits', lNbrVisits)
        oStatsProxy.add_stat('Global', 'Friends', lNbrFriends)

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
#          log_err "Unable to find the core user ID: #{lDashboardPage.root}"
#        else
#          # Call the Ajax script
#          lStatsAjaxContent = iMechanizeAgent.get_file("http://www.myspace.com/Modules/Music/Handlers/Dashboard.ashx?sourceApplication=#{lAppID}&pkey=#{lPKey}&action=GETCORESTATS&userID=#{lCoreUserID}")
#          lStrVisits, lStrFriends = lStatsAjaxContent.match(/^\{'totalprofileviews':'([^']*)','totalfriends':'([^']*)'/)[1..2]
#          lNbrVisits = Integer(lStrVisits.delete(','))
#          lNbrFriends = Integer(lStrFriends.delete(','))
#          oStatsProxy.add_stat('Global', 'Visits', lNbrVisits)
#          oStatsProxy.add_stat('Global', 'Friends', lNbrFriends)
#        end
      end

      # Get the songs statistics
      #
      # Parameters::
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
            log_err "Unable to find plays node: #{iSongNode}"
          else
            begin
              lNbrPlays = Integer(lPlaysNode.content)
            rescue Exception
              log_err "Invalid number of plays content: #{lPlaysNode}"
            end
          end
          if (lSongTitle == nil)
            log_err "Unable to get the song title: #{iSongNode}"
          end
          if (lNbrPlays == nil)
            log_err "Unable to get the song number of plays: #{iSongNode}"
            if (lSongTitle != nil)
              # We can try this one again
              lLstRecoverableObjectsForSongPlays << lSongTitle
            end
          end
          if ((lSongTitle != nil) and
              (lNbrPlays != nil))
            oStatsProxy.add_stat(lSongTitle, 'Song plays', lNbrPlays)
          end
          lLstSongsPlayRead << lSongTitle
        end
        log_debug "#{lLstSongsPlayRead.size} songs read for songs plays: #{lLstSongsPlayRead.join(', ')}"
        if (!lLstRecoverableObjectsForSongPlays.empty?)
          oStatsProxy.add_recoverable_order(lLstRecoverableObjectsForSongPlays, ['Song plays'])
        end
      end
      
      # Get the videos statistics
      #
      # Parameters::
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
          oStatsProxy.add_stat(lVideoTitle, 'Video plays', lNbrPlays)
          oStatsProxy.add_stat(lVideoTitle, 'Video comments', lNbrComments)
          oStatsProxy.add_stat(lVideoTitle, 'Video likes', lNbrLikes)
          oStatsProxy.add_stat(lVideoTitle, 'Video rating', lRating)
          lLstVideosRead << lVideoTitle
        end
        log_debug "#{lLstVideosRead.size} videos read: #{lLstVideosRead.join(', ')}"
      end

      # Get the blogs statistics
      #
      # Parameters::
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
          oStatsProxy.add_stat(lBlogTitle, 'Blog likes', lNbrLikes)
          oStatsProxy.add_stat(lBlogTitle, 'Blog reads', lNbrReads)
          lLstBlogsRead << lBlogTitle
        end
        log_debug "#{lLstBlogsRead.size} blogs read: #{lLstBlogsRead.join(', ')}"
      end

      # Get the friends list
      #
      # Parameters::
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      def getFriendsList(oStatsProxy, iMechanizeAgent)
        lFriendsPage = iMechanizeAgent.get('http://www.myspace.com/my/friends/grid/page/1')
        # Keep track of the last first friend of the page, as we will detect ending page thanks to it.
        lLastFirstFriend = nil
        lFriendsMap = {}
        lIdxPage = 2
        while (lFriendsPage != nil)
          lFirstFriend = nil
          lFriendsPage.root.css('ul.myDataList li').each do |iFriendNode|
            if (iFriendNode['data-id'] != nil)
              # We have a friend node
              lFriendID = iFriendNode['data-id']
              lFriendName = nil
              iFriendNode.css('div div.vcard span.hcard a.nickname').each do |iFriendLinkNode|
                lFriendName = iFriendLinkNode['href'][1..-1]
                if (lFriendName == nil)
                  log_err "Could not get friend's name for ID #{lFriendID}: #{iFriendLinkNode}"
                end
                lFriendsMap[lFriendID] = lFriendName
              end
              if (lFirstFriend == nil)
                # Check if the page has not changed
                if (lLastFirstFriend == lFriendID)
                  # Finished
                  break
                end
                lFirstFriend = lFriendID
              end
            end
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
        oStatsProxy.add_stat('Global', 'Friends list', lFriendsMap)
      end

    end

  end

end
