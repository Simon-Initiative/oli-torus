defmodule Oli.InstructorDashboard.DataSnapshot.Projections.Progress.ProjectorTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Scope
  alias Oli.InstructorDashboard.DataSnapshot.Projections.Progress.Projector
  alias Oli.Resources.ResourceType

  describe "build/4 and reproject/2" do
    test "uses mixed direct children fallback axis copy and threshold reprojection" do
      {:ok, scope} = Scope.new(%{container_type: :course})

      progress_bins_payload = %{
        total_students: 10,
        by_resource_bins: %{
          101 => %{50 => 4, 100 => 6},
          202 => %{20 => 8, 100 => 2}
        },
        by_container_bins: %{101 => %{50 => 4, 100 => 6}}
      }

      scope_resources_payload = %{
        items: [
          %{
            resource_id: 101,
            resource_type_id: ResourceType.id_for_container(),
            title: "Module 1"
          },
          %{resource_id: 202, resource_type_id: ResourceType.id_for_page(), title: "Page 2"}
        ]
      }

      base_projection = Projector.build(scope, progress_bins_payload, scope_resources_payload)

      projection =
        Projector.reproject(base_projection, %{
          completion_threshold: 100,
          y_axis_mode: :count,
          page: 1
        })

      assert projection.axis_label == "Course Content"
      assert projection.class_size == 10
      assert Enum.map(projection.series, & &1.label) == ["Module 1", "Page 2"]
      assert Enum.map(projection.series, & &1.count) == [6, 2]
    end

    test "maps course scope container children to course units and paginates percent mode" do
      {:ok, scope} = Scope.new(%{container_type: :course})

      progress_bins_payload = %{
        total_students: 10,
        by_container_bins:
          Enum.into(1..8, %{}, fn resource_id ->
            {resource_id, %{100 => resource_id}}
          end)
      }

      scope_resources_payload = %{
        items:
          Enum.map(1..8, fn resource_id ->
            %{
              resource_id: resource_id,
              resource_type_id: ResourceType.id_for_container(),
              title: "Unit #{resource_id}"
            }
          end)
      }

      base_projection = Projector.build(scope, progress_bins_payload, scope_resources_payload)

      projection =
        Projector.reproject(base_projection, %{
          completion_threshold: 100,
          y_axis_mode: :percent,
          page: 2
        })

      assert projection.axis_label == "Course Units"
      assert projection.page_window.page == 2
      assert projection.page_window.total_pages == 2
      assert Enum.map(projection.series, & &1.label) == ["Unit 8"]
      assert hd(projection.series).value == 80.0
    end
  end
end
