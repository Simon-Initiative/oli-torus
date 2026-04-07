defmodule Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport.ProjectorTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport.Projector
  alias Oli.InstructorDashboard.StudentSupportParameters

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
          picture: "https://example.edu/ada.png",
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
      assert ada.picture == "https://example.edu/ada.png"
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

    test "classifies excelling students using 60 progress and 80 proficiency thresholds" do
      now = ~U[2026-03-13 12:00:00Z]

      progress_rows = [
        %{student_id: 12, progress_pct: 65.0, proficiency_pct: 82.0},
        %{student_id: 13, progress_pct: 59.0, proficiency_pct: 82.0}
      ]

      student_info_rows = [
        %{
          student_id: 12,
          email: "edsger@example.edu",
          given_name: "Edsger",
          family_name: "Dijkstra",
          last_interaction_at: ~U[2026-03-13 08:00:00Z]
        },
        %{
          student_id: 13,
          email: "leslie@example.edu",
          given_name: "Leslie",
          family_name: "Lamport",
          last_interaction_at: ~U[2026-03-13 08:00:00Z]
        }
      ]

      projection = Projector.build(progress_rows, student_info_rows, now: now)

      excelling_bucket = Enum.find(projection.buckets, &(&1.id == "excelling"))
      on_track_bucket = Enum.find(projection.buckets, &(&1.id == "on_track"))

      assert Enum.map(excelling_bucket.students, & &1.display_name) == ["Edsger Dijkstra"]
      assert Enum.map(on_track_bucket.students, & &1.display_name) == ["Leslie Lamport"]
    end

    test "struggling requires low or high progress together with low proficiency" do
      now = ~U[2026-03-13 12:00:00Z]

      progress_rows = [
        %{student_id: 40, progress_pct: 50.0, proficiency_pct: 30.0},
        %{student_id: 41, progress_pct: 85.0, proficiency_pct: 30.0},
        %{student_id: 42, progress_pct: 20.0, proficiency_pct: 30.0}
      ]

      student_info_rows = [
        %{
          student_id: 40,
          email: "mid_progress@example.edu",
          given_name: "Mid",
          family_name: "Progress",
          last_interaction_at: ~U[2026-03-13 08:00:00Z]
        },
        %{
          student_id: 41,
          email: "high_progress@example.edu",
          given_name: "High",
          family_name: "Progress",
          last_interaction_at: ~U[2026-03-13 08:00:00Z]
        },
        %{
          student_id: 42,
          email: "low_progress@example.edu",
          given_name: "Low",
          family_name: "Progress",
          last_interaction_at: ~U[2026-03-13 08:00:00Z]
        }
      ]

      projection = Projector.build(progress_rows, student_info_rows, now: now)

      struggling_bucket = Enum.find(projection.buckets, &(&1.id == "struggling"))
      struggling_names = Enum.map(struggling_bucket.students, & &1.display_name)

      refute "Mid Progress" in struggling_names
      assert "High Progress" in struggling_names
      assert "Low Progress" in struggling_names
    end

    test "custom thresholds can move students between buckets" do
      now = ~U[2026-03-13 12:00:00Z]

      progress_rows = [
        %{student_id: 50, progress_pct: 55.0, proficiency_pct: 65.0}
      ]

      student_info_rows = [
        %{
          student_id: 50,
          email: "custom@example.edu",
          given_name: "Custom",
          family_name: "Threshold",
          last_interaction_at: ~U[2026-03-13 08:00:00Z]
        }
      ]

      default_projection = Projector.build(progress_rows, student_info_rows, now: now)

      custom_projection =
        Projector.build(
          progress_rows,
          student_info_rows,
          Keyword.merge(
            [now: now],
            StudentSupportParameters.to_projector_opts(%{
              inactivity_days: 7,
              struggling_progress_low_lt: 35,
              struggling_progress_high_gt: 90,
              struggling_proficiency_lte: 35,
              excelling_progress_gte: 50,
              excelling_proficiency_gte: 60
            })
          )
        )

      assert Enum.find(default_projection.buckets, &(&1.id == "on_track")).count == 1
      assert Enum.find(default_projection.buckets, &(&1.id == "excelling")).count == 0

      assert Enum.find(custom_projection.buckets, &(&1.id == "on_track")).count == 0
      assert Enum.find(custom_projection.buckets, &(&1.id == "excelling")).count == 1
    end

    test "custom inactivity days change active and inactive counts" do
      now = ~U[2026-03-13 12:00:00Z]

      progress_rows = [
        %{student_id: 60, progress_pct: 70.0, proficiency_pct: 75.0}
      ]

      student_info_rows = [
        %{
          student_id: 60,
          email: "activity@example.edu",
          given_name: "Activity",
          family_name: "Window",
          last_interaction_at: ~U[2026-03-03 12:00:00Z]
        }
      ]

      default_projection = Projector.build(progress_rows, student_info_rows, now: now)

      custom_projection =
        Projector.build(progress_rows, student_info_rows, now: now, inactivity_days: 14)

      assert default_projection.totals.active_students == 0
      assert default_projection.totals.inactive_students == 1

      assert custom_projection.totals.active_students == 1
      assert custom_projection.totals.inactive_students == 0
    end

    test "classifies the struggling proficiency boundary inclusively" do
      now = ~U[2026-03-13 12:00:00Z]

      progress_rows = [
        %{student_id: 70, progress_pct: 25.0, proficiency_pct: 40.0}
      ]

      student_info_rows = [
        %{
          student_id: 70,
          email: "boundary@example.edu",
          given_name: "Boundary",
          family_name: "Student",
          last_interaction_at: ~U[2026-03-13 08:00:00Z]
        }
      ]

      projection = Projector.build(progress_rows, student_info_rows, now: now)

      assert Enum.find(projection.buckets, &(&1.id == "struggling")).count == 1
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

    test "normalizes integer 0..1 proficiency ratios before bucket classification" do
      now = ~U[2026-03-13 12:00:00Z]

      progress_rows = [
        %{student_id: 30, progress_pct: 82.0, proficiency_pct: 1},
        %{student_id: 31, progress_pct: 25.0, proficiency_pct: 0}
      ]

      student_info_rows = [
        %{
          student_id: 30,
          email: "barbara@example.edu",
          given_name: "Barbara",
          family_name: "Liskov",
          last_interaction_at: ~U[2026-03-13 08:00:00Z]
        },
        %{
          student_id: 31,
          email: "donald@example.edu",
          given_name: "Donald",
          family_name: "Knuth",
          last_interaction_at: ~U[2026-03-12 08:00:00Z]
        }
      ]

      projection = Projector.build(progress_rows, student_info_rows, now: now)

      assert Enum.find(projection.buckets, &(&1.id == "excelling")).count == 1
      assert Enum.find(projection.buckets, &(&1.id == "struggling")).count == 1

      excelling_bucket = Enum.find(projection.buckets, &(&1.id == "excelling"))
      struggling_bucket = Enum.find(projection.buckets, &(&1.id == "struggling"))

      assert [barbara] = excelling_bucket.students
      assert [donald] = struggling_bucket.students
      assert barbara.proficiency_pct == 100.0
      assert donald.proficiency_pct == 0.0
    end
  end
end
