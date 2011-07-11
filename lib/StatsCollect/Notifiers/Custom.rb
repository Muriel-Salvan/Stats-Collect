#--
# Copyright (c) 2010 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Notifiers

    class Custom

      # Send a given notification
      #
      # Parameters:
      # * *iConf* (<em>map<Symbol,Object></em>): The notifier config
      # * *iMessage* (_String_): Message to send
      def sendNotification(iConf, iMessage)
        iConf[:SendCode].call(iMessage)
      end

    end

  end

end
