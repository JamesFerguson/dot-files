#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'tmpdir'
require_relative 'cache_clock'

class CacheClockTest < Minitest::Test
  NOW = Time.utc(2026, 10, 29, 2, 0, 0)

  # A request sent at `at` and its reply, whose last line is written `took` seconds later.
  def exchange(at, took: 5, **usage)
    id = "msg_#{at.to_i}"
    [prompt(at), reply(at + 2, id:, **usage), reply(at + took, id:, **usage)]
  end

  def prompt(at, sidechain: false)
    JSON.generate(type: 'user', isSidechain: sidechain, timestamp: at.utc.iso8601, message: { content: 'go' })
  end

  def reply(at, w5: 0, w1: 0, read: 0, input: 0, sidechain: false, id: "msg_#{at.to_i}")
    JSON.generate(type: 'assistant', isSidechain: sidechain, timestamp: at.utc.iso8601,
                  message: { id:, usage: { input_tokens: input, cache_read_input_tokens: read,
                                           cache_creation_input_tokens: w5 + w1,
                                           cache_creation: { ephemeral_5m_input_tokens: w5, ephemeral_1h_input_tokens: w1 } } })
  end

  def compaction(at)
    JSON.generate(type: 'system', subtype: 'compact_boundary', timestamp: at.utc.iso8601)
  end

  def transcript(*lines)
    path = File.join(Dir.mktmpdir, 't.jsonl')
    File.write(path, lines.flatten.join("\n") + "\n")
    path
  end

  def test_the_clock_runs_from_the_last_request_with_the_ttl_of_the_last_write
    reading = CacheClock.read(transcript(exchange(NOW - 3000, w1: 90_000), exchange(NOW - 600, took: 40, read: 90_000)))
    assert_equal [NOW - 600, 3600], [reading.last_at, reading.ttl]
  end

  def test_a_five_minute_write_sets_a_five_minute_ttl
    reading = CacheClock.read(transcript(exchange(NOW - 3000, w1: 90_000), exchange(NOW - 60, w5: 4_000, read: 90_000)))
    assert_equal [NOW - 60, 300], [reading.last_at, reading.ttl]
  end

  def test_subagent_entries_do_not_touch_the_main_thread_cache
    reading = CacheClock.read(transcript(exchange(NOW - 900, w1: 90_000), prompt(NOW - 40, sidechain: true),
                                         reply(NOW - 30, w5: 1_000, sidechain: true)))
    assert_equal [NOW - 900, 3600], [reading.last_at, reading.ttl]
  end

  def test_back_to_back_replies_time_from_the_one_before
    reading = CacheClock.read(transcript(reply(NOW - 900, w1: 90_000), reply(NOW - 880, read: 90_000)))
    assert_equal NOW - 900, reading.last_at
  end

  def test_the_context_is_every_input_token_of_the_last_reply
    reading = CacheClock.read(transcript(exchange(NOW - 3000, w1: 90_000), exchange(NOW - 600, input: 12, w1: 3_000, read: 90_000)))
    assert_equal 93_012, reading.tokens
  end

  def test_nothing_from_before_a_compaction
    assert_nil CacheClock.read(transcript(exchange(NOW - 900, w1: 250_000), compaction(NOW - 800)))
    reading = CacheClock.read(transcript(exchange(NOW - 900, w1: 250_000), compaction(NOW - 800), exchange(NOW - 700, w1: 30_000)))
    assert_equal [NOW - 700, 30_000], [reading.last_at, reading.tokens]
  end

  def test_no_reading_without_a_reply
    assert_nil CacheClock.read(transcript('{"type":"user"}'))
    assert_nil CacheClock.read('/nonexistent.jsonl')
  end

  def test_warm_shows_the_minutes_left
    assert_includes CacheClock.render(CacheClock::Reading.new(NOW - 600, 3600, 0), now: NOW), '50m'
  end

  def test_cold_says_so
    assert_includes CacheClock.render(CacheClock::Reading.new(NOW - 4000, 3600, 0), now: NOW), 'cold'
  end
end
