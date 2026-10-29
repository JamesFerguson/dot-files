# frozen_string_literal: true

# Usage-credits meter for the status line.
#
# Once a plan's rate limit is used up, Claude Code bills further usage to prepaid usage credits.
# Nothing in the status-line payload reports the credit balance, so this estimates the spend: it
# prices every assistant message in ~/.claude/projects transcripts at API rates and counts the ones
# sent while a limit was at 100%. The payload's per-session cost can't be used instead, because a
# session open before the limit ran out carries its earlier spend.
#
# The status line records the stretches of time when it sees a limit at 100% ("windows"), so
# counting stops at the reset and starts again if a limit runs out later. A window opens from the
# previous redraw, so a message sent just before the first 100% redraw still counts.
#
# Config, written by hand when credits are bought: ~/.claude/usage-credits.json
#   {"budget_usd": 100, "started_at": "2026-10-27T11:24:00+11:00"}
# Delete it to hide the meter.

require 'json'
require 'time'

module UsageCredits
  # $ per million tokens: [input, output, cache read]. Cache writes are 1.25x input (5-minute) and
  # 2x input (1-hour). Rates from the Claude API reference, 2026-10.
  PRICES = {
    'claude-fable-5-1' => [10.0, 50.0, 0.25],
    'claude-fable-5' => [10.0, 50.0, 1.0],
    'claude-opus-5-5' => [4.0, 20.0, 0.20],
    'claude-opus-5' => [5.0, 25.0, 0.50],
    'claude-opus-4-8' => [5.0, 25.0, 0.50],
    'claude-opus-4-7' => [5.0, 25.0, 0.50],
    'claude-opus-4-6' => [5.0, 25.0, 0.50],
    'claude-sonnet-5-5' => [2.0, 10.0, 0.20],
    'claude-sonnet-5' => [2.0, 10.0, 0.20],
    'claude-sonnet-4-6' => [3.0, 15.0, 0.30],
    'claude-haiku-5-5' => [0.10, 0.50, 0.01],
    'claude-haiku-4-5' => [1.0, 5.0, 0.10]
  }.freeze
  DEFAULT_MODEL = 'claude-opus-5-5'

  module_function

  # Advisor and fallback calls run on their own models and appear as extra `iterations`, so a
  # message with iterations is the sum of them, each at its own model's rates.
  def message_cost(usage, model, unpriced: [])
    parts = usage['iterations'].is_a?(Array) && !usage['iterations'].empty? ? usage['iterations'] : [usage]
    parts.sum { |part| tokens_cost(part, part['model'] || model, unpriced) }
  end

  def tokens_cost(usage, model, unpriced)
    id = model.to_s.sub(/\[.*\]\z/, '')
    # Claude Code writes these replies itself (an interrupted turn, an API error), with no API call.
    return 0.0 if id == '<synthetic>'

    unless PRICES.key?(id)
      unpriced << id unless unpriced.include?(id)
      id = DEFAULT_MODEL
    end
    input, output, cache_read = PRICES[id]
    writes = usage['cache_creation'] || {}
    write_5m = writes['ephemeral_5m_input_tokens'] || (writes.empty? ? usage['cache_creation_input_tokens'].to_i : 0)
    write_1h = writes['ephemeral_1h_input_tokens'].to_i

    (usage['input_tokens'].to_i * input + usage['output_tokens'].to_i * output +
      usage['cache_read_input_tokens'].to_i * cache_read +
      write_5m.to_i * input * 1.25 + write_1h * input * 2) / 1_000_000.0
  end

  class Meter
    RECENT_REQUESTS = 50

    def initialize(config_path:, state_path:, projects_dir:, now: Time.now)
      @config_path = config_path
      @state_path = state_path
      @projects_dir = projects_dir
      @now = now.to_f
    end

    # Records whether a limit is at 100% now, counts new messages, and returns the totals.
    # Another session's redraw may hold the lock; this one then shows the last saved total.
    def update(limit_hit:)
      config = (JSON.parse(File.read(@config_path)) rescue nil) or return nil
      @started_at = Time.iso8601(config.fetch('started_at')).to_f
      budget = config.fetch('budget_usd').to_f

      state = File.open("#{@state_path}.lock", File::RDWR | File::CREAT) do |lock|
        next load_state unless lock.flock(File::LOCK_EX | File::LOCK_NB)

        load_state.tap do |s|
          record_window(s, limit_hit)
          scan(s)
          File.write(@state_path, JSON.generate(s))
        end
      end
      spent = state['spent'].to_f
      { spent: spent, budget: budget, pct: (spent / budget * 100).round, unpriced: state['unpriced'] }
    end

    private

    def load_state
      state = (JSON.parse(File.read(@state_path)) rescue nil) || {}
      return fresh_state unless state['started_at'] == @started_at

      state
    end

    def fresh_state = { 'started_at' => @started_at, 'windows' => [], 'files' => {}, 'spent' => 0.0, 'unpriced' => [] }

    def record_window(state, limit_hit)
      windows = state['windows']
      if limit_hit
        if state['hit'] && windows.any? then windows.last[1] = @now
        else windows << [state['last_render_at'] || @started_at, @now]
        end
      elsif state['hit'] && windows.any?
        windows.last[1] = @now
      end
      state['hit'] = limit_hit
      state['last_render_at'] = @now
    end

    def scan(state)
      return if state['windows'].empty?

      earliest = state['windows'].first[0]
      Dir.glob(File.join(@projects_dir, '**', '*.jsonl')).each do |path|
        next if File.mtime(path).to_f < earliest

        file = state['files'][path] ||= { 'offset' => first_offset_after(path, earliest), 'recent' => [] }
        read_new_lines(path, file, state)
      end
    end

    def read_new_lines(path, file, state)
      size = File.size(path)
      file['offset'] = 0 if size < file['offset'] # rewritten or truncated
      return if size == file['offset']

      chunk = File.open(path, 'rb') { |f| f.seek(file['offset']); f.read }
      complete = chunk[0..chunk.rindex("\n").to_i]
      return unless chunk.include?("\n")

      file['offset'] += complete.bytesize
      complete.each_line { |line| count(line, file, state) }
    end

    def count(line, file, state)
      return unless line.include?('"type":"assistant"')

      entry = JSON.parse(line) rescue return
      return unless entry['type'] == 'assistant' && (usage = entry.dig('message', 'usage'))

      at = (Time.iso8601(entry['timestamp']).to_f rescue return)
      return unless state['windows'].any? { |from, to| at >= from && at <= to }

      id = entry['requestId'] || entry['uuid']
      return if file['recent'].include?(id)

      file['recent'] = (file['recent'] << id).last(RECENT_REQUESTS)
      state['spent'] += UsageCredits.message_cost(usage, entry.dig('message', 'model'), unpriced: state['unpriced'])
    end

    # Transcripts are append-only and in time order, so binary-search for the first line at or
    # after `since` rather than reading a large file from the start.
    def first_offset_after(path, since)
      File.open(path, 'rb') do |f|
        low, high = 0, f.size
        while low < high
          mid = (low + high) / 2
          f.seek(mid)
          f.gets unless mid.zero? # skip to the start of the next whole line
          at, start = next_timestamp(f)
          if at.nil? || at >= since then high = mid
          else low = start + 1
          end
        end
        line_start(f, low)
      end
    end

    # The first timestamp at or after the file's position, and the offset of the line it was on.
    def next_timestamp(file)
      while (start = file.pos) && (line = file.gets)
        stamp = line[/"timestamp":"([^"]+)"/, 1] or next
        return [(Time.iso8601(stamp).to_f rescue nil), start]
      end
      [nil, file.size]
    end

    def line_start(file, offset)
      return 0 if offset.zero?

      file.seek(offset - 1)
      file.read(1) == "\n" ? offset : (file.gets && file.pos)
    end
  end
end
