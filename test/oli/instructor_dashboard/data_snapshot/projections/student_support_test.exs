defmodule Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupportTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport
  alias Oli.InstructorDashboard.StudentSupportParameters

  describe "derive/2" do
    test "uses persisted section settings when deriving the support projection" do
      now = ~U[2026-03-13 12:00:00Z]
      section = insert(:section)

      attrs = %{
        inactivity_days: 14,
        struggling_progress_low_lt: 60,
        struggling_progress_high_gt: 90,
        struggling_proficiency_lte: 50,
        excelling_progress_gte: 70,
        excelling_proficiency_gte: 85
      }

      assert {:ok, settings} = StudentSupportParameters.save_for_section(section.id, attrs)

      snapshot =
        snapshot_fixture(
          section.id,
          [%{student_id: 1, progress_pct: 55.0, proficiency_pct: 45.0}],
          [
            %{
              student_id: 1,
              email: "ada@example.edu",
              given_name: "Ada",
              family_name: "Lovelace",
              last_interaction_at: ~U[2026-03-03 12:00:00Z]
            }
          ]
        )

      assert {:ok, projection} = StudentSupport.derive(snapshot, now: now)

      assert projection.support_parameters == settings
      assert projection.support.parameters == settings

      assert Enum.find(projection.support.buckets, &(&1.id == "struggling")).count == 1
      assert projection.support.totals.active_students == 1
      assert projection.support.totals.inactive_students == 0
    end

    test "uses defaults when no section settings row exists" do
      now = ~U[2026-03-13 12:00:00Z]
      section = insert(:section)

      snapshot =
        snapshot_fixture(
          section.id,
          [%{student_id: 1, progress_pct: 55.0, proficiency_pct: 65.0}],
          [
            %{
              student_id: 1,
              email: "ada@example.edu",
              given_name: "Ada",
              family_name: "Lovelace",
              last_interaction_at: ~U[2026-03-13 08:00:00Z]
            }
          ]
        )

      assert {:ok, projection} = StudentSupport.derive(snapshot, now: now)

      assert projection.support_parameters == StudentSupportParameters.default_settings()
      assert projection.support.parameters == StudentSupportParameters.default_settings()

      assert Enum.find(projection.support.buckets, &(&1.id == "on_track")).count == 1
      assert Enum.find(projection.support.buckets, &(&1.id == "excelling")).count == 0
    end

    test "supports explicit settings overrides for targeted rederive calls" do
      now = ~U[2026-03-13 12:00:00Z]
      section = insert(:section)

      settings = %{
        inactivity_days: 7,
        struggling_progress_low_lt: 35,
        struggling_progress_high_gt: 90,
        struggling_proficiency_lte: 35,
        excelling_progress_gte: 50,
        excelling_proficiency_gte: 60
      }

      snapshot =
        snapshot_fixture(
          section.id,
          [%{student_id: 1, progress_pct: 55.0, proficiency_pct: 65.0}],
          [
            %{
              student_id: 1,
              email: "ada@example.edu",
              given_name: "Ada",
              family_name: "Lovelace",
              last_interaction_at: ~U[2026-03-13 08:00:00Z]
            }
          ]
        )

      assert {:ok, projection} =
               StudentSupport.derive(snapshot, now: now, student_support_settings: settings)

      assert projection.support_parameters == settings
      assert Enum.find(projection.support.buckets, &(&1.id == "excelling")).count == 1
    end

    test "returns a deterministic error when a required oracle is missing" do
      section = insert(:section)
      snapshot = snapshot_fixture(section.id, [], [], %{oracle_instructor_student_info: nil})

      assert {:error, {:missing_required_oracles, [:oracle_instructor_student_info]}} =
               StudentSupport.derive(snapshot, [])
    end
  end

  defp snapshot_fixture(section_id, progress_rows, student_info_rows, overrides \\ %{}) do
    default_oracles = %{
      oracle_instructor_progress_proficiency: progress_rows,
      oracle_instructor_student_info: student_info_rows
    }

    oracles =
      overrides
      |> Enum.reduce(default_oracles, fn
        {key, nil}, acc -> Map.delete(acc, key)
        {key, value}, acc -> Map.put(acc, key, value)
      end)

    {:ok, snapshot} =
      Contract.new_snapshot(%{
        request_token: "token-student-support-proj-1",
        context: %{
          dashboard_context_type: :section,
          dashboard_context_id: section_id,
          user_id: 88,
          scope: %{container_type: :container, container_id: 777}
        },
        metadata: %{timezone: "UTC"},
        oracles: oracles,
        oracle_statuses:
          Enum.into(Map.keys(oracles), %{}, fn key ->
            {key, %{status: :ready}}
          end)
      })

    snapshot
  end
end
