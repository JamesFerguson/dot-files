#!/usr/bin/env ruby
# frozen_string_literal: true

# rubocop:disable Layout/LineLength

# <xbar.title>Brew Updates</xbar.title>
# <xbar.version>v2.7.3</xbar.version>
# <xbar.author>Jim Myhrberg</xbar.author>
# <xbar.author.github>jimeh</xbar.author.github>
# <xbar.desc>List and manage outdated Homebrew formulas and casks</xbar.desc>
# <xbar.image>https://raw.githubusercontent.com/jimeh/dotfiles/70e616332e9cc196d365e5375156b27ce8c9451e/xbar/img/brew-updates.png</xbar.image>
# <xbar.dependencies>ruby</xbar.dependencies>
# <xbar.abouturl>https://github.com/jimeh/dotfiles/tree/main/xbar</xbar.abouturl>
#
# <xbar.var>string(VAR_BREW_PATH=""): Path to "brew" executable.</xbar.var>
# <xbar.var>boolean(VAR_GREEDY_LATEST=false): Run "brew outdated" with --greedy-latest flag..</xbar.var>
# <xbar.var>boolean(VAR_GREEDY_AUTO_UPDATES=false): Run "brew outdated" with --greedy-auto-updates flag.</xbar.var>
# <xbar.var>boolean(VAR_POST_RUN_CLEANUP=false): Run "brew cleanup" after package changes.</xbar.var>
# <xbar.var>boolean(VAR_POST_RUN_DOCTOR=false): Run "brew cleanup" after package changes.</xbar.var>
# <xbar.var>string(VAR_UPGRADE_ALL_EXCLUDE=""): Comma-separated list formulas/casks to exclude from upgrade all operations.</xbar.var>

# rubocop:enable Layout/LineLength

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/BlockLength
# rubocop:disable Metrics/ClassLength
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/PerceivedComplexity
# rubocop:disable Style/IfUnlessModifier

require 'fileutils'
require 'json'
require 'open3'
require 'set'

