#!/usr/bin/env ruby
# frozen_string_literal: true

# Claude Code status line, drawn above the prompt by the statusline mod. Reads the mod's JSON on stdin
# and prints one line of ANSI-coloured text. `parts` in the JSON switches each part off with false.

require 'json'
require 'shellwords'
require_relative 'quota_bar'
require_relative 'cache_clock'
require_relative 'default_model'

input = $stdin.read
data = begin
  JSON.parse(input)
rescue JSON::ParserError
  {}
end

# ── ANSI helpers ──
def rgb(red, grn, blu)
  "\033[38;2;#{red};#{grn};#{blu}m"
end

GREEN   = "\033[32m"
YELLOW  = "\033[33m"
RED     = "\033[31m"
MAGENTA = "\033[1;35m"
BLUE    = "\033[1;34m"
BOLD    = "\033[1m"
RESET   = "\033[0m"
DIM     = rgb(60, 60, 60)
GREY    = rgb(140, 140, 140)

# ── Parse fields ──
PARTS = data['parts'] || {}
def on?(part) = PARTS[part] != false

model   = data.dig('model', 'display_name')
effort  = data.dig('effort', 'level')
used    = data.dig('context_window', 'used_percentage')
ctx_tokens = data.dig('context_window', 'total_input_tokens')
cwd     = data.dig('workspace', 'current_dir') || data['cwd'] || ''
used_5h      = (data.dig('rate_limits', 'five_hour', 'used_percentage') || 0).round
used_7d      = (data.dig('rate_limits', 'seven_day', 'used_percentage') || 0).round
resets_at_5h = data.dig('rate_limits', 'five_hour', 'resets_at')
resets_at_7d = data.dig('rate_limits', 'seven_day', 'resets_at')

# ── Git info ──
branch = ''
repo   = ''
if on?('repo') && !cwd.empty?
  branch   = `git -C #{cwd.shellescape} --no-optional-locks symbolic-ref --short HEAD 2>/dev/null`.chomp
  toplevel = `git -C #{cwd.shellescape} --no-optional-locks rev-parse --show-toplevel 2>/dev/null`.chomp
  repo     = File.basename(toplevel) unless toplevel.empty?
end

# ── Context bar ──
BAR_WIDTH = 10

def bar_color_at(pos)
  # Maps bar position (0–100) to an RGB color along a green -> yellow -> red gradient
  if pos <= 50
    t = pos / 50.0
    rgb(blend(0, 220, t), 200, blend(80, 0, t))
  else
    t = (pos - 50) / 50.0
    rgb(220, blend(200, 40, t), blend(0, 20, t))
  end
end

def blend(from, to, pct)
  (from + (to - from) * pct).round
end

def ctx_emoji(pct)
  case pct
  when 90.. then '🚨'
  when 70.. then '🔥'
  when 20.. then '⚡'
  else '🟢'
  end
end

def pct_ansi(pct)
  case pct
  when 90.. then RED
  when 70.. then YELLOW
  else GREEN
  end
end

def build_bar(used_int)
  filled = (used_int * BAR_WIDTH + 50) / 100
  (0...BAR_WIDTH).map do |i|
    pos = i * 100 / (BAR_WIDTH - 1)
    i < filled ? "#{bar_color_at(pos)}█" : "#{DIM}░"
  end.join + RESET
end

def relative_time(resets_at)
  return nil unless resets_at
  secs = resets_at.to_i - Time.now.to_i
  return nil if secs <= 0
  d = secs / 86400
  h = (secs % 86400) / 3600
  m = (secs % 3600) / 60
  if d > 0
    h > 0 ? "#{d}d#{h}h#{m.to_s.rjust(2, '0')}m" : "#{d}d#{m.to_s.rjust(2, '0')}m"
  elsif h > 0
    "#{h}h#{m.to_s.rjust(2, '0')}m"
  else
    "#{m}m"
  end
end

def context_bar(used, tokens)
  return "🟢 #{DIM}#{'░' * BAR_WIDTH}#{RESET} --%" unless used

  used_int = used.round
  "#{ctx_emoji(used_int)}#{build_bar(used_int)} #{pct_ansi(used_int)}#{used_int}%#{RESET}" \
    "#{tokens ? " #{DIM}#{token_count(tokens)}#{RESET}" : ''}"
