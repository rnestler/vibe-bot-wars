# frozen_string_literal: true

require "test_helper"

module Arena
  class TickTest < ActiveSupport::TestCase
    include ArenaTestHelpers

    setup { @game = build_running_game }

    test "an open move relocates the bot and sets heading" do
      bot = place_bot(@game, name: "A", x: 5, y: 5)
      Tick.call(@game, client: StubClient.new("A" => move("E")))
      bot.reload
      assert_equal [6, 5], bot.coordinates
      assert_equal "E", bot.heading
      assert_equal @game.max_hp, bot.hp
    end

    test "crashing into a wall costs HP and blocks the move" do
      @game.update!(walls: [[6, 5]])
      bot = place_bot(@game, name: "A", x: 5, y: 5)
      Tick.call(@game, client: StubClient.new("A" => move("E")))
      bot.reload
      assert_equal [5, 5], bot.coordinates
      assert_equal @game.max_hp - @game.wall_damage, bot.hp
      assert_equal "E", bot.heading
    end

    test "moving off the arena edge is a crash" do
      bot = place_bot(@game, name: "A", x: 0, y: 5)
      Tick.call(@game, client: StubClient.new("A" => move("W")))
      bot.reload
      assert_equal [0, 5], bot.coordinates
      assert_equal @game.max_hp - @game.wall_damage, bot.hp
    end

    test "ramming another bot damages both and blocks the mover" do
      a = place_bot(@game, name: "A", x: 5, y: 5)
      b = place_bot(@game, name: "B", x: 6, y: 5)
      Tick.call(@game, client: StubClient.new("A" => move("E"))) # B idles
      a.reload
      b.reload
      assert_equal [5, 5], a.coordinates
      assert_equal [6, 5], b.coordinates
      assert_equal @game.max_hp - @game.collision_damage, a.hp
      assert_equal @game.max_hp - @game.collision_damage, b.hp
    end

    test "two bots targeting the same cell both bounce and take damage" do
      a = place_bot(@game, name: "A", x: 5, y: 5)
      c = place_bot(@game, name: "C", x: 7, y: 5)
      Tick.call(@game, client: StubClient.new("A" => move("E"), "C" => move("W")))
      a.reload
      c.reload
      assert_equal [5, 5], a.coordinates
      assert_equal [7, 5], c.coordinates
      assert_equal @game.max_hp - @game.collision_damage, a.hp
      assert_equal @game.max_hp - @game.collision_damage, c.hp
    end

    test "bots swapping cells collide" do
      a = place_bot(@game, name: "A", x: 5, y: 5)
      b = place_bot(@game, name: "B", x: 6, y: 5)
      Tick.call(@game, client: StubClient.new("A" => move("E"), "B" => move("W")))
      a.reload
      b.reload
      assert_equal [5, 5], a.coordinates
      assert_equal [6, 5], b.coordinates
      assert_equal @game.max_hp - @game.collision_damage, a.hp
    end

    test "collecting a gem scores and respawns to keep the board full" do
      @game.update!(gems: [[6, 5]])
      bot = place_bot(@game, name: "A", x: 5, y: 5)
      Tick.call(@game, client: StubClient.new("A" => move("E")))
      bot.reload
      @game.reload
      assert_equal [6, 5], bot.coordinates
      assert_equal 1, bot.gems_collected
      assert_equal 1, @game.gems.size
      assert_not_includes @game.gems, [6, 5]
    end

    test "repair heals and revives a downed bot" do
      bot = place_bot(@game, name: "A", x: 5, y: 5, hp: 0, downed: true)
      Tick.call(@game, client: StubClient.new("A" => { "command" => "repair" }))
      bot.reload
      assert_equal @game.repair_amount, bot.hp
      assert_not bot.downed?
    end

    test "a downed bot cannot move" do
      bot = place_bot(@game, name: "A", x: 5, y: 5, hp: 0, downed: true)
      Tick.call(@game, client: StubClient.new("A" => move("E")))
      bot.reload
      assert_equal [5, 5], bot.coordinates
      assert_equal 0, bot.hp
      assert bot.downed?
    end

    test "scan widens vision for the next tick then reverts" do
      bot = place_bot(@game, name: "A", x: 5, y: 5)
      Tick.call(@game, client: StubClient.new("A" => { "command" => "scan" }))
      assert_equal @game.scan_radius, bot.reload.vision_radius

      Tick.call(@game, client: StubClient.new("A" => { "command" => "idle" }))
      assert_equal @game.vision_radius, bot.reload.vision_radius
    end

    test "a failed webhook is treated as an idle tick with a recorded error" do
      bot = place_bot(@game, name: "A", x: 5, y: 5)
      Tick.call(@game, client: ErrorClient.new)
      bot.reload
      assert_equal [5, 5], bot.coordinates
      assert_equal "idle", bot.last_command
      assert_equal "timeout", bot.last_error
    end

    test "the match ends at max_ticks and the top collector wins" do
      @game.update!(max_ticks: 1)
      place_bot(@game, name: "A", x: 1, y: 1, gems_collected: 3)
      winner_by_gems = place_bot(@game, name: "B", x: 8, y: 8, gems_collected: 5)
      Tick.call(@game, client: StubClient.new)
      @game.reload
      assert_predicate @game, :finished?
      assert_equal winner_by_gems.id, @game.winner_bot_id
    end

    test "does nothing when the game is not running" do
      @game.update!(status: "setup")
      bot = place_bot(@game, name: "A", x: 5, y: 5)
      Tick.call(@game, client: StubClient.new("A" => move("E")))
      assert_equal [5, 5], bot.reload.coordinates
    end
  end
end
