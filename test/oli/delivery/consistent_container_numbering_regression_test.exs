defmodule Oli.Delivery.ConsistentContainerNumberingRegressionTest do
  @moduledoc """
  Phase 8 closeout for MER-5871: a single shared "suppressed top-level unit" section
  fixture, checked against every independent code path that ended up consuming
  `Oli.Delivery.Sections.decorated_numbering_map/1` (directly or through one of its
  overlay helpers) or the decorated hierarchy it's built from, across Phases 1-7. Each
  phase already has its own focused tests proving its own surface renders correctly in
  isolation; this test's job is different -- it proves those independent surfaces don't
  quietly drift apart from each other over time, by checking they all report the exact
  same suppression-aware number for the exact same containers, from one shared fixture,
  in one test run.
  """

  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.DisplayLabels
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Resources.Numbering
  alias Oli.Resources.ResourceType

  setup do
    author = insert(:author)
    project = insert(:project, authors: [author])

    page_a_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        title: "Foundations Assessment",
        graded: true
      )

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
      insert(:revision, resource_type_id: ResourceType.id_for_page(), title: "Stats Reading")

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

    {:ok, section} =
      Sections.update_section(section, %{unnumbered_unit_ids: [unit1_revision.resource_id]})

    {:ok, _} = Sections.rebuild_contained_pages(section)

    [
      section: section,
      unit1_id: unit1_revision.resource_id,
      unit2_id: unit2_revision.resource_id,
      module_a_id: module_a_revision.resource_id,
      module_b_id: module_b_revision.resource_id,
      page_a_id: page_a_revision.resource_id
    ]
  end

  test "decorated_numbering_map/1 (Learn; the shared primitive every other surface below is built on)",
       %{section: section, unit1_id: unit1_id, unit2_id: unit2_id, module_b_id: module_b_id} do
    numbering_map = Sections.decorated_numbering_map(section)

    refute Map.has_key?(numbering_map, unit1_id)
    assert numbering_map[unit2_id] == %Numbering{level: 1, index: 1}
    assert numbering_map[module_b_id] == %Numbering{level: 2, index: 1}
  end

  test "DisplayLabels.effective_numbering/1 on the decorated hierarchy (Group C: ScopeResources, Student Progress breadcrumbs, Instructor Preview / Lesson TOC)",
       %{section: section, unit1_id: unit1_id, unit2_id: unit2_id} do
    hierarchy = SectionResourceDepot.get_delivery_resolver_full_hierarchy(section)
    nodes_by_resource_id = Map.new(Hierarchy.flatten_hierarchy(hierarchy), &{&1.resource_id, &1})

    assert DisplayLabels.effective_numbering(nodes_by_resource_id[unit1_id]) == nil

    assert DisplayLabels.effective_numbering(nodes_by_resource_id[unit2_id]) == %Numbering{
             level: 1,
             index: 1
           }
  end

  test "get_parent_containers_map/2 (Group A: Assessment Settings, Student Exceptions, Grade Sync)",
       %{section: section, page_a_id: page_a_id} do
    parent_map = Sections.get_parent_containers_map(section, [page_a_id])

    # Foundations Assessment's parent, "Foundations", is suppressed -- absent from the
    # map, same as "no parent container" everywhere else in this feature.
    refute Map.has_key?(parent_map, page_a_id)
  end

  test "get_units_and_modules_containers/1 (Group B: Instructor Dashboard Content 'Order' column)",
       %{section: section, unit1_id: unit1_id, unit2_id: unit2_id} do
    {_count, containers} = Sections.get_units_and_modules_containers(section)

    unit1 = Enum.find(containers, &(&1.id == unit1_id))
    unit2 = Enum.find(containers, &(&1.id == unit2_id))

    assert unit1.numbering_index == nil
    assert unit2.numbering_index == 1
  end

  test "overlay_suppression_aware_numbering/2 (Group B: container navigators, Course Content, AI Dialogue context)",
       %{section: section, unit1_id: unit1_id, unit2_id: unit2_id} do
    containers =
      SectionResourceDepot.containers(section.id, numbering_level: {:in, [1, 2]})
      |> Sections.overlay_suppression_aware_numbering(section)

    unit1 = Enum.find(containers, &(&1.resource_id == unit1_id))
    unit2 = Enum.find(containers, &(&1.resource_id == unit2_id))

    assert unit1.numbering_index == nil
    assert unit2.numbering_index == 1
  end

  test "Hierarchy.build_navigation_link_map/1 (previous_next_index / legacy Course Content)",
       %{section: section, unit1_id: unit1_id, unit2_id: unit2_id} do
    hierarchy = SectionResourceDepot.get_delivery_resolver_full_hierarchy(section)
    link_map = Hierarchy.build_navigation_link_map(hierarchy)

    unit1_entry = Map.get(link_map, Integer.to_string(unit1_id))
    unit2_entry = Map.get(link_map, Integer.to_string(unit2_id))

    assert unit1_entry["display_numbering"] == nil
    assert unit2_entry["display_numbering"] == %{"level" => "1", "index" => "1"}
  end
end
