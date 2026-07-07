# frozen_string_literal: true

# Every bot belongs to one of three groups (one per school class). Integer-backed enum;
# existing rows default to the first group.
class AddGroupToBots < ActiveRecord::Migration[8.1]
  def change
    add_column :bots, :group, :integer, null: false, default: 0
    add_index :bots, :group
  end
end
