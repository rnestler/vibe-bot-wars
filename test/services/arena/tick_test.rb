# frozen_string_literal: true

require "test_helper"

module Arena
  class TickTest < ActiveSupport::TestCase
    include ArenaTestHelpers
    include ActionCable::TestHelper

    setup { @game = build_running_game }

    test "the contested cell of a collision is broadcast for the UI to highlight" do
      place_bot(@game, name: "A", x: 4, y: 5)
      place_bot(@game, name: "B", x: 6, y: 5)
      messages = capture_broadcasts(Broadcaster::STREAM) do
        Tick.call(@game, client: StubClient.new("A" => move("E"), "B" => move("W"))) # both -> (5,5)
      end
      assert_includes messages.last["collisions"], [5, 5]
    end

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

    test "two bots colliding into one cell both take damage while an idle third is untouched" do
      a = place_bot(@game, name: "A", x: 4, y: 5)
      b = place_bot(@game, name: "B", x: 6, y: 5)
      c = place_bot(@game, name: "C", x: 4, y: 8) # idles, uninvolved
      Tick.call(@game, client: StubClient.new("A" => move("E"), "B" => move("W"))) # both -> (5,5)
      [a, b, c].each(&:reload)

      assert_equal [4, 5], a.coordinates
      assert_equal [6, 5], b.coordinates
      assert_equal @game.max_hp - @game.collision_damage, a.hp, "A took damage"
      assert_equal @game.max_hp - @game.collision_damage, b.hp, "B took damage"
      assert_equal @game.max_hp, c.hp, "the idle third bot is unharmed"
    end

    test "two bots ramming a stationary third bot: all three take damage" do
      a = place_bot(@game, name: "A", x: 4, y: 5)
      b = place_bot(@game, name: "B", x: 6, y: 5)
      c = place_bot(@game, name: "C", x: 5, y: 5) # idles on the contested cell
      Tick.call(@game, client: StubClient.new("A" => move("E"), "B" => move("W"))) # both -> (5,5)
      [a, b, c].each(&:reload)

      assert_equal @game.max_hp - @game.collision_damage, a.hp
      assert_equal @game.max_hp - @game.collision_damage, b.hp
      assert_equal @game.max_hp - @game.collision_damage, c.hp, "the rammed bot took damage"
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

    test "a fighter deals more collision damage but takes normal damage back" do
      fighter = place_bot(@game, name: "F", x: 5, y: 5, role: "fighter",
                                 max_hp: @game.fighter_max_hp, hp: @game.fighter_max_hp)
      victim = place_bot(@game, name: "V", x: 6, y: 5) # collector, idles
      Tick.call(@game, client: StubClient.new("F" => move("E")))
      fighter.reload
      victim.reload

      assert_equal [5, 5], fighter.coordinates, "fighter is blocked by the collision"
      # Victim takes the fighter's heavier hit; the fighter takes the collector's normal hit.
      assert_equal @game.max_hp - @game.fighter_collision_damage, victim.hp
      assert_equal @game.fighter_max_hp - @game.collision_damage, fighter.hp
      # Each side is credited with the damage it actually dealt.
      assert_equal @game.fighter_collision_damage, fighter.damage_dealt
      assert_equal @game.collision_damage, victim.damage_dealt
    end

    test "only collectors pick up gems; other roles pass over them" do
      @game.update!(gems: [[6, 5]])
      fighter = place_bot(@game, name: "F", x: 5, y: 5, role: "fighter",
                                 max_hp: @game.fighter_max_hp, hp: @game.fighter_max_hp)
      Tick.call(@game, client: StubClient.new("F" => move("E")))
      fighter.reload
      @game.reload

      assert_equal [6, 5], fighter.coordinates
      assert_equal 0, fighter.gems_collected
      assert_includes @game.gems, [6, 5], "the gem stays on the board"
    end

    test "a healer heals same-group allies in range and revives a lamed ally early" do
      healer = place_bot(@game, name: "H", x: 5, y: 5, role: "healer", group: "group_a")
      ally = place_bot(@game, name: "A", x: 6, y: 5, group: "group_a", hp: 0, downed: true, lamed_ticks: 8)
      Tick.call(@game, client: StubClient.new("H" => { "command" => "heal" }))
      ally.reload

      assert_equal @game.heal_amount, ally.hp
      assert_not ally.downed?, "healing above 0 ends the lame"
      assert_equal 0, ally.lamed_ticks
      assert_equal @game.heal_amount, healer.reload.hp_restored
    end

    test "hp restored counts only real healing, not overheal" do
      healer = place_bot(@game, name: "H", x: 5, y: 5, role: "healer", group: "group_a")
      # Ally is 5 HP below max, so only 5 is restored even though heal_amount is larger.
      place_bot(@game, name: "A", x: 6, y: 5, group: "group_a", hp: @game.max_hp - 5)
      Tick.call(@game, client: StubClient.new("H" => { "command" => "heal" }))

      assert_equal 5, healer.reload.hp_restored
    end

    test "a healer does not heal bots from other groups or out of range" do
      place_bot(@game, name: "H", x: 5, y: 5, role: "healer", group: "group_a")
      enemy = place_bot(@game, name: "E", x: 6, y: 5, group: "group_b", hp: 40)
      far_ally = place_bot(@game, name: "A", x: 9, y: 9, group: "group_a", hp: 40)
      Tick.call(@game, client: StubClient.new("H" => { "command" => "heal" }))

      assert_equal 40, enemy.reload.hp, "different group is not healed"
      assert_equal 40, far_ally.reload.hp, "out-of-range ally is not healed"
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

    test "hitting zero HP lames the bot for the configured number of ticks" do
      bot = place_bot(@game, name: "A", x: 0, y: 5, hp: 5) # weak bot at the west edge
      Tick.call(@game, client: StubClient.new("A" => move("W"))) # crashes off-grid
      bot.reload
      assert_equal 0, bot.hp
      assert bot.downed?
      assert_equal @game.lame_ticks, bot.lamed_ticks
    end

    test "a lamed bot ignores commands, stays put, and counts down" do
      bot = place_bot(@game, name: "A", x: 5, y: 5, hp: 0, downed: true, lamed_ticks: 3)
      Tick.call(@game, client: StubClient.new("A" => move("E")))
      bot.reload
      assert_equal [5, 5], bot.coordinates
      assert_equal 0, bot.hp
      assert bot.downed?
      assert_equal 2, bot.lamed_ticks
    end

    test "a lamed bot revives at 1 HP once its timer runs out" do
      bot = place_bot(@game, name: "A", x: 5, y: 5, hp: 0, downed: true, lamed_ticks: 0)
      Tick.call(@game, client: StubClient.new("A" => { "command" => "idle" }))
      bot.reload
      assert_not bot.downed?
      assert_equal 1, bot.hp
      assert_equal 0, bot.lamed_ticks
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
