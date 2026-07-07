# frozen_string_literal: true

# Helpers for exercising the arena engine without any real HTTP. StubClient mimics
# WebhookClient's interface but never loads net/http, so these tests run anywhere.
module ArenaTestHelpers
  Result = Struct.new(:command, :error) do
    def ok?
      error.nil?
    end
  end

  # Returns scripted commands keyed by bot name (a command Hash). Unknown => idle.
  class StubClient
    def initialize(script = {})
      @script = script
    end

    def call(bot, _payload, **)
      Result.new(@script.fetch(bot.name, { "command" => "idle" }), nil)
    end
  end

  # Always reports a failed webhook (e.g. timeout).
  class ErrorClient
    def call(_bot, _payload, **)
      Result.new(nil, "timeout")
    end
  end

  def build_running_game(**attrs)
    Game.create!({
      status: "running", width: 10, height: 10, gem_count: 1, max_ticks: 1000,
      walls: [], gems: []
    }.merge(attrs))
  end

  def place_bot(game, name:, x:, y:, **attrs)
    game.bots.create!({
      # A unique per-device (per-IP) webhook, as the model now requires.
      name: name, webhook_url: "http://10.0.0.#{game.bots.count + 1}:4567/", x: x, y: y,
      hp: game.max_hp, heading: "N", vision_radius: game.vision_radius
    }.merge(attrs))
  end

  def move(dir)
    { "command" => "move", "dir" => dir }
  end
end