end

# 92k, 1.2M
def token_count(tokens)
  tokens >= 999_500 ? "#{(tokens / 1e6).round(1)}M" : "#{(tokens / 1e3).round}k"
end

def month_reset_epoch
  now = Time.now
  y = now.year
  m = now.month + 1
  (m > 12) && (y += 1) && (m = 1)
  Time.new(y, m, 1, 0, 0, 0).to_i
end

CURRENCY_SIGNS = { 'AUD' => 'A$', 'USD' => '$' }.freeze

def money(minor, credits, cents: true)
  amount = minor.to_f / (10**credits.fetch('exponent', 2))
  sign   = CURRENCY_SIGNS.fetch(credits['currency']) { "#{credits['currency']} " }
  "#{sign}#{cents ? format('%.2f', amount) : amount.round}"
end

# ── Model alerts ──
# The payload carries the model id but nothing marking it as Claude Code's default.
# default_model.rb records the default, read from a fresh session no setting can
# override, plus the other models on offer. The model turns red when it isn't that default.
DEFAULT_MODEL_CACHE = ENV['STATUSLINE_DEFAULT_MODEL_CACHE'] || File.expand_path('~/.claude/statusline-default-model.json')
MODEL_TIERS = %w[haiku sonnet opus fable].freeze
SETTINGS_FILE = ENV['STATUSLINE_SETTINGS'] || File.expand_path('~/.claude/settings.json')

if on?('model')
  DefaultModel.refresh(record: DEFAULT_MODEL_CACHE, lock: "#{DEFAULT_MODEL_CACHE}.lock",
                       log: File.expand_path('~/.claude/statusline-default-model.log'))
end

def model_info
  @model_info ||= (JSON.parse(File.read(DEFAULT_MODEL_CACHE)) rescue nil) || {}
end

def bare_model_id(id) = id.to_s.sub(/\[.*\]\z/, '')

# Matches the family and version in an id such as claude-opus-5-5 or claude-haiku-4-5-20251001.
MODEL_ID = /\Aclaude-(?<family>[a-z]+)-(?<major>\d+)(?:-(?<minor>\d{1,2}))?(?:-\d{8})?\z/

def model_rank(id)
  m = MODEL_ID.match(bare_model_id(id)) or return nil
  tier = MODEL_TIERS.index(m[:family]) or return nil
  [tier, Gem::Version.new([m[:major], m[:minor]].compact.join('.'))]
end

def model_name(id)
  m = MODEL_ID.match(bare_model_id(id)) or return bare_model_id(id)
  "#{m[:family].capitalize} #{[m[:major], m[:minor]].compact.join('.')}"
end

def non_default_model?(model_id)
  default_id = model_info['default_id'] && bare_model_id(model_info['default_id'])
  !!(model_id && default_id) && bare_model_id(model_id) != default_id
end

# A session keeps the advisor it started with until /clear or /compact, so settings.json can be
# stale; each assistant entry in the transcript records the one in effect, and has no key when the
# advisor is off. Nothing records it at a compaction or a /clear, though, so when one of those comes
# after the latest assistant entry, or there isn't one, the next turn picks up settings.json.
# Reads backwards from the end, a chunk at a time.
def session_advisor(transcript_path)
  return configured_advisor unless transcript_path && File.file?(transcript_path)

  File.open(transcript_path, 'rb') do |f|
    pos  = f.size
    tail = +''
    while pos.positive? && f.size - pos < 8 << 20
      step = [pos, 256 << 10].min
      pos -= step
      f.seek(pos)
      lines = (f.read(step) + tail).split("\n")
      tail  = pos.positive? ? lines.shift.to_s : ''
      lines.reverse_each do |line|
        next unless line.include?('"type":"assistant"') || line.include?('"compact_boundary"')

        entry = JSON.parse(line) rescue next
        next if entry['isSidechain']
        return entry['advisorModel'] if entry['type'] == 'assistant'
        return configured_advisor if entry['subtype'] == 'compact_boundary'
      end
    end
  end
  configured_advisor
end

