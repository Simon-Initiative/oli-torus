defmodule Oli.Delivery.RemixContainerTest do
  use Oli.DataCase

  import Oli.Factory
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Delivery.Remix
  alias Oli.Delivery.Remix.State
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Hierarchy
  alias Oli.Publishing.DeliveryResolver

  import Oli.Test.HierarchyBuilder

  describe "create_container/3" do
    setup do
      author = insert(:author)

      # Base project (the template's own project)
      base_project = insert(:project, authors: [author])
      base_publication = insert(:publication, project: base_project, published: nil)

      _base_tree =
        build_hierarchy(
          base_project,
          base_publication,
          author,
          {:container, "Root",
           [
             {:container, "Unit 1",
              [
                {:container, "Module 1",
                 [
                   {:page, "Page A"},
                   {:page, "Page B"}
                 ]}
              ]}
           ]}
        )

      # Source project (where we pull materials from during remix)
      source_project = insert(:project)

      source_publication =
        insert(:publication, project: source_project, published: DateTime.utc_now())

      source_tree =
        build_hierarchy(
          source_project,
          source_publication,
          author,
          {:container, "Source Root",
           [
             {:page, "Extra Page"}
           ]}
        )

      # Reload publication — build_hierarchy updated root_resource_id in DB
      base_publication =
        Repo.get!(Oli.Publishing.Publications.Publication, base_publication.id)

      section = insert(:section, type: :blueprint, base_project: base_project)
      {:ok, section} = Sections.create_section_resources(section, base_publication)
      {:ok, state} = Remix.init_open_and_free(section)

      %{
        state: state,
        section: section,
        base_project: base_project,
        author: author,
        source_pub: source_publication,
        source_page: source_tree["Extra Page"].resource
      }
    end

    test "creates a container and updates the hierarchy state", ctx do
      children_before = length(ctx.state.active.children)
      last_before = List.last(ctx.state.active.children)
      refute ctx.state.has_unsaved_changes
      assert ctx.state.hierarchy.finalized

      %State{} = new_state = Remix.create_container(ctx.state, :module, "New Module")

      # One more child, appended at the end
      new_node = List.last(new_state.active.children)
      assert length(new_state.active.children) == children_before + 1
      assert Enum.at(new_state.active.children, -2).uuid == last_before.uuid
      assert new_node.uuid != last_before.uuid

      # State flags updated
      assert new_state.has_unsaved_changes
      assert new_state.hierarchy.finalized
    end

    test "new container is usable (navigable and accepts materials)", ctx do
      new_state = Remix.create_container(ctx.state, :module, "New Module")
      new_node = List.last(new_state.active.children)

      # Can navigate into the new container
      {:ok, active_state} = Remix.select_active(new_state, new_node.uuid)
      assert active_state.active.uuid == new_node.uuid
      assert active_state.active.children == []

      # Can add materials to it
      {:ok, updated_state} =
        Remix.add_materials(active_state, [{ctx.source_pub.id, ctx.source_page.id}])

      assert length(updated_state.active.children) == 1
    end

    test "save materializes drafts and persists the full structure", ctx do
      # Create draft container, navigate into it, add materials
      new_state = Remix.create_container(ctx.state, :module, "New Module")
      draft_node = List.last(new_state.active.children)

      # Draft has negative resource_id (not in DB yet)
      assert draft_node.resource_id < 0

      {:ok, active_state} = Remix.select_active(new_state, draft_node.uuid)

      {:ok, populated_state} =
        Remix.add_materials(active_state, [{ctx.source_pub.id, ctx.source_page.id}])

      # Save triggers redirect to product overview (materializes drafts then persists)
      Remix.save(populated_state, ctx.author)

      # Reload hierarchy — the container now has a real positive resource_id
      reloaded = DeliveryResolver.full_hierarchy(ctx.section.slug)
      all_titles = Hierarchy.flatten_hierarchy(reloaded) |> Enum.map(& &1.revision.title)
      assert "New Module" in all_titles

      # Find the materialized container's SectionResource
      new_module =
        Hierarchy.flatten_hierarchy(reloaded)
        |> Enum.find(&(&1.revision.title == "New Module"))

      # Material is a child of the container in the persisted SectionResource tree
      container_sr =
        Repo.get_by(SectionResource,
          section_id: ctx.section.id,
          resource_id: new_module.resource_id
        )

      material_sr =
        Repo.get_by(SectionResource,
          section_id: ctx.section.id,
          resource_id: ctx.source_page.id
        )

      assert material_sr.id in container_sr.children
    end
  end
end
