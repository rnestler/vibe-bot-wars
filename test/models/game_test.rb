# frozen_string_literal: true

require "test_helper"

class GameTest < ActiveSupport::TestCase
  test "current returns a persisted singleton, reused on subsequent calls" do
    game = Game.current
    assert_predicate game, :persisted?
    assert_equal game.id, Game.current.id
    assert_no_difference("Game.count") { 3.times { Game.current } }
  end

  test "defaults describe a 20x20 setup arena" do
    game = Game.create!
    assert_equal "setup", game.status
    assert_equal 20, game.width
    assert_equal 20, game.height
    assert_equal [], game.walls
  end

  test "status predicates" do
    game = Game.new(status: "running")
    assert_predicate game, :running?
    assert_not_predicate game, :finished?
  end

  test "bounds and wall helpers" do
    game = Game.new(width: 5, height: 5, walls: [[2, 2]])
    assert game.in_bounds?(0, 0)
    assert_not game.in_bounds?(5, 0)
    assert game.wall?(2, 2)
    assert_not game.open_cell?(2, 2)
    assert game.open_cell?(1, 1)
  end
end
