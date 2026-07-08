# frozen_string_literal: true

# The arena. This app runs a single persistent arena (the "current" game); a new
# match resets its runtime state (positions, HP, gems, walls, tick) while the
# registered bots persist. See Arena::Setup and Arena::Tick.
class Game < ApplicationRecord
  STATUSES = %w[setup running finished].freeze
  HEADINGS = %w[N E S W].freeze

  # dx/dy for each heading. Grid origin is top-left: +y is south, +x is east.
  DIRECTIONS = { "N" => [0, -1], "E" => [1, 0], "S" => [0, 1], "W" => [-1, 0] }.freeze

  has_many :bots, dependent: :destroy
  belongs_to :winner_bot, class_name: "Bot", optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :width, :height, numericality: { greater_than_or_equal_to: 5 }
  validates :max_ticks, :tick_ms, :gem_count, :scan_radius, :max_hp,
            :fighter_max_hp, :fighter_collision_damage, :heal_amount, :lame_ticks,
            numericality: { greater_than: 0 }
  validates :vision_radius, numericality: { greater_than_or_equal_to: 1 }

  STATUSES.each do |state|
    define_method("#{state}?") { status == state }
  end

  # The single arena row, created on first use.
  def self.current
    first || create!
  end

  def running_bots
    bots.where(active: true)
  end

  def wall?(x, y)
    walls.include?([x, y])
  end

  def in_bounds?(x, y)
    x >= 0 && y >= 0 && x < width && y < height
  end

  # A cell that is inside the arena and not a wall. Bots and gems may still occupy it.
  def open_cell?(x, y)
    in_bounds?(x, y) && !wall?(x, y)
  end
end
