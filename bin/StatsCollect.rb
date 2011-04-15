#!/bin/env ruby
#--
# Copyright (c) 2010 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'rUtilAnts/Logging'
RUtilAnts::Logging::initializeLogging('','')
require 'tmpdir'
lLogFile = "#{Dir.tmpdir}/StatsCollect_#{Process.pid}.log"
setLogFile(lLogFile)
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
