# Run: ruby dot_claude/claude_notify/claude_notify_test.rb
# Drives the CLI as a subprocess, with terminal-notifier, say and osascript swapped for recorders.
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
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_a_link_opens_on_click
    notify!('--title', 'Gateway incident', '--message', 'RC 91 on every eftpos txn', '--open', 'https://example.test/x')
    assert_includes calls, 'terminal-notifier -title Claude: Gateway incident -message RC 91 on every eftpos txn ' \
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

  def test_falls_back_to_osascript_without_terminal_notifier
    File.delete(File.join(@dir, 'terminal-notifier'))
    notify!('--title', 'Deadline', '--message', 'Enrol the Mac today')
    assert_match(/\Aosascript .*display notification.* Enrol the Mac today Claude: Deadline\z/, calls.first)
  end

  def test_title_and_message_are_required
    _out, err, status = run_notify('--title', 'Deadline')
    refute status.success?
    assert_match(/--message/, err)
  end

  private

  def run_notify(*args)
    Open3.capture3({ 'PATH' => "#{@dir}:/usr/bin:/bin" }, RbConfig.ruby, SCRIPT, *args)
  end

  def notify!(*args)
    out, err, status = run_notify(*args)
    assert status.success?, "claude-notify failed: #{out}#{err}"
  end

  def calls
    File.exist?(@calls) ? File.readlines(@calls, chomp: true) : []
  end
end
