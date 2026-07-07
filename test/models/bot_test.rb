# frozen_string_literal: true

require "test_helper"

class BotTest < ActiveSupport::TestCase
  setup { @game = Game.current }

  test "requires a name and a valid http webhook url" do
    assert_not Bot.new(webhook_url: "http://x/").valid?
    bot = Bot.new(name: "A", webhook_url: "not-a-url")
    assert_not bot.valid?
    assert_includes bot.errors[:webhook_url].to_s, "http"
    assert Bot.new(name: "A", webhook_url: "https://x/").valid?
  end

  test "name is unique" do
    @game.bots.create!(name: "Dup", webhook_url: "http://x/")
    assert_not @game.bots.new(name: "Dup", webhook_url: "http://x/").valid?
  end

  test "damage floors at zero and downs the bot" do
    bot = @game.bots.new(hp: 12)
    bot.damage!(10)
    assert_equal 2, bot.hp
    assert_not bot.downed?
    bot.damage!(10)
    assert_equal 0, bot.hp
    assert bot.downed?
  end

  test "repair heals up to max and clears downed" do
    bot = @game.bots.new(hp: 0, downed: true)
    bot.repair!(20, 100)
    assert_equal 20, bot.hp
    assert_not bot.downed?
    bot.repair!(1000, 100)
    assert_equal 100, bot.hp
  end
end
