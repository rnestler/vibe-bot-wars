# frozen_string_literal: true

# When a bot's HP hits 0 it is "lamed" (out of action) for a fixed number of ticks, then
# revives at 1 HP. `lamed_ticks` counts the remaining lamed ticks on a bot; `lame_ticks`
# is the game-wide duration.
class AddLameMechanic < ActiveRecord::Migration[8.1]
  def change
    add_column :bots, :lamed_ticks, :integer, null: false, default: 0
    add_column :games, :lame_ticks, :integer, null: false, default: 10
  end
end
