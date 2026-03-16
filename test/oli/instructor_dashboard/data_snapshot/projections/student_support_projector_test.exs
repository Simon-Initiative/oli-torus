defmodule Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport.ProjectorTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport.Projector

  describe "build/3" do
    test "prefers struggling when present and derives inactive rows outside the UI" do
      now = ~U[2026-03-13 12:00:00Z]

      progress_rows = [
        %{student_id: 1, progress_pct: 25.0, proficiency_pct: 35.0},
        %{student_id: 2, progress_pct: 82.0, proficiency_pct: 88.0}
      ]

      student_info_rows = [
        %{
          student_id: 1,
          email: "ada@example.edu",
          given_name: "Ada",
          family_name: "Lovelace",
          last_interaction_at: ~U[2026-03-01 12:00:00Z]
        },
        %{
          student_id: 2,
          email: "grace@example.edu",
          given_name: "Grace",
          family_name: "Hopper",
          last_interaction_at: ~U[2026-03-12 12:00:00Z]
        }
      ]

      projection = Projector.build(progress_rows, student_info_rows, now: now)

      assert projection.default_bucket_id == "struggling"
      assert projection.totals == %{total_students: 2, active_students: 1, inactive_students: 1}

      struggling_bucket = Enum.find(projection.buckets, &(&1.id == "struggling"))
      assert struggling_bucket.inactive_count == 1
      assert [ada] = struggling_bucket.students
      assert ada.display_name == "Ada Lovelace"
      assert ada.activity_status == :inactive
      assert ada.progress_pct == 25.0
      assert ada.proficiency_pct == 35.0
    end

    test "falls back to the first non-empty bucket when struggling is empty" do
      now = ~U[2026-03-13 12:00:00Z]

      progress_rows = [
        %{student_id: 10, progress_pct: 72.0, proficiency_pct: 75.0},
        %{student_id: 11, progress_pct: 80.0, proficiency_pct: nil}
      ]

      student_info_rows = [
        %{
          student_id: 10,
          email: "marie@example.edu",
          given_name: "Marie",
          family_name: "Curie",
          last_interaction_at: ~U[2026-03-13 08:00:00Z]
        },
        %{
          student_id: 11,
          email: "rosalind@example.edu",
          given_name: "Rosalind",
          family_name: "Franklin",
          last_interaction_at: nil
        }
      ]

      projection = Projector.build(progress_rows, student_info_rows, now: now)

      assert projection.default_bucket_id == "on_track"
      assert Enum.find(projection.buckets, &(&1.id == "struggling")).count == 0
      assert Enum.find(projection.buckets, &(&1.id == "on_track")).count == 1
      assert Enum.find(projection.buckets, &(&1.id == "not_enough_information")).count == 1
      assert projection.has_activity_data? == true
    end

    test "normalizes 0..1 proficiency ratios before bucket classification" do
      now = ~U[2026-03-13 12:00:00Z]

      progress_rows = [
        %{student_id: 20, progress_pct: 82.0, proficiency_pct: 0.84},
        %{student_id: 21, progress_pct: 25.0, proficiency_pct: 0.35}
      ]

      student_info_rows = [
        %{
          student_id: 20,
          email: "katherine@example.edu",
          given_name: "Katherine",
          family_name: "Johnson",
          last_interaction_at: ~U[2026-03-13 08:00:00Z]
        },
        %{
          student_id: 21,
          email: "alan@example.edu",
          given_name: "Alan",
          family_name: "Turing",
          last_interaction_at: ~U[2026-03-12 08:00:00Z]
        }
      ]

      projection = Projector.build(progress_rows, student_info_rows, now: now)

      assert Enum.find(projection.buckets, &(&1.id == "excelling")).count == 1
      assert Enum.find(projection.buckets, &(&1.id == "struggling")).count == 1

      excelling_bucket = Enum.find(projection.buckets, &(&1.id == "excelling"))
      struggling_bucket = Enum.find(projection.buckets, &(&1.id == "struggling"))

      assert [katherine] = excelling_bucket.students
      assert [alan] = struggling_bucket.students
      assert katherine.proficiency_pct == 84.0
      assert alan.proficiency_pct == 35.0
    end
  end
end
