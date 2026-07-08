# frozen_string_literal: true

module Arena
  # Starts a new match on the arena: lays out random interior walls, resets and
  # places every active bot on a free cell, spawns the initial gems, and flips the
  # game to `running`. The arena border is not a wall — moving off-grid is treated
  # as a crash by the tick engine, which keeps the whole grid playable.
  class Setup
    WALL_DENSITY = 0.06 # fraction of interior cells turned into obstacles

    def self.call(game)
      new(game).call
    end

    def initialize(game)
      @game = game
    end

    def call
      @game.transaction do
        walls = generate_walls
        place_bots(walls)
        gems = spawn_gems(walls)
        @game.update!(
          status: "running", tick: 0, walls: walls, gems: gems,
          winner_bot: nil, started_at: Time.current, finished_at: nil
        )
      end
      @game
    end

    private

    def generate_walls
      count = (@game.width * @game.height * WALL_DENSITY).round
      all_cells.sample(count)
    end

    # Resets each active bot's runtime state and drops it on a random free cell.
    # Inactive bots are cleared off the board (x/y nil) so they're skipped by ticks.
    def place_bots(walls)
      occupied = walls.to_set
      @game.bots.find_each do |bot|
        max_hp = role_max_hp(bot)
        bot.assign_attributes(
          max_hp: max_hp, hp: max_hp, downed: false, lamed_ticks: 0,
          gems_collected: 0, damage_dealt: 0, hp_restored: 0,
          heading: Game::HEADINGS.sample, vision_radius: @game.vision_radius,
          last_command: nil, last_error: nil
        )
        if bot.active?
          cell = random_free_cell(occupied)
          bot.x, bot.y = cell
          occupied << cell
        else
          bot.x = bot.y = nil
        end
        bot.save!
      end
    end

    def spawn_gems(walls)
      occupied = walls.to_set
      @game.bots.active.each { |b| occupied << b.coordinates if b.placed? }
      gems = []
      @game.gem_count.times do
        cell = random_free_cell(occupied) or break
        gems << cell
        occupied << cell
      end
      gems
    end

    # Fighters are tougher; everyone else uses the game's base max HP.
    def role_max_hp(bot)
      bot.fighter? ? @game.fighter_max_hp : @game.max_hp
    end

    def all_cells
      @all_cells ||= (0...@game.width).to_a.product((0...@game.height).to_a)
    end

    def random_free_cell(occupied)
      (all_cells - occupied.to_a).sample
    end
  end
end
