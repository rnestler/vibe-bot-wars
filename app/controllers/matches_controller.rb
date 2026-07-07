# frozen_string_literal: true

# Starts and stops matches on the single arena.
class MatchesController < ApplicationController
  before_action :require_admin

  CONFIG_KEYS = %i[width height gem_count max_ticks tick_ms].freeze

  def create
    game = Game.current
    game.update!(config_params)
    Arena::Setup.call(game)
    Arena::Broadcaster.call(game)
    redirect_to root_path, notice: "New match started."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to root_path, alert: "Could not start match: #{e.record.errors.full_messages.to_sentence}"
  end

  def stop
    game = Game.current
    game.update!(status: "setup")
    Arena::Broadcaster.call(game)
    redirect_to root_path, notice: "Match stopped."
  end

  private

  def config_params
    params.permit(*CONFIG_KEYS).to_h.symbolize_keys.transform_values(&:to_i).compact_blank
  end
end
