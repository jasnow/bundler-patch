require_relative '../../spec_helper'

describe TargetBundle do
  before do
    @tmp_dir = File.join(__dir__, 'fixture')
    FileUtils.makedirs @tmp_dir
  end

  after do
    FileUtils.rmtree(@tmp_dir)
  end

  def gemfile_create(ruby_version)
    GemfileLockFixture.create(dir: @tmp_dir, ruby_version: ruby_version) do |fix_dir|
      yield fix_dir
    end
  end

  it 'should default to current directory and Gemfile' do
    TargetBundle.new.tap do |bnd|
      bnd.dir.should == Dir.pwd
      bnd.gemfile.should == 'Gemfile'
    end
  end

  it 'should find ruby version from Gemfile or lockfile' do
    # CI will run on older Bundler versions to verify this
    gemfile_create(RUBY_VERSION) do |dir|
      tb = TargetBundle.new(dir: dir, use_target_ruby: true)
      if TargetBundle.bundler_version_or_higher('1.12.0')
        tb.find_target_ruby_version.to_s.should == "ruby #{RUBY_VERSION}p#{RUBY_PATCHLEVEL}"
      else
        tb.find_target_ruby_version.to_s.should == "ruby #{RUBY_VERSION}"
      end
    end
  end

  it 'should behave with ruby requirement' do
    if TargetBundle.bundler_version_or_higher('1.12.0')
      conf = RbConfig::CONFIG
      gemfile_create("~> #{conf['MAJOR']}.#{conf['MINOR']}") do |dir|
        tb = TargetBundle.new(dir: dir, use_target_ruby: true)
        tb.find_target_ruby_version.to_s.should == "ruby #{RUBY_VERSION}p#{RUBY_PATCHLEVEL}"
      end
    else
      pending 'test irrelevant in versions prior to 1.12.0'
      fail
    end
  end
end
