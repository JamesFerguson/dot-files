# Run: ruby dot_claude/rules_changes/rules_changes_test.rb
# Drives the CLI against a temp register, with future_claude swapped for a recorder.
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

  # 27 Oct 2026 is a Tuesday, 30 Oct a Friday, 31 Oct a Saturday, 2 Nov a Monday.
  def test_next_slot_is_the_next_review_time_on_a_weekday
    assert_equal '2026-10-27 13:00', slot_at('2026-10-27 12:59')
    assert_equal '2026-10-27 17:15', slot_at('2026-10-27 13:00')
    assert_equal '2026-10-28 13:00', slot_at('2026-10-27 17:15')
    assert_equal '2026-11-02 13:00', slot_at('2026-10-30 17:20')
    assert_equal '2026-11-02 13:00', slot_at('2026-10-31 10:00')
  end

  def test_add_registers_the_change_and_queues_one_headless_digest_job_keyed_to_the_slot
    out = rc!('add', '--file', '~/.claude/rules/fz/tooling.md', '--section', 'mise',
              '--gist', 'mise.toml outranks .tool-versions', '--commit', '5d27337', '--session', 'nightly',
              now: '2026-10-27 14:54')

    row = register.first
    assert_equal ['~/.claude/rules/fz/tooling.md'], row['files']
    assert_equal 'mise.toml outranks .tool-versions', row['gist']
    assert_nil row['sent_at']
    assert_match(/2026-10-27 17:15/, out)

    args = File.read(@fc_calls).lines.map(&:chomp)
    assert_equal 'add', args.first
    assert_equal '2026-10-27 17:15', args[args.index('--at') + 1]
    assert_equal 'rules-digest:2026-10-27 17:15', args[args.index('--key') + 1]
    assert_includes args, '--headless'
    assert_includes args[args.index('--allowed-tools') + 1], 'SendMessage'
    assert_includes File.read(@fc_calls), 'rules-changes digest' # the prompt spans several recorded lines
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

  def slot_at(now) = rc!('next-slot', now: now).strip

  def rc(*args, now: nil)
    env = { 'RULES_CHANGES_FILE' => File.join(@dir, 'register.jsonl'),
            'RULES_CHANGES_FUTURE_CLAUDE' => File.join(@dir, 'future_claude'),
            'RULES_CHANGES_NOW' => now, 'TZ' => 'Australia/Sydney' }
    Open3.capture3(env, SCRIPT, *args)
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
