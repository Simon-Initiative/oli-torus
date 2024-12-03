defmodule Oli.Delivery.Sections.SectionResourceDepotTest do
  use Oli.DataCase

  import Ecto.Query
  import Oli.Factory

  alias Oli.Delivery.Depot
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.Numbering
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Resources.ResourceType

  @depot_desc SectionResourceDepot.depot_desc()

  describe "get_full_hierarchy/2" do
    setup [:create_project]

    test "gets hierarchy and triggers Depot", ctx do
      %{
        section: %{id: section_id} = section,
        container_revision: container_revision,
        module_1_revision: module_1_revision,
        page_1_revision: page_1_revision,
        page_2_revision: page_2_revision
      } = ctx

      container_revision_id = container_revision.id
      module_1_revision_id = module_1_revision.id
      page_1_revision_id = page_1_revision.id
      page_2_revision_id = page_2_revision.id

      assert %{
               "id" => ^container_revision_id,
               "is_root?" => true,
               "numbering" => %{"index" => 1, "level" => 0},
               "children" => [
                 %{
                   "id" => ^module_1_revision_id,
                   "is_root?" => false,
                   "numbering" => %{"index" => 1, "level" => 1},
                   "children" => [
                     %{
                       "id" => ^page_1_revision_id,
                       "is_root?" => false,
                       "numbering" => %{"index" => 1, "level" => 2},
                       "children" => []
                     },
                     %{
                       "id" => ^page_2_revision_id,
                       "is_root?" => false,
                       "numbering" => %{"index" => 2, "level" => 2},
                       "children" => []
                     }
                   ]
                 }
               ]
             } =
               SectionResourceDepot.get_full_hierarchy(section)

      # Test Depot
      test_depot(section_id)
    end
  end

  describe "get_delivery_resolver_full_hierarchy/1" do
    setup [:create_project]

    test "retrieves the full hierarchy of section resources for a given section", ctx do
      %{
        section: %{id: section_id} = section,
        container_revision: container_revision,
        module_1_revision: module_1_revision,
        page_1_revision: page_1_revision,
        page_2_revision: page_2_revision
      } = ctx

      container_revision_id = container_revision.id
      module_1_revision_id = module_1_revision.id
      page_1_revision_id = page_1_revision.id
      page_2_revision_id = page_2_revision.id

      revision_ids =
        [container_revision_id, module_1_revision_id, page_1_revision_id, page_2_revision_id]

      [container_sr_id, module_1_sr_id, page_1_sr_id, page_2_sr_id] =
        from(sr in SectionResource,
          join: r in Oli.Resources.Revision,
          on: r.resource_id == sr.resource_id,
          where: r.id in ^revision_ids,
          select: {r.id, sr.id}
        )
        |> Repo.all()
        |> Enum.reduce([nil, nil, nil, nil], fn {r_id, sr_id}, acc ->
          index = Enum.find_index(revision_ids, fn revision_id -> revision_id == r_id end)
          List.replace_at(acc, index, sr_id)
        end)

      assert %HierarchyNode{
               numbering: %Numbering{level: 0, index: 1},
               section_resource: %SectionResource{id: ^container_sr_id},
               children: [
                 %HierarchyNode{
                   numbering: %Numbering{level: 1, index: 1},
                   section_resource: %SectionResource{id: ^module_1_sr_id},
                   children: [
                     %HierarchyNode{
                       numbering: %Numbering{level: 2, index: 1},
                       children: [],
                       section_resource: %SectionResource{id: ^page_1_sr_id}
                     },
                     %HierarchyNode{
                       numbering: %Numbering{level: 2, index: 2},
                       children: [],
                       section_resource: %SectionResource{id: ^page_2_sr_id}
                     }
                   ]
                 }
               ]
             } =
               SectionResourceDepot.get_delivery_resolver_full_hierarchy(section)

      # Test Depot
      test_depot(section_id)
    end
  end

  describe "graded_pages/2" do
    setup [:create_project]

    test "returns a list of SectionResource records for all graded pages for a given section",
         ctx do
      %{
        section: %{id: section_id} = _section,
        page_2_revision: page_2_revision
      } = ctx

      graded_page_resource_id = page_2_revision.resource_id

      graded_page_sr_id =
        from(sr in SectionResource,
          where: sr.resource_id == ^graded_page_resource_id,
          select: sr.id
        )
        |> Repo.one()

      assert [%Oli.Delivery.Sections.SectionResource{id: ^graded_page_sr_id}] =
               SectionResourceDepot.graded_pages(section_id)

      # Test Depot
      test_depot(section_id)
    end
  end

  describe "retrieve_schedule/2" do
    setup [:create_project]

    test "access the SectionResource records pertaining to the course schedule for pages", ctx do
      %{
        section: %{id: section_id} = _section,
        page_1_revision: page_1_revision,
        page_2_revision: page_2_revision
      } = ctx

      revision_ids = [page_1_revision.id, page_2_revision.id]
      page_sr_ids = get_section_resource_ids(revision_ids)

      assert [%SectionResource{id: sr_1}, %SectionResource{id: sr_2}] =
               SectionResourceDepot.retrieve_schedule(section_id, :pages)

      assert Enum.all?([sr_1, sr_2], &(&1 in page_sr_ids))

      # Test Depot
      test_depot(section_id)
    end

    test "access the SectionResource records pertaining to the course schedule for containers",
         ctx do
      %{
        section: %{id: section_id} = _section,
        container_revision: container_revision,
        module_1_revision: module_1_revision
      } = ctx

      revision_ids = [container_revision.id, module_1_revision.id]
      container_sr_ids = get_section_resource_ids(revision_ids)

      assert [%SectionResource{id: sr_1}, %SectionResource{id: sr_2}] =
               SectionResourceDepot.retrieve_schedule(section_id, :containers)

      assert Enum.all?([sr_1, sr_2], &(&1 in container_sr_ids))

      # Test Depot
      test_depot(section_id)
    end
  end

  describe "get_lessons/2" do
    setup [:create_project]

    test "returns a list of SectionResource pages (graded + ungraded)", ctx do
      %{
        section: %{id: section_id} = _section,
        page_1_revision: page_1_revision,
        page_2_revision: page_2_revision
      } = ctx

      revision_ids = [page_1_revision.id, page_2_revision.id]
      page_sr_ids = get_section_resource_ids(revision_ids)

      assert [%SectionResource{id: sr_1}, %SectionResource{id: sr_2}] =
               SectionResourceDepot.get_lessons(section_id)

      assert Enum.all?([sr_1, sr_2], &(&1 in page_sr_ids))

      # Test Depot
      test_depot(section_id)
    end

    test "returns a list of SectionResource pages only graded", ctx do
      %{
        section: %{id: section_id} = _section,
        page_1_revision: page_1_revision,
        page_2_revision: page_2_revision
      } = ctx

      revision_ids = [page_1_revision.id, page_2_revision.id]
      page_sr_ids = get_section_resource_ids(revision_ids)

      assert [%SectionResource{id: sr_graded_page}] =
               SectionResourceDepot.get_lessons(section_id, true)

      assert Enum.all?([sr_graded_page], &(&1 in page_sr_ids))

      # Test Depot
      test_depot(section_id)
    end
  end

  describe "get_section_resources_by_type_ids/2" do
    setup [:create_project]

    test "returns a list of SectionResource record filter type ids", ctx do
      %{section: %{id: section_id} = _section} = ctx

      page_type_id = Oli.Resources.ResourceType.id_for_page()
      container_type_id = Oli.Resources.ResourceType.id_for_container()

      assert SectionResourceDepot.get_section_resources_by_type_ids(
               section_id,
               [page_type_id]
             )
             |> Enum.count() == 2

      assert SectionResourceDepot.get_section_resources_by_type_ids(
               section_id,
               [container_type_id]
             )
             |> Enum.count() == 2

      assert SectionResourceDepot.get_section_resources_by_type_ids(
               section_id,
               [page_type_id, container_type_id]
             )
             |> Enum.count() == 4
    end
  end

  describe "fetch_recently_active_sections/0" do
    setup [
      :remove_depot_warmer_days_lookback_env_on_exit,
      :setup_for_fetch_recently_active_sections
    ]

    test "checks days_back", ctx do
      %{section_1_id: section_1_id, section_2_id: section_2_id, section_3_id: section_3_id} = ctx
      setup_depot_warmer_days_lookback_env("5")
      setup_depot_warmer_max_number_of_entries_env("10")

      active_sections = SectionResourceDepot.fetch_recently_active_sections()

      assert length(active_sections) == 2
      assert Enum.all?(active_sections, fn ac -> ac in [section_1_id, section_2_id] end)
      assert section_3_id not in active_sections
    end

    test "checks when max_entries is equal to 0" do
      setup_depot_warmer_days_lookback_env("5")
      setup_depot_warmer_max_number_of_entries_env("0")

      active_sections = SectionResourceDepot.fetch_recently_active_sections()

      assert length(active_sections) == 0
    end

    test "checks limit is apply when max_entries is defined", ctx do
      %{section_1_id: section_1_id} = ctx
      setup_depot_warmer_days_lookback_env("5")
      setup_depot_warmer_max_number_of_entries_env("1")

      assert [^section_1_id] = SectionResourceDepot.fetch_recently_active_sections()
    end
  end

  defp setup_depot_warmer_max_number_of_entries_env(max_entries) do
    Application.put_env(:oli, :depot_warmer_max_number_of_entries, max_entries)
  end

  defp setup_depot_warmer_days_lookback_env(days) do
    Application.put_env(:oli, :depot_warmer_days_lookback, days)
  end

  defp remove_depot_warmer_days_lookback_env_on_exit(_) do
    on_exit(fn -> Application.put_env(:oli, :depot_warmer_days_lookback, nil) end)
    on_exit(fn -> Application.put_env(:oli, :depot_warmer_max_number_of_entries, nil) end)
  end

  defp setup_for_fetch_recently_active_sections(_) do
    now = DateTime.utc_now()
    yesterday = DateTime.add(now, -1, :day)
    six_days_ago = DateTime.add(now, -6, :day)

    %{id: section_1_id} = section_1 = insert(:section)
    %{id: section_2_id} = section_2 = insert(:section)
    %{id: section_3_id} = section_3 = insert(:section)

    page_type_id = Oli.Resources.ResourceType.id_for_page()

    insert(:section_resource, section: section_1, resource_type_id: page_type_id)
    insert(:section_resource, section: section_2, resource_type_id: page_type_id)
    insert(:section_resource, section: section_3, resource_type_id: page_type_id)

    insert(:resource_access, section: section_1, updated_at: now)
    insert(:resource_access, section: section_2, updated_at: yesterday)
    insert(:resource_access, section: section_3, updated_at: six_days_ago)

    SectionResourceDepot.process_table_creation(section_1_id)
    SectionResourceDepot.process_table_creation(section_2_id)
    SectionResourceDepot.process_table_creation(section_3_id)
    %{section_1_id: section_1_id, section_2_id: section_2_id, section_3_id: section_3_id}
  end

  defp get_section_resource_ids(revision_ids) do
    from(sr in SectionResource,
      join: r in Oli.Resources.Revision,
      on: r.resource_id == sr.resource_id,
      where: r.id in ^revision_ids,
      select: sr.id
    )
    |> Repo.all()
  end

  defp test_depot(section_id) do
    resource_ids =
      from(s in Section,
        where: s.id == ^section_id,
        join: sr in assoc(s, :section_resources),
        select: sr.resource_id
      )
      |> Repo.all()

    assert Depot.count(@depot_desc, section_id) == 4

    for resource_id <- resource_ids do
      assert Depot.get(@depot_desc, section_id, resource_id)
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
