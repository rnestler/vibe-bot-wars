# frozen_string_literal: true

# Renders the live arena. Ongoing updates arrive over ArenaChannel; these actions only
# provide the initial state and surrounding UI. `show` is the operator dashboard (with
# match controls, behind Basic auth); `view` is a public, read-only spectator page.
class ArenaController < ApplicationController
  before_action :require_admin, only: :show

  def show
    @game = Game.current
    @bots = @game.bots.order(:id)
    @state = Arena::Broadcaster.new(@game).state
  end

  def view
    @game = Game.current
    @state = Arena::Broadcaster.new(@game).state
  end
end
