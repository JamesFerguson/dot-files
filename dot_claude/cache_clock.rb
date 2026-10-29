# frozen_string_literal: true

require 'json'
require 'time'

# How long until the session's prompt cache goes cold, for the status line.
#
# Every API call restarts the cache's clock, and the TTL is whichever the last cache write used
# (5 minutes, or 1 hour; a session in usage overage drops to 5). Once it runs out, the next reply
# rewrites the whole context at the cache-write price.
module CacheClock
  SOON = 600 # warn once the cache has ten minutes or less left

  module_function

  # [time of the last main-thread reply, TTL in seconds], or nil. Reads backwards from the end.
  def read(transcript_path)
    return nil unless transcript_path && File.file?(transcript_path)

    last_at = nil
    each_line_backwards(transcript_path) do |line|
      next unless line.include?('"usage"')

      entry = JSON.parse(line) rescue next
      next if entry['type'] != 'assistant' || entry['isSidechain']

      usage = entry.dig('message', 'usage') or next
      last_at ||= Time.parse(entry['timestamp']) rescue next
      cc = usage['cache_creation'] || {}
      return [last_at, 3600] if cc['ephemeral_1h_input_tokens'].to_i.positive?
      return [last_at, 300] if cc['ephemeral_5m_input_tokens'].to_i.positive?
    end
    nil
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

  def render(last_at, ttl, now: Time.now)
    left = (last_at + ttl - now).to_i
    return "\033[38;2;90;140;200m🧊 cold\033[0m" unless left.positive?

    colour = left > SOON ? '0;200;80' : '255;140;0'
    "\033[38;2;#{colour}m⏳ #{left >= 60 ? "#{left / 60}m" : "#{left}s"}\033[0m"
  end
end
