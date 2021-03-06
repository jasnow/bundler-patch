module Bundler::Patch
  class AdvisoryConsolidator
    def initialize(options={}, all_ads=nil)
      @options = options
      @all_ads = all_ads || [].tap do |a|
        unless options[:skip_bundler_advise]
          if options[:ruby_advisory_db_path]
            a << Bundler::Advise::Advisories.new(dir: options[:ruby_advisory_db_path])
          else
            a << Bundler::Advise::Advisories.new # annoying
          end
        end
        a << Bundler::Advise::Advisories.new(dir: options[:advisory_db_path], repo: nil) if options[:advisory_db_path]
      end
    end

    def vulnerable_gems
      @all_ads.map do |ads|
        ads.update if ads.repo
        File.exist?(Bundler.default_lockfile) ? Bundler::Advise::GemAdviser.new(advisories: ads).scan_lockfile : []
      end.flatten.map do |advisory|
        patched = advisory.patched_versions.map do |pv|
          # this is a little stupid for compound requirements, but works itself out in consolidate_gemfiles
          pv.requirements.map { |_, v| v.to_s }
        end.flatten
        Gemfile.new(gem_name: advisory.gem, patched_versions: patched)
      end.group_by do |gemfile|
        gemfile.gem_name
      end.map do |_, gemfiles|
        consolidate_gemfiles(gemfiles)
      end.flatten
    end

    def patch_gemfile_and_get_gem_specs_to_patch
      gem_update_specs = vulnerable_gems
      locked = File.exist?(Bundler.default_lockfile) ?
        Bundler::LockfileParser.new(Bundler.read_file(Bundler.default_lockfile)).specs : []

      gem_update_specs.map(&:update) # modify requirements in Gemfile if necessary

      gem_update_specs.map do |up_spec|
        old_version = locked.detect { |s| s.name == up_spec.gem_name }.version.to_s
        new_version = up_spec.calc_new_version(old_version)
        if new_version
          GemPatch.new(gem_name: up_spec.gem_name, old_version: old_version,
                       new_version: new_version, patched_versions: up_spec.patched_versions)
        else
          GemPatch.new(gem_name: up_spec.gem_name, old_version: old_version, patched_versions: up_spec.patched_versions)
        end
      end
    end

    private

    def consolidate_gemfiles(gemfiles)
      gemfiles if gemfiles.length == 1
      all_gem_names = gemfiles.map(&:gem_name).uniq
      raise 'Must be all same gem name' unless all_gem_names.length == 1
      highest_minor_patched = gemfiles.map do |g|
        g.patched_versions
      end.flatten.group_by do |v|
        Gem::Version.new(v).segments[0..1].join('.')
      end.map do |_, all|
        all.sort.last
      end
      Gemfile.new(target_bundle: @options[:target] || TargetBundle.new,
                  gem_name: all_gem_names.first, patched_versions: highest_minor_patched)
    end
  end

  class GemPatch
    include Comparable

    # TODO: requested_version is better name than new_version?
    attr_reader :gem_name, :old_version, :new_version, :patched_versions

    def initialize(gem_name:, old_version: nil, new_version: nil, patched_versions: nil)
      @gem_name = gem_name
      @old_version = Gem::Version.new(old_version) if old_version
      @new_version = Gem::Version.new(new_version) if new_version
      @patched_versions = patched_versions
    end

    def <=>(other)
      self.gem_name <=> other.gem_name
    end

    def hash
      @gem_name.hash
    end

    def eql?(other)
      @gem_name.eql?(other.gem_name)
    end
  end
end
