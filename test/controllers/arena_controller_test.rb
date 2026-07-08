# frozen_string_literal: true

require "test_helper"

class ArenaControllerTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  test "the spectator view is public and shows the arena" do
    get arena_view_path
    assert_response :success
    assert_select "[data-controller=arena]"
    assert_select "form", false, "the read-only view has no match-control forms"
  end

  test "the operator dashboard requires Basic auth" do
    get root_path
    assert_response :unauthorized
  end

  test "Stop is its own form, not nested inside the New-match form" do
    creds = ActionController::HttpAuthentication::Basic.encode_credentials(
      ENV.fetch("ARENA_ADMIN_USER", "admin"), ENV.fetch("ARENA_ADMIN_PASSWORD", "botwars")
    )
    get root_path, headers: { "HTTP_AUTHORIZATION" => creds }
    assert_response :success

    assert_select "form#match-form"
    assert_select "form[action=?][method=post]", stop_match_path
    assert_select "input[type=submit][form=match-form]" # New match submit bound to the config form
    assert_select "form#match-form form", false, "the Stop form must not be nested in the match form"
  end
end
