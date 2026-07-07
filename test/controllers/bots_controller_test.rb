# frozen_string_literal: true

require "test_helper"

# Covers the access rules layered on bot CRUD:
#   - anyone may register a bot (no auth)
#   - deleting a bot is operator-only (HTTP Basic auth)
#   - editing is allowed straight from the bot's own webhook host, otherwise it falls
#     back to operator auth
class BotsControllerTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  def admin_headers
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "botwars") }
  end

  def create_bot(webhook_url)
    Game.current.bots.create!(name: "bot-#{SecureRandom.hex(4)}", webhook_url: webhook_url)
  end

  test "the add-bot page shows the webhook contract" do
    get new_bot_path
    assert_response :success
    assert_select "h2", text: "Webhook contract"
  end

  test "anyone can register a bot without auth" do
    assert_difference("Bot.count", 1) do
      post bots_path, params: { bot: { name: "Newcomer", webhook_url: "http://127.0.0.1:4000/" } }
    end
    assert_redirected_to bots_path
  end

  test "deleting a bot requires operator auth" do
    bot = create_bot("http://127.0.0.1:4000/")

    assert_no_difference("Bot.count") do
      delete bot_path(bot)
    end
    assert_response :unauthorized

    assert_difference("Bot.count", -1) do
      delete bot_path(bot), headers: admin_headers
    end
  end

  test "editing is allowed from the bot's own webhook host" do
    bot = create_bot("http://127.0.0.1:4000/") # test requests come from 127.0.0.1

    get edit_bot_path(bot)
    assert_response :success

    patch bot_path(bot), params: { bot: { name: "Renamed" } }
    assert_redirected_to bots_path
    assert_equal "Renamed", bot.reload.name
  end

  test "editing from a foreign host falls back to operator auth" do
    bot = create_bot("http://10.11.12.13:4000/") # not the requester's IP

    get edit_bot_path(bot)
    assert_response :unauthorized

    get edit_bot_path(bot), headers: admin_headers
    assert_response :success
  end
end
