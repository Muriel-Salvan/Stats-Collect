#--
# Copyright (c) 2010 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Locations

    class GoogleGroup

      MEMBERSTATUS_INVITED = 0
      MEMBERSTATUS_MEMBER = 1
      MEMBERSTATUS_OWNER = 2

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
        lLoginForm = lMechanizeAgent.get('http://groups.google.com/').link_with(:text => 'Sign in').click.forms[0]
        lLoginForm.Email = iConf[:LoginEMail]
        lLoginForm.Passwd = iConf[:LoginPassword]
        lMechanizeAgent.submit(lLoginForm, lLoginForm.buttons.first).meta_refresh.first.click
        iConf[:Objects].each do |iGroupName|
          if (oStatsProxy.isCategoryIncluded?('Friends'))
            getMembers(oStatsProxy, lMechanizeAgent, iGroupName)
          end
          if (oStatsProxy.isCategoryIncluded?('Friends list'))
            getMembersList(oStatsProxy, lMechanizeAgent, iGroupName)
          end
        end
      end

      # Get the members statistics
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      # * *iGroupName* (_String_): Name of the group to retrieve members from
      def getMembers(oStatsProxy, iMechanizeAgent, iGroupName)
        lMembersPage = iMechanizeAgent.get("http://groups.google.com/group/#{iGroupName}/manage_members?hl=en")
        lNbrFriends = Integer(lMembersPage.root.css('div.mngcontentbox table.membertabs tr td.st b').first.content.match(/All members \((\d*)\)/)[1])
        oStatsProxy.addStat(iGroupName, 'Friends', lNbrFriends)
      end

      # Get the members list
      #
      # Parameters:
      # * *oStatsProxy* (_StatsProxy_): The stats proxy to be used to populate stats
      # * *iMechanizeAgent* (_Mechanize_): The agent reading pages
      # * *iGroupName* (_String_): Name of the group to retrieve members from
      def getMembersList(oStatsProxy, iMechanizeAgent, iGroupName)
        lExportForm = iMechanizeAgent.get("http://groups.google.com/group/#{iGroupName}/manage_members?hl=en").forms[4]
        lLstMembers = iMechanizeAgent.submit(lExportForm, lExportForm.buttons.first).content.split("\n")[2..-1]
        # The map of members
        # map< Name, [ MemberStatus, JoinDateTime ] >
        lMapMembers = {}
        lLstMembers.each do |iStrMemberInfo|
          lEmail, _, lStrStatus, _, _, _, lStrYear, lStrMonth, lStrDay, lStrHour, lStrMinute, lStrSecond = iStrMemberInfo.split(',')
          lStatus = nil
          case lStrStatus
          when 'invited'
            lStatus = MEMBERSTATUS_INVITED
          when 'member'
            lStatus = MEMBERSTATUS_MEMBER
          when 'owner'
            lStatus = MEMBERSTATUS_OWNER
          else
            logErr "Unknown member status (#{lStrStatus}) for email #{lEmail}. Will be counted as a member."
            lStatus = MEMBERSTATS_MEMBER
          end
          lMapMembers[lEmail] = [
            lStatus,
            DateTime.civil(
              lStrYear.to_i,
              lStrMonth.to_i,
              lStrDay.to_i,
              lStrHour.to_i,
              lStrMinute.to_i,
              lStrSecond.to_i)
          ]
        end
        oStatsProxy.addStat(iGroupName, 'Friends list', lMapMembers)
      end

    end

  end

end