# settings.json holds an alias such as "fable"; resolve it to the newest id of that family on offer.
def configured_advisor
  setting = (JSON.parse(File.read(SETTINGS_FILE))['advisorModel'] rescue nil) or return nil
  return setting if setting.start_with?('claude-')

  [model_info['default_id'], *model_info['offered']].compact.map { bare_model_id(_1) }
    .select { MODEL_ID.match(_1)&.[](:family) == setting }.max_by { model_rank(_1) } || "claude-#{setting}"
end

ALERT = "\033[1;97;41m" # bold bright white on red
WARN  = "\033[1;30;48;2;255;140;0m" # bold black on orange

EFFORT_LEVELS = %w[low medium high xhigh max].freeze

def low_effort?(effort) = (EFFORT_LEVELS.index(effort) || EFFORT_LEVELS.size) < EFFORT_LEVELS.index('high')

# The status line command gets a transcript path; the mod passes the session id instead.
transcript = data['transcript_path'] ||
             (data['session_id'] && Dir.glob(File.expand_path("~/.claude/projects/*/#{data['session_id']}.jsonl")).first)

# ── Assemble output ──
parts = []

if on?('repo') && !repo.empty?
  branch_part = branch.empty? ? '' : "#{BOLD}#{GREEN} #{branch}#{RESET}"
  parts << "#{YELLOW}[#{BOLD}#{repo}#{branch_part}#{YELLOW}]#{RESET}"
end

parts << "🧠 #{context_bar(used, ctx_tokens)}" if on?('context')
if on?('cache') && (cache = (CacheClock.read(transcript) rescue nil))
  parts << CacheClock.render(*cache)
end

QUOTA_BAR_WIDTH = 10
[['⏱️', used_5h, resets_at_5h, 'five_hour'], ['📆', used_7d, resets_at_7d, 'seven_day']].each do |icon, pct, resets_at, window|
  next unless on?(window)

  reset = relative_time(resets_at)
  parts << "#{icon} #{QuotaBar.render(pct, resets_at, window, width: QUOTA_BAR_WIDTH)}#{reset ? " #{DIM}#{reset}#{RESET}" : ''}"
end

# Usage credits: the extra-usage spend cap as /usage reports it, fetched by the mod. The spend resets
# on the 1st. Grey until a quota runs out, when credits are what's being spent.
if on?('credits') && (credits = data['usage_credits'])
  colour = used_5h >= 100 || used_7d >= 100 ? RED : GREY
  parts << "#{colour}💵 #{money(credits['used_minor'], credits)}/#{money(credits['limit_minor'], credits, cents: false)} " \
           "#{Time.at(month_reset_epoch).strftime('%-d %b')}#{RESET}"
end

model_id = data.dig('model', 'id')
model  ||= model_id ? model_name(model_id) : 'Unknown'
if on?('model')
  parts << (non_default_model?(model_id) ? "#{ALERT} ⚠️ #{model} #{RESET}" : "#{BLUE}🤖 #{model}#{RESET}")
end
# Sessions run with no advisor; one that has an advisor is flagged.
if on?('advisor') && (advisor_id = (session_advisor(transcript) rescue nil))
  parts << "#{ALERT} 🎓 #{model_name(advisor_id)} #{RESET}"
end

if on?('effort')
  # Only hooks fired inside a turn carry the effort, so the mod has none until the first turn ends.
  effort ||= (begin
    settings = JSON.parse(File.read(SETTINGS_FILE))
    settings.dig('modelSettings', bare_model_id(model_id), 'effortLevel') || settings['effortLevel']
  rescue StandardError
    nil
  end) || 'Unknown'
  parts << (low_effort?(effort) ? "#{WARN} 💪 #{effort} #{RESET}" : "#{MAGENTA}💪 #{effort}#{RESET}")
end

# ── Claude Code version ──
# The newest cask on disk is what a restart would run; the session keeps the version it started on.
CASKROOM = ENV['STATUSLINE_CASKROOM'] || '/opt/homebrew/Caskroom/claude-code'
running = data['version']
if on?('version') && running
  latest = (Dir.children(CASKROOM).filter_map { Gem::Version.new(_1) rescue nil }.max&.to_s rescue nil)
  behind = latest && Gem::Version.new(running) < Gem::Version.new(latest)
  parts << (behind ? "#{RED}v#{running}#{RESET}#{DIM}→#{RESET}#{GREEN}#{latest}#{RESET}" : "#{DIM}v#{running}#{RESET}")
end

print parts.join(' ')
