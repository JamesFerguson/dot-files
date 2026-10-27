# Run: ruby dot_claude/future_claude/future_claude_test.rb
# Drives the CLI as a subprocess against a temp queue, with say/osascript/claude swapped for recorders.
require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'open3'
require 'fileutils'

class FutureClaudeTest < Minitest::Test
  SCRIPT = File.expand_path('future_claude', __dir__)

  def setup
    @dir = Dir.mktmpdir('future_claude_test')
    @calls = File.join(@dir, 'calls.log')
    @recorder = write_exe('recorder', "#!/bin/sh\nprintf '%s\\n' \"$(basename \"$0\") $*\" >> #{@calls}\n")
    FileUtils.ln_s(@recorder, File.join(@dir, 'say'))
    FileUtils.ln_s(@recorder, File.join(@dir, 'osascript'))
    fake_claude('echo "did the thing"; echo HANDED_BACK')
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_add_prints_an_id_and_lists_the_job_as_pending
    out = fc!('add', '--at', '+1h', '--notify', 'Stand up and stretch')
    id = out.strip
    assert_match(/\A[0-9a-f]{6}\z/, id)

    listing = fc!('list')
    assert_includes listing, id
    assert_includes listing, 'pending'
    assert_includes listing, 'Stand up and stretch'
  end

  def test_add_parses_an_absolute_local_time
    id = fc!('add', '--at', '2031-03-04 09:47', '--notify', 'x').strip
    job = queue.find { |j| j['id'] == id }
    assert_equal Time.local(2031, 3, 4, 9, 47).to_i, job['at']
  end

  def test_add_parses_relative_times
    before = Time.now.to_i
    id = fc!('add', '--at', '+90m', '--notify', 'x').strip
    at = queue.find { |j| j['id'] == id }['at']
    assert_in_delta before + 5400, at, 5
  end

  def test_add_refuses_an_unparseable_time
    _out, err, status = fc('add', '--at', 'next tuesday-ish', '--notify', 'x')
    refute status.success?
    assert_match(/can't parse --at/, err)
    assert_empty queue
  end

  def test_add_needs_exactly_one_of_notify_and_prompt
    refute fc('add', '--at', '+1h')[2].success?
    refute fc('add', '--at', '+1h', '--notify', 'a', '--prompt', 'b')[2].success?
    assert_empty queue
  end

  def test_run_fires_a_due_notify_job_and_leaves_future_ones_alone
    due = fc!('add', '--at', '-1m', '--notify', 'Enrol the Mac', '--title', 'MDM', '--say', 'Enrol now').strip
    later = fc!('add', '--at', '+1h', '--notify', 'Later').strip

    fc!('run')

    assert_includes calls, 'say Enrol now'
    assert_match(/osascript .*Enrol the Mac Claude: MDM/, calls)
    refute_includes calls, 'Later'
    assert_equal 'done', job(due)['status']
    assert_equal 'pending', job(later)['status']
  end

  def test_run_does_not_fire_a_job_twice
    fc!('add', '--at', '-1m', '--notify', 'Once')
    fc!('run')
    fc!('run')
    assert_equal 1, calls.scan('say Once').size
  end

  def test_a_prompt_job_with_an_origin_tells_claude_to_hand_back_to_that_session
    id = fc!('add', '--at', '-1m', '--prompt', 'Check the deploy', '--origin', 'mise').strip
    fc!('run')

    prompt = File.read(File.join(@dir, 'claude_args'))
    assert_includes prompt, 'Check the deploy'
    assert_includes prompt, '"mise"'
    assert_includes prompt, id
    assert_equal 'done', job(id)['status']
    assert_equal 'handed_back', job(id)['outcome']
    refute_includes calls, 'osascript', 'a hand-back needs no notification'
  end

  def test_a_prompt_job_queued_from_a_session_hands_back_to_that_sessions_address_by_default
    id = fc!('add', '--at', '-1m', '--prompt', 'Check the deploy',
             env: { 'CLAUDE_CODE_MESSAGING_SOCKET' => '/tmp/cc-socks/4242.sock' }).strip
    assert_equal 'uds:/tmp/cc-socks/4242.sock', job(id)['origin']

    fc!('run')
    assert_includes File.read(File.join(@dir, 'claude_args')), 'SendMessage to exactly "uds:/tmp/cc-socks/4242.sock"'
  end

  def test_headless_skips_the_hand_back_even_from_a_session
    id = fc!('add', '--at', '-1m', '--prompt', 'Check the deploy', '--headless',
             env: { 'CLAUDE_CODE_MESSAGING_SOCKET' => '/tmp/cc-socks/4242.sock' }).strip
    assert_nil job(id)['origin']

    fc!('run')
    refute_includes File.read(File.join(@dir, 'claude_args')), 'SendMessage'
  end

  def test_a_prompt_job_whose_origin_was_gone_notifies
    fake_claude('echo DONE_MYSELF')
    id = fc!('add', '--at', '-1m', '--prompt', 'Check the deploy', '--origin', 'gone-session').strip
    fc!('run')

    assert_equal 'ran_headless', job(id)['outcome']
    assert_match(/osascript .*#{id}/, calls)
  end

  def test_a_headless_job_that_succeeds_makes_no_noise
    fake_claude('echo DONE_MYSELF')
    id = fc!('add', '--at', '-1m', '--prompt', 'Send the digest', '--headless').strip
    fc!('run')

    assert_equal 'done', job(id)['status']
    refute_includes calls, 'osascript'
  end

  def test_a_key_already_pending_returns_that_job_instead_of_adding_another
    first = fc!('add', '--at', '+1h', '--key', 'digest:13:00', '--notify', 'x').strip
    second = fc!('add', '--at', '+1h', '--key', 'digest:13:00', '--notify', 'y').strip

    assert_equal first, second
    assert_equal 1, queue.size
  end

  def test_different_keys_add_separate_jobs
    fc!('add', '--at', '+1h', '--key', 'digest:13:00', '--notify', 'x')
    fc!('add', '--at', '+5h', '--key', 'digest:17:15', '--notify', 'x')
    assert_equal 2, queue.size
  end

  def test_a_finished_job_with_the_key_does_not_block_a_new_one
    first = fc!('add', '--at', '-1m', '--key', 'digest:13:00', '--notify', 'x').strip
    fc!('run')
    second = fc!('add', '--at', '+1h', '--key', 'digest:13:00', '--notify', 'x').strip

    refute_equal first, second
  end

  def test_allowed_tools_are_passed_to_claude
    fc!('add', '--at', '-1m', '--prompt', 'Send the digest', '--headless',
        '--allowed-tools', 'ListAgents,SendMessage,Bash(rules-changes *)')
    fc!('run')
    assert_includes File.read(File.join(@dir, 'claude_args')),
                    '--allowedTools ListAgents,SendMessage,Bash(rules-changes *)'
  end

  def test_a_failing_prompt_job_is_marked_failed_and_notifies
    fake_claude('echo boom >&2; exit 3')
    id = fc!('add', '--at', '-1m', '--prompt', 'Check the deploy').strip
    fc!('run')

    assert_equal 'failed', job(id)['status']
    assert_equal 3, job(id)['exit']
    assert_match(/osascript .*failed/, calls)
    assert_includes File.read(job(id)['log']), 'boom'
  end

  def test_a_prompt_job_past_its_timeout_is_killed_and_marked_failed
    fake_claude('sleep 30')
    id = fc!('add', '--at', '-1m', '--prompt', 'Hang', '--timeout', '1').strip
    started = Time.now
    fc!('run')

    assert_operator Time.now - started, :<, 15
    assert_equal 'failed', job(id)['status']
    assert_equal 'timeout', job(id)['outcome']
  end

  def test_a_repeating_job_is_listed_with_its_interval
    fc!('add', '--at', '+1h', '--every', '1d', '--notify', 'Daily')
    assert_includes fc!('list'), 'every 1d'
  end

  def test_add_refuses_a_bad_interval
    refute fc('add', '--at', '+1h', '--every', 'fortnightly', '--notify', 'x')[2].success?
    refute fc('add', '--at', '+1h', '--every', '0h', '--notify', 'x')[2].success?
    assert_empty queue
  end

  def test_a_repeating_job_fires_once_and_is_rescheduled_for_its_next_slot
    id = fc!('add', '--at', '-1m', '--every', '1h', '--notify', 'Hourly').strip
    at = job(id)['at']
    fc!('run')

    assert_equal 1, calls.scan('say Hourly').size
    assert_equal 'pending', job(id)['status']
    assert_equal at + 3600, job(id)['at']
    assert_equal 1, job(id)['runs']
    assert_equal 'notified', job(id)['last_outcome']
  end

  def test_a_repeating_job_that_missed_several_slots_fires_once_and_skips_to_the_next_future_slot
    id = fc!('add', '--at', '-190m', '--every', '1h', '--notify', 'Hourly').strip
    at = job(id)['at']
    fc!('run')

    assert_equal 1, calls.scan('say Hourly').size
    assert_equal at + 4 * 3600, job(id)['at']
  end

  def test_a_daily_job_keeps_its_wall_clock_time_across_a_daylight_saving_change
    sydney = { 'TZ' => 'Australia/Sydney' }
    id = fc!('add', '--at', '2026-07-01 09:00', '--every', '1d', '--notify', 'x', env: sydney).strip
    fc!('run', env: sydney)

    out, = Open3.capture2({ 'TZ' => 'Australia/Sydney' }, 'date', '-r', job(id)['at'].to_s, '+%H:%M')
    assert_equal '09:00', out.strip
    assert_operator job(id)['at'], :>, Time.now.to_i
  end

  def test_weekdays_moves_a_weekend_start_to_monday
    id = fc!('add', '--at', '2031-03-08 09:00', '--every', '1d', '--weekdays', '--notify', 'x').strip # a Saturday
    assert_equal Time.local(2031, 3, 10, 9, 0).to_i, job(id)['at']
  end

  def test_weekdays_reschedules_onto_a_weekday
    id = fc!('add', '--at', '-1m', '--every', '1d', '--weekdays', '--notify', 'x').strip
    fc!('run')
    refute_includes [0, 6], Time.at(job(id)['at']).wday
  end

  def test_a_repeating_job_ends_once_its_next_slot_is_past_until
    id = fc!('add', '--at', '-1m', '--every', '1h', '--until', '+30m', '--notify', 'Last').strip
    fc!('run')

    assert_equal 'done', job(id)['status']
    assert_includes calls, 'say Last'
  end

  def test_a_failed_run_of_a_repeating_job_still_reschedules_it
    fake_claude('exit 3')
    id = fc!('add', '--at', '-1m', '--every', '1h', '--prompt', 'Check').strip
    fc!('run')

    assert_equal 'pending', job(id)['status']
    assert_equal 'failed', job(id)['last_status']
    assert_match(/osascript .*failed/, calls)
  end

  def test_a_repeating_prompt_job_that_ran_headless_does_not_notify_every_time
    fake_claude('echo DONE_MYSELF')
    fc!('add', '--at', '-1m', '--every', '1h', '--prompt', 'Check', '--origin', 'gone-session')
    fc!('run')
    refute_includes calls, 'osascript'
  end

  def test_a_repeating_job_whose_runner_died_is_rescheduled_not_ended
    id = fc!('add', '--at', '-2h', '--every', '1d', '--notify', 'x').strip
    rewrite_job(id, 'status' => 'running', 'runner_pid' => 999_999)
    fc!('run')

    assert_equal 'pending', job(id)['status']
    assert_equal 'runner_died', job(id)['last_outcome']
    assert_operator job(id)['at'], :>, Time.now.to_i
  end

  def test_rm_removes_a_pending_job
    id = fc!('add', '--at', '+1h', '--notify', 'x').strip
    fc!('rm', id)
    assert_empty queue
  end

  private

  def fc(*args, env: {})
    env = {
      'FUTURE_CLAUDE_HOME' => @dir,
      'FUTURE_CLAUDE_CLAUDE' => File.join(@dir, 'claude'),
      'PATH' => "#{@dir}:#{ENV['PATH']}",
      'CLAUDE_CODE_MESSAGING_SOCKET' => nil
    }.merge(env)
    Open3.capture3(env, SCRIPT, *args)
  end

  def fc!(*args, env: {})
    out, err, status = fc(*args, env: env)
    assert status.success?, "future_claude #{args.join(' ')} failed: #{err}"
    out
  end

  def fake_claude(body)
    write_exe('claude', "#!/bin/sh\nprintf '%s' \"$*\" > #{File.join(@dir, 'claude_args')}\n#{body}\n")
  end

  def write_exe(name, body)
    path = File.join(@dir, name)
    File.write(path, body)
    File.chmod(0o755, path)
    path
  end

  def queue
    path = File.join(@dir, 'queue.jsonl')
    File.exist?(path) ? File.readlines(path).map { |l| JSON.parse(l) } : []
  end

  def job(id)
    queue.find { |j| j['id'] == id }
  end

  def rewrite_job(id, changes)
    jobs = queue.map { |j| j['id'] == id ? j.merge(changes) : j }
    File.write(File.join(@dir, 'queue.jsonl'), jobs.map { |j| "#{JSON.generate(j)}\n" }.join)
  end

  def calls
    File.exist?(@calls) ? File.read(@calls) : ''
  end
end
