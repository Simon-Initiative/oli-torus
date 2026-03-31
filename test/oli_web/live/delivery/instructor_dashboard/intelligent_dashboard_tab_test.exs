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

  describe "parse_student_support_tile_state/1" do
    test "normalizes tile-local dashboard params" do
      assert IntelligentDashboardTab.parse_student_support_tile_state(%{
               "tile_support" => %{
                 "bucket" => "struggling",
                 "filter" => "inactive",
                 "page" => "2",
                 "q" => " ada "
               }
             }) == %{
               selected_bucket_id: "struggling",
               selected_activity_filter: :inactive,
               search_term: "ada",
               page: 2,
               visible_count: 40
             }
    end

    test "falls back safely when tile_support is not a map" do
      assert IntelligentDashboardTab.parse_student_support_tile_state(%{
               "tile_support" => "bad"
             }) == %{
               selected_bucket_id: nil,
               selected_activity_filter: :all,
               search_term: "",
               page: 1,
               visible_count: 20
             }
    end
  end

  describe "parse_assessments_tile_state/1" do
    test "normalizes tile-local dashboard params" do
      assert IntelligentDashboardTab.parse_assessments_tile_state(%{
               "tile_assessments" => %{"expanded" => "123"}
             }) == %{
               expanded_assessment_id: 123
             }
    end

    test "falls back safely when tile_assessments is not a map" do
      assert IntelligentDashboardTab.parse_assessments_tile_state(%{
               "tile_assessments" => "bad"
             }) == %{
               expanded_assessment_id: nil
             }
    end
  end

  describe "student_support_path/2" do
    test "preserves only dashboard and namespaced tile params" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          section: %{slug: "elixir_30"},
          dashboard_scope: "course",
          params: %{
            "view" => "insights",
            "active_tab" => "dashboard",
            "section_slug" => "elixir_30",
            "dashboard_scope" => "course",
            "tile_support" => %{"filter" => "inactive"}
          }
        }
      }

      assert IntelligentDashboardTab.student_support_path(socket, %{bucket: "on_track", page: 1}) ==
               "/sections/elixir_30/instructor_dashboard/insights/dashboard?dashboard_scope=course&tile_support[bucket]=on_track&tile_support[filter]=inactive"
    end
  end

  describe "assessments_path/2" do
    test "preserves only dashboard and namespaced tile params" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          section: %{slug: "elixir_30"},
          dashboard_scope: "course",
          params: %{
            "view" => "insights",
            "active_tab" => "dashboard",
            "section_slug" => "elixir_30",
            "dashboard_scope" => "course",
            "tile_support" => %{"filter" => "inactive"}
          }
        }
      }

      assert IntelligentDashboardTab.assessments_path(socket, %{expanded: 456}) ==
               "/sections/elixir_30/instructor_dashboard/insights/dashboard?dashboard_scope=course&tile_assessments[expanded]=456&tile_support[filter]=inactive"
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
