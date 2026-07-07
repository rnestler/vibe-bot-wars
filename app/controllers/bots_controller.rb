# frozen_string_literal: true

# CRUD for registered bots plus a one-off webhook probe (`test`) that helps authors
# confirm their server responds with a valid command.
class BotsController < ApplicationController
  before_action :set_bot, only: %i[edit update destroy test]
  # Only the operator may delete bots; participants can register and edit their own.
  before_action :require_admin, only: :destroy
  # Editing is allowed from the bot's own host, otherwise it falls back to operator auth.
  before_action :authorize_bot_edit, only: %i[edit update]

  def index
    @bots = Game.current.bots.order(:id)
  end

  def new
    @bot = Game.current.bots.new
  end

  def edit; end

  def create
    @bot = Game.current.bots.new(bot_params)
    if @bot.save
      redirect_to bots_path, notice: "Bot registered."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @bot.update(bot_params)
      redirect_to bots_path, notice: "Bot updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @bot.destroy
    redirect_to bots_path, notice: "Bot removed."
  end

  # Sends one sample sensor payload to the bot's webhook and reports the response.
  def test
    result = WebhookClient.call(@bot, sample_payload, timeout_ms: Game.current.webhook_timeout_ms)
    flash[:notice] = if result.ok?
                       "Webhook responded: #{result.command.inspect}"
                     else
                       "Webhook error: #{result.error}"
                     end
    redirect_to bots_path
  end

  private

  def set_bot
    @bot = Game.current.bots.find(params.expect(:id))
  end

  # Allow editing straight through if the request comes from the bot's own webhook host;
  # otherwise require the operator password (which can edit any bot).
  def authorize_bot_edit
    require_admin unless request_from_webhook_host?(@bot)
  end

  def bot_params
    params.expect(bot: %i[name webhook_url secret active group role])
  end

  def sample_payload
    game = Game.current
    Arena::SensorPayload.call(
      game: game, bot: probe_bot(game), others: [], radius: game.vision_radius
    )
  end

  # Use the bot's live state if it's on the board, otherwise a neutral centre-of-arena probe.
  def probe_bot(game)
    return @bot if @bot.placed?

    @bot.dup.tap do |b|
      b.x = game.width / 2
      b.y = game.height / 2
    end
  end
end
