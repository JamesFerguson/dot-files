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

  def test_projection_extends_the_rate_so_far_to_the_reset
    assert_in_delta 80.0, QuotaBar.projected(40, 0.5)
  end

  def test_projection_floors_elapsed_so_an_early_window_does_not_explode
    assert_in_delta 20.0, QuotaBar.projected(2, 0.01)
  end

  def test_fill_is_green_up_to_80_projected_shading_to_orange_by_100_and_red_beyond
    assert_equal [0, 200, 80], QuotaBar.pace_rgb(80)
    assert_equal [220, 200, 0], QuotaBar.pace_rgb(80.0001).map(&:round)
    assert_equal [255, 140, 0], QuotaBar.pace_rgb(100)
    assert_equal [220, 40, 20], QuotaBar.pace_rgb(100.5)
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
