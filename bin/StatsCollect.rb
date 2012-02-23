#!/bin/env ruby
#--
# Copyright (c) 2010 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'rUtilAnts/Logging'
RUtilAnts::Logging::install_logger_on_object
require 'tmpdir'
lLogFile = "#{Dir.tmpdir}/StatsCollect_#{Process.pid}.log"
set_log_file(lLogFile)
require 'StatsCollect/Stats'

rErrorCode = 0

lStatsCollect = StatsCollect::Stats.new
rErrorCode = lStatsCollect.setup(ARGV)
if (rErrorCode == 0)
  rErrorCode = lStatsCollect.collect
  lStatsCollect.notify(lLogFile)
end

File.unlink(lLogFile)

exit rErrorCode
