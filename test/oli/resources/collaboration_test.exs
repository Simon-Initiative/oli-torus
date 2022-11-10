defmodule Oli.Resources.CollaborationTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Resources
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.{CollabSpaceConfig, Post}
  alias Oli.Resources.ResourceType

  defp create_project_with_collab_space_and_posts() do
    user = insert(:user)
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
        slug: "page_one",
        collab_space_config: nil
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

    section = insert(:section, base_project: project)
    {:ok, _root_section_resource} = Sections.create_section_resources(section, publication)

    first_post = insert(:post, section: section, resource: page_resource_cs, user: user)
    second_post = insert(:post, status: :submitted, content: %{message: "Other post"}, section: section, resource: page_resource_cs, user: user)

    {:ok,
      %{
        project: project,
        publication: publication,
        page_revision: page_revision,
        page_revision_cs: page_revision_cs,
        collab_space_revision: collab_space_revision,
        author: author,
        section: section,
        posts: [first_post, second_post]
      }}
  end

  describe "collaborative spaces" do
    test "create_collaborative_space/4 with valid data creates a collaborative space" do
      {:ok, %{project: project, page_revision: page_revision, author: author}} =
        create_project_with_collab_space_and_posts()

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
      {:ok, %{project: project, author: author}} = create_project_with_collab_space_and_posts()
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
        }} = create_project_with_collab_space_and_posts()

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
        create_project_with_collab_space_and_posts()

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

    test "search_collaborative_spaces/1 returns collab spaces correctly with posts" do
      {:ok,
        %{
          page_revision_cs: page_revision_cs,
          collab_space_revision: collab_space_revision,
          section: section
        }} = create_project_with_collab_space_and_posts()

      assert [%{
        collab_space: collab_space,
        page: page,
        number_of_posts: 2,
        number_of_posts_pending_approval: 1,
        most_recent_post: %DateTime{}
      }] = Collaboration.search_collaborative_spaces(section.slug)

      assert collab_space.resource_id == collab_space_revision.resource_id
      assert page.resource_id == page_revision_cs.resource_id
    end

    test "get_collab_space_config_for_page/2 returns nil when no collab space is present" do
      {:ok,
        %{
          page_revision: page_revision,
          section: section
        }} = create_project_with_collab_space_and_posts()

      assert {:ok, nil} ==
        Collaboration.get_collab_space_config_for_page(section.slug, page_revision.slug)
    end

    test "get_collab_space_config_for_page/2 returns error when no section or page exists" do
      assert {:error, :not_found} ==
        Collaboration.get_collab_space_config_for_page("section_slug", "page_revision")
    end

    test "get_collab_space_config_for_page/2 returns the page collab space when no delivery setting" do
      {:ok,
        %{
          page_revision_cs: page_revision_cs,
          collab_space_revision: collab_space_revision,
          section: section
        }} = create_project_with_collab_space_and_posts()

      assert {:ok, %CollabSpaceConfig{} = returned_cs} =
        Collaboration.get_collab_space_config_for_page(section.slug, page_revision_cs.slug)

      assert collab_space_revision.collab_space_config == returned_cs
    end

    test "get_collab_space_config_for_page/2 returns the delivery setting collab space when present" do
      {:ok,
        %{
          page_revision_cs: page_revision_cs,
          collab_space_revision: collab_space_revision,
          section: section
        }} = create_project_with_collab_space_and_posts()

      ds_collab_space = params_for(:collab_space_config, status: :archived)
      insert(
        :delivery_setting,
        section: section,
        resource: page_revision_cs.resource,
        collab_space_config: ds_collab_space
      )

      assert {:ok, %CollabSpaceConfig{} = returned_cs} =
        Collaboration.get_collab_space_config_for_page(section.slug, page_revision_cs.slug)

      refute collab_space_revision.collab_space_config == returned_cs
      assert ds_collab_space.status == returned_cs.status
    end
  end

  describe "posts" do
    test "create_post/1 with valid data creates a post" do
      params = params_with_assocs(:post)
      assert {:ok, %Post{} = post} = Collaboration.create_post(params)

      assert post.content == params.content
      assert post.status == params.status
      assert post.user_id == params.user_id
      assert post.section_id == params.section_id
      assert post.resource_id == params.resource_id
    end

    test "create_post/1 with existing name returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Collaboration.create_post(%{status: :testing})
    end

    test "get_post_by/1 returns a post when the id exists" do
      post = insert(:post)

      returned_post = Collaboration.get_post_by(%{id: post.id})

      assert post.id == returned_post.id
      assert post.content.message == returned_post.content["message"]
    end

    test "get_post_by/1 returns nil if the post does not exist" do
      assert nil == Collaboration.get_post_by(%{id: -1})
    end

    test "update_post/2 updates the post successfully" do
      post = insert(:post)

      {:ok, updated_post} = Collaboration.update_post(post, %{status: :archived})

      assert post.id == updated_post.id
      assert updated_post.status == :archived
    end

    test "update_post/2 does not update the post when there is an invalid field" do
      post = insert(:post)

      {:error, changeset} = Collaboration.update_post(post, %{status: :testing})
      {error, _} = changeset.errors[:status]

      refute changeset.valid?
      assert error =~ "is invalid"
    end

    test "change_post/1 returns a post changeset" do
      post = insert(:post)
      assert %Ecto.Changeset{} = Collaboration.change_post(post)
    end

    test "search_posts/1 returns all posts meeting the criteria" do
      [post | _] = insert_pair(:post, status: :archived)
      insert(:post, status: :approved)

      assert [returned_post | _] = Collaboration.search_posts(%{status: :archived})

      assert returned_post.id == post.id
      assert returned_post.replies_count == 0
    end
  end
end
