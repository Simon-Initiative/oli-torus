defmodule Oli.InstructorDashboard.DataSnapshot.Projections.ChallengingObjectivesTest do
  use Oli.DataCase

  import Ecto.Query, warn: false
  import Oli.Factory

  alias Oli.Dashboard.Snapshot.Contract
  alias Oli.InstructorDashboard.DataSnapshot.Projections.ChallengingObjectives
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Resources.ResourceType

  describe "derive/2" do
    test "builds low-proficiency hierarchy rows in curriculum order" do
      %{section: section, unit: unit, parent: parent, child: child} = setup_projection_resources()

      snapshot =
        snapshot_fixture(section.id, unit.resource_id, [
          %{
            objective_id: parent.resource_id,
            title: parent.title,
            proficiency_distribution: %{"Low" => 2, "High" => 1}
          },
          %{
            objective_id: child.resource_id,
            title: child.title,
            proficiency_distribution: %{"Low" => 3}
          }
        ])

      assert {:ok, projection} = ChallengingObjectives.derive(snapshot, [])

      assert projection.state == :populated
      assert projection.has_objectives
      assert projection.scope.selector == "container:#{unit.resource_id}"
      assert projection.scope.label == unit.title
      assert projection.row_count == 2

      assert projection.navigation.view_all == %{
               filter_by: Integer.to_string(unit.resource_id),
               navigation_source: "challenging_objectives_tile"
             }

      assert [
               %{
                 objective_id: parent_id,
                 row_type: :objective,
                 numbering: "1",
                 proficiency_label: "Low",
                 has_children: true,
                 navigation: %{
                   filter_by: filter_by,
                   objective_id: objective_navigation_id,
                   navigation_source: "challenging_objectives_tile"
                 },
                 children: [
                   %{
                     objective_id: child_id,
                     row_type: :subobjective,
                     numbering: "1.1",
                     proficiency_label: "Low",
                     parent_objective_id: child_parent_id,
                     parent_title: child_parent_title
                   }
                 ]
               }
             ] = projection.rows

      assert parent_id == parent.resource_id
      assert filter_by == Integer.to_string(unit.resource_id)
      assert objective_navigation_id == parent.resource_id
      assert child_id == child.resource_id
      assert child_parent_id == parent_id
      assert child_parent_title == parent.title
    end

    test "returns no_data when only not-enough-data distributions are present" do
      %{section: section, unit: unit, parent: parent} = setup_projection_resources()

      snapshot =
        snapshot_fixture(section.id, unit.resource_id, [
          %{
            objective_id: parent.resource_id,
            title: parent.title,
            proficiency_distribution: %{"Not enough data" => 4}
          }
        ])

      assert {:ok, projection} = ChallengingObjectives.derive(snapshot, [])
      assert projection.state == :no_data
      assert projection.has_objectives
      assert projection.rows == []
      assert projection.row_count == 0
    end

    test "treats lowercase proficiency keys as meaningful objective data" do
      %{section: section, unit: unit, parent: parent} = setup_projection_resources()

      snapshot =
        snapshot_fixture(section.id, unit.resource_id, [
          %{
            objective_id: parent.resource_id,
            title: parent.title,
            proficiency_distribution: %{"medium" => 2}
          }
        ])

      assert {:ok, projection} = ChallengingObjectives.derive(snapshot, [])
      assert projection.state == :empty_low_proficiency
      assert projection.rows == []
    end

    test "returns empty_low_proficiency when objective data exists but none is low" do
      %{section: section, unit: unit, parent: parent} = setup_projection_resources()

      snapshot =
        snapshot_fixture(section.id, unit.resource_id, [
          %{
            objective_id: parent.resource_id,
            title: parent.title,
            proficiency_distribution: %{"High" => 2, "Medium" => 1}
          }
        ])

      assert {:ok, projection} = ChallengingObjectives.derive(snapshot, [])
      assert projection.state == :empty_low_proficiency
      assert projection.has_objectives
      assert projection.rows == []
      assert projection.row_count == 0
    end

    test "renders the parent as context when only the child qualifies as low" do
      %{section: section, unit: unit, parent: parent, child: child} = setup_projection_resources()

      snapshot =
        snapshot_fixture(section.id, unit.resource_id, [
          %{
            objective_id: parent.resource_id,
            title: parent.title,
            proficiency_distribution: %{"High" => 2}
          },
          %{
            objective_id: child.resource_id,
            title: child.title,
            proficiency_distribution: %{"Low" => 2}
          }
        ])

      assert {:ok, projection} = ChallengingObjectives.derive(snapshot, [])
      assert projection.state == :populated
      assert projection.has_objectives
      assert projection.row_count == 1

      assert [
               %{
                 objective_id: parent_id,
                 row_type: :objective,
                 numbering: "1",
                 has_children: true,
                 title: parent_title,
                 proficiency_label: parent_proficiency_label,
                 children: [
                   %{
                     objective_id: child_id,
                     row_type: :subobjective,
                     numbering: "1.1",
                     parent_objective_id: child_parent_id,
                     parent_title: child_parent_title,
                     has_children: false,
                     children: [],
                     navigation: %{
                       filter_by: filter_by,
                       objective_id: navigation_objective_id,
                       navigation_source: "challenging_objectives_tile",
                       subobjective_id: navigation_subobjective_id
                     }
                   }
                 ]
               }
             ] = projection.rows

      assert child_id == child.resource_id
      assert parent_id == parent.resource_id
      assert parent_title == parent.title
      assert parent_proficiency_label == "High"
      assert child_parent_id == parent.resource_id
      assert child_parent_title == parent.title
      assert filter_by == Integer.to_string(unit.resource_id)
      assert navigation_objective_id == parent.resource_id
      assert navigation_subobjective_id == child.resource_id
    end

    test "marks scopes with no objectives so the tile can be omitted" do
      %{section: section, unit: unit} = setup_projection_resources()

      snapshot = snapshot_fixture(section.id, unit.resource_id, [])

      assert {:ok, projection} = ChallengingObjectives.derive(snapshot, [])
      assert projection.state == :no_data
      refute projection.has_objectives
      assert projection.rows == []
    end

    test "falls back to revision children when objective section resources do not store hierarchy" do
      %{section: section, unit: unit, parent: parent, child: child} =
        setup_projection_resources(children_on_section_resource?: false)

      snapshot =
        snapshot_fixture(section.id, unit.resource_id, [
          %{
            objective_id: parent.resource_id,
            title: parent.title,
            proficiency_distribution: %{"High" => 2}
          },
          %{
            objective_id: child.resource_id,
            title: child.title,
            proficiency_distribution: %{"Low" => 2}
          }
        ])

      assert {:ok, projection} = ChallengingObjectives.derive(snapshot, [])

      assert [
               %{
                 objective_id: parent_id,
                 has_children: true,
                 children: [%{objective_id: child_id}]
               }
             ] = projection.rows

      assert parent_id == parent.resource_id
      assert child_id == child.resource_id
    end

    test "preserves curriculum numbering from the full objective tree" do
      %{section: section, unit: unit, parent: parent, child: child} =
        setup_projection_resources(extra_root_before?: true)

      snapshot =
        snapshot_fixture(section.id, unit.resource_id, [
          %{
            objective_id: parent.resource_id,
            title: parent.title,
            proficiency_distribution: %{"Low" => 2}
          },
          %{
            objective_id: child.resource_id,
            title: child.title,
            proficiency_distribution: %{"Low" => 2}
          }
        ])

      assert {:ok, projection} = ChallengingObjectives.derive(snapshot, [])

      assert [
               %{
                 objective_id: parent_id,
                 numbering: "2",
                 children: [%{objective_id: child_id, numbering: "2.1"}]
               }
             ] = projection.rows

      assert parent_id == parent.resource_id
      assert child_id == child.resource_id
    end

    test "guards against cycles in objective hierarchy recursion" do
      %{section: section, unit: unit, parent: parent, child: child} = setup_projection_resources()

      from(sr in Oli.Delivery.Sections.SectionResource, where: sr.id == ^child.id)
      |> Repo.update_all(set: [children: [child.resource_id]])

      SectionResourceDepot.update_section_resource(child)

      snapshot =
        snapshot_fixture(section.id, unit.resource_id, [
          %{
            objective_id: parent.resource_id,
            title: parent.title,
            proficiency_distribution: %{"Low" => 2}
          },
          %{
            objective_id: child.resource_id,
            title: child.title,
            proficiency_distribution: %{"Low" => 2}
          }
        ])

      assert {:ok, projection} = ChallengingObjectives.derive(snapshot, [])

      assert [
               %{
                 objective_id: parent_id,
                 children: [%{objective_id: child_id, children: []}]
               }
             ] = projection.rows

      assert parent_id == parent.resource_id
      assert child_id == child.resource_id
    end
  end

  defp setup_projection_resources(opts \\ []) do
    objective_type_id = ResourceType.id_for_objective()
    children_on_section_resource? = Keyword.get(opts, :children_on_section_resource?, true)
    extra_root_before? = Keyword.get(opts, :extra_root_before?, false)

    section = insert(:section)
    project = insert(:project)

    unit_resource = insert(:resource)
    parent_resource = insert(:resource)
    child_resource = insert(:resource)

    parent_revision =
      insert(:revision, resource: parent_resource, resource_type_id: objective_type_id)

    child_revision =
      insert(:revision, resource: child_resource, resource_type_id: objective_type_id)

    unit_revision =
      insert(:revision,
        resource: unit_resource,
        resource_type_id: ResourceType.id_for_container()
      )

    from(r in Oli.Resources.Revision, where: r.id == ^parent_revision.id)
    |> Repo.update_all(set: [children: [child_resource.id]])

    unit =
      insert(:section_resource, %{
        section: section,
        project: project,
        resource_id: unit_resource.id,
        revision_id: unit_revision.id,
        resource_type_id: ResourceType.id_for_container(),
        title: "Unit 1",
        slug: "unit-1",
        numbering_index: 1,
        numbering_level: 1
      })

    parent =
      insert(:section_resource, %{
        section: section,
        project: project,
        resource_id: parent_resource.id,
        revision_id: parent_revision.id,
        resource_type_id: objective_type_id,
        title: "Objective A",
        slug: "objective-a",
        numbering_index: 10,
        numbering_level: 2,
        children: if(children_on_section_resource?, do: [child_resource.id], else: [])
      })

    child =
      insert(:section_resource, %{
        section: section,
        project: project,
        resource_id: child_resource.id,
        revision_id: child_revision.id,
        resource_type_id: objective_type_id,
        title: "Sub Objective A.1",
        slug: "sub-objective-a-1",
        numbering_index: 11,
        numbering_level: 3
      })

    extra_root =
      if extra_root_before? do
        extra_root_resource = insert(:resource)

        extra_root_revision =
          insert(:revision, resource: extra_root_resource, resource_type_id: objective_type_id)

        extra_root =
          insert(:section_resource, %{
            section: section,
            project: project,
            resource_id: extra_root_resource.id,
            revision_id: extra_root_revision.id,
            resource_type_id: objective_type_id,
            title: "Objective Before",
            slug: "objective-before",
            numbering_index: 5,
            numbering_level: 2
          })

        SectionResourceDepot.update_section_resource(extra_root)
        extra_root
      end

    SectionResourceDepot.update_section_resource(unit)
    SectionResourceDepot.update_section_resource(parent)
    SectionResourceDepot.update_section_resource(child)

    %{section: section, unit: unit, parent: parent, child: child, extra_root: extra_root}
  end

  defp snapshot_fixture(section_id, container_id, objective_rows) do
    objective_resources = SectionResourceDepot.objectives_with_effective_children(section_id)

    {:ok, snapshot} =
      Contract.new_snapshot(%{
        request_token: "challenging-objectives-phase-1",
        context: %{
          dashboard_context_type: :section,
          dashboard_context_id: section_id,
          user_id: 99,
          scope: %{container_type: :container, container_id: container_id}
        },
        metadata: %{timezone: "UTC"},
        oracles: %{
          oracle_instructor_scope_resources: %{
            course_title: "Course Title",
            scope_label: "Unit 1",
            items: []
          },
          oracle_instructor_objectives_proficiency: %{
            objective_rows: objective_rows,
            objective_resources: objective_resources
          }
        },
        oracle_statuses: %{
          oracle_instructor_scope_resources: %{status: :ready},
          oracle_instructor_objectives_proficiency: %{status: :ready}
        }
      })

    snapshot
  end
end
