#--
# Copyright (c) 2010 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

RubyPackager::ReleaseInfo.new.
  author(
    :Name => 'Muriel Salvan',
    :EMail => 'murielsalvan@users.sourceforge.net',
    :WebPageURL => 'http://murielsalvan.users.sourceforge.net'
  ).
  project(
    :Name => 'StatsCollect',
    :WebPageURL => 'http://statscollect.sourceforge.net/',
    :Summary => 'Command line tool gathering statistics from external sources.',
    :Description => 'StatsCollect is a little framework gathering statistics from external sources (social networks, web sites...), stored in pluggable backends. It can be very easily extended thanks to its plugins (currently include Facebook, Myspace, Youtube, Google).',
    :ImageURL => 'http://statscollect.sourceforge.net/wiki/images/c/c9/Logo.jpg',
    :FaviconURL => 'http://statscollect.sourceforge.net/wiki/images/2/26/Favicon.png',
    :SVNBrowseURL => 'http://statscollect.svn.sourceforge.net/viewvc/statscollect/',
    :DevStatus => 'Beta'
  ).
  addCoreFiles( [
    '{lib,bin}/**/*'
  ] ).
#  addTestFiles( [
#    'test/**/*'
#  ] ).
  addAdditionalFiles( [
    'README',
    'LICENSE',
    'AUTHORS',
    'Credits',
    'TODO',
    'ChangeLog',
    '*.example'
  ] ).
  gem(
    :GemName => 'StatsCollect',
    :GemPlatformClassName => 'Gem::Platform::RUBY',
    :RequirePath => 'lib',
    :HasRDoc => true
#    :TestFile => 'test/run.rb'
  ).
  sourceForge(
    :Login => 'murielsalvan',
    :ProjectUnixName => 'statscollect'
  ).
  rubyForge(
    :ProjectUnixName => 'statscollect'
  ).
  executable(
    :StartupRBFile => 'bin/StatsCollect.rb'
  )
