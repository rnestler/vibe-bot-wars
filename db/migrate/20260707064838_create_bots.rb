# frozen_string_literal: true

class CreateBots < ActiveRecord::Migration[8.1]
  def change
    create_table :bots do |t|
      t.references :game, null: false, foreign_key: true
      t.string :name, null: false
      t.string :webhook_url, null: false
      t.string :secret
      t.integer :x
      t.integer :y
      t.string :heading, null: false, default: "N"
      t.integer :hp, null: false, default: 100
      t.integer :gems_collected, null: false, default: 0
      t.boolean :downed, null: false, default: false
      t.integer :vision_radius, null: false, default: 1
      t.boolean :active, null: false, default: true
      t.string :last_command
      t.string :last_error
      t.datetime :last_contacted_at

      t.timestamps
    end
  end
end
