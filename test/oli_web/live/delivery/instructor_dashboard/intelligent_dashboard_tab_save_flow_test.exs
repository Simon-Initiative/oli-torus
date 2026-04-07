defmodule OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTabSaveFlowTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Dashboard.Oracle.Result
  alias Oli.Dashboard.Snapshot.Assembler
  alias Oli.InstructorDashboard.StudentSupportParameters
  alias OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab

  describe "handle_student_support_parameters_saved/2" do
    test "opens, updates, and cancels draft state without persistence" do
      %{section: section, socket: socket} = dashboard_socket_fixture()

      assert {:ok, socket} =
               IntelligentDashboardTab.handle_student_support_parameters_opened(socket)

      assert socket.assigns.show_student_support_parameters_modal

      assert socket.assigns.student_support_parameters_draft ==
               StudentSupportParameters.default_settings()

      assert {:ok, socket} =
               IntelligentDashboardTab.handle_student_support_parameters_draft_updated(socket, %{
                 "excelling_progress_gte" => "70",
                 "ignored_field" => "100"
               })

      assert socket.assigns.student_support_parameters_draft.excelling_progress_gte == "70"
      refute Map.has_key?(socket.assigns.student_support_parameters_draft, :ignored_field)
      assert StudentSupportParameters.get_active_settings(section.id).excelling_progress_gte == 60

      assert {:ok, socket} =
               IntelligentDashboardTab.handle_student_support_parameters_cancelled(socket)

      refute socket.assigns.show_student_support_parameters_modal

      assert socket.assigns.student_support_parameters_draft ==
               StudentSupportParameters.default_settings()

      assert StudentSupportParameters.get_active_settings(section.id).excelling_progress_gte == 60
    end

    test "persists settings and replaces the current Student Support projection" do
      %{section: section, user: user, socket: socket} = dashboard_socket_fixture()

      assert {:ok, socket} =
               IntelligentDashboardTab.handle_student_support_parameters_saved(socket, %{
                 inactivity_days: 14,
                 struggling_progress_low_lt: 35,
                 struggling_progress_high_gt: 90,
                 struggling_proficiency_lte: 35,
                 excelling_progress_gte: 50,
                 excelling_proficiency_gte: 60
               })

      assert StudentSupportParameters.get_active_settings(section.id).excelling_progress_gte == 50
      assert socket.assigns.current_user.id == user.id

      support_projection =
        socket.assigns.dashboard_bundle_state.projections.student_support.support

      assert Enum.find(support_projection.buckets, &(&1.id == "excelling")).count == 1
      assert Enum.find(support_projection.buckets, &(&1.id == "on_track")).count == 0

      dashboard_projection = socket.assigns.dashboard.student_support_projection
      assert Enum.find(dashboard_projection.buckets, &(&1.id == "excelling")).count == 1
    end

    test "failed save preserves the current projection and persisted settings" do
      %{section: section, socket: socket} = dashboard_socket_fixture()
      original_projection = socket.assigns.dashboard_bundle_state.projections.student_support

      assert {:error, :save_failed, socket} =
               IntelligentDashboardTab.handle_student_support_parameters_saved(socket, %{
                 inactivity_days: 21,
                 struggling_progress_low_lt: 35,
                 struggling_progress_high_gt: 90,
                 struggling_proficiency_lte: 35,
                 excelling_progress_gte: 50,
                 excelling_proficiency_gte: 60
               })

      assert StudentSupportParameters.get_active_settings(section.id) ==
               StudentSupportParameters.default_settings()

      assert socket.assigns.dashboard_bundle_state.projections.student_support ==
               original_projection
    end

    test "reprojection failure preserves the current projection after successful persistence" do
      %{section: section, socket: socket} = dashboard_socket_fixture()
      original_projection = socket.assigns.dashboard_bundle_state.projections.student_support
      socket = %{socket | assigns: Map.put(socket.assigns, :dashboard_bundle_state, nil)}

      assert {:error, :reprojection_failed, socket} =
               IntelligentDashboardTab.handle_student_support_parameters_saved(socket, %{
                 inactivity_days: 14,
                 struggling_progress_low_lt: 35,
                 struggling_progress_high_gt: 90,
                 struggling_proficiency_lte: 35,
                 excelling_progress_gte: 50,
                 excelling_proficiency_gte: 60
               })

      assert StudentSupportParameters.get_active_settings(section.id).excelling_progress_gte == 50
      assert is_nil(socket.assigns.dashboard_bundle_state)
      assert original_projection.support.default_bucket_id == "on_track"
    end
  end

  defp dashboard_socket_fixture do
    section = insert(:section)
    user = insert(:user)
    scope = %{container_type: :course, container_id: nil}

    context = %{
      dashboard_context_type: :section,
      dashboard_context_id: section.id,
      user_id: user.id,
      scope: scope
    }

    oracle_results = %{
      oracle_instructor_progress_proficiency:
        Result.ok(
          :oracle_instructor_progress_proficiency,
          [%{student_id: 1, progress_pct: 55.0, proficiency_pct: 65.0}],
          version: 1,
          metadata: %{source: :runtime}
        ),
      oracle_instructor_student_info:
        Result.ok(
          :oracle_instructor_student_info,
          [
            %{
              student_id: 1,
              email: "ada@example.edu",
              given_name: "Ada",
              family_name: "Lovelace",
              last_interaction_at: ~U[2026-03-13 08:00:00Z]
            }
          ],
          version: 1,
          metadata: %{source: :runtime}
        )
    }

    dependency_profile = %{
      required: [:oracle_instructor_progress_proficiency, :oracle_instructor_student_info],
      optional: []
    }

    {:ok, snapshot} =
      Assembler.assemble(context, "1", oracle_results,
        scope: scope,
        expected_oracles: dependency_profile.required,
        metadata: %{timezone: "UTC", source: :test}
      )

    {:ok, projection, projection_status} =
      Oli.Dashboard.Snapshot.Projections.derive(:student_support, snapshot)

    projections = %{student_support: projection}
    projection_statuses = %{student_support: projection_status}

    bundle = %{
      snapshot: %{snapshot | projections: projections, projection_statuses: projection_statuses},
      projections: projections,
      projection_statuses: projection_statuses,
      context: context,
      scope: scope,
      request_token: "1",
      dependency_profile: dependency_profile
    }

    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        section: section,
        current_user: user,
        dashboard_scope: "course",
        dashboard_oracle_results: oracle_results,
        dashboard_bundle_state: bundle,
        dashboard_revisit_hydration: %{source: :skipped, revisit_hits: 0, revisit_misses: 0},
        dashboard: %{student_support_projection: projections.student_support.support}
      }
    }

    %{section: section, user: user, socket: socket}
  end
end
