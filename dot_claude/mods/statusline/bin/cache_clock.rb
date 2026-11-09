# frozen_string_literal: true

require 'json'
require 'time'

# How long until the session's prompt cache goes cold, and how big the context was at the last reply,
# for the status line.
#
# Every API call restarts the cache's clock, and the TTL is whichever the last cache write used
# (5 minutes, or 1 hour; a session in usage overage drops to 5). Once it runs out, the next reply
# rewrites the whole context at the cache-write price.
module CacheClock
  SOON = 600 # warn once the cache has ten minutes or less left

  # last_at: when the last main-thread request went out; ttl: seconds the cache lives after it; tokens: the context
  # that reply was answered over (uncached, cache-written and cache-read input together).
  Reading = Data.define(:last_at, :ttl, :tokens) do
    def expires_at = last_at + ttl
  end

  # What's written just before a request goes out: the prompt or the tool results, and their attachments.
  REQUEST_TYPES = %w[user attachment].freeze

  module_function

  # The Reading for the newest main-thread reply, or nil. Reads backwards from the end, and stops at a
  # compaction: the replies before it were over a context that's gone.
  #
  # The cache's clock restarts when the request goes out, which can be 40 seconds before the reply's
  # last line is written, so it runs from the entry the request was sent after.
  def read(transcript_path)
    return nil unless transcript_path && File.file?(transcript_path)

    reply = sent_at = ttl = nil
    each_line_backwards(transcript_path) do |line|
      return nil if line.include?('"compact_boundary"') && compaction?(line)
      next unless line.include?('"usage"') || (reply && !sent_at)

      entry = JSON.parse(line) rescue next
      next if entry['isSidechain'] || !(at = (Time.parse(entry['timestamp']) rescue nil))

      usage = entry['type'] == 'assistant' && entry.dig('message', 'usage')
      if usage && !reply
        reply = { id: entry.dig('message', 'id'), tokens: usage.values_at('input_tokens', 'cache_read_input_tokens', 'cache_creation_input_tokens').sum(&:to_i) }
      elsif reply && !sent_at && (REQUEST_TYPES.include?(entry['type']) || (usage && entry.dig('message', 'id') != reply[:id]))
        sent_at = at
      end
      ttl ||= usage && ttl_of(usage)
      return Reading.new(sent_at, ttl, reply[:tokens]) if sent_at && ttl
    end
    nil
  end

  # The TTL a reply's cache write used, or nil when it wrote nothing.
  def ttl_of(usage)
    cc = usage['cache_creation'] || {}
    return 3600 if cc['ephemeral_1h_input_tokens'].to_i.positive?

    300 if cc['ephemeral_5m_input_tokens'].to_i.positive?
  end

  def compaction?(line)
    entry = JSON.parse(line) rescue (return false)
    entry['type'] == 'system' && entry['subtype'] == 'compact_boundary'
  end

  def each_line_backwards(path, limit: 8 << 20)
    File.open(path, 'rb') do |f|
      pos  = f.size
      tail = +''
      while pos.positive? && f.size - pos < limit
        step = [pos, 256 << 10].min
        pos -= step
        f.seek(pos)
        lines = (f.read(step) + tail).split("\n")
        tail  = pos.positive? ? lines.shift.to_s : ''
        lines.reverse_each { yield _1 }
      end
    end
  end

  def render(reading, now: Time.now)
    left = (reading.expires_at - now).to_i
    return "\033[38;2;90;140;200m🧊 cold\033[0m" unless left.positive?

    colour = left > SOON ? '0;200;80' : '255;140;0'
    "\033[38;2;#{colour}m⏳ #{left >= 60 ? "#{left / 60}m" : "#{left}s"}\033[0m"
  end
end
