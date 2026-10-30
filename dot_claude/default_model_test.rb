#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative 'default_model'

class DefaultModelTest < Minitest::Test
  def setup
    @dir    = Dir.mktmpdir
    @record = File.join(@dir, 'record.json')
    @lock   = File.join(@dir, 'record.lock')
    @ran    = File.join(@dir, 'ran')
    @probe  = "touch #{@ran}"
  end

  def teardown = FileUtils.rm_rf(@dir)

  def refresh(now: Time.now) = DefaultModel.refresh(record: @record, lock: @lock, probe: @probe, now:)

  def probe_ran?
    20.times { File.exist?(@ran) ? break : sleep(0.05) }
    File.exist?(@ran)
  end

  def test_a_missing_record_starts_the_probe_in_the_background
    assert_equal :started, refresh
    assert probe_ran?
  end

  def test_a_record_under_ten_minutes_old_is_left_alone
    File.write(@record, '{}')
    assert_equal :fresh, refresh(now: Time.now + 590)
    assert_equal :started, refresh(now: Time.now + 610)
  end

  def test_the_probe_gets_none_of_the_session_env
    @probe = "env > #{@ran}"
    ENV['ANTHROPIC_MODEL'] = 'claude-haiku-4-5'
    refresh
    assert probe_ran?
    sleep 0.1
    refute_includes File.read(@ran), 'ANTHROPIC_MODEL'
    assert_includes File.read(@ran), "HOME=#{Dir.home}"
  ensure
    ENV.delete('ANTHROPIC_MODEL')
  end

  def test_only_one_draw_starts_the_probe
    assert_equal :started, refresh
    assert_equal :locked, refresh
  end

  def test_a_lock_left_by_a_failed_probe_lets_a_retry_through_after_two_minutes
    assert_equal :started, refresh
    assert_equal :locked, refresh(now: Time.now + 110)
    assert_equal :started, refresh(now: Time.now + 130)
  end
end
