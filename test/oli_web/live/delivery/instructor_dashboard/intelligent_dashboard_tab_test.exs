defmodule OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTabTest do
  use ExUnit.Case, async: true

  alias OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab

  describe "parse_scope/1" do
    test "parses the course scope" do
      assert IntelligentDashboardTab.parse_scope("course") == %{
               container_type: :course,
               container_id: nil
             }
    end

    test "parses a valid container scope" do
      assert IntelligentDashboardTab.parse_scope("container:123") == %{
               container_type: :container,
               container_id: 123
             }
    end

    test "falls back to the course scope for invalid values" do
      assert IntelligentDashboardTab.parse_scope(nil) == %{
               container_type: :course,
               container_id: nil
             }

      assert IntelligentDashboardTab.parse_scope("container:not-a-number") == %{
               container_type: :course,
               container_id: nil
             }

      assert IntelligentDashboardTab.parse_scope("container:-1") == %{
               container_type: :course,
               container_id: nil
             }

      assert IntelligentDashboardTab.parse_scope("wat") == %{
               container_type: :course,
               container_id: nil
             }
    end
  end

  describe "scope_selector/1" do
    test "builds the canonical selector string for a container scope" do
      assert IntelligentDashboardTab.scope_selector(%{
               container_type: :container,
               container_id: 456
             }) ==
               "container:456"
    end

    test "falls back to course for non-container scopes" do
      assert IntelligentDashboardTab.scope_selector(%{container_type: :course}) == "course"
      assert IntelligentDashboardTab.scope_selector(%{}) == "course"
    end
  end

  describe "path/2" do
    test "builds the canonical dashboard path and url-encodes the scope selector" do
      socket = %Phoenix.LiveView.Socket{assigns: %{section: %{slug: "elixir_30"}}}

      assert IntelligentDashboardTab.path(socket, "container:151334") ==
               "/sections/elixir_30/instructor_dashboard/insights/dashboard?dashboard_scope=container%3A151334"
    end
  end

  describe "validate_scope_selector/3" do
    test "accepts course scope" do
      assert IntelligentDashboardTab.validate_scope_selector(%{}, nil, "course") ==
               {:ok, "course"}
    end

    test "accepts a valid container from assigned containers" do
      section = %{slug: "example-section"}
      containers = {1, [%{id: 123}]}

      assert IntelligentDashboardTab.validate_scope_selector(section, containers, "container:123") ==
               {:ok, "container:123"}
    end

    test "rejects an invalid container from assigned containers" do
      section = %{slug: "example-section"}
      containers = {1, [%{id: 123}]}

      assert IntelligentDashboardTab.validate_scope_selector(section, containers, "container:999") ==
               :error
    end
  end

  describe "normalize_scope_selector/3" do
    test "falls back to course for an invalid container" do
      section = %{slug: "example-section"}
      containers = {1, [%{id: 123}]}

      assert IntelligentDashboardTab.normalize_scope_selector(
               section,
               containers,
               "container:999"
             ) ==
               "course"
    end

    test "returns the canonical selector for a valid container" do
      section = %{slug: "example-section"}
      containers = {1, [%{id: 123}]}

      assert IntelligentDashboardTab.normalize_scope_selector(
               section,
               containers,
               "container:123"
             ) ==
               "container:123"
    end
  end

  describe "handle_dashboard_request_timeout/2" do
    test "fails closed when no authenticated user id is available" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, section: %{id: 123}, dashboard_scope: "course"}
      }

      assert {:noreply, updated_socket} =
               IntelligentDashboardTab.handle_dashboard_request_timeout(socket, 1)

      assert updated_socket.assigns.dashboard.runtime_status_text =~ "missing_user_id"
    end
  end
end
