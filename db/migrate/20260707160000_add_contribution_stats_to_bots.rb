# frozen_string_literal: true

# Per-match contribution counters: total collision damage a bot has dealt (mainly
# meaningful for fighters) and total HP a bot has restored to allies (healers). Reset
# each match by Arena::Setup, alongside gems_collected.
class AddContributionStatsToBots < ActiveRecord::Migration[8.1]
  def change
    add_column :bots, :damage_dealt, :integer, null: false, default: 0
    add_column :bots, :hp_restored, :integer, null: false, default: 0
  end
end
