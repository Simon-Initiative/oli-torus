defmodule Oli.Delivery.Remix.ContainerCreationTest do
  use Oli.DataCase

  import Oli.Factory
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Delivery.Remix.ContainerCreation
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Publishing
  alias Oli.Publishing.PublishedResource
  alias Oli.Resources.{Resource, Revision, ResourceType}

  import Oli.Test.HierarchyBuilder

  describe "build_draft/4" do
    setup do
      author = insert(:author)
      project = insert(:project, authors: [author])
      publication = insert(:publication, project: project, published: nil)

      _tree =
        build_hierarchy(
          project,
          publication,
          author,
          {:container, "Root",
           [
             {:page, "Page A"}
           ]}
        )

      # Reload publication — build_hierarchy updated root_resource_id in DB
      publication = Repo.get!(Oli.Publishing.Publications.Publication, publication.id)

      section = insert(:section, type: :blueprint, base_project: project)
      {:ok, section} = Oli.Delivery.Sections.create_section_resources(section, publication)
      {:ok, state} = Oli.Delivery.Remix.init_open_and_free(section)

      %{project: project, author: author, hierarchy: state.hierarchy}
    end

    test "returns a HierarchyNode with deterministic negative IDs", ctx do
      node = ContainerCreation.build_draft(ctx.hierarchy, ctx.project, "New Module")

      assert %HierarchyNode{} = node

      # First draft gets -1 (all existing IDs are positive)
      assert node.resource_id == -1
      assert node.revision.id == -1
      assert node.revision.resource_id == node.resource_id

      # Correct type, scope, and structure
      assert node.revision.resource_type_id == ResourceType.id_for_container()
      assert node.revision.container_scope == :blueprint
      assert node.children == []
      assert node.uuid != nil
      assert node.project_id == ctx.project.id
    end

    test "sequential drafts get sequential negative IDs",
         %{hierarchy: %HierarchyNode{} = hierarchy} = ctx do
      node1 = ContainerCreation.build_draft(hierarchy, ctx.project, "Module 1")

      # Append first draft to hierarchy so the next one sees it
      updated = %HierarchyNode{hierarchy | children: hierarchy.children ++ [node1]}
      node2 = ContainerCreation.build_draft(updated, ctx.project, "Module 2")

      assert node1.resource_id == -1
      assert node2.resource_id == -2
      assert node1.uuid != node2.uuid
    end

    test "container_scope is parameterized for future reuse", ctx do
      blueprint = ContainerCreation.build_draft(ctx.hierarchy, ctx.project, "Template Module")
      assert blueprint.revision.container_scope == :blueprint

      section =
        ContainerCreation.build_draft(ctx.hierarchy, ctx.project, "Instructor Module",
          container_scope: :section
        )

      assert section.revision.container_scope == :section
    end

    test "no database writes occur", ctx do
      counts_before = %{
        resources: Repo.aggregate(Resource, :count),
        revisions: Repo.aggregate(Revision, :count)
      }

      _node = ContainerCreation.build_draft(ctx.hierarchy, ctx.project, "New Module")

      # Purely in-memory — zero DB footprint
      assert Repo.aggregate(Resource, :count) == counts_before.resources
      assert Repo.aggregate(Revision, :count) == counts_before.revisions
    end
  end

  describe "materialize/3" do
    setup do
      author = insert(:author)
      project = insert(:project, authors: [author])
      published_pub = insert(:publication, project: project, published: DateTime.utc_now())
      working_pub = insert(:publication, project: project, published: nil)

      tree =
        build_hierarchy(
          project,
          working_pub,
          author,
          {:container, "Root",
           [
             {:container, "Unit 1",
              [
                {:page, "Page A"},
                {:page, "Page B"}
              ]}
           ]}
        )

      # build_hierarchy sets root on working_pub; sync published_pub and reload working_pub
      Repo.update!(
        Ecto.Changeset.change(published_pub, root_resource_id: tree["Root"].resource.id)
      )

      working_pub = Repo.get!(Oli.Publishing.Publications.Publication, working_pub.id)

      section = insert(:section, type: :blueprint, base_project: project)
      {:ok, section} = Oli.Delivery.Sections.create_section_resources(section, working_pub)
      {:ok, state} = Oli.Delivery.Remix.init_open_and_free(section)

      %{
        project: project,
        author: author,
        tree: tree,
        hierarchy: state.hierarchy,
        section: section
      }
    end

    test "replaces draft nodes with real DB records and positive IDs",
         %{hierarchy: %HierarchyNode{} = root_hierarchy} = ctx do
      draft = ContainerCreation.build_draft(root_hierarchy, ctx.project, "New Module")
      hierarchy = %HierarchyNode{root_hierarchy | children: root_hierarchy.children ++ [draft]}

      {:ok, materialized} = ContainerCreation.materialize(hierarchy, ctx.project, ctx.author)

      # Find the node that was the draft (same uuid)
      new_node = Hierarchy.find_in_hierarchy(materialized, draft.uuid)

      # Draft materialized — real records now exist in DB
      assert Repo.exists?(from r in Resource, where: r.id == ^new_node.resource_id)
      assert Repo.exists?(from r in Revision, where: r.id == ^new_node.revision.id)

      # Order preserved — draft was last child, still is after materialization
      assert List.last(materialized.children).uuid == draft.uuid
    end

    test "creates PublishedResource records for ALL publications",
         %{hierarchy: %HierarchyNode{} = root_hierarchy} = ctx do
      draft = ContainerCreation.build_draft(root_hierarchy, ctx.project, "New Module")
      hierarchy = %HierarchyNode{root_hierarchy | children: root_hierarchy.children ++ [draft]}

      {:ok, materialized} = ContainerCreation.materialize(hierarchy, ctx.project, ctx.author)
      new_node = Hierarchy.find_in_hierarchy(materialized, draft.uuid)

      # PublishedResource exists for each publication in the project
      all_pub_ids =
        Publishing.get_all_publications_for_project(ctx.project.id) |> Enum.map(& &1.id)

      materialized_pub_ids =
        Repo.all(
          from pr in PublishedResource,
            where: pr.resource_id == ^new_node.resource_id,
            select: pr.publication_id
        )

      assert Enum.sort(materialized_pub_ids) == Enum.sort(all_pub_ids)
    end

    test "leaves non-draft nodes unchanged",
         %{hierarchy: %HierarchyNode{} = root_hierarchy} = ctx do
      draft = ContainerCreation.build_draft(root_hierarchy, ctx.project, "New Module")
      hierarchy = %HierarchyNode{root_hierarchy | children: root_hierarchy.children ++ [draft]}

      {:ok, materialized} = ContainerCreation.materialize(hierarchy, ctx.project, ctx.author)

      # Root resource_id unchanged
      assert materialized.resource_id == root_hierarchy.resource_id

      # Existing children keep their original resource_ids
      original_ids = Enum.map(root_hierarchy.children, & &1.resource_id) |> Enum.sort()

      non_draft_ids =
        materialized.children
        |> Enum.map(& &1.resource_id)
        |> Enum.filter(&(&1 in original_ids))
        |> Enum.sort()

      assert non_draft_ids == original_ids
    end

    test "no-op when hierarchy has no drafts (nil author)", ctx do
      {:ok, result} = ContainerCreation.materialize(ctx.hierarchy, ctx.project, nil)
      assert result == ctx.hierarchy
    end

    test "returns error when nil author but drafts exist",
         %{hierarchy: %HierarchyNode{} = root_hierarchy} = ctx do
      draft = ContainerCreation.build_draft(root_hierarchy, ctx.project, "New Module")
      hierarchy = %HierarchyNode{root_hierarchy | children: root_hierarchy.children ++ [draft]}

      assert {:error, :author_required_for_materialization} =
               ContainerCreation.materialize(hierarchy, ctx.project, nil)
    end

    test "no-op when hierarchy has no drafts (with author)", ctx do
      {:ok, result} = ContainerCreation.materialize(ctx.hierarchy, ctx.project, ctx.author)
      assert result == ctx.hierarchy
    end

    test "materializes multiple drafts preserving order",
         %{hierarchy: %HierarchyNode{} = root_hierarchy} = ctx do
      draft_a = ContainerCreation.build_draft(root_hierarchy, ctx.project, "Module A")

      hierarchy_with_a = %HierarchyNode{
        root_hierarchy
        | children: root_hierarchy.children ++ [draft_a]
      }

      draft_b = ContainerCreation.build_draft(hierarchy_with_a, ctx.project, "Module B")

      hierarchy_with_ab = %HierarchyNode{
        hierarchy_with_a
        | children: hierarchy_with_a.children ++ [draft_b]
      }

      draft_c = ContainerCreation.build_draft(hierarchy_with_ab, ctx.project, "Module C")

      # Deterministic negative IDs: -1, -2, -3
      assert draft_a.resource_id == -1
      assert draft_b.resource_id == -2
      assert draft_c.resource_id == -3

      hierarchy = %HierarchyNode{
        root_hierarchy
        | children: root_hierarchy.children ++ [draft_a, draft_b, draft_c]
      }

      {:ok, materialized} = ContainerCreation.materialize(hierarchy, ctx.project, ctx.author)

      # All drafts materialized to real positive IDs, order preserved by title
      titles = materialized.children |> Enum.map(& &1.revision.title)
      assert ["Unit 1", "Module A", "Module B", "Module C"] == titles

      # All former drafts now have real DB records
      Enum.each([draft_a, draft_b, draft_c], fn draft ->
        node = Hierarchy.find_in_hierarchy(materialized, draft.uuid)
        assert Repo.exists?(from r in Resource, where: r.id == ^node.resource_id)
      end)
    end

    test "materializes nested drafts (parent draft containing child draft)",
         %{hierarchy: %HierarchyNode{} = root_hierarchy} = ctx do
      # Create a draft Unit at the top level
      draft_unit = ContainerCreation.build_draft(root_hierarchy, ctx.project, "New Unit")

      hierarchy_with_unit = %HierarchyNode{
        root_hierarchy
        | children: root_hierarchy.children ++ [draft_unit]
      }

      # Create a draft Module inside the draft Unit
      draft_module = ContainerCreation.build_draft(hierarchy_with_unit, ctx.project, "New Module")

      nested_unit = %HierarchyNode{draft_unit | children: [draft_module]}

      hierarchy = %HierarchyNode{
        root_hierarchy
        | children: root_hierarchy.children ++ [nested_unit]
      }

      {:ok, materialized} = ContainerCreation.materialize(hierarchy, ctx.project, ctx.author)

      # Both drafts materialized to real positive IDs
      mat_unit = Hierarchy.find_in_hierarchy(materialized, draft_unit.uuid)
      mat_module = Hierarchy.find_in_hierarchy(materialized, draft_module.uuid)

      assert mat_unit.resource_id > 0
      assert mat_module.resource_id > 0
      assert Repo.exists?(from r in Resource, where: r.id == ^mat_unit.resource_id)
      assert Repo.exists?(from r in Resource, where: r.id == ^mat_module.resource_id)

      # Child is still nested under the parent
      assert length(mat_unit.children) == 1
      assert hd(mat_unit.children).uuid == draft_module.uuid
    end
  end

  describe "generate_title/1" do
    setup do
      author = insert(:author)
      project = insert(:project, authors: [author])
      publication = insert(:publication, project: project, published: nil)

      _tree =
        build_hierarchy(
          project,
          publication,
          author,
          {:container, "Root",
           [
             {:container, "Unit 1",
              [
                {:container, "Module 1",
                 [
                   {:page, "Page A"}
                 ]}
              ]}
           ]}
        )

      publication = Repo.get!(Oli.Publishing.Publications.Publication, publication.id)

      section = insert(:section, type: :blueprint, base_project: project)
      {:ok, section} = Oli.Delivery.Sections.create_section_resources(section, publication)
      {:ok, state} = Oli.Delivery.Remix.init_open_and_free(section)

      %{hierarchy: state.hierarchy}
    end

    test "starts numbering at 1 when no containers exist at target level", ctx do
      # Navigate into Unit 1 → Module 1 (has only pages, no container children)
      unit = Enum.find(ctx.hierarchy.children, &(&1.revision.title == "Unit 1"))
      module = Enum.find(unit.children, &(&1.revision.title == "Module 1"))

      title = ContainerCreation.generate_title(module)
      assert title == "Section 1"
    end

    test "appends number when containers already exist", ctx do
      # Root has 1 container child (Unit 1), so next is "Unit 2"
      title = ContainerCreation.generate_title(ctx.hierarchy)
      assert title == "Unit 2"
    end

    test "counts only containers, not pages", ctx do
      # Unit 1 has 1 container child (Module 1), so next is "Module 2"
      unit = Enum.find(ctx.hierarchy.children, &(&1.revision.title == "Unit 1"))
      title = ContainerCreation.generate_title(unit)
      assert title == "Module 2"
    end
  end
end
