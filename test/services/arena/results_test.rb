# frozen_string_literal: true

require "test_helper"

module Arena
  class ResultsTest < ActiveSupport::TestCase
    include ArenaTestHelpers

    # score_exponent 1 makes the score a plain per-bot average, which is easy to reason about.
    setup { @game = build_running_game(score_exponent: 1) }

    test "with exponent 1 the score is the plain per-bot average" do
      place_bot(@game, name: "A1", x: 1, y: 1, group: "group_a", gems_collected: 4)
      place_bot(@game, name: "A2", x: 2, y: 1, group: "group_a", gems_collected: 2)
      place_bot(@game, name: "B1", x: 3, y: 1, group: "group_b", gems_collected: 10)
      place_bot(@game, name: "B2", x: 4, y: 1, group: "group_b", role: "fighter", gems_collected: 0)

      groups = Results.new(@game).groups.index_by { |g| g[:key] }
      assert_equal 3.0, groups["group_a"][:score] # (4 + 2) / 2
      assert_equal 5.0, groups["group_b"][:score] # 10 / 2
      assert_equal 10, groups["group_b"][:total]
    end

    test "a larger exponent handicaps the bigger team even at equal per-bot average" do
      @game.update!(score_exponent: 1.5)
      # Both teams average 4 gems/bot, but group_b has twice as many bots.
      2.times { |i| place_bot(@game, name: "A#{i}", x: i, y: 1, group: "group_a", gems_collected: 4) }
      4.times { |i| place_bot(@game, name: "B#{i}", x: i, y: 2, group: "group_b", gems_collected: 4) }

      groups = Results.new(@game).groups.index_by { |g| g[:key] }
      assert_equal (8 / (2**1.5)).round(2), groups["group_a"][:score]
      assert_equal (16 / (4**1.5)).round(2), groups["group_b"][:score]
      assert_operator groups["group_a"][:score], :>, groups["group_b"][:score],
                      "smaller team with the same per-bot average scores higher"
    end

    test "a group with no bots scores zero" do
      empty = Bot.groups.keys.last
      place_bot(@game, name: "A1", x: 1, y: 1, group: Bot.groups.keys.first, gems_collected: 3)

      groups = Results.new(@game).groups.index_by { |g| g[:key] }
      assert_equal 0.0, groups[empty][:score]
    end

    test "winning group is the one with the highest score" do
      place_bot(@game, name: "A1", x: 1, y: 1, group: "group_a", gems_collected: 4)
      place_bot(@game, name: "A2", x: 2, y: 1, group: "group_a", gems_collected: 4)
      place_bot(@game, name: "B1", x: 3, y: 1, group: "group_b", gems_collected: 9)

      results = Results.new(@game)
      assert_equal "group_b", results.winning_group
      assert_equal %w[group_b group_a], results.ranked_groups.first(2).pluck(:key)
    end

    test "winning group is nil when no group has any bots" do
      assert_nil Results.new(@game).winning_group
    end

    test "group summaries are JSON-friendly and use the configured labels" do
      place_bot(@game, name: "A1", x: 1, y: 1, group: "group_a", gems_collected: 7)

      summary = Results.new(@game).group_summaries.find { |g| g[:key] == "group_a" }
      assert_equal Bot::GROUP_LABELS.fetch("group_a"), summary[:label]
      assert_equal 7, summary[:total]
      assert_equal 7.0, summary[:score]
      assert_equal 1, summary[:size]
    end
  end
end
