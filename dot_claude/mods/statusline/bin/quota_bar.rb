# frozen_string_literal: true

# Rate-limit bars for the status line, paced against a target share of each window by its reset
# (80% unless the mod says otherwise). In the last fifth of the window the target climbs to 100%,
# since quota left unused at the reset is wasted.
#
# The fill is green while usage is at or under the target pace, red once it is past a steady path to
# 100%, and yellow shading to orange in between. The dotted background is green from the end of the
# fill up to the target pace, so the green stretch is the headroom left.
module QuotaBar
  TARGET = 80.0
  CONVERGE_FROM = 0.8
  WINDOW_SECS = { 'five_hour' => 5 * 3600, 'seven_day' => 7 * 86_400 }.freeze
  # A few minutes into a window, both paces are near zero and any usage shows red. Treating at least
  # a tenth of the window as gone keeps the colour meaningful until there's a rate worth judging.
  MIN_ELAPSED = 0.1

  module_function

  # Share of the window already gone (0..1), or nil without a reset time.
  def elapsed(resets_at, window_secs, now: Time.now.to_i)
    return nil unless resets_at

    (1 - (resets_at.to_i - now).to_f / window_secs).clamp(0.0, 1.0)
  end

  # Where usage would be now on the target path: a steady rate to the target, then from the last
  # fifth of the window a steady climb to 100% by the reset.
  def on_track(elapsed, target = TARGET)
    return 0.0 unless elapsed
    return target * elapsed if elapsed <= CONVERGE_FROM

    start = target * CONVERGE_FROM
    start + (100 - start) * (elapsed - CONVERGE_FROM) / (1 - CONVERGE_FROM)
  end

  # One symbol per cell: :used, :headroom (unused but within the target pace) or :empty.
  def cells(used, elapsed, width, target = TARGET)
    filled = (used * width / 100.0).round.clamp(0, width)
    pace   = (on_track(elapsed, target) * width / 100.0).round.clamp(0, width)
    Array.new(width) { |i| if i < filled then :used elsif i < pace then :headroom else :empty end }
  end

  # The fill colour as RGB. Without a reset time it colours by usage against the target alone.
  def pace_rgb(used, elapsed, target = TARGET)
    el       = elapsed ? [elapsed, MIN_ELAPSED].max : 1.0
    green_to = elapsed ? on_track(el, target) : target
    red_from = 100 * el
    return [0, 200, 80] if used <= green_to
    return [220, 40, 20] if used > red_from

    t = (used - green_to) / (red_from - green_to)
    [blend(220, 255, t), blend(200, 140, t), 0] # yellow to orange
  end

  def blend(from, to, frac) = (from + (to - from) * frac).round

  def render(used, resets_at, window, width:, target: TARGET, now: Time.now.to_i)
    el   = elapsed(resets_at, WINDOW_SECS.fetch(window), now: now)
    fill = "\033[38;2;#{pace_rgb(used, el, target).join(';')}m"
    bar  = cells(used, el, width, target).map do |cell|
      case cell
      when :used     then "#{fill}█"
      when :headroom then "\033[38;2;30;120;55m░"
      else "\033[38;2;60;60;60m░"
      end
    end.join
    "#{bar}\033[0m #{fill}#{used.round}%\033[0m"
  end
end
