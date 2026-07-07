# frozen_string_literal: true

require "test_helper"

class BotTest < ActiveSupport::TestCase
  setup { @game = Game.current }

  test "requires a name and an IP-address webhook url" do
    assert_not Bot.new(webhook_url: "http://10.0.0.1/").valid? # missing name
    bot = Bot.new(name: "A", webhook_url: "http://my-bot.example.com/") # hostname, not an IP
    assert_not bot.valid?
    assert_includes bot.errors[:webhook_url].to_s, "IP"
    assert Bot.new(name: "A", webhook_url: "http://192.168.1.5:4567/").valid?
  end

  test "name is unique" do
    @game.bots.create!(name: "Dup", webhook_url: "http://10.0.0.1/")
    assert_not @game.bots.new(name: "Dup", webhook_url: "http://10.0.0.2/").valid?
  end

  test "only one bot per device (webhook IP), ignoring port and path" do
    @game.bots.create!(name: "First", webhook_url: "http://10.0.0.9:4567/")
    dup = @game.bots.new(name: "Second", webhook_url: "http://10.0.0.9:9000/tick")
    assert_not dup.valid?
    assert_includes dup.errors[:webhook_url].to_s, "device"
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
