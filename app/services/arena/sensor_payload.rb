# frozen_string_literal: true

module Arena
  # Builds the JSON sensor payload sent to a single bot's webhook each tick.
  # Vision is a square (Chebyshev) radius around the bot: `radius` is the game's
  # default (1) normally, and the larger scan_radius on the tick after a `scan`.
  class SensorPayload
    def self.call(...)
      new(...).call
    end

    def initialize(game:, bot:, others:, radius:)
      @game = game
      @bot = bot
      @others = others
      @radius = radius
    end

    def call
      {
        game_id: @game.id,
        tick: @game.tick,
        arena: { width: @game.width, height: @game.height },
        self: {
          id: @bot.id, name: @bot.name, x: @bot.x, y: @bot.y, heading: @bot.heading,
          hp: @bot.hp, max_hp: @bot.max_hp, gems: @bot.gems_collected,
          downed: @bot.downed, lamed_ticks: @bot.lamed_ticks, blocked_ticks: @bot.blocked_ticks,
          respawn_cooldown: @bot.respawn_cooldown, group: @bot.group, role: @bot.role
        },
        vision: {
          radius: @radius,
          walls: visible(@game.walls),
          gems: visible(@game.gems),
          bots: visible_bots
        }
      }
    end

    private

    def within?(x, y)
      (x - @bot.x).abs <= @radius && (y - @bot.y).abs <= @radius
    end

    def visible(cells)
      cells.select { |(x, y)| within?(x, y) }
    end

    def visible_bots
      @others.select { |b| b.placed? && within?(b.x, b.y) }.map do |b|
        { x: b.x, y: b.y, hp: b.hp, max_hp: b.max_hp, downed: b.downed, group: b.group, role: b.role }
      end
    end
  end
end
