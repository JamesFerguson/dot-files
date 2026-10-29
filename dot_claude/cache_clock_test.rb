#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'tmpdir'
require_relative 'cache_clock'

class CacheClockTest < Minitest::Test
  NOW = Time.utc(2026, 10, 29, 2, 0, 0)

  def reply(at, w5: 0, w1: 0, read: 0, sidechain: false)
    JSON.generate(type: 'assistant', isSidechain: sidechain, timestamp: at.utc.iso8601,
                  message: { usage: { cache_read_input_tokens: read,
                                      cache_creation: { ephemeral_5m_input_tokens: w5, ephemeral_1h_input_tokens: w1 } } })
  end

  def transcript(*lines)
    path = File.join(Dir.mktmpdir, 't.jsonl')
    File.write(path, lines.join("\n") + "\n")
    path
  end

  def test_the_clock_runs_from_the_last_reply_with_the_ttl_of_the_last_write
    path = transcript(reply(NOW - 3000, w1: 90_000), reply(NOW - 600, read: 90_000))
    assert_equal [NOW - 600, 3600], CacheClock.read(path)
  end

  def test_a_five_minute_write_sets_a_five_minute_ttl
    path = transcript(reply(NOW - 3000, w1: 90_000), reply(NOW - 60, w5: 4_000, read: 90_000))
    assert_equal [NOW - 60, 300], CacheClock.read(path)
  end

  def test_subagent_replies_do_not_touch_the_main_thread_cache
    path = transcript(reply(NOW - 900, w1: 90_000), reply(NOW - 30, w5: 1_000, sidechain: true))
    assert_equal [NOW - 900, 3600], CacheClock.read(path)
  end

  def test_no_reading_without_a_reply
    assert_nil CacheClock.read(transcript('{"type":"user"}'))
    assert_nil CacheClock.read('/nonexistent.jsonl')
  end

  def test_warm_shows_the_minutes_left
    assert_includes CacheClock.render(NOW - 600, 3600, now: NOW), '50m'
  end

  def test_cold_says_so
    assert_includes CacheClock.render(NOW - 4000, 3600, now: NOW), 'cold'
  end
end
