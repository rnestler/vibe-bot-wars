# frozen_string_literal: true

# Bots now have a role (collector / fighter / healer). Fighters are tougher and hit
# harder; healers heal same-group allies. Per-bot `max_hp` is set per role at match
# setup. New game-level knobs tune fighter strength and the healer's output.
class AddRolesAndCombatStats < ActiveRecord::Migration[8.1]
  def change
    add_column :bots, :role, :integer, null: false, default: 0
    add_index :bots, :role
    add_column :bots, :max_hp, :integer, null: false, default: 100

    add_column :games, :fighter_max_hp, :integer, null: false, default: 200
    add_column :games, :fighter_collision_damage, :integer, null: false, default: 30
    add_column :games, :heal_amount, :integer, null: false, default: 15
  end
end
