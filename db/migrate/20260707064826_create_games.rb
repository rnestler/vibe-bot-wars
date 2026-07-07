# frozen_string_literal: true

class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.string :status, null: false, default: "setup"
      t.integer :width, null: false, default: 20
      t.integer :height, null: false, default: 20
      t.integer :tick, null: false, default: 0
      t.integer :max_ticks, null: false, default: 400
      t.integer :tick_ms, null: false, default: 500
      t.integer :gem_count, null: false, default: 15
      t.integer :vision_radius, null: false, default: 1
      t.integer :scan_radius, null: false, default: 4
      t.integer :max_hp, null: false, default: 100
      t.integer :wall_damage, null: false, default: 10
      t.integer :collision_damage, null: false, default: 15
      t.integer :repair_amount, null: false, default: 20
      t.integer :webhook_timeout_ms, null: false, default: 400
      t.jsonb :walls, null: false, default: []
      t.jsonb :gems, null: false, default: []
      t.bigint :winner_bot_id
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end
  end
end
