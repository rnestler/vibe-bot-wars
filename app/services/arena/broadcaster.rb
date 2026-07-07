# frozen_string_literal: true

module Arena
  # Pushes the full arena state to the browser over Action Cable after each tick.
  # The Stimulus arena controller subscribes to ArenaChannel and renders this.
  class Broadcaster
    STREAM = "arena"

    def self.call(game)
      new(game).call
    end

    def initialize(game)
      @game = game
    end

    def call
      ActionCable.server.broadcast(STREAM, state)
    end

    def state
      {
        status: @game.status,
        tick: @game.tick,
        max_ticks: @game.max_ticks,
        width: @game.width,
        height: @game.height,
        walls: @game.walls,
        gems: @game.gems,
        winner_bot_id: @game.winner_bot_id,
        bots: @game.bots.order(:id).map { |bot| bot_state(bot) }
      }
    end

    private

    def bot_state(bot)
      {
        id: bot.id, name: bot.name, x: bot.x, y: bot.y, heading: bot.heading,
        hp: bot.hp, max_hp: @game.max_hp, gems: bot.gems_collected,
        downed: bot.downed, active: bot.active,
        last_command: bot.last_command, last_error: bot.last_error
      }
    end
  end
end
