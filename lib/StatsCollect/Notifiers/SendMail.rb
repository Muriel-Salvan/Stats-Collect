#--
# Copyright (c) 2010 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Notifiers

    class SendMail

      # Send a given notification
      #
      # Parameters::
      # * *iConf* (<em>map<Symbol,Object></em>): The notifier config
      # * *iMessage* (_String_): Message to send
      def send_notification(iConf, iMessage)
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
