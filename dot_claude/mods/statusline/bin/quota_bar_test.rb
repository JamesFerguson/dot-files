#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'quota_bar'

class QuotaBarTest < Minitest::Test
  FIVE_H = 5 * 3600
  NOW = 1_800_000_000

  def test_elapsed_is_the_share_of_the_window_gone
    assert_in_delta 0.25, QuotaBar.elapsed(NOW + FIVE_H * 3 / 4, FIVE_H, now: NOW)
    assert_nil QuotaBar.elapsed(nil, FIVE_H, now: NOW)
  end

  def test_the_target_path_is_steady_to_80_percent_then_climbs_to_100_in_the_last_fifth
    assert_in_delta 40.0, QuotaBar.on_track(0.5)
    assert_in_delta 64.0, QuotaBar.on_track(0.8)
    assert_in_delta 82.0, QuotaBar.on_track(0.9)
    assert_in_delta 100.0, QuotaBar.on_track(1.0)
  end
  
  def test_the_target_is_configurable
    assert_in_delta 30.0, QuotaBar.on_track(0.5, 60)
  end
  
  def test_fill_is_green_on_the_target_path_shading_to_orange_by_a_steady_path_to_100_and_red_beyond
    assert_equal [0, 200, 80], QuotaBar.pace_rgb(40, 0.5)
    assert_equal [220, 200, 0], QuotaBar.pace_rgb(40.0001, 0.5).map(&:round)
    assert_equal [255, 140, 0], QuotaBar.pace_rgb(50, 0.5)
    assert_equal [220, 40, 20], QuotaBar.pace_rgb(50.5, 0.5)
  end
  
  def test_90_percent_used_with_a_quarter_hour_of_five_left_is_green
    assert_equal [0, 200, 80], QuotaBar.pace_rgb(90, 0.95)
  end
  
  def test_early_in_a_window_a_tenth_of_it_counts_as_gone
    assert_equal [0, 200, 80], QuotaBar.pace_rgb(8, 0.01)
    assert_equal [220, 40, 20], QuotaBar.pace_rgb(11, 0.01)
  end
  
  def test_without_a_reset_time_usage_is_judged_against_the_target_alone
    assert_equal [0, 200, 80], QuotaBar.pace_rgb(80, nil)
    assert_equal [220, 40, 20], QuotaBar.pace_rgb(101, nil)
  end

  def test_headroom_runs_from_the_fill_to_the_on_track_point
    # half the window gone: on track is 40%, so cells 2-3 of 10 are headroom after 20% used
    assert_equal %i[used used headroom headroom empty empty empty empty empty empty],
                 QuotaBar.cells(20, 0.5, 10)
  end

  def test_no_headroom_when_usage_is_ahead_of_the_on_track_point
    assert_equal %i[used used used used used used empty empty empty empty], QuotaBar.cells(60, 0.5, 10)
  end

  def test_render_without_a_reset_time_colours_by_usage_alone
    assert_includes QuotaBar.render(90, nil, 'five_hour', width: 10), '38;2;'
  end
end
