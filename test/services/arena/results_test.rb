# frozen_string_literal: true

require "test_helper"

module Arena
  class ResultsTest < ActiveSupport::TestCase
    include ArenaTestHelpers

    setup { @game = build_running_game }

    test "a group's score is its average gems per bot, regardless of size" do
      # group_a: two bots (4 + 2 gems) over 2 bots -> avg 3.0
      place_bot(@game, name: "A1", x: 1, y: 1, group: "group_a", gems_collected: 4)
      place_bot(@game, name: "A2", x: 2, y: 1, group: "group_a", gems_collected: 2)
      # group_b: one collector (10) plus a support bot with 0 gems -> avg 5.0
      place_bot(@game, name: "B1", x: 3, y: 1, group: "group_b", gems_collected: 10)
      place_bot(@game, name: "B2", x: 4, y: 1, group: "group_b", role: "fighter", gems_collected: 0)

      groups = Results.new(@game).groups.index_by { |g| g[:key] }

      assert_equal 3.0, groups["group_a"][:average]
      assert_equal 2, groups["group_a"][:size]
      assert_equal 5.0, groups["group_b"][:average]
      assert_equal 10, groups["group_b"][:total]
      assert_equal 0.0, groups["group_c"][:average]
    end

    test "winning group is the one with the highest average score" do
      place_bot(@game, name: "A1", x: 1, y: 1, group: "group_a", gems_collected: 4)
      place_bot(@game, name: "A2", x: 2, y: 1, group: "group_a", gems_collected: 4) # avg 4
      place_bot(@game, name: "B1", x: 3, y: 1, group: "group_b", gems_collected: 9) # avg 9

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
      assert_equal 7.0, summary[:average]
      assert_equal 1, summary[:size]
    end
  end
end
