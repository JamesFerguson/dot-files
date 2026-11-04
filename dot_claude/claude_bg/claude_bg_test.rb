# Run: ruby dot_claude/claude_bg/claude_bg_test.rb
# Drives claude-bg as a subprocess with `claude` swapped for a fake that plays the background session.
require 'minitest/autorun'
require 'tmpdir'
require 'open3'
require 'fileutils'

class ClaudeBgTest < Minitest::Test
  SCRIPT = File.expand_path('claude-bg', __dir__)
  URL = 'https://claude.ai/code/artifact/0b5e'.freeze

  def setup
    @dir = Dir.mktmpdir('claude_bg_test')
    @state = File.join(@dir, 'state')
    @page = File.join(@dir, 'report.html')
    File.write(@page, <<~HTML)
      <!DOCTYPE html>
      <html lang="en">
      <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Daily Purchase Stats</title>
      <style>body { color: red }</style>
      </head>
      <body>
      <h1>Stats</h1>
      </body>
      </html>
    HTML
    fake_claude(%(printf '%s' "#{URL}" > "$done"))
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_publish_stages_the_page_without_its_document_wrapper
    bg!('publish', '--file', @page, '--state', @state)
    staged = File.read(File.join(@state, 'report.html'))

    assert_includes staged, '<title>Daily Purchase Stats</title>'
    assert_includes staged, '<h1>Stats</h1>'
    refute_match(/<!doctype|<html|<head|<body|charset|name="viewport"/i, staged)
  end

  def test_a_first_publish_asks_for_a_new_artifact_and_remembers_its_url
    out = bg!('publish', '--file', @page, '--state', @state, '--icon', 'chart')

    assert_equal URL, out.strip
    assert_equal URL, File.read(File.join(@state, 'artifact_url'))
    assert_includes calls, 'icon "chart"'
    refute_includes calls, 'action "read"'
  end

  def test_a_later_publish_reads_the_live_artifact_and_replaces_it
    FileUtils.mkdir_p(@state)
    File.write(File.join(@state, 'artifact_url'), URL)
    bg!('publish', '--file', @page, '--state', @state)

    assert_includes calls, %(action "read" and that url first, then publish with file_path #{File.join(@state, 'report.html')} and url #{URL})
  end

  def test_the_publish_session_is_stopped_and_removed_once_it_finishes
    bg!('publish', '--file', @page, '--state', @state)

    assert_match(/^stop feed42$/, calls)
    assert_match(/^rm feed42$/, calls)
  end

  def test_a_failed_publish_exits_nonzero_and_keeps_the_old_url
    FileUtils.mkdir_p(@state)
    File.write(File.join(@state, 'artifact_url'), URL)
    fake_claude(%(printf 'FAILED: %s' 'publish refused' > "$done"))
    _out, err, status = bg('publish', '--file', @page, '--state', @state)

    refute status.success?
    assert_includes err, 'publish refused'
    assert_equal URL, File.read(File.join(@state, 'artifact_url'))
  end

  def test_a_publish_that_never_finishes_leaves_the_session_up_and_exits_2
    fake_claude(':')
    _out, err, status = bg('publish', '--file', @page, '--state', @state, '--timeout', '1')

    assert_equal 2, status.exitstatus
    assert_includes err, 'claude attach feed42'
    refute_match(/^stop /, calls)
  end

  def test_start_prints_the_id_of_a_session_left_running
    out = bg!('start', '--name', 'purchase-stats 2026-11-05', '--model', 'opus', 'Drill into the flags')

    assert_equal 'feed42', out.strip
    assert_includes calls, '--bg --name purchase-stats 2026-11-05 --permission-mode auto --model opus -- Drill into the flags'
    refute_match(/^stop /, calls)
  end

  private

  # The fake records each call. For --bg it finds the done file the prompt names and runs body.
  def fake_claude(body)
    path = File.join(@dir, 'claude')
    File.write(path, <<~SH)
      #!/bin/sh
      printf '%s\\n' "$*" >> #{File.join(@dir, 'calls.log')}
      if [ "$1" = "--bg" ]; then
        done=$(printf '%s' "$*" | grep -oE "> [^ ]+publish.done" | head -1 | cut -c3-)
        #{body}
        echo "  claude stop feed42    stop this session"
      fi
    SH
    File.chmod(0o755, path)
  end

  def bg(*args)
    Open3.capture3({ 'CLAUDE_BG_CLAUDE' => File.join(@dir, 'claude') }, SCRIPT, *args, chdir: @dir)
  end

  def bg!(*args)
    out, err, status = bg(*args)
    assert status.success?, "claude-bg #{args.join(' ')} failed: #{err}"
    out
  end

  def calls
    path = File.join(@dir, 'calls.log')
    File.exist?(path) ? File.read(path) : ''
  end
end