# Xbar is a tiny helper library for creating Xbar and SwiftBar plugins in Ruby.
module Xbar
  class CommandError < StandardError; end
  class RPCError < StandardError; end

  module Helpers
    def plugin_data_path
      @plugin_data_path ||= swiftbar_data_path || File.dirname(__FILE__)
    end

    def plugin_file_path
      @plugin_file_path ||= swiftbar_plugin_path || __FILE__
    end

    def plugin_filename
      @plugin_filename ||= File.basename(plugin_file_path)
    end

    def plugin_name
      @plugin_name ||= begin
        parts = plugin_filename.split('.')
        if parts.size < 3
          raise "Invalid plugin name: #{plugin_filename}"
        end

        parts[0..-3].join('.')
      end
    end

    def swiftbar?
      ENV['SWIFTBAR'] == '1'
    end

    def swiftbar_cache_path
      @swiftbar_cache_path ||= ENV['SWIFTBAR_PLUGIN_CACHE_PATH'] if swiftbar?
    end

    def swiftbar_data_path
      @swiftbar_data_path ||= ENV['SWIFTBAR_PLUGIN_DATA_PATH'] if swiftbar?
    end

    def swiftbar_plugin_path
      @swiftbar_plugin_path ||= ENV['SWIFTBAR_PLUGIN_PATH'] if swiftbar?
    end
  end

  module Service
    include Helpers

    private

    def config
      @config ||= Xbar::Config.new
    end

    def printer
      @printer ||= ::Xbar::Printer.new
    end

    def cmd(*args, dir: nil)
      opts = {}
      opts[:chdir] = File.expand_path(dir) if dir

      out, err, s = Open3.capture3(*args, opts)
      if s.exitstatus != 0
        msg = "Command failed: #{args.join(' ')}"
        msg += ": #{err}" unless err.empty?

        raise CommandError, msg
      end

      out
    end
  end

  class Runner
    attr_reader :service

    def initialize(service)
      @service = service
    end

    def run(argv = [])
      return service.run if argv.empty?
      unless service.respond_to?(argv[0])
        raise RPCError, "Unknown RPC method: #{argv[0]}"
      end

      service.public_send(*argv)
    end
  end

  # Config is a simple wrapper around a JSON file that contains the plugin's
  # configuration. It is compatible with Xbar's behavior of loading environment
  # variables from it. We don't rely on that however and directly read the file
  # ourselves.
  #
  # In SwiftBar, we use `SWIFTBAR_PLUGIN_DATA_PATH` to determine where to store
  # the configuration in a `config.json` file.
  class Config < Hash
    include Helpers

    def initialize
      super

      return unless File.exist?(filename)

      merge!(JSON.parse(File.read(filename)))
    end

    def as_set(name)
      values = self[name]&.to_s&.split(',')&.map(&:strip)&.reject(&:empty?)

      ::Set.new(values || [])
    end

    def filename
      @filename ||= File.join(
        plugin_data_path,
        swiftbar? ? 'config.json' : "#{plugin_filename}.vars.json"
      )
    end

    def dirname
      @dirname ||= File.dirname(filename)
    end

    def save
      FileUtils.mkdir_p(dirname)
      File.write(filename, JSON.pretty_generate(self))
    end
  end

  class Printer
    include Helpers

    attr_reader :nested_level

    SUB_STR = '--'
    SEP_STR = '---'
    PARAM_SEP = '|'

    # The menu's own text colour, light,dark. SwiftBar 2.1.1 greys out a
    # submenu row with no action once it patches the row on a refresh
    # (swiftbar/SwiftBar#512, fixed in 2.1.2), but a colour gives it one.
    TEXT_COLOR = '#242424,#dcdcdc'

    def initialize(nested_level = 0)
      @nested_level = nested_level
    end

    def item(label = nil, **props)
      return if label.nil? || label.empty?

      props = props.dup
      if block_given? && !(props.keys & %i[color shell rpc href]).any?
        props[:color] = TEXT_COLOR
      end
      props = normalize_props(props)
      alt = props.delete(:alt)
      nested_items = props.delete(:nested) || :both

      yield_main = block_given? && [:main, :both].include?(nested_items)
      yield_alt = block_given? && [:alt, :both].include?(nested_items)

      print_item(label, **props)
      yield(sub_printer) if yield_main

      return if alt.nil? || alt.strip.empty?

      print_item(alt, **props.merge(alternate: true))
      yield(sub_printer) if yield_alt
    end

    def separator
      print_item(SEP_STR)
    end
    alias sep separator

    private

    def print_item(text, **props)
      output = [text]
      unless props.empty?
        output << PARAM_SEP
        output += props.map { |k, v| "#{k}=\"#{v}\"" }
      end

      $stdout.print(SUB_STR * nested_level, output.join(' '))
      $stdout.puts
    end

    def plugin_refresh_uri
      return @plugin_refresh_uri if @plugin_refresh_uri

      @plugin_refresh_uri = if swiftbar?
                              "swiftbar://refreshplugin?name=#{plugin_name}"
                            else
                              'xbar://app.xbarapp.com/refreshPlugin' \
                                                    "?path=#{plugin_filename}"
                            end
    end

    def normalize_props(props = {})
      props = props.dup

      # Explicitly set terminal to false for SwiftBar, as it seems to default
      # to true when not specified. At least with SwiftBar 2.0.1.
      if swiftbar? && !props.key?(:terminal)
        props[:terminal] = false
      end

      if props[:rpc] && props[:shell].nil?
        props[:shell] = [__FILE__] + props[:rpc]
        props.delete(:rpc)
      end

      if props[:shell].is_a?(Array)
        cmd = props[:shell]
        props[:shell] = cmd[0]
        cmd[1..].each_with_index do |c, i|
          props["param#{i + 1}".to_sym] = c
        end
      end

      # Always refresh SwiftBar via refresh plugin URI so as to temporarily
      # disable the menu bar icon while refresh is running.
      #
      # For Xbar this does not work when terminal is false, so we only trigger
      # refresh via the plugin refresh URI when terminal is true.
      if props[:refresh] && props[:shell] && (swiftbar? || props[:terminal])
        props[:refresh] = false
        i = 1
        i += 1 while props.key?("param#{i}".to_sym)
        props["param#{i}".to_sym] = ';'
        props["param#{i + 1}".to_sym] = 'open'
        props["param#{i + 2}".to_sym] = '-jg'
        props["param#{i + 3}".to_sym] = "'#{plugin_refresh_uri}'"
      end

      props
    end

    def sub_printer
      @sub_printer || self.class.new(nested_level + 1)
    end
  end
