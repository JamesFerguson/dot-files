# Run: ruby dot_claude/rules_changes/rules_changes_test.rb
# Drives the CLI against a temp register and seen-markers dir, with future_claude swapped for a recorder.
require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'open3'
require 'fileutils'

class RulesChangesTest < Minitest::Test
  SCRIPT = File.expand_path('rules-changes', __dir__)

  def setup
    @dir = Dir.mktmpdir('rules_changes_test')
    @fc_calls = File.join(@dir, 'fc_calls')
    fake = File.join(@dir, 'future_claude')
    File.write(fake, "#!/bin/sh\nprintf '%s\\n' \"$@\" > #{@fc_calls}\necho abc123\n")
    File.chmod(0o755, fake)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_add_registers_the_change_without_queuing_a_job
    out = rc!('add', '--file', '~/.claude/rules/fz/tooling.md', '--section', 'mise',
              '--gist', 'mise.toml outranks .tool-versions', '--commit', '5d27337', '--session', 'nightly',
              now: '2026-10-27 14:54')
  
    row = register.first
    assert_equal ['~/.claude/rules/fz/tooling.md'], row['files']
    assert_equal 'mise.toml outranks .tool-versions', row['gist']
    assert_nil row['sent_at']
    assert_match(/registered #{row['id']}/, out)
    refute File.exist?(@fc_calls)
  end
  
  def test_prompt_hook_shows_changes_made_since_the_session_started
    rc!('add', '--file', 'fz/old.md', '--gist', 'before the session', now: '2026-10-27 09:00')
    rc!('add', '--file', 'fz/tooling.md', '--gist', 'mise note', '--commit', 'aaa111', now: '2026-10-27 11:00')
    transcript = transcript_started_at('2026-10-26T23:30:00Z') # 10:30 AEDT
  
    out = hook!('s1', transcript, now: '2026-10-27 12:00')
  
    context = JSON.parse(out).dig('hookSpecificOutput', 'additionalContext')
    assert_equal 'UserPromptSubmit', JSON.parse(out).dig('hookSpecificOutput', 'hookEventName')
    assert_includes context, 'fz/tooling.md'
    assert_includes context, 'mise note (aaa111)'
    refute_includes context, 'before the session'
  end
  
  def test_prompt_hook_shows_each_change_once_per_session
    transcript = transcript_started_at('2026-10-26T22:00:00Z')
    rc!('add', '--file', 'a.md', '--gist', 'one', now: '2026-10-27 10:00')
    hook!('s1', transcript, now: '2026-10-27 10:05')
  
    assert_empty hook!('s1', transcript, now: '2026-10-27 10:10')
  
    rc!('add', '--file', 'b.md', '--gist', 'two', now: '2026-10-27 10:20')
    context = JSON.parse(hook!('s1', transcript, now: '2026-10-27 10:30')).dig('hookSpecificOutput', 'additionalContext')
    assert_includes context, 'two'
    refute_includes context, 'one'
  end
  
  def test_prompt_hook_prints_nothing_when_nothing_changed
    assert_empty hook!('s2', transcript_started_at('2026-10-27T00:00:00Z'), now: '2026-10-27 12:00')
  end
  
  def test_add_needs_a_file_and_a_gist
    refute rc('add', '--gist', 'x')[2].success?
    refute rc('add', '--file', 'a.md')[2].success?
    assert_empty register
  end

  def test_digest_groups_pending_changes_by_file_and_ends_with_their_ids
    rc!('add', '--file', 'fz/tooling.md', '--gist', 'mise note', '--commit', 'aaa111')
    rc!('add', '--file', 'fz/tooling.md', '--gist', 'second note')
    rc!('add', '--file', 'general/notifications.md', '--gist', 'reminders only when asked')
    ids = register.map { |r| r['id'] }

    out = rc!('digest')

    assert_match(/\ARules digest:/, out)
    assert_equal 1, out.scan('fz/tooling.md').size
    assert_includes out, 'mise note (aaa111)'
    assert_includes out, 'second note'
    assert_equal "IDS: #{ids.join(' ')}", out.lines.last.chomp
  end

  def test_digest_with_nothing_pending_says_so
    assert_equal "nothing pending\n", rc!('digest')
  end

  def test_mark_sent_marks_only_the_named_ids
    rc!('add', '--file', 'a.md', '--gist', 'one')
    rc!('add', '--file', 'b.md', '--gist', 'two')
    first, second = register.map { |r| r['id'] }

    rc!('mark-sent', first)

    sent, unsent = register
    refute_nil sent['sent_at']
    assert_nil unsent['sent_at']
    assert_equal [second], rc!('pending').lines.map { |l| l.split.first }
  end

  private

  def transcript_started_at(utc)
    path = File.join(@dir, "t#{rand(1_000_000)}.jsonl")
    File.write(path, JSON.generate('type' => 'user', 'timestamp' => utc) + "\n")
    path
  end
  
  def hook!(session, transcript, now:)
    input = JSON.generate('session_id' => session, 'transcript_path' => transcript, 'hook_event_name' => 'UserPromptSubmit')
    out, err, status = Open3.capture3(env(now), SCRIPT, 'prompt-hook', stdin_data: input)
    assert status.success?, "prompt-hook failed: #{err}"
    out
  end
  
  def env(now)
    { 'RULES_CHANGES_FILE' => File.join(@dir, 'register.jsonl'),
      'RULES_CHANGES_SEEN_DIR' => File.join(@dir, 'seen'),
      'RULES_CHANGES_FUTURE_CLAUDE' => File.join(@dir, 'future_claude'),
      'RULES_CHANGES_NOW' => now, 'TZ' => 'Australia/Sydney' }
  end
  
  def rc(*args, now: nil)
    Open3.capture3(env(now), SCRIPT, *args)
  end

  def rc!(*args, now: nil)
    out, err, status = rc(*args, now: now)
    assert status.success?, "rules-changes #{args.join(' ')} failed: #{err}"
    out
  end

  def register
    path = File.join(@dir, 'register.jsonl')
    File.exist?(path) ? File.readlines(path).map { |l| JSON.parse(l) } : []
  end
end
