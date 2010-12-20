#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Notifiers

    class SendMail

      # Send a given notification
      #
      # Parameters:
      # * *iConf* (<em>map<Symbol,Object></em>): The notifier config
      # * *iMessage* (_String_): Message to send
      def sendNotification(iConf, iMessage)
        require 'mail'
        Mail.defaults do
         delivery_method(:smtp, iConf[:SMTP])
        end
        Mail.deliver do
          from iConf[:From]
          to iConf[:To]
          subject "Report of stats collection - #{DateTime.now.strftime('%Y-%m-%d %H:%M:%S')}"
          body iMessage
        end
      end

    end

  end

end
