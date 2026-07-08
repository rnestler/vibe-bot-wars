# frozen_string_literal: true

# The `respawn` command teleports a bot to a random free cell, then blocks it (out of
# action) for a short time. `blocked_ticks` counts a bot's remaining blocked ticks;
# `respawn_block_ticks` is the game-wide block length.
class AddRespawnCommand < ActiveRecord::Migration[8.1]
  def change
    add_column :bots, :blocked_ticks, :integer, null: false, default: 0
    add_column :games, :respawn_block_ticks, :integer, null: false, default: 3
  end
end
