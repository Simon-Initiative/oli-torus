defmodule Oli.Resources.CollaborationTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Resources
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.CollabSpaceConfig
  alias Oli.Resources.ResourceType

  defp create_project_with_collab_space() do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # Create collab space
    collab_space_config = build(:collab_space_config)
    collab_space_resource = insert(:resource)
    collab_space_revision =
      insert(:revision, %{
        resource_type_id: ResourceType.get_id_by_type("collabspace"),
        title: "CollabSpace",
        resource: collab_space_resource,
        slug: "collab_space",
        collab_space_config: collab_space_config
      })
    # Associate collab space to the project
    insert(:project_resource, %{project_id: project.id, resource_id: collab_space_resource.id})

    # Create page with collab space
    page_resource_cs = insert(:resource)
    page_revision_cs =
      insert(:revision, %{
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.get_id_by_type("page"),
        collab_space_id: collab_space_resource.id,
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Page with collab",
        resource: page_resource_cs,
        slug: "page_collab"
      })
    # Associate page to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource_cs.id})

    # Create page
    page_resource = insert(:resource)
    page_revision =
      insert(:revision, %{
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.get_id_by_type("page"),
        children: [],
        content: %{"model" => []},
        deleted: false,
        title: "Page 1",
        resource: page_resource,
        slug: "page_one"
      })
    # Associate page to the project
    insert(:project_resource, %{project_id: project.id, resource_id: page_resource.id})

    # root container
    container_resource = insert(:resource)
    container_revision =
      insert(:revision, %{
        resource: container_resource,
        objectives: %{},
        resource_type_id: ResourceType.get_id_by_type("container"),
        children: [page_resource.id],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    # Associate root container to the project
    insert(:project_resource, %{project_id: project.id, resource_id: container_resource.id})

    # Publication of project with root container
    publication =
      insert(:publication, %{
        project: project,
        published: nil,
        root_resource_id: container_resource.id
      })

    # Publish root container resource
    insert(:published_resource, %{
      publication: publication,
      resource: container_resource,
      revision: container_revision,
      author: author
    })

    # Publish page resource
    insert(:published_resource, %{
      author: hd(project.authors),
      publication: publication,
      resource: page_resource,
      revision: page_revision
    })

    # Publish page with collab space resource
    insert(:published_resource, %{
      author: hd(project.authors),
      publication: publication,
      resource: page_resource_cs,
      revision: page_revision_cs
    })

    # Publish collab space resource
    insert(:published_resource, %{
      author: hd(project.authors),
      publication: publication,
      resource: collab_space_resource,
      revision: collab_space_revision
    })

    {:ok,
      %{
        project: project,
        publication: publication,
        page_revision: page_revision,
        page_revision_cs: page_revision_cs,
        collab_space_revision: collab_space_revision,
        author: author
      }}
  end

  describe "collaborative spaces" do
    test "create_collaborative_space/4 with valid data creates a collaborative space" do
      {:ok, %{project: project, page_revision: page_revision, author: author}} =
        create_project_with_collab_space()

      attrs = %{collab_space_config: attrs_collab_space_config} = params_with_assocs(:revision)

      assert {:ok,
              %{
                cs_resource: cs_resource,
                cs_revision: cs_revision,
                cs_published_resource: _cs_published_resource,
                project: _project,
                publication: _publication,
                page_resource: _page_resource,
                next_page_revision: next_page_revision
              }} =
                Collaboration.create_collaborative_space(
                  attrs,
                  project,
                  page_revision.slug,
                  author.id
                )

      assert %CollabSpaceConfig{
              auto_accept: auto_accept,
              participation_min_posts: participation_min_posts,
              participation_min_replies: participation_min_replies,
              status: status,
              threaded: threaded,
              show_full_history: show_full_history
            } = cs_revision.collab_space_config

      assert auto_accept == attrs_collab_space_config.auto_accept
      assert participation_min_posts == attrs_collab_space_config.participation_min_posts
      assert participation_min_replies == attrs_collab_space_config.participation_min_replies
      assert status == attrs_collab_space_config.status
      assert threaded == attrs_collab_space_config.threaded
      assert show_full_history == attrs_collab_space_config.show_full_history

      assert next_page_revision.collab_space_id == cs_resource.id
    end

    test "create_collaborative_space/4 with invalid data rollback changes correctly" do
      {:ok, %{project: project, author: author}} = create_project_with_collab_space()
      attrs = params_with_assocs(:revision)

      assert {:error, {:error, {:not_found}}} ==
              Collaboration.create_collaborative_space(
                attrs,
                project,
                "unexisting_slug",
                author.id
              )

      refute Resources.get_resource_from_slug(attrs.slug)
    end

    test "update_collaborative_space/4 with valid data updates a collaborative space" do
      {:ok,
        %{
          project: project,
          page_revision_cs: page_revision_cs,
          collab_space_revision: collab_space_revision,
          author: author
        }} = create_project_with_collab_space()

      new_attrs = %{
        collab_space_config: %{
          auto_accept: false,
          participation_min_posts: 10,
          participation_min_replies: 10,
          status: :enabled,
          threaded: false,
          show_full_history: false
        }
      }

      assert {:ok, new_revision} =
              Collaboration.update_collaborative_space(
                collab_space_revision.resource_id,
                new_attrs,
                project,
                author.id
              )

      assert %CollabSpaceConfig{
              auto_accept: auto_accept,
              participation_min_posts: participation_min_posts,
              participation_min_replies: participation_min_replies,
              status: status,
              threaded: threaded,
              show_full_history: show_full_history
            } = new_revision.collab_space_config

      assert auto_accept == new_attrs.collab_space_config.auto_accept
      assert participation_min_posts == new_attrs.collab_space_config.participation_min_posts
      assert participation_min_replies == new_attrs.collab_space_config.participation_min_replies
      assert status == new_attrs.collab_space_config.status
      assert threaded == new_attrs.collab_space_config.threaded
      assert show_full_history == new_attrs.collab_space_config.show_full_history

      assert page_revision_cs.collab_space_id == collab_space_revision.resource_id
      assert page_revision_cs.collab_space_id == new_revision.resource_id
    end

    test "update_collaborative_space/4 with invalid data rollback changes correctly" do
      {:ok, %{project: project, collab_space_revision: collab_space_revision, author: author}} =
        create_project_with_collab_space()

      new_attrs = %{
        collab_space_config: %{
          auto_accept: false,
          participation_min_posts: 10,
          participation_min_replies: 10,
          status: :enabled,
          threaded: false,
          show_full_history: false
        }
      }

      assert {:error, {:error, {:not_found}}} ==
              Collaboration.update_collaborative_space(-1, new_attrs, project, author.id)

      assert %CollabSpaceConfig{
              auto_accept: auto_accept,
              participation_min_posts: participation_min_posts,
              participation_min_replies: participation_min_replies,
              status: status,
              threaded: threaded,
              show_full_history: show_full_history
            } = collab_space_revision.collab_space_config

      refute auto_accept == new_attrs.collab_space_config.auto_accept
      refute participation_min_posts == new_attrs.collab_space_config.participation_min_posts
      refute participation_min_replies == new_attrs.collab_space_config.participation_min_replies
      refute status == new_attrs.collab_space_config.status
      refute threaded == new_attrs.collab_space_config.threaded
      refute show_full_history == new_attrs.collab_space_config.show_full_history
    end

    test "search_collaborative_spaces/1 returns correctly when no collab spaces present" do
      section = insert(:section)

      assert [] == Collaboration.search_collaborative_spaces(section.slug)
    end

    test "search_collaborative_spaces/1 returns collab spaces correctly" do
      {:ok,
        %{
          project: project,
          page_revision_cs: page_revision_cs,
          collab_space_revision: collab_space_revision,
          publication: publication
        }} = create_project_with_collab_space()

      section = insert(:section, base_project: project)
      {:ok, _section} = Sections.create_section_resources(section, publication)

      assert [%{
        collab_space: collab_space,
        page: page
      }] = Collaboration.search_collaborative_spaces(section.slug)

      assert collab_space.resource_id == collab_space_revision.resource_id
      assert page.resource_id == page_revision_cs.resource_id
    end
  end
end
