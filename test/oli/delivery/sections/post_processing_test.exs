defmodule Oli.Delivery.Sections.PostProcessingTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.PostProcessing
  alias Oli.Resources.ResourceType
  alias Oli.Repo

  describe "apply/2 with :related_activities" do
    setup [:create_section_with_related_activities]

    test "populates related_activities field for objectives based on activity objectives mapping",
         %{
           section: section,
           objective_1: objective_1,
           objective_2: objective_2,
           activity_1: activity_1,
           activity_2: activity_2,
           activity_3: _activity_3
         } do
      # Verify initial state - related_activities should be empty
      objective_1_sr = Sections.get_section_resource(section.id, objective_1.resource_id)
      objective_2_sr = Sections.get_section_resource(section.id, objective_2.resource_id)

      assert objective_1_sr.related_activities == []
      assert objective_2_sr.related_activities == []

      # Apply post processing with related_activities
      PostProcessing.apply(section, [:related_activities])

      # Reload section resources to get updated related_activities
      objective_1_sr = Repo.reload(objective_1_sr)
      objective_2_sr = Repo.reload(objective_2_sr)

      # Objective 1 should be related to activities 1 and 2
      assert length(objective_1_sr.related_activities) == 2

      assert Enum.sort(objective_1_sr.related_activities) ==
               Enum.sort([activity_1.resource_id, activity_2.resource_id])

      # Objective 2 should be related to activity 2 only
      assert objective_2_sr.related_activities == [activity_2.resource_id]
    end

    test "handles objectives with no related activities", %{
      section: section,
      objective_3: objective_3
    } do
      # Apply post processing with related_activities
      PostProcessing.apply(section, [:related_activities])

      # Reload section resource to get updated related_activities
      objective_3_sr = Sections.get_section_resource(section.id, objective_3.resource_id)

      # Objective 3 should have no related activities (activity 3 has no objectives)
      assert objective_3_sr.related_activities == []
    end

    test "handles activities with malformed objectives field", %{
      section: section,
      objective_1: objective_1,
      activity_4: activity_4
    } do
      # Apply post processing with related_activities
      PostProcessing.apply(section, [:related_activities])

      # Reload section resource to get updated related_activities
      objective_1_sr = Sections.get_section_resource(section.id, objective_1.resource_id)

      # Should not include activity_4 since its objectives field is malformed (nil objectives array)
      refute activity_4.resource_id in objective_1_sr.related_activities
    end

    test "applies multiple post processing actions including related_activities", %{
      section: section,
      objective_1: objective_1
    } do
      # Apply multiple actions including related_activities
      result_section = PostProcessing.apply(section, [:discussions, :related_activities])

      # Should return the section (no change to section itself)
      assert result_section.id == section.id

      # Related activities should still be populated
      objective_1_sr = Sections.get_section_resource(section.id, objective_1.resource_id)
      assert length(objective_1_sr.related_activities) > 0
    end
  end

  defp create_section_with_related_activities(_) do
    # Create objectives
    objective_1 =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 1"
      )

    objective_2 =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 2"
      )

    objective_3 =
      insert(:revision,
        resource_type_id: ResourceType.id_for_objective(),
        title: "Objective 3"
      )

    # Create activities with different objective mappings
    activity_1 =
      insert(:revision,
        resource_type_id: ResourceType.id_for_activity(),
        title: "Activity 1",
        objectives: %{
          "1" => [objective_1.resource_id]
        }
      )

    activity_2 =
      insert(:revision,
        resource_type_id: ResourceType.id_for_activity(),
        title: "Activity 2",
        objectives: %{
          "1" => [objective_1.resource_id, objective_2.resource_id]
        }
      )

    # Activity 3 has no objectives
    activity_3 =
      insert(:revision,
        resource_type_id: ResourceType.id_for_activity(),
        title: "Activity 3",
        objectives: %{}
      )

    # Activity 4 has malformed objectives (nil array)
    activity_4 =
      insert(:revision,
        resource_type_id: ResourceType.id_for_activity(),
        title: "Activity 4",
        objectives: %{
          "1" => nil
        }
      )

    # Create a page that contains the activities (activities are embedded, not children)
    page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Page with Activities"
      )

    # Root container
    container_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        title: "Root Container",
        children: [page_revision.resource_id]
      )

    instructor = insert(:user)
    project = insert(:project, authors: [instructor.author])

    all_revisions = [
      container_revision,
      page_revision,
      objective_1,
      objective_2,
      objective_3,
      activity_1,
      activity_2,
      activity_3,
      activity_4
    ]

    # Associate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # Publish project
    publication =
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

    # Publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: instructor.author
      })
    end)

    # Create section
    section = insert(:section, base_project: project, title: "Test Section")

    # Create section-resources
    {:ok, section} = Sections.create_section_resources(section, publication)

    %{
      section: section,
      objective_1: objective_1,
      objective_2: objective_2,
      objective_3: objective_3,
      activity_1: activity_1,
      activity_2: activity_2,
      activity_3: activity_3,
      activity_4: activity_4,
      page_revision: page_revision,
      container_revision: container_revision
    }
  end
end
