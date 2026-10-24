#!/usr/bin/env ruby
# frozen_string_literal: true

# Claude Code status line: RGB gradient, dynamic emoji, cost, code velocity

require 'json'
require 'shellwords'

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

CYAN    = "\033[1;36m"
GREEN   = "\033[32m"
YELLOW  = "\033[33m"
RED     = "\033[31m"
MAGENTA = "\033[1;35m"
BLUE    = "\033[1;34m"
BOLD    = "\033[1m"
RESET   = "\033[0m"
DIM     = rgb(60, 60, 60)


# ── Parse fields ──
model   = data.dig('model', 'display_name') || 'Unknown'
effort  = data.dig('effort', 'level')       || 'Unknown'
used    = data.dig('context_window', 'used_percentage')
cwd     = data.dig('workspace', 'current_dir') || data['cwd'] || ''
used_5h      = (data.dig('rate_limits', 'five_hour', 'used_percentage') || 0).round
used_7d      = (data.dig('rate_limits', 'seven_day', 'used_percentage') || 0).round
resets_at_5h = data.dig('rate_limits', 'five_hour', 'resets_at')
resets_at_7d = data.dig('rate_limits', 'seven_day', 'resets_at')
cost_total   = data.dig('cost', 'total_cost_usd')

# ── Git info ──
branch = ''
repo   = ''
unless cwd.empty?
  branch   = `git -C #{cwd.shellescape} --no-optional-locks symbolic-ref --short HEAD 2>/dev/null`.chomp
  toplevel = `git -C #{cwd.shellescape} --no-optional-locks rev-parse --show-toplevel 2>/dev/null`.chomp
  repo     = File.basename(toplevel) unless toplevel.empty?
end

# ── Context bar ──
BAR_WIDTH = 20

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

def context_bar(used)
  return "🟢 #{DIM}#{'░' * BAR_WIDTH}#{RESET} --%" unless used

  used_int = used.round
  "#{ctx_emoji(used_int)}#{build_bar(used_int)} #{pct_ansi(used_int)}#{used_int}%#{RESET}"
end

# ── Org monthly-spend meter ──
# The status-line payload has no org monthly-spend field — only `cost.total_cost_usd`, a
# cumulative figure. So we synthesise a calendar-month meter: snapshot the cumulative total at
# the first render of each month, show the delta since, and measure it against an ASSUMED cap
# (we don't get the real one). The assumed cap self-corrects: if a month's spend blows past it,
# the real cap must be higher, so next month starts from the higher figure.
SPEND_STATE   = File.expand_path('~/.claude/spend-meter.json')
SPEND_CAP_DEF = 340.0 # best guess: last month's spend hit the org limit at ~this figure

def month_reset_epoch
  now = Time.now
  y = now.year
  m = now.month + 1
  (m > 12) && (y += 1) && (m = 1)
  Time.new(y, m, 1, 0, 0, 0).to_i
end

def spend_meter(cost_total)
  return nil unless cost_total

  state    = (JSON.parse(File.read(SPEND_STATE)) rescue nil) || {}
  now_month = Time.now.strftime('%Y-%m')
  cap       = (state['assumed_cap_usd'] || SPEND_CAP_DEF).to_f
  baseline  = state['baseline_usd']&.to_f

  # Re-baseline on a new calendar month, first run, or if the cumulative total reset under us.
  if state['month'] != now_month || baseline.nil? || cost_total < baseline
    if baseline && state['month'] && cost_total >= baseline
      last_spend = cost_total - baseline               # the month that just ended
      cap = last_spend.ceil.to_f if last_spend > cap   # learn: the real cap was at least this
    end
    baseline = cost_total
  end

  spend = cost_total - baseline
  File.write(SPEND_STATE, JSON.generate('month' => now_month, 'baseline_usd' => baseline, 'assumed_cap_usd' => cap)) rescue nil
  { pct: (cap.positive? ? (spend / cap * 100).round : 0), spend: spend, cap: cap }
end

# ── Non-default model alert ──
# The payload carries the model id but nothing marking it as Claude Code's default, so learn the
# default: a session with no model override in effect is running it. A session with an override
# is compared against the last learned id instead. An undetected override would teach the wrong
# default, so check every place Claude reads a model from.
DEFAULT_MODEL_CACHE = ENV['STATUSLINE_DEFAULT_MODEL_CACHE'] || File.expand_path('~/.claude/statusline-default-model.json')

def claude_argv
  pid = Process.ppid
  8.times do
    ppid, comm = `ps -o ppid=,comm= -p #{pid}`.split(' ', 2).map(&:strip)
    return `ps -o args= -p #{pid}`.strip if File.basename(comm.to_s) == 'claude'
    return '' if ppid.to_i <= 1
    pid = ppid.to_i
  end
  ''
end

def model_override?(project_dir)
  settings_files = [
    '~/.claude/settings.json', '~/.claude/settings.local.json',
    '/Library/Application Support/ClaudeCode/managed-settings.json'
  ].map { File.expand_path(_1) }
  settings_files += %w[settings.json settings.local.json].map { File.join(project_dir, '.claude', _1) } unless project_dir.empty?
  settings = settings_files.filter_map { (JSON.parse(File.read(_1)) rescue nil) }

  ENV['ANTHROPIC_MODEL'].to_s != '' ||
    settings.any? { _1['model'] || _1.dig('env', 'ANTHROPIC_MODEL') } ||
    claude_argv.match?(/\s--model[\s=]/)
end

# Strips a context-size suffix such as "[1m]" so it doesn't count as a different model.
def non_default_model?(model_id, project_dir)
  return false unless model_id

  id = model_id.sub(/\[.*\]\z/, '')
  unless model_override?(project_dir)
    File.write(DEFAULT_MODEL_CACHE, JSON.generate('default_id' => id)) rescue nil
    return false
  end

  default_id = (JSON.parse(File.read(DEFAULT_MODEL_CACHE))['default_id'] rescue nil)
  default_id.nil? || id != default_id
end

ALERT = "\033[1;97;41m" # bold bright white on red

ctx_part = context_bar(used)

# ── Assemble output ──
branch_part = branch.empty? ? '' : "#{BOLD}#{GREEN} #{branch}#{RESET}"
repo_part   = repo.empty?   ? '' : "#{YELLOW}[#{BOLD}#{repo}#{branch_part}#{YELLOW}]#{RESET}"

out = "🧠 #{repo_part}#{repo_part.empty? ? '' : ' '}#{ctx_part}"
reset_5h = relative_time(resets_at_5h)
reset_7d = relative_time(resets_at_7d)
out += " #{CYAN}⏱️ #{used_5h}%#{reset_5h ? " #{DIM}#{reset_5h}#{RESET}#{CYAN}" : ''}#{RESET}"
out += " #{CYAN}📆 #{used_7d}%#{reset_7d ? " #{DIM}#{reset_7d}#{RESET}#{CYAN}" : ''}#{RESET}"
sm = spend_meter(cost_total)
if sm
  reset_month = relative_time(month_reset_epoch)
  out += " #{pct_ansi(sm[:pct])}💵 ~#{sm[:pct]}%#{RESET}#{reset_month ? " #{DIM}#{reset_month}#{RESET}" : ''}"
end
project_dir = data.dig('workspace', 'project_dir') || cwd
out += if non_default_model?(data.dig('model', 'id'), project_dir)
         " #{ALERT} ⚠️ #{model} #{RESET}"
       else
         " #{BLUE}🤖 #{model}#{RESET}"
       end
out += " #{MAGENTA}💪 #{effort}#{RESET}"

print out
