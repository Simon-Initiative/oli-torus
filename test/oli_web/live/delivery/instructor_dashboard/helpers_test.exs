defmodule OliWeb.Delivery.InstructorDashboard.HelpersTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType
  alias OliWeb.Delivery.InstructorDashboard.Helpers

  # Builds a small section with two units, each containing one module and one practice
  # page, using Oli.Factory (the preferred fixture mechanism in this codebase) rather
  # than Oli.Seeder. Module/unit titles are deliberately distinct from any numbered-label
  # format (e.g. "Introduction to Math", not "Module 1") so an assertion against a bare
  # container title can't be misread as an assertion against a numbered label that just
  # happens to look similar.
  defp create_section_with_two_units(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    page_a_revision =
      insert(:revision, resource_type_id: ResourceType.id_for_page(), title: "Page A")

    module_a_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [page_a_revision.resource_id],
        title: "Introduction to Math"
      )

    unit1_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [module_a_revision.resource_id],
        title: "Foundations"
      )

    page_b_revision =
      insert(:revision, resource_type_id: ResourceType.id_for_page(), title: "Page B")

    module_b_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [page_b_revision.resource_id],
        title: "Statistics Basics"
      )

    unit2_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [module_b_revision.resource_id],
        title: "Data Analysis"
      )

    container_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_container(),
        children: [unit1_revision.resource_id, unit2_revision.resource_id],
        title: "Root Container"
      )

    all_revisions = [
      page_a_revision,
      module_a_revision,
      unit1_revision,
      page_b_revision,
      module_b_revision,
      unit2_revision,
      container_revision
    ]

    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, project_id: project.id, resource_id: revision.resource_id)
    end)

    publication =
      insert(:publication, project: project, root_resource_id: container_revision.resource_id)

    Enum.each(all_revisions, fn revision ->
      insert(:published_resource,
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      )
    end)

    section =
      insert(:section,
        base_project: project,
        context_id: UUID.uuid4(),
        open_and_free: true,
        registration_open: true,
        type: :enrollable
      )

    {:ok, section} = Sections.create_section_resources(section, publication)

    [
      section: section,
      unit1_resource: unit1_revision.resource,
      page_a: page_a_revision,
      page_b: page_b_revision
    ]
  end

  describe "get_practice_pages/2 (return_page/3 container labels)" do
    setup [:create_section_with_two_units]

    test "shows suppression-aware container labels when a top-level unit is unnumbered", %{
      section: section,
      unit1_resource: unit1_resource,
      page_a: page_a,
      page_b: page_b
    } do
      {:ok, section} =
        Sections.update_section(section, %{unnumbered_unit_ids: [unit1_resource.id]})

      pages = Helpers.get_practice_pages(section, [])

      page_a_result = Enum.find(pages, &(&1.resource_id == page_a.resource_id))
      page_b_result = Enum.find(pages, &(&1.resource_id == page_b.resource_id))

      # "Introduction to Math" sits inside the suppressed "Foundations" unit, so its
      # pages get a bare title label (the container's own title, no numbering prefix)
      # instead of a numbered label like "Module 1: Introduction to Math".
      refute page_a_result.container_label == "Module 1: Introduction to Math"
      assert page_a_result.container_label == "Introduction to Math"

      # "Statistics Basics" sits inside "Data Analysis" (not suppressed), but
      # "Foundations" being suppressed means "Introduction to Math" never consumes a
      # numbering slot, so "Statistics Basics" is renumbered to "Module 1" instead of
      # showing the raw "Module 2" -- the exact bug from the ticket.
      refute page_b_result.container_label == "Module 2: Statistics Basics"
      assert page_b_result.container_label == "Module 1: Statistics Basics"
    end

    test "matches canonical container labels when no unit is suppressed", %{
      section: section,
      page_a: page_a
    } do
      pages = Helpers.get_practice_pages(section, [])
      page_a_result = Enum.find(pages, &(&1.resource_id == page_a.resource_id))

      assert page_a_result.container_label == "Module 1: Introduction to Math"
    end
  end
end
