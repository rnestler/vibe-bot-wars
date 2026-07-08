# frozen_string_literal: true

# Rate-limit the respawn command: after a respawn a bot must wait out a cooldown before it
# may respawn again. `respawn_cooldown` counts a bot's remaining cooldown ticks;
# `respawn_cooldown_ticks` is the game-wide length.
class AddRespawnCooldown < ActiveRecord::Migration[8.1]
  def change
    add_column :bots, :respawn_cooldown, :integer, null: false, default: 0
    add_column :games, :respawn_cooldown_ticks, :integer, null: false, default: 100
  end
end
