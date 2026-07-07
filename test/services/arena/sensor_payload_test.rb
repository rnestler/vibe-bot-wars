# frozen_string_literal: true

require "test_helper"

module Arena
  class SensorPayloadTest < ActiveSupport::TestCase
    include ArenaTestHelpers

    setup do
      @game = build_running_game(walls: [[5, 6], [0, 0]], gems: [[6, 6], [9, 9]])
      @bot = place_bot(@game, name: "A", x: 5, y: 5, hp: 80)
      @near = place_bot(@game, name: "N", x: 4, y: 5)
      @far = place_bot(@game, name: "F", x: 0, y: 1)
    end

    test "vision at radius 1 includes only Chebyshev-adjacent features" do
      payload = SensorPayload.call(game: @game, bot: @bot, others: [@near, @far], radius: 1)

      assert_equal [[5, 6]], payload[:vision][:walls]
      assert_equal [[6, 6]], payload[:vision][:gems]
      assert_equal 1, payload[:vision][:bots].size
      assert_equal({ x: 4, y: 5, hp: @game.max_hp, downed: false }, payload[:vision][:bots].first)
    end

    test "self block reports own state and max_hp" do
      payload = SensorPayload.call(game: @game, bot: @bot, others: [], radius: 1)
      assert_equal 5, payload[:self][:x]
      assert_equal 80, payload[:self][:hp]
      assert_equal @game.max_hp, payload[:self][:max_hp]
      assert_equal @game.id, payload[:game_id]
    end

    test "a larger radius reveals more" do
      payload = SensorPayload.call(game: @game, bot: @bot, others: [@near, @far], radius: 5)
      assert_includes payload[:vision][:gems], [9, 9]
      assert_equal 2, payload[:vision][:bots].size
    end
  end
end
