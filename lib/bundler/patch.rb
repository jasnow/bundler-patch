require 'bundler'

module Bundler
  module Patch
  end
end

require 'bundler/patch/updater'
require 'bundler/patch/gemfile'
require 'bundler/patch/ruby_version'
require 'bundler/patch/advisory_consolidator'
require 'bundler/patch/patch_analysis'
require 'bundler/patch/conservative_resolver'
require 'bundler/patch/scanner'
require 'bundler/patch/version'
