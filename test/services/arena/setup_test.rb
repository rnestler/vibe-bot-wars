# frozen_string_literal: true

require "test_helper"

module Arena
  class SetupTest < ActiveSupport::TestCase
    include ArenaTestHelpers

    test "starts a match: places active bots, spawns gems, marks running" do
      game = Game.create!(width: 12, height: 12, gem_count: 8)
      game.bots.create!(name: "A", webhook_url: "http://x/")
      game.bots.create!(name: "B", webhook_url: "http://x/")
      inactive = game.bots.create!(name: "C", webhook_url: "http://x/", active: false)

      Setup.call(game)
      game.reload

      assert_predicate game, :running?
      assert_equal 0, game.tick
      assert_equal 8, game.gems.size
      assert_not_nil game.started_at

      active = game.bots.active
      assert active.all?(&:placed?)
      assert(active.all? { |b| b.hp == game.max_hp })
      assert(active.none? { |b| game.wall?(*b.coordinates) })
      assert_not inactive.reload.placed?
    end

    test "bots and gems never share a wall cell" do
      game = Game.create!(width: 10, height: 10, gem_count: 10)
      3.times { |i| game.bots.create!(name: "B#{i}", webhook_url: "http://x/") }

      Setup.call(game)
      game.reload

      walls = game.walls.to_set { |c| [c[0], c[1]] }
      assert(game.gems.none? { |g| walls.include?(g) })
      occupied = game.bots.active.map(&:coordinates)
      assert_equal occupied.uniq.size, occupied.size, "bots overlap"
      assert_not occupied.intersect?(game.gems), "bot spawned on a gem"
    end
  end
end
