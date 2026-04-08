defmodule Oli.Publishing.ScopeIsolationTest do
  use Oli.DataCase

  import Oli.Factory
  import Ecto.Query, warn: false

  alias Oli.Publishing.AuthoringResolver
  alias Oli.Publishing
  alias Oli.Resources
  alias Oli.Resources.ResourceType
  alias Oli.Delivery.Hierarchy

  import Oli.Test.HierarchyBuilder

  describe "AuthoringResolver with container_scope filtering" do
    setup do
      author = insert(:author)
      project = insert(:project, authors: [author])
      publication = insert(:publication, project: project, published: nil)

      # Build the normal project hierarchy (Root > Unit 1 > Pages)
      tree =
        build_hierarchy(
          project,
          publication,
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

      # Create a blueprint-scoped container separately — NOT as a child of Root.
      # In real usage, blueprint containers are created by ContainerCreation.materialize
      # and added to the SectionResource tree, not to the project hierarchy's children arrays.
      # They exist in the publication but are not referenced by any parent container.
      blueprint_resource = insert(:resource)

      blueprint_revision =
        insert(:revision,
          resource: blueprint_resource,
          resource_type_id: ResourceType.id_for_container(),
          title: "Blueprint Container",
          container_scope: :blueprint,
          children: [],
          author: author
        )

      insert(:project_resource, project_id: project.id, resource_id: blueprint_resource.id)

      insert(:published_resource,
        publication: publication,
        resource: blueprint_resource,
        revision: blueprint_revision
      )

      %{
        project: project,
        unit: tree["Unit 1"],
        blueprint_resource_id: blueprint_resource.id
      }
    end

    test "full_hierarchy/1 includes project-scoped containers", ctx do
      hierarchy = AuthoringResolver.full_hierarchy(ctx.project.slug)
      resource_ids = Hierarchy.flatten_hierarchy(hierarchy) |> Enum.map(& &1.resource_id)

      assert ctx.unit.resource.id in resource_ids
    end

    test "full_hierarchy/1 excludes blueprint-scoped containers", ctx do
      hierarchy = AuthoringResolver.full_hierarchy(ctx.project.slug)
      resource_ids = Hierarchy.flatten_hierarchy(hierarchy) |> Enum.map(& &1.resource_id)

      refute ctx.blueprint_resource_id in resource_ids
    end

    test "all_revisions_in_hierarchy/1 excludes blueprint-scoped revisions from the lookup map",
         ctx do
      # This is the query that full_hierarchy uses to build its revisions_by_resource_id map.
      # The container_scope filter here prevents blueprint revisions from being loaded at all.
      revisions = AuthoringResolver.all_revisions_in_hierarchy(ctx.project.slug)
      resource_ids = Enum.map(revisions, & &1.resource_id)

      refute ctx.blueprint_resource_id in resource_ids
    end

    test "revisions_of_type/2 for containers excludes blueprint-scoped", ctx do
      container_type = ResourceType.id_for_container()
      revisions = AuthoringResolver.revisions_of_type(ctx.project.slug, container_type)
      resource_ids = Enum.map(revisions, & &1.resource_id)

      refute ctx.blueprint_resource_id in resource_ids
    end

    test "all_revisions/1 excludes blueprint-scoped revisions", ctx do
      revisions = AuthoringResolver.all_revisions(ctx.project.slug)
      resource_ids = Enum.map(revisions, & &1.resource_id)

      refute ctx.blueprint_resource_id in resource_ids
    end
  end

  describe "Publishing with container_scope filtering" do
    setup do
      author = insert(:author)
      project = insert(:project, authors: [author])
      publication = insert(:publication, project: project, published: nil)

      build_hierarchy(
        project,
        publication,
        author,
        {:container, "Root",
         [
           {:container, "Unit 1",
            [
              {:page, "Page A"}
            ]}
         ]}
      )

      # Blueprint container — exists in publication but not in any container's children
      blueprint_resource = insert(:resource)

      blueprint_revision =
        insert(:revision,
          resource: blueprint_resource,
          resource_type_id: ResourceType.id_for_container(),
          title: "Blueprint Container",
          container_scope: :blueprint,
          children: [],
          author: author
        )

      insert(:project_resource, project_id: project.id, resource_id: blueprint_resource.id)

      insert(:published_resource,
        publication: publication,
        resource: blueprint_resource,
        revision: blueprint_revision
      )

      %{
        project: project,
        blueprint_resource_id: blueprint_resource.id
      }
    end

    test "query_unpublished_revisions_by_type for containers excludes blueprint-scoped", ctx do
      resource_ids =
        Publishing.query_unpublished_revisions_by_type(ctx.project.slug, "container")
        |> Repo.all()
        |> Enum.map(& &1.resource_id)

      refute ctx.blueprint_resource_id in resource_ids
    end
  end

  describe "create_revision_from_previous preserves container_scope" do
    test "new revision inherits container_scope from previous revision", _ctx do
      resource = insert(:resource)

      revision =
        insert(:revision,
          resource: resource,
          container_scope: :blueprint,
          author: insert(:author),
          resource_type_id: ResourceType.id_for_container()
        )

      {:ok, new_revision} =
        Resources.create_revision_from_previous(revision, %{title: "Updated Title"})

      assert new_revision.container_scope == :blueprint
      assert new_revision.title == "Updated Title"
    end
  end
end
