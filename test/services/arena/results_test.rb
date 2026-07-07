# frozen_string_literal: true

require "test_helper"

module Arena
  class ResultsTest < ActiveSupport::TestCase
    include ArenaTestHelpers

    setup { @game = build_running_game }

    test "overall best is the bot with the most gems across all groups" do
      place_bot(@game, name: "A", x: 1, y: 1, group: "group_a", gems_collected: 3)
      top = place_bot(@game, name: "B", x: 2, y: 2, group: "group_b", gems_collected: 9)
      place_bot(@game, name: "C", x: 3, y: 3, group: "group_c", gems_collected: 5)

      assert_equal top.id, Results.new(@game).overall_best.id
    end

    test "best bot per group and average score handle uneven group sizes" do
      # group_a: two bots (4 and 2 gems) -> avg 3.0, best is the 4-gem bot
      place_bot(@game, name: "A1", x: 1, y: 1, group: "group_a", gems_collected: 4)
      place_bot(@game, name: "A2", x: 2, y: 1, group: "group_a", gems_collected: 2)
      # group_b: one bot (10 gems) -> avg 10.0
      place_bot(@game, name: "B1", x: 3, y: 1, group: "group_b", gems_collected: 10)
      # group_c: no bots -> avg 0.0

      groups = Results.new(@game).groups.index_by { |g| g[:key] }

      assert_equal "A1", groups["group_a"][:best].name
      assert_equal 3.0, groups["group_a"][:average]
      assert_equal 2, groups["group_a"][:size]

      assert_equal 10.0, groups["group_b"][:average]
      assert_equal 1, groups["group_b"][:size]

      assert_equal 0.0, groups["group_c"][:average]
      assert_nil groups["group_c"][:best]
    end

    test "group summaries are JSON-friendly for broadcasting" do
      place_bot(@game, name: "A1", x: 1, y: 1, group: "group_a", gems_collected: 7)

      summary = Results.new(@game).group_summaries.find { |g| g[:key] == "group_a" }
      assert_equal "Group A", summary[:label]
      assert_equal "A1", summary[:best_bot_name]
      assert_equal 7, summary[:best_bot_gems]
      assert_equal 7.0, summary[:average]
    end
  end
end
