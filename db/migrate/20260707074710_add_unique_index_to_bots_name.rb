# frozen_string_literal: true

class AddUniqueIndexToBotsName < ActiveRecord::Migration[8.1]
  def change
    add_index :bots, :name, unique: true
  end
end
