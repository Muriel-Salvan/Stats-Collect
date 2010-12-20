#!/bin/env ruby
#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# Uncomment for PlanetHoster
#require 'rubygems'
#ENV['GEM_PATH'] = "/home/murieles/ruby/gems:/home/murieles/.gem/ruby/1.8:/usr/lib/ruby/gems/1.8"
#Gem.clear_paths

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
