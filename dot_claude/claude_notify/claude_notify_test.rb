# Run: ruby dot_claude/claude_notify/claude_notify_test.rb
# Drives the CLI as a subprocess, with terminal-notifier, the Claude apps, say and osascript swapped for recorders.
require 'minitest/autorun'
require 'tmpdir'
require 'open3'
require 'fileutils'

class ClaudeNotifyTest < Minitest::Test
  SCRIPT = File.expand_path('claude-notify', __dir__)

  def setup
    @dir = Dir.mktmpdir('claude_notify_test')
    @calls = File.join(@dir, 'calls.log')
    @recorder = File.join(@dir, 'recorder')
    File.write(@recorder, "#!/bin/sh\nprintf '%s\\n' \"$(basename \"$0\") $*\" >> #{@calls}\n")
    File.chmod(0o755, @recorder)
    %w[say osascript terminal-notifier].each { |n| FileUtils.ln_s(@recorder, File.join(@dir, n)) }
    @apps = File.join(@dir, 'Applications')
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_a_link_opens_on_click
    notify!('--title', 'Gateway incident', '--message', 'RC 91 on every eftpos txn', '--open', 'https://example.test/x')
    assert_includes calls, 'terminal-notifier -title 🔔 Claude: Gateway incident -message RC 91 on every eftpos txn ' \
                           '-sound Submarine -open https://example.test/x'
  end

  def test_without_a_link_a_click_brings_iterm_forward
    notify!('--title', 'Deadline', '--message', 'Enrol the Mac today')
    assert_match(/-activate com\.googlecode\.iterm2\z/, calls.first)
  end

  def test_say_speaks_only_the_short_words
    notify!('--title', 'Deadline', '--message', 'Enrol the Mac today, before 5pm', '--say', 'Deadline: enrolment')
    assert_includes calls, 'say Deadline: enrolment'
  end

  def test_nothing_is_spoken_without_say
    notify!('--title', 'Deadline', '--message', 'Enrol the Mac today')
    assert(calls.none? { |c| c.start_with?('say') })
  end

  def test_each_level_leads_with_its_emoji
    { 'urgent' => '🚨', 'warn' => '⚠️', 'info' => '🔔' }.each do |level, emoji|
      notify!('--title', 'Deadline', '--message', 'Enrol', '--level', level)
      assert_match(/-title #{emoji} Claude: Deadline /, calls.last)
    end
  end

  def test_an_unknown_level_is_refused
    _out, err, status = run_notify('--title', 'Deadline', '--message', 'Enrol', '--level', 'loud')
    refute status.success?
    assert_match(/urgent, warn or info/, err)
  end

  def test_urgent_goes_through_the_claude_urgent_app_once_set_up
    fake_app('Claude Notify')
    fake_app('Claude Urgent')
    notify!('--title', 'Gateway incident', '--message', 'RC 91', '--level', 'urgent')
    assert_equal 'Claude Urgent -title 🚨 Gateway incident -message RC 91 -sound Submarine ' \
                 '-activate com.googlecode.iterm2', calls.last
  end

  def test_other_levels_go_through_the_claude_app_once_set_up
    fake_app('Claude Notify')
    fake_app('Claude Urgent')
    notify!('--title', 'Deadline', '--message', 'Enrol', '--level', 'warn')
    assert_match(/\AClaude Notify -title ⚠️ Deadline /, calls.last)
  end

  def test_setup_never_replaces_an_app_it_did_not_build
    plist = File.join(@apps, 'Claude Notify.app', 'Contents', 'Info.plist')
    FileUtils.mkdir_p(File.dirname(plist))
    system('plutil', '-create', 'xml1', plist)
    system('plutil', '-insert', 'CFBundleIdentifier', '-string', 'com.example.someone-else', plist)

    _out, err, status = run_notify('--setup')

    refute status.success?
    assert_match(/someone else's app \(com\.example\.someone-else\)/, err)
    assert File.exist?(plist)
  end

  def test_falls_back_to_osascript_without_terminal_notifier
    File.delete(File.join(@dir, 'terminal-notifier'))
    notify!('--title', 'Deadline', '--message', 'Enrol the Mac today')
    assert_match(/\Aosascript .*display notification.* Enrol the Mac today 🔔 Claude: Deadline\z/, calls.first)
  end

  def test_title_and_message_are_required
    _out, err, status = run_notify('--title', 'Deadline')
    refute status.success?
    assert_match(/--message/, err)
  end

  private

  def run_notify(*args)
    env = { 'PATH' => "#{@dir}:/usr/bin:/bin", 'CLAUDE_NOTIFY_APPS' => @apps }
    Open3.capture3(env, RbConfig.ruby, SCRIPT, *args)
  end

  def notify!(*args)
    out, err, status = run_notify(*args)
    assert status.success?, "claude-notify failed: #{out}#{err}"
  end

  def fake_app(name)
    bin = File.join(@apps, "#{name}.app", 'Contents', 'MacOS', 'terminal-notifier')
    FileUtils.mkdir_p(File.dirname(bin))
    File.write(bin, "#!/bin/sh\nprintf '%s\\n' \"#{name} $*\" >> #{@calls}\n")
    File.chmod(0o755, bin)
  end

  def calls
    File.exist?(@calls) ? File.readlines(@calls, chomp: true) : []
  end
end
