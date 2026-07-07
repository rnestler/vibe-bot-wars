# frozen_string_literal: true

require "test_helper"

class DemoBotControllerTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  def ask(payload)
    post demo_bot_path, params: payload.to_json, headers: { "Content-Type" => "application/json" }
    response.parsed_body
  end

  test "moves toward the nearest visible gem" do
    command = ask(
      "self" => { "x" => 5, "y" => 5, "hp" => 100, "max_hp" => 100, "downed" => false },
      "vision" => { "radius" => 1, "walls" => [], "gems" => [[8, 5]], "bots" => [] }
    )
    assert_equal "move", command["command"]
    assert_equal "E", command["dir"]
  end

  test "repairs when hurt" do
    command = ask(
      "self" => { "x" => 5, "y" => 5, "hp" => 10, "max_hp" => 100, "downed" => false },
      "vision" => { "radius" => 1, "walls" => [], "gems" => [[8, 5]], "bots" => [] }
    )
    assert_equal "repair", command["command"]
  end

  test "scans when nothing is visible at close range" do
    command = ask(
      "self" => { "x" => 5, "y" => 5, "hp" => 100, "max_hp" => 100, "downed" => false },
      "vision" => { "radius" => 1, "walls" => [], "gems" => [], "bots" => [] }
    )
    assert_equal "scan", command["command"]
  end

  test "invalid JSON yields idle" do
    post demo_bot_path, params: "not json", headers: { "Content-Type" => "application/json" }
    assert_equal({ "command" => "idle" }, response.parsed_body)
  end
end
