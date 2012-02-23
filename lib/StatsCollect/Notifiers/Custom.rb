#--
# Copyright (c) 2010 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Notifiers

    class Custom

      # Send a given notification
      #
      # Parameters::
      # * *iConf* (<em>map<Symbol,Object></em>): The notifier config
      # * *iMessage* (_String_): Message to send
      def send_notification(iConf, iMessage)
        iConf[:SendCode].call(iMessage)
      end

    end

  end

end
