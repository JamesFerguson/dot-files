# frozen_string_literal: true

# Rate-limit bars for the status line, paced against using 80% of each window by its reset.
#
# The fill is coloured by where usage is heading at the current rate: green when it ends the window
# at 80% or less, yellow shading to orange between 80% and 100%, solid red past 100%. The dotted
# background is green from the end of the fill up to where usage would be now if it were on track
# for exactly 80%, so the green stretch is the headroom left at that pace.
module QuotaBar
  TARGET = 80.0
  WINDOW_SECS = { 'five_hour' => 5 * 3600, 'seven_day' => 7 * 86_400 }.freeze
  # A few minutes into a window, any usage projects to thousands of percent. Treating at least a
  # tenth of the window as gone keeps the colour meaningful until there's a rate worth projecting.
  MIN_ELAPSED = 0.1

  module_function

  # Share of the window already gone (0..1), or nil without a reset time.
  def elapsed(resets_at, window_secs, now: Time.now.to_i)
    return nil unless resets_at

    (1 - (resets_at.to_i - now).to_f / window_secs).clamp(0.0, 1.0)
  end

  # Usage at the end of the window if the rate so far holds.
  def projected(used, elapsed)
    return used.to_f unless elapsed

    used / [elapsed, MIN_ELAPSED].max
  end

  # Where usage would be now on a steady path to TARGET by the reset.
  def on_track(elapsed) = elapsed ? TARGET * elapsed : 0.0

  # One symbol per cell: :used, :headroom (unused but within the on-track pace) or :empty.
  def cells(used, elapsed, width)
    filled = (used * width / 100.0).round.clamp(0, width)
    pace   = (on_track(elapsed) * width / 100.0).round.clamp(0, width)
    Array.new(width) { |i| if i < filled then :used elsif i < pace then :headroom else :empty end }
  end

  # The fill colour as RGB.
  def pace_rgb(projected)
    return [0, 200, 80] if projected <= TARGET
    return [220, 40, 20] if projected > 100

    t = (projected - TARGET) / (100 - TARGET)
    [blend(220, 255, t), blend(200, 140, t), 0] # yellow to orange
  end

  def blend(from, to, frac) = (from + (to - from) * frac).round

  def render(used, resets_at, window, width:, now: Time.now.to_i)
    el   = elapsed(resets_at, WINDOW_SECS.fetch(window), now: now)
    fill = "\033[38;2;#{pace_rgb(projected(used, el)).join(';')}m"
    bar  = cells(used, el, width).map do |cell|
      case cell
      when :used     then "#{fill}█"
      when :headroom then "\033[38;2;30;120;55m░"
      else "\033[38;2;60;60;60m░"
      end
    end.join
    "#{bar}\033[0m #{fill}#{used.round}%\033[0m"
  end
end
