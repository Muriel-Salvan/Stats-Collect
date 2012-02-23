#--
# Copyright (c) 2010 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module StatsCollect

  module Notifiers

    class LogFile

      # Send a given notification
      #
      # Parameters::
      # * *iConf* (<em>map<Symbol,Object></em>): The notifier config
      # * *iMessage* (_String_): Message to send
      def send_notification(iConf, iMessage)
        File.open(iConf[:log_file], (iConf[:Append] == true) ? 'a' : 'w') do |oFile|
          oFile.write(iMessage)
        end
      end

    end

  end

end
