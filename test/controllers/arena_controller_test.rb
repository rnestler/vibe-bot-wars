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
end
