# frozen_string_literal: true

namespace :arena do
  desc "Run the real-time game loop: ticks the arena every tick_ms while a match is running"
  task run: :environment do
    Rails.logger.info("[arena:run] game loop starting")
    puts "[arena:run] game loop starting (Ctrl-C to stop)"

    running = true
    trap("INT")  { running = false }
    trap("TERM") { running = false }

    while running
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      game = Game.current

      if game.running?
        begin
          Arena::Tick.call(game)
        rescue StandardError => e
          Rails.logger.error("[arena:run] tick error: #{e.class}: #{e.message}")
        end
      end

      # Sleep out the remainder of the tick interval (min 50ms when idle).
      interval = (game.running? ? game.tick_ms : 500) / 1000.0
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      sleep([interval - elapsed, 0.05].max)
    end

    puts "[arena:run] game loop stopped"
  end
end
