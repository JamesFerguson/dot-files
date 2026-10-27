#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'tmpdir'
require 'fileutils'
require 'time'
require_relative 'usage_credits'

class UsageCreditsCostTest < Minitest::Test
  def test_prices_every_token_kind_at_the_models_rates
    usage = { 'input_tokens' => 1_000_000, 'output_tokens' => 1_000_000, 'cache_read_input_tokens' => 1_000_000,
              'cache_creation' => { 'ephemeral_5m_input_tokens' => 1_000_000, 'ephemeral_1h_input_tokens' => 1_000_000 } }

    # Opus 5.5: $4 in, $20 out, $0.20 cache read, 1.25x and 2x input for 5m and 1h writes
    assert_in_delta 4 + 20 + 0.20 + 5 + 8, UsageCredits.message_cost(usage, 'claude-opus-5-5'), 1e-9
  end

  def test_prices_each_iteration_at_its_own_model_so_advisor_calls_count
    usage = { 'input_tokens' => 1, 'output_tokens' => 1,
              'iterations' => [
                { 'type' => 'message', 'input_tokens' => 1_000_000, 'output_tokens' => 0 },
                { 'type' => 'advisor_message', 'model' => 'claude-fable-5-1', 'input_tokens' => 1_000_000, 'output_tokens' => 0 }
              ] }

    assert_in_delta 4 + 10, UsageCredits.message_cost(usage, 'claude-opus-5-5'), 1e-9
  end

  def test_unknown_models_are_priced_at_the_default_rate_and_reported
    unpriced = []
    cost = UsageCredits.message_cost({ 'input_tokens' => 1_000_000 }, 'claude-new-9', unpriced: unpriced)

    assert_in_delta 4, cost, 1e-9
    assert_equal ['claude-new-9'], unpriced
  end
end

class UsageCreditsMeterTest < Minitest::Test
  START = Time.utc(2026, 10, 27, 0, 24)

  def setup
    @dir = Dir.mktmpdir
    @projects = File.join(@dir, 'projects', 'p')
    FileUtils.mkdir_p(@projects)
    @config = File.join(@dir, 'usage-credits.json')
    @state = File.join(@dir, 'usage-credits-state.json')
    File.write(@config, JSON.generate('budget_usd' => 100, 'started_at' => START.iso8601))
  end

  def teardown = FileUtils.rm_rf(@dir)

  def meter(now) = UsageCredits::Meter.new(config_path: @config, state_path: @state, projects_dir: File.dirname(@projects), now: now)

  # One assistant entry costing $4 (1M Opus 5.5 input tokens).
  def entry(at, request_id)
    JSON.generate('type' => 'assistant', 'timestamp' => at.utc.iso8601(3), 'requestId' => request_id,
                  'message' => { 'model' => 'claude-opus-5-5', 'usage' => { 'input_tokens' => 1_000_000 } })
  end

  def append(file, *lines) = File.open(File.join(@projects, file), 'a') { |f| lines.each { f.puts(_1) } }

  def test_counts_only_messages_from_when_credits_started
    append('a.jsonl', entry(START - 60, 'r0'), entry(START + 60, 'r1'))

    assert_in_delta 4, meter(START + 120).update(limit_hit: true)[:spent], 1e-9
  end

  def test_counts_a_request_once_however_many_content_blocks_it_wrote
    append('a.jsonl', entry(START + 60, 'r1'), entry(START + 61, 'r1'))

    assert_in_delta 4, meter(START + 120).update(limit_hit: true)[:spent], 1e-9
  end

  def test_reads_only_new_lines_on_later_redraws
    append('a.jsonl', entry(START + 60, 'r1'))
    meter(START + 120).update(limit_hit: true)
    append('a.jsonl', entry(START + 180, 'r2'))

    assert_in_delta 8, meter(START + 240).update(limit_hit: true)[:spent], 1e-9
  end

  def test_sums_across_sessions_and_subagents
    append('a.jsonl', entry(START + 60, 'r1'))
    FileUtils.mkdir_p(File.join(@projects, 's', 'subagents'))
    append('s/subagents/agent-1.jsonl', entry(START + 70, 'r2'))

    assert_in_delta 8, meter(START + 120).update(limit_hit: true)[:spent], 1e-9
  end

  def test_stops_counting_once_no_limit_is_hit_and_resumes_when_one_is
    append('a.jsonl', entry(START + 60, 'r1'))
    meter(START + 120).update(limit_hit: true)
    meter(START + 3600).update(limit_hit: false)                 # weekly reset: back on the plan
    append('a.jsonl', entry(START + 3700, 'r2'))
    meter(START + 3800).update(limit_hit: false)
    append('a.jsonl', entry(START + 7300, 'r3'))

    assert_in_delta 8, meter(START + 7400).update(limit_hit: true)[:spent], 1e-9
  end

  def test_finds_the_start_in_a_long_file_without_counting_earlier_lines
    old = (1..500).map { entry(START - (600 - _1), "old#{_1}") }
    append('big.jsonl', *old, entry(START + 60, 'new'))

    assert_in_delta 4, meter(START + 120).update(limit_hit: true)[:spent], 1e-9
  end

  def test_reports_percentage_of_budget
    append('a.jsonl', entry(START + 60, 'r1'))

    assert_equal 4, meter(START + 120).update(limit_hit: true)[:pct]
  end

  def test_returns_nil_without_a_config
    File.delete(@config)

    assert_nil meter(START).update(limit_hit: true)
  end
end
