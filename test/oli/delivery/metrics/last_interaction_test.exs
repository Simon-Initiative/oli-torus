defmodule Oli.Delivery.Metrics.LastInteractionTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Resources.ResourceType

  defp set_interaction(section, resource, user, timestamp) do
    insert(:resource_access, %{
      section: section,
      resource: resource,
      user: user,
      inserted_at: timestamp,
      updated_at: timestamp
    })
  end

  defp create_project(_conn) do
    author = insert(:author)
    project = insert(:project, %{authors: [author]})

    # revisions...
    page_1_revision = insert(:revision, %{resource_type_id: ResourceType.id_for_page()})

    page_2_revision = insert(:revision, %{resource_type_id: ResourceType.id_for_page()})

    unit_1_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_container(),
        children: [page_1_revision.resource_id],
        title: "Unit 1"
      })

    unit_2_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_container(),
        children: [page_2_revision.resource_id],
        title: "Unit 2"
      })

    container_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.id_for_container(),
        children: [unit_1_revision.resource_id, unit_2_revision.resource_id],
        title: "Root Container"
      })

    # asociate resources to project
    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: page_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unit_1_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: unit_2_revision.resource_id
    })

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: container_revision.resource_id
    })

    # publish project and resources
    publication =
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

    insert(:published_resource, %{
      publication: publication,
      resource: page_1_revision.resource,
      revision: page_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_2_revision.resource,
      revision: page_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_1_revision.resource,
      revision: unit_1_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: unit_2_revision.resource,
      revision: unit_2_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: container_revision.resource,
      revision: container_revision,
      author: author
    })

    # create section...
    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)

    # enroll students...
    [student_1, student_2] = insert_pair(:user)

    Sections.enroll(student_1.id, section.id, [ContextRoles.get_role(:context_learner)])

    {:ok, %{updated_at: student_2_enrollment_timestamp}} =
      Sections.enroll(student_2.id, section.id, [ContextRoles.get_role(:context_learner)])

    %{
      section: section,
      student_1: student_1,
      student_2: student_2,
      student_2_enrollment_timestamp: student_2_enrollment_timestamp,
      page_1: page_1_revision,
      page_2: page_2_revision,
      unit_1: unit_1_revision
    }
  end

  describe "last_interaction calculations" do
    setup [:create_project]

    test "students_last_interaction_across/1 calculates correctly across all course section", %{
      section: section,
      student_1: student_1,
      student_2: student_2,
      student_2_enrollment_timestamp: student_2_enrollment_timestamp,
      page_1: page_1,
      page_2: page_2
    } do
      set_interaction(section, page_1.resource, student_1, ~U[2023-04-03 12:25:42.000000Z])
      set_interaction(section, page_2.resource, student_1, ~U[2023-04-05 12:25:42.000000Z])

      last_interactions = Metrics.students_last_interaction_across(section)

      assert last_interactions[student_1.id] == ~U[2023-04-05 12:25:42.000000Z]

      assert last_interactions[student_2.id] |> DateTime.truncate(:second) ==
               student_2_enrollment_timestamp
    end

    test "students_last_interaction_across/1 calculates correctly across a particular container",
         %{
           section: section,
           student_1: student_1,
           student_2: student_2,
           student_2_enrollment_timestamp: student_2_enrollment_timestamp,
           page_1: page_1,
           page_2: page_2,
           unit_1: unit_1
         } do
      set_interaction(section, page_1.resource, student_1, ~U[2023-04-03 12:25:42.000000Z])
      set_interaction(section, page_2.resource, student_1, ~U[2023-04-05 12:25:42.000000Z])

      last_interactions = Metrics.students_last_interaction_across(section, unit_1.resource_id)

      assert last_interactions[student_1.id] == ~U[2023-04-03 12:25:42.000000Z]

      assert last_interactions[student_2.id] |> DateTime.truncate(:second) ==
               student_2_enrollment_timestamp
    end

    test "students_last_interaction_for_page/2 calculates correctly", %{
      section: section,
      student_1: student_1,
      student_2: student_2,
      student_2_enrollment_timestamp: student_2_enrollment_timestamp,
      page_1: page_1,
      page_2: page_2
    } do
      set_interaction(section, page_1.resource, student_1, ~U[2023-04-03 12:25:42.000000Z])
      set_interaction(section, page_2.resource, student_1, ~U[2023-04-04 12:25:42.000000Z])

      last_interactions_for_page =
        Metrics.students_last_interaction_for_page(section.slug, page_1.resource_id)

      assert last_interactions_for_page[student_1.id] == ~U[2023-04-03 12:25:42.000000Z]

      assert last_interactions_for_page[student_2.id] |> DateTime.truncate(:second) ==
               student_2_enrollment_timestamp
    end
  end
end
