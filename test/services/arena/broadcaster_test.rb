# frozen_string_literal: true

require "test_helper"

module Arena
  class BroadcasterTest < ActiveSupport::TestCase
    include ArenaTestHelpers

    setup { @game = build_running_game }

    test "state includes collision cells when given, and none by default" do
      place_bot(@game, name: "A", x: 5, y: 5)

      assert_empty Broadcaster.new(@game).state[:collisions]
      assert_equal [[5, 5]], Broadcaster.new(@game, collisions: [[5, 5]]).state[:collisions]
    end
  end
end
