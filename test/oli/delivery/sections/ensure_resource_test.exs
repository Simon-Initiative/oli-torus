defmodule Oli.Delivery.Sections.SectionResourceDepotTest do
  use Oli.DataCase

  import Ecto.Query
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.Updates
  alias Oli.Resources.ResourceType

  describe "ensure resource exists" do
    setup [:create_project]

    test "gets hierarchy and triggers Depot", ctx do
      %{
        section: %{id: section_id} = section,
        page_1_revision: page_1_revision
      } = ctx

      # Verify that when the resource exists, it doesn't get created again
      {:ok, :exists} =
        Updates.ensure_section_resource_exists(section.slug, page_1_revision.resource_id)

      # simulate a missing SR by deleting it
      Oli.Repo.delete_all(
        from(sr in SectionResource,
          where: sr.section_id == ^section_id and sr.resource_id == ^page_1_revision.resource_id
        )
      )

      # Ensure the resource gets created
      {:ok, count_created} =
        Updates.ensure_section_resource_exists(section.slug, page_1_revision.resource_id)

      assert count_created == 1
    end
  end

  defp create_project(_) do
    # Revisions tree
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Page 1"
      )

    # Graded page
    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Page 2",
        graded: true
      )

    module_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        title: "Module 1"
      )

    # Root container
    container_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        title: "Root Container",
        children: [module_1_revision.resource_id]
      )

    instructor = insert(:user)
    project = insert(:project, authors: [instructor.author])

    all_revisions = [container_revision, module_1_revision, page_1_revision, page_2_revision]

    # Asociate resources to project
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
    section = insert(:section, base_project: project, title: "The Project")

    # Create section-resources
    {:ok, section} = Sections.create_section_resources(section, publication)

    %{
      section: section,
      container_revision: container_revision,
      module_1_revision: module_1_revision,
      page_1_revision: page_1_revision,
      page_2_revision: page_2_revision
    }
  end
end
