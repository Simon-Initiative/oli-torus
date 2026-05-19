defmodule Oli.InstructorDashboard.Prototype.Tiles.Progress.DataTest do
  use ExUnit.Case, async: true

  alias Oli.InstructorDashboard.Prototype.MockData
  alias Oli.InstructorDashboard.Prototype.Scope
  alias Oli.InstructorDashboard.Prototype.Snapshot
  alias Oli.InstructorDashboard.Prototype.Tiles.Progress
  alias Oli.InstructorDashboard.Prototype.Tiles.Progress.Data

  describe "build/1" do
    test "uses 100 as the default completion threshold when scope filters omit it" do
      scope = Scope.new(%{container_type: :course})

      assert {:ok, projection} = build_snapshot(scope)
      assert projection.completion_threshold == 100
    end

    test "projects direct mixed children for a unit scope and falls back axis label to course content" do
      scope =
        Scope.new(%{
          container_type: :unit,
          container_id: 1,
          filters: %{completion_threshold: 80}
        })

      assert {:ok, projection} = build_snapshot(scope)

      assert projection.axis_label == "Course Content"
      assert projection.class_size == length(MockData.student_ids())
      assert projection.completion_threshold == 80
      assert projection.y_axis_mode == :count
      assert projection.page_window.page == 1
      assert projection.page_window.total_items == 3
      assert projection.page_window.total_pages == 1
      assert projection.schedule_marker == %{present?: false}
      assert is_nil(projection.empty_state)

      assert Enum.map(projection.series, & &1.resource_type) == [:module, :page, :module]
      assert Enum.map(projection.series, & &1.label) == ["Module 1A", "Intro Page", "Module 1B"]

      intro_page = Enum.find(projection.series, &(&1.label == "Intro Page"))
      assert intro_page.value == intro_page.count
      assert intro_page.total == projection.class_size
      assert intro_page.percent == 20.0
    end

    test "projects homogeneous unit children for the course scope" do
      scope =
        Scope.new(%{
          container_type: :course,
          filters: %{completion_threshold: 80}
        })

      assert {:ok, projection} = build_snapshot(scope)

      assert projection.axis_label == "Course Units"
      assert Enum.all?(projection.series, &(&1.resource_type == :unit))
      assert Enum.map(projection.series, & &1.label) == Enum.map(MockData.units(), & &1.title)
    end

    test "supports page scope using direct children of a module" do
      scope =
        Scope.new(%{
          container_type: :module,
          container_id: 101,
          filters: %{completion_threshold: 80}
        })

      assert {:ok, projection} = build_snapshot(scope)

      assert projection.axis_label == "Course Pages"
      assert Enum.map(projection.series, & &1.resource_type) == [:page, :page]
      assert Enum.map(projection.series, & &1.label) == ["Practice Page", "Quiz Page"]
    end

    test "uses threshold to derive count and percent values" do
      scope =
        Scope.new(%{
          container_type: :unit,
          container_id: 1,
          filters: %{completion_threshold: 50}
        })

      assert {:ok, projection} = build_snapshot(scope)

      module_1a = Enum.find(projection.series, &(&1.container_id == 101))
      assert module_1a.count == 4
      assert module_1a.percent == 40.0
      assert module_1a.value == 4
    end

    test "returns empty state when direct children are unavailable" do
      scope =
        Scope.new(%{
          container_type: :module,
          container_id: 999_999,
          filters: %{completion_threshold: 80}
        })

      assert {:ok, projection} = build_snapshot(scope)

      assert projection.axis_label == "Course Content"
      assert projection.series == []
      assert projection.empty_state == %{type: :no_scope_children}
      assert projection.page_window.total_items == 0
      assert projection.page_window.total_pages == 0
    end
  end

  describe "reproject/2" do
    test "switches to percent mode and paginates projected results" do
      scope =
        Scope.new(%{
          container_type: :course,
          filters: %{completion_threshold: 80}
        })

      {:ok, base_projection} = Data.build(base_snapshot(scope))

      reprojected =
        Data.reproject(base_projection, %{
          y_axis_mode: :percent,
          completion_threshold: 80,
          page: 2,
          per_page: 2
        })

      assert reprojected.y_axis_mode == :percent
      assert reprojected.page_window.page == 2
      assert reprojected.page_window.per_page == 2
      assert reprojected.page_window.total_pages == 3
      assert length(reprojected.series) == 2
      assert Enum.all?(reprojected.series, &(&1.value == &1.percent))
    end

    test "exposes schedule marker metadata when complete schedule context is present" do
      scope =
        Scope.new(%{
          container_type: :course,
          filters: %{completion_threshold: 80}
        })

      snapshot =
        base_snapshot(scope, %{
          schedule: %{
            current_resource_id: 3,
            label: "Unit 3",
            tooltip: "Schedule is currently at Unit 3"
          }
        })

      assert {:ok, projection} = Data.build(snapshot)

      assert projection.schedule_marker == %{
               present?: true,
               container_id: 3,
               label: "Unit 3",
               tooltip: "Schedule is currently at Unit 3",
               page: 1,
               visible?: true
             }
    end

    test "falls back to no schedule marker when schedule payload is incomplete" do
      scope =
        Scope.new(%{
          container_type: :course,
          filters: %{completion_threshold: 80}
        })

      snapshot =
        base_snapshot(scope, %{
          schedule: %{
            current_resource_id: 3
          }
        })

      assert {:ok, projection} = Data.build(snapshot)
      assert projection.schedule_marker == %{present?: false}
    end

    test "computes schedule marker page and visibility from paginated series" do
      scope =
        Scope.new(%{
          container_type: :course,
          filters: %{completion_threshold: 80}
        })

      snapshot =
        base_snapshot(scope, %{
          schedule: %{
            current_resource_id: 5,
            label: "Unit 5",
            tooltip: "Schedule is currently at Unit 5"
          }
        })

      {:ok, base_projection} = Data.build(snapshot)

      reprojected =
        Data.reproject(base_projection, %{
          y_axis_mode: :count,
          completion_threshold: 80,
          page: 1,
          per_page: 2
        })

      assert reprojected.schedule_marker == %{
               present?: true,
               container_id: 5,
               label: "Unit 5",
               tooltip: "Schedule is currently at Unit 5",
               page: 3,
               visible?: false
             }
    end

    test "returns no-students empty state when the scope has children but no learners" do
      scope =
        Scope.new(%{
          container_type: :course,
          filters: %{completion_threshold: 80}
        })

      snapshot =
        %Snapshot{
          scope: scope,
          oracle_payloads: %{
            progress: %{by_container: %{unit: %{}}, by_student: %{}, student_ids: []},
            contents:
              Oli.InstructorDashboard.Prototype.Oracles.Contents.load(scope, []) |> elem(1)
          },
          oracle_statuses: %{},
          projections: %{},
          projection_statuses: %{}
        }

      assert {:ok, projection} = Data.build(snapshot)
      assert projection.empty_state == %{type: :no_students}
      assert Enum.all?(projection.series, &(&1.percent == 0.0))
    end
  end

  defp build_snapshot(scope, extra_oracles \\ %{}) do
    snapshot = base_snapshot(scope, extra_oracles)
    Progress.project(snapshot)
  end

  defp base_snapshot(scope, extra_oracles \\ %{}) do
    oracle_payloads =
      %{
        progress: Oli.InstructorDashboard.Prototype.Oracles.Progress.load(scope, []) |> elem(1),
        contents: Oli.InstructorDashboard.Prototype.Oracles.Contents.load(scope, []) |> elem(1)
      }
      |> Map.merge(extra_oracles)

    %Snapshot{
      scope: scope,
      oracle_payloads: oracle_payloads,
      oracle_statuses: %{},
      projections: %{},
      projection_statuses: %{}
    }
  end
end
