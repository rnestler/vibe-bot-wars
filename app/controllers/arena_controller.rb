# frozen_string_literal: true

# Renders the live arena page. Ongoing updates arrive over ArenaChannel; this action
# only provides the initial state and the surrounding UI (controls + scoreboard).
class ArenaController < ApplicationController
  before_action :require_admin

  def show
    @game = Game.current
    @bots = @game.bots.order(:id)
    @state = Arena::Broadcaster.new(@game).state
  end
end
