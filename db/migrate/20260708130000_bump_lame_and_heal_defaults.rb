# frozen_string_literal: true

# Make healers more impactful: longer lame (harder to survive being downed without help)
# and a much bigger heal. Updates existing games still sitting on the old defaults.
class BumpLameAndHealDefaults < ActiveRecord::Migration[8.1]
  def up
    change_column_default :games, :lame_ticks, from: 10, to: 30
    change_column_default :games, :heal_amount, from: 15, to: 60
    execute "UPDATE games SET lame_ticks = 30 WHERE lame_ticks = 10"
    execute "UPDATE games SET heal_amount = 60 WHERE heal_amount = 15"
  end

  def down
    change_column_default :games, :lame_ticks, from: 30, to: 10
    change_column_default :games, :heal_amount, from: 60, to: 15
    execute "UPDATE games SET lame_ticks = 10 WHERE lame_ticks = 30"
    execute "UPDATE games SET heal_amount = 15 WHERE heal_amount = 60"
  end
end
