defmodule OliWeb.Delivery.InstructorDashboard.DashboardTabTest do
  use ExUnit.Case, async: true

  alias OliWeb.Delivery.InstructorDashboard.DashboardTab

  describe "parse_scope/1" do
    test "parses the course scope" do
      assert DashboardTab.parse_scope("course") == %{container_type: :course}
    end

    test "parses a valid container scope" do
      assert DashboardTab.parse_scope("container:123") == %{
               container_type: :container,
               container_id: 123
             }
    end

    test "falls back to the course scope for invalid values" do
      assert DashboardTab.parse_scope(nil) == %{container_type: :course}
      assert DashboardTab.parse_scope("container:not-a-number") == %{container_type: :course}
      assert DashboardTab.parse_scope("container:-1") == %{container_type: :course}
      assert DashboardTab.parse_scope("wat") == %{container_type: :course}
    end
  end

  describe "scope_selector/1" do
    test "builds the canonical selector string for a container scope" do
      assert DashboardTab.scope_selector(%{container_type: :container, container_id: 456}) ==
               "container:456"
    end

    test "falls back to course for non-container scopes" do
      assert DashboardTab.scope_selector(%{container_type: :course}) == "course"
      assert DashboardTab.scope_selector(%{}) == "course"
    end
  end

  describe "path/2" do
    test "builds the canonical dashboard path and url-encodes the scope selector" do
      socket = %Phoenix.LiveView.Socket{assigns: %{section: %{slug: "elixir_30"}}}

      assert DashboardTab.path(socket, "container:151334") ==
               "/sections/elixir_30/instructor_dashboard/insights/dashboard?dashboard_scope=container%3A151334"
    end
  end
end
