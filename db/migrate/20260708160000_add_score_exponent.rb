# frozen_string_literal: true

# Team score is total gems divided by team_size ** score_exponent. An exponent of 1 is a
# plain per-bot average; larger values (e.g. 1.5) handicap bigger teams more, reducing the
# advantage of simply having more bots.
class AddScoreExponent < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :score_exponent, :decimal, precision: 4, scale: 2, null: false, default: 1.5
  end
end
