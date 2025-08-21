defmodule OliWeb.Instructor.ReviewActivitiesLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections

  describe "review activities live" do
    setup [:instructor_conn]

    test "route exists and responds appropriately to invalid selection", %{
      conn: conn,
      instructor: instructor
    } do
      section = insert(:section, %{open_and_free: true})
      user_id = instructor.id
      Sections.enroll(user_id, section.id, [ContextRoles.get_role(:context_instructor)])

      # Test that the route exists and handles invalid page gracefully
      result = live(conn, ~p"/sections/#{section.slug}/preview/page/invalid_page/selection/invalid_selection")

      # Should redirect with error flash
      assert {:error, {:redirect, %{flash: %{"error" => error_message}}}} = result
      assert error_message =~ "Failed to load selection"
    end

    test "LiveView module exists and has mount function", %{conn: _conn} do
      # Basic module test
      assert function_exported?(OliWeb.Instructor.ReviewActivitiesLive, :mount, 3)
      assert function_exported?(OliWeb.Instructor.ReviewActivitiesLive, :render, 1)
    end
  end
end