end

#
# ------------------------------------------------------------------------------
#

# Brew module contains classes for managing Homebrew formulas and casks.
module Brew
  class Common
    include Xbar::Service

    def self.prefix(value = nil)
      return @prefix if value.nil? || value == ''

      @prefix = value
    end

    private

    def prefix
      self.class.prefix
    end

    def brew_path
      @brew_path ||= brew_path_from_env ||
                     brew_path_from_which ||
                     brew_path_from_fs_check ||
                     raise('Unable to find "brew" executable')
    end

    def brew_path_from_env
      env_value = config['VAR_BREW_PATH']&.to_s&.strip || ''

      return if env_value == ''
      return unless File.exist?(env_value)

      env_value
    end

    def brew_path_from_which
      detect = cmd('which', 'brew').strip
      return if detect == ''

      detect
    rescue Xbar::CommandError
      nil
    end

    def brew_path_from_fs_check
      ['/usr/local/bin/brew', '/opt/homebrew/bin/brew'].each do |path|
        return path if File.exist?(path)
      end

      nil
    end

    def brew_check(printer = nil)
      printer ||= default_printer
      return if File.exist?(brew_path)

      printer.item("#{prefix}↑⚠️", dropdown: false)
      printer.sep
      printer.item('Homebrew not found', color: 'red')
      printer.item("Executable \"#{brew_path}\" does not exist.")
      printer.sep
      printer.item(
        'Visit https://brew.sh/ for installation instructions',
        href: 'https://brew.sh'
      )

      exit 0
    end
  end

  class Package
    attr_reader :name, :installed_versions, :latest_version,
                :pinned, :pinned_version

    def initialize(attributes = {})
      @name = attributes['name']
      @installed_versions = Array(attributes['installed_versions'])
      @latest_version = attributes['current_version']
      @pinned = attributes['pinned']
      @pinned_version = attributes['pinned_version']
    end

    def current_version
      installed_versions.last
    end
  end

  class Formula < Package; end
  class Cask < Package; end

  class FormulaUpdates < Common
    prefix '🍻'

    # The nightly's cooldown, which Waypoint reads too.
    BREW_READY = File.join(
      Dir.home, 'code/personal/dot-files/nightly-skill-mise/brew-ready.zsh'
    )

    # The nightly leaves these out of its brew upgrades (system-update.zsh's
    # EXCLUDE, and Waypoint's Scan @excluded).
    NIGHTLY_EXCLUDE = {
      'firefox' => '',
      'visual-studio-code' => '',
      'claude' => '',
      'claude-code' => ', since upgrading it kills backgrounded Claude sessions',
      'google-chrome' => ", since Fat Zebra's device management updates it " \
                         'and sets the deadline'
    }.freeze

    # The menu bar icon when nothing is ready: 🍻 in greyscale, at 2x (bin/grey-emoji).
    IDLE_ICON = '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'

    def run
      brew_check(printer)
      brew_update

      print_menu_title
      printer.sep
      printer.item('Brew Updates️') do |printer|
        print_settings(printer)
      end

      printer.item(status_label) do |printer|
        printer.item('⏳ Refresh', alt: '⏳ Refresh (⌘R)', refresh: true)

        printer.sep
        all_formulas = formulas.select { |f| ready?(f) }
        excluded = (formulas + casks).select { |p| left_out?(p.name) }

        # Formulae only: a bulk cask upgrade stacks the App Management
        # prompts that wedge the UI, so casks go one at a time, watched.
        if all_formulas.size.positive?
          names = all_formulas.map(&:name)
          printer.item(
            "⬆️ Upgrade Ready Formulas (#{all_formulas.size})",
            terminal: true, refresh: true,
            shell: [
              brew_path, 'upgrade', '--formula'
            ] + names + post_commands
          )
        end
        if excluded.size.positive?
          printer.sep
          printer.item("Excluded (#{excluded.size}):")
          excluded.sort_by(&:name).each do |item|
            type = item.is_a?(Formula) ? 'Formula' : 'Cask'
            printer.item("#{item.name} (#{type})")
          end
        end
      end

      print_formulas(printer)
      print_casks(printer)
      print_pinned(printer)
      printer.sep
    end

    def greedy_latest(*args)
      config['VAR_GREEDY_LATEST'] = truthy?(args.first)
      config.save
    end

    def greedy_auto_updates(*args)
      config['VAR_GREEDY_AUTO_UPDATES'] = truthy?(args.first)
      config.save
    end

    def post_run_cleanup(*args)
      config['VAR_POST_RUN_CLEANUP'] = truthy?(args.first)
      config.save
    end

    def post_run_doctor(*args)
      config['VAR_POST_RUN_DOCTOR'] = truthy?(args.first)
      config.save
    end

    def exclude_upgrade_all(*args)
      exclude = upgrade_all_exclude.clone
      exclude += args.map(&:strip).reject(&:empty?)

      config['VAR_UPGRADE_ALL_EXCLUDE'] = exclude.sort.join(',')
      config.save
    end

    def include_upgrade_all(*args)
      exclude = upgrade_all_exclude.clone
      exclude -= args.map(&:strip).reject(&:empty?)

      config['VAR_UPGRADE_ALL_EXCLUDE'] = exclude.sort.join(',')
      config.save
    end

    private

    def greedy_latest?
      @greedy_latest ||= truthy?(config['VAR_GREEDY_LATEST'])
    end

    def greedy_auto_updates?
      @greedy_auto_updates ||= truthy?(config['VAR_GREEDY_AUTO_UPDATES'])
    end

    def post_run_cleanup?
      @post_run_cleanup ||= truthy?(config['VAR_POST_RUN_CLEANUP'])
    end

    def post_run_doctor?
      @post_run_doctor ||= truthy?(config['VAR_POST_RUN_DOCTOR'])
    end

    def upgrade_all_exclude?(name)
      upgrade_all_exclude.include?(name)
    end

    def nightly_exclude?(name)
      NIGHTLY_EXCLUDE.key?(name)
    end

    def left_out?(name)
      nightly_exclude?(name) || upgrade_all_exclude?(name)
    end

    # brew-ready.zsh's verdicts as name => [status, days], or nil when the
    # check failed, so a broken check can't pass for "nothing to do".
    def cooldown
      return @cooldown if defined?(@cooldown)

      @cooldown = cmd({ 'BREW_READY_TSV' => '1' }, BREW_READY)
                  .each_line.to_h do |line|
        name, _latest, status, days = line.chomp.split("\t")
        [name, [status, days.to_i]]
      end
    rescue Xbar::CommandError, SystemCallError
      @cooldown = nil
    end

    # :ready, :cooling, or :undated when there's no release date to go by.
    def status(name)
      case cooldown&.dig(name, 0)
      when 'READY' then :ready
      when 'COOLING' then :cooling
      else :undated
      end
    end

    def detail(name)
      days = cooldown&.dig(name, 1)

      case status(name)
      when :ready then "#{days}d old"
      when :cooling then "#{days}d left"
      else 'no release date'
      end
    end

    def ready?(package)
      status(package.name) == :ready && !left_out?(package.name)
    end

    def status_text(name)
      return 'left out of the nightly' if nightly_exclude?(name)

      case status(name)
      when :ready then "ready · #{detail(name)}"
      when :cooling then "cooling · #{detail(name)}"
      else 'no release date'
      end
    end

    def upgrade_question(package)
      name = package.name

      if nightly_exclude?(name)
        "The nightly leaves #{name} out#{NIGHTLY_EXCLUDE[name]}. " \
          'Force the upgrade?'
      elsif status(name) == :cooling
        "#{name} #{package.latest_version} is still cooling " \
          "(#{detail(name)}). Upgrade it early?"
      elsif status(name) == :undated
        "There's no release date for #{name} #{package.latest_version}, " \
          'so no cooldown to go by. Upgrade it?'
      end
    end

    def upgrade_all_exclude
      @upgrade_all_exclude ||= config.as_set('VAR_UPGRADE_ALL_EXCLUDE')
    end

    def truthy?(value)
      %w[true yes 1 on y t].include?(value.to_s.downcase)
    end

    def brew_update
      cmd(brew_path, 'update')
    rescue Xbar::CommandError
      # Continue as if nothing happened when brew update fails, as it likely
      # to be due to another update process is already running.
    end

    def print_menu_title
      outdated = formulas + casks
      ready = outdated.count { |p| ready?(p) }

      if cooldown.nil? && outdated.any?
        printer.item("#{prefix}⚠️", dropdown: false)
      elsif ready.positive?
        printer.item("#{prefix}↑#{ready}", dropdown: false)
      else
        printer.item(
          ' ', image: IDLE_ICON, width: 18, height: 18, dropdown: false
        )
      end
    end

    def status_label
      outdated = formulas + casks
      if cooldown.nil? && outdated.any?
        return "cooldown check failed: #{File.basename(BREW_READY)}"
      end

      others = outdated.reject { |p| left_out?(p.name) }
      counts = {
        'ready' => others.count { |p| status(p.name) == :ready },
        'cooling' => others.count { |p| status(p.name) == :cooling },
        'with no release date' => others.count { |p| status(p.name) == :undated },
        'left out' => outdated.count { |p| left_out?(p.name) },
        'pinned' => pinned.size
      }

      label = counts.select { |_, n| n.positive? }.map { |what, n| "#{n} #{what}" }
      label = ['no updates available'] if label.empty?
      label.join(', ')
    end

    def print_settings(printer)
      printer.item('Settings')
      printer.sep

      print_rpc_toggle(
        printer, 'Greedy: Latest', 'greedy_latest', greedy_latest?
      )

      print_rpc_toggle(
        printer, 'Greedy: Auto Updates', 'greedy_auto_updates',
        greedy_auto_updates?
      )

      print_rpc_toggle(
        printer, 'Post Run: Cleanup', 'post_run_cleanup', post_run_cleanup?
      )

      print_rpc_toggle(
        printer, 'Post-Run: Doctor', 'post_run_doctor', post_run_doctor?
      )
    end

    def print_rpc_toggle(printer, name, rpc, current_value)
      if current_value
        icon = '✅'
        value = 'false'
      else
        icon = '☑️'
        value = 'true'
      end

      printer.item("#{icon} #{name}", rpc: [rpc, value], refresh: true)
    end

    def print_formulas(printer)
      return unless formulas.size.positive?

      printer.sep
      printer.item("Formulas (#{formulas.size}):")
      formulas.each do |formula|
        printer.item(package_label(formula), color: package_color(formula)) do |printer|
          print_upgrade(printer, formula, 'formula')
          printer.sep
          printer.item("→ Installed: #{formula.installed_versions.join(', ')}")
          printer.item("↑ Latest: #{formula.latest_version}")
          printer.item("⏳ #{status_text(formula.name)}")
          printer.sep
          printer.item(
            '📌 Pin',
            alt: "📌 Pin (to #{formula.current_version})",
            terminal: false, refresh: true,
            shell: [brew_path, 'pin', formula.name]
          )
          print_exclude_toggle(printer, formula)
          printer.item('🚫 Uninstall') do |printer|
            printer.item('Are you sure?')
            printer.item(
              'Yes',
              terminal: true, refresh: true,
              shell: [
                brew_path, 'uninstall', '--formula', formula.name
              ] + post_commands
            )
          end
        end
      end
    end

    def print_casks(printer)
      return unless casks.size.positive?

      printer.sep
      printer.item("Casks (#{casks.size}):")
      casks.each do |cask|
        printer.item(package_label(cask), color: package_color(cask)) do |printer|
          print_upgrade(printer, cask, 'cask')
          printer.sep
          printer.item("→ Installed: #{cask.installed_versions.join(', ')}")
          printer.item("↑ Latest: #{cask.latest_version}")
          printer.item("⏳ #{status_text(cask.name)}")
          printer.sep
          print_exclude_toggle(printer, cask)
          printer.item('🚫 Uninstall') do |printer|
            printer.item('Are you sure?')
            printer.sep
            printer.item(
              'Yes',
              terminal: true, refresh: true,
              shell: [
                brew_path, 'uninstall', '--cask', cask.name
              ] + post_commands
            )
          end
        end
      end
    end

    # Like Waypoint's status chips: left out of the nightly in orange, ready in
    # the menu's text colour, cooling and undated dimmed.
    def package_color(package)
      if nightly_exclude?(package.name)
        '#c45c00,#ff9f0a'
      elsif status(package.name) == :ready
        Xbar::Printer::TEXT_COLOR
      else
        '#8e8e93,#8e8e93'
      end
    end

    def package_label(package)
      name = package.name
      return "#{name} ⤫" if left_out?(name)

      case status(name)
      when :cooling then "#{name} ⏳ #{detail(name)}"
      when :undated then "#{name} ?"
      else name
      end
    end

    # Like Waypoint's buttons: a ready package upgrades straight away; a
    # cooling, undated or left-out one asks first.
    def print_upgrade(printer, package, kind)
      shell = [brew_path, 'upgrade', "--#{kind}", package.name] + post_commands
      versions = "(#{package.current_version} → #{package.latest_version})"
      question = upgrade_question(package) unless ready?(package)

      if question.nil?
        printer.item(
          '⬆️ Upgrade', alt: "⬆️ Upgrade #{versions}",
                       terminal: true, refresh: true, shell: shell
        )
        return
      end

      label = nightly_exclude?(package.name) ? 'Force upgrade' : 'Upgrade early'
      printer.item("⬆️ #{label}", alt: "⬆️ #{label} #{versions}") do |printer|
        printer.item(question)
        printer.sep
        printer.item('Yes', terminal: true, refresh: true, shell: shell)
      end
    end

    def print_exclude_toggle(printer, package)
      if nightly_exclude?(package.name)
        printer.item('⤫ Left out of the nightly')
      elsif upgrade_all_exclude?(package.name)
        printer.item(
          '✅ Upgrade All: Exclude',
          terminal: false, refresh: true,
          rpc: ['include_upgrade_all', package.name]
        )
      else
        printer.item(
          '☑️ Upgrade All: Exclude',
          terminal: false, refresh: true,
          rpc: ['exclude_upgrade_all', package.name]
        )
      end
    end

    def print_pinned(printer)
      return unless pinned.size.positive?

      printer.sep
      printer.item("Pinned Formulas (#{pinned.size}):")
      pinned.each do |formula|
        printer.item(formula.name) do |printer|
          printer.item(
            '⬆ Upgrade',
            alt: '⬆ Upgrade ' \
                 "(#{formula.current_version} → #{formula.latest_version})"
          )
          printer.sep
          printer.item("→ Pinned: #{formula.pinned_version}")
          if formula.installed_versions.size > 1
            printer.item("→ Installed: #{formula.installed_versions.join(', ')}")
          end
          printer.item("↑ Latest: #{formula.latest_version}")
          printer.sep
          printer.item(
            '📌 Unpin',
            terminal: false, refresh: true,
            shell: [brew_path, 'unpin', formula.name]
          )
          printer.item('🚫 Uninstall') do |printer|
            printer.item('Are you sure?')
            printer.item(
              'Yes',
              terminal: true, refresh: true,
              shell: [
                brew_path, 'uninstall', '--formula', formula.name
              ] + post_commands
            )
          end
        end
      end
    end

    def post_commands
      cmds = []
      cmds += ['&&', brew_path, 'cleanup'] if post_run_cleanup?
      cmds += ['&&', brew_path, 'doctor'] if post_run_doctor?

      cmds
    end

    def formulas
      @formulas ||= all_formulas.reject(&:pinned)
    end

    def pinned
      @pinned ||= all_formulas.select(&:pinned)
    end

    def all_formulas
      @all_formulas ||= outdated['formulae'].map { |f| Formula.new(f) }
    end

    def casks
      @casks ||= outdated['casks'].map { |c| Cask.new(c) }
    end

    def greedy_args
      args = []
      args << '--greedy-latest' if greedy_latest?
      args << '--greedy-auto-updates' if greedy_auto_updates?
      args
    end

    def outdated_args
      ['outdated', greedy_args, '--json=v2'].flatten.compact
    end

    def outdated
      @outdated ||= JSON.parse(cmd(brew_path, *outdated_args))
    end
  end
end

begin
  service = Brew::FormulaUpdates.new
  Xbar::Runner.new(service).run(ARGV)
rescue StandardError => e
  puts ":warning: #{File.basename(__FILE__)}"
  puts '---'
  puts 'exit status 1'
  puts '---'
  puts 'Error:'
  puts e.message
  e.backtrace.each do |line|
    puts "--#{line}"
  end
  exit 0
end

# rubocop:enable Style/IfUnlessModifier
# rubocop:enable Metrics/PerceivedComplexity
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/ClassLength
# rubocop:enable Metrics/BlockLength
# rubocop:enable Metrics/AbcSize
