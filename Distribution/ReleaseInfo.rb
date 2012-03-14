#--
# Copyright (c) 2010 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

RubyPackager::ReleaseInfo.new.
  author(
    :name => 'Muriel Salvan',
    :email => 'muriel@x-aeon.com',
    :web_page_url => 'http://murielsalvan.users.sourceforge.net'
  ).
  project(
    :name => 'StatsCollect',
    :web_page_url => 'http://statscollect.sourceforge.net/',
    :summary => 'Command line tool gathering statistics from external sources.',
    :description => 'StatsCollect is a little framework gathering statistics from external sources (social networks, web sites...), stored in pluggable backends. It can be very easily extended thanks to its plugins (currently include Facebook, Myspace, Youtube, Google).',
    :image_url => 'http://statscollect.sourceforge.net/wiki/images/c/c9/Logo.jpg',
    :favicon_url => 'http://statscollect.sourceforge.net/wiki/images/2/26/Favicon.png',
    :browse_source_url => 'http://statscollect.git.sourceforge.net/',
    :dev_status => 'Beta'
  ).
  add_core_files( [
    '{lib,bin}/**/*'
  ] ).
#  add_test_files( [
#    'test/**/*'
#  ] ).
  add_additional_files( [
    'README',
    'LICENSE',
    'AUTHORS',
    'Credits',
    'ChangeLog',
    '*.example'
  ] ).
  gem(
    :gem_name => 'StatsCollect',
    :gem_platform_class_name => 'Gem::Platform::RUBY',
    :require_path => 'lib',
    :has_rdoc => true
#    :test_file => 'test/run.rb'
  ).
  source_forge(
    :login => 'murielsalvan',
    :project_unix_name => 'statscollect'
  ).
  ruby_forge(
    :project_unix_name => 'statscollect'
  ).
  executable(
    :startup_rb_file => 'bin/StatsCollect.rb'
  )
