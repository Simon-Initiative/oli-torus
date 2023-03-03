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

    # Create page with collab space
    page_resource_cs = insert(:resource)

    page_revision_cs =
      insert(:revision, %{
        scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"),
        resource_type_id: ResourceType.get_id_by_type("page"),
        collab_space_config: collab_space_config,
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

    section = insert(:section, base_project: project)
    {:ok, _root_section_resource} = Sections.create_section_resources(section, publication)

    first_post = insert(:post, section: section, resource: page_resource_cs, user: user)

    second_post =
      insert(:post,
        status: :submitted,
        content: %{message: "Other post"},
        section: section,
        resource: page_resource_cs,
        user: user
      )

    {:ok,
     %{
       project: project,
       publication: publication,
       page_revision: page_revision,
       page_revision_cs: page_revision_cs,
       page_resource_cs: page_resource_cs,
       collab_space_config: collab_space_config,
       author: author,
       section: section,
       posts: [first_post, second_post]
     }}
  end

  describe "collaborative spaces" do
    test "upsert_collaborative_space/4 with valid data creates a collaborative space" do
      {:ok, %{project: project, page_revision: page_revision, author: author}} =
        create_project_with_collab_space_and_posts()

      attrs = params_for(:collab_space_config)

      assert {:ok,
              %{
                project: _project,
                publication: _publication,
                page_resource: _page_resource,
                next_page_revision: next_page_revision
              }} =
               Collaboration.upsert_collaborative_space(
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
               show_full_history: show_full_history,
               anonymous_posting: anonymous_posting
             } = next_page_revision.collab_space_config

      assert auto_accept == attrs.auto_accept
      assert participation_min_posts == attrs.participation_min_posts
      assert participation_min_replies == attrs.participation_min_replies
      assert status == attrs.status
      assert threaded == attrs.threaded
      assert show_full_history == attrs.show_full_history
      assert anonymous_posting == attrs.anonymous_posting
    end

    test "upsert_collaborative_space/4 with valid data updates a collaborative space" do
      {:ok,
       %{
         project: project,
         page_revision_cs: page_revision_cs,
         author: author
       }} = create_project_with_collab_space_and_posts()

      new_attrs = %{
        auto_accept: false,
        participation_min_posts: 10,
        participation_min_replies: 10,
        status: :enabled,
        threaded: false,
        show_full_history: false,
        anonymous_posting: false
      }

      assert {:ok,
              %{
                project: _project,
                publication: _publication,
                page_resource: _page_resource,
                next_page_revision: next_page_revision
              }} =
               Collaboration.upsert_collaborative_space(
                 new_attrs,
                 project,
                 page_revision_cs.slug,
                 author.id
               )

      assert %CollabSpaceConfig{
               auto_accept: auto_accept,
               participation_min_posts: participation_min_posts,
               participation_min_replies: participation_min_replies,
               status: status,
               threaded: threaded,
               show_full_history: show_full_history,
               anonymous_posting: anonymous_posting
             } = next_page_revision.collab_space_config

      assert auto_accept == new_attrs.auto_accept
      assert participation_min_posts == new_attrs.participation_min_posts
      assert participation_min_replies == new_attrs.participation_min_replies
      assert status == new_attrs.status
      assert threaded == new_attrs.threaded
      assert show_full_history == new_attrs.show_full_history
      assert anonymous_posting == new_attrs.anonymous_posting
    end

    test "upsert_collaborative_space/4 with invalid data rollback changes correctly" do
      {:ok, %{project: project, author: author}} = create_project_with_collab_space_and_posts()
      slug = "unexisting_slug"
      attrs = params_for(:collab_space_config)

      assert {:error, {:error, {:not_found}}} ==
               Collaboration.upsert_collaborative_space(
                 attrs,
                 project,
                 slug,
                 author.id
               )

      refute Resources.get_resource_from_slug(slug)
    end

    test "list_collaborative_spaces_in_section/1 returns correctly when no collab spaces present" do
      section = insert(:section)

      assert [] == Collaboration.list_collaborative_spaces_in_section(section.slug)
    end

    test "list_collaborative_spaces_in_section/1 returns collab spaces correctly with posts configured in pages" do
      {:ok,
       %{
         page_revision_cs: page_revision_cs,
         collab_space_config: collab_space_config,
         section: section
       }} = create_project_with_collab_space_and_posts()

      assert [
               %{
                 collab_space_config: returned_collab_space_config,
                 page: page,
                 number_of_posts: 2,
                 number_of_posts_pending_approval: 1,
                 most_recent_post: _most_recent_post,
                 section: returned_section
               }
             ] = Collaboration.list_collaborative_spaces_in_section(section.slug)

      assert returned_collab_space_config["status"] |> String.to_atom() ==
               collab_space_config.status

      assert returned_collab_space_config["threaded"] == collab_space_config.threaded
      assert page.resource_id == page_revision_cs.resource_id
      assert returned_section.id == section.id
    end

    test "list_collaborative_spaces_in_section/1 returns collab spaces correctly with posts configured in the delivery setting" do
      {:ok,
       %{
         page_revision_cs: page_revision_cs,
         page_resource_cs: page_resource_cs,
         section: section
       }} = create_project_with_collab_space_and_posts()

      collab_space_config = build(:collab_space_config, status: :archived)

      insert(:delivery_setting,
        section: section,
        resource: page_resource_cs,
        collab_space_config: collab_space_config
      )

      assert [
               %{
                 collab_space_config: returned_collab_space_config,
                 page: page,
                 number_of_posts: 2,
                 number_of_posts_pending_approval: 1,
                 most_recent_post: _most_recent_post,
                 section: returned_section
               }
             ] = Collaboration.list_collaborative_spaces_in_section(section.slug)

      assert returned_collab_space_config["status"] |> String.to_atom() == :archived
      assert returned_collab_space_config["threaded"] == collab_space_config.threaded
      assert page.resource_id == page_revision_cs.resource_id
      assert returned_section.id == section.id
    end

    test "list_collaborative_spaces/0 returns correctly when no collab spaces present" do
      assert [] == Collaboration.list_collaborative_spaces()
    end

    test "list_collaborative_spaces/0 returns collab spaces correctly with posts configured in pages" do
      {:ok,
       %{
         page_revision_cs: page_revision_cs,
         collab_space_config: collab_space_config,
         project: project
       }} = create_project_with_collab_space_and_posts()

      assert [
               %{
                 collab_space_config: returned_collab_space_config,
                 page: page,
                 number_of_posts: 2,
                 number_of_posts_pending_approval: 1,
                 most_recent_post: _most_recent_post,
                 project: returned_project
               }
             ] = Collaboration.list_collaborative_spaces()

      assert returned_collab_space_config == collab_space_config
      assert page.resource_id == page_revision_cs.resource_id
      assert returned_project.id == project.id
    end

    test "get_collab_space_config_for_page_in_section/2 returns nil when no collab space is present" do
      {:ok,
       %{
         page_revision: page_revision,
         section: section
       }} = create_project_with_collab_space_and_posts()

      assert {:ok, nil} ==
               Collaboration.get_collab_space_config_for_page_in_section(
                 page_revision.slug,
                 section.slug
               )
    end

    test "get_collab_space_config_for_page_in_section/2 returns error when no section or page exists" do
      assert {:error, :not_found} ==
               Collaboration.get_collab_space_config_for_page_in_section(
                 "page_revision",
                 "section_slug"
               )
    end

    test "get_collab_space_config_for_page_in_section/2 returns the page collab space when no delivery setting" do
      {:ok,
       %{
         page_revision_cs: page_revision_cs,
         collab_space_config: collab_space_config,
         section: section
       }} = create_project_with_collab_space_and_posts()

      assert {:ok, %CollabSpaceConfig{} = returned_cs} =
               Collaboration.get_collab_space_config_for_page_in_section(
                 page_revision_cs.slug,
                 section.slug
               )

      assert collab_space_config == returned_cs
    end

    test "get_collab_space_config_for_page_in_section/2 returns the delivery setting collab space when present" do
      {:ok,
       %{
         page_revision_cs: page_revision_cs,
         collab_space_config: collab_space_config,
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
               Collaboration.get_collab_space_config_for_page_in_section(
                 page_revision_cs.slug,
                 section.slug
               )

      refute collab_space_config == returned_cs
      refute collab_space_config.status == returned_cs.status
      assert ds_collab_space.status == returned_cs.status
    end

    test "get_collab_space_config_for_page_in_project/2 returns nil when no collab space is present" do
      {:ok,
       %{
         page_revision: page_revision,
         project: project
       }} = create_project_with_collab_space_and_posts()

      assert {:ok, nil} ==
               Collaboration.get_collab_space_config_for_page_in_project(
                 page_revision.slug,
                 project.slug
               )
    end

    test "get_collab_space_config_for_page_in_project/2 returns error when no project or page exists" do
      assert {:error, :not_found} ==
               Collaboration.get_collab_space_config_for_page_in_project(
                 "page_revision",
                 "project_slug"
               )
    end

    test "get_collab_space_config_for_page_in_project/2 returns the page collab space" do
      {:ok,
       %{
         page_revision_cs: page_revision_cs,
         collab_space_config: collab_space_config,
         project: project
       }} = create_project_with_collab_space_and_posts()

      assert {:ok, %CollabSpaceConfig{} = returned_cs} =
               Collaboration.get_collab_space_config_for_page_in_project(
                 page_revision_cs.slug,
                 project.slug
               )

      assert collab_space_config == returned_cs
    end
  end

  describe "posts" do
    test "create_post/1 with valid data creates a post" do
      params = params_with_assocs(:post)
      assert {:ok, %Post{} = post} = Collaboration.create_post(params)

      assert post.content.message == params.content.message
      assert post.status == params.status
      assert post.user_id == params.user_id
      assert post.section_id == params.section_id
      assert post.resource_id == params.resource_id
      assert post.anonymous == params.anonymous
    end

    test "create_post/1 with existing name returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Collaboration.create_post(%{status: :testing})
    end

    test "get_post_by/1 returns a post when the id exists" do
      post = insert(:post)

      returned_post = Collaboration.get_post_by(%{id: post.id})

      assert post.id == returned_post.id
      assert post.content.message == returned_post.content.message
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

    test "search_posts/1 returns empty when no posts meets the criteria" do
      insert_pair(:post)

      assert [] == Collaboration.search_posts(%{status: :deleted})
    end

    test "list_posts_for_user_in_page_section/3 returns posts meeting the criteria" do
      user = insert(:user)
      section = insert(:section)
      resource = insert(:resource)

      parent_post = insert(:post, user: user, section: section, resource: resource)
      insert(:post, thread_root: parent_post, user: user, section: section, resource: resource)

      insert(:post,
        thread_root: parent_post,
        user: user,
        section: section,
        resource: resource,
        status: :deleted
      )

      insert(:post,
        thread_root: parent_post,
        user: user,
        section: section,
        resource: resource,
        status: :submitted
      )

      insert(:post,
        thread_root: parent_post,
        section: section,
        resource: resource,
        status: :submitted
      )

      insert(:post, user: user, section: section, resource: resource, status: :archived)
      insert(:post, user: user, section: section, resource: resource, status: :submitted)

      insert(:post, section: section, resource: resource, status: :submitted)
      insert(:post, user: user, section: section, resource: resource, status: :deleted)

      posts = Collaboration.list_posts_for_user_in_page_section(section.id, resource.id, user.id)

      assert 5 == length(posts)
      assert 2 == posts |> Enum.filter(&(&1.thread_root_id == parent_post.id)) |> length()
    end

    test "list_posts_for_user_in_page_section/3 returns empty when no posts meets the criteria" do
      user = insert(:user)
      section = insert(:section)
      resource = insert(:resource)

      insert_pair(:post)

      assert [] ==
               Collaboration.list_posts_for_user_in_page_section(section.id, resource.id, user.id)
    end

    test "list_posts_for_user_in_page_section/4 returns posts after the enter time" do
      enter_time = yesterday()

      user = insert(:user)
      section = insert(:section)
      resource = insert(:resource)

      insert(:post, user: user, section: section, resource: resource)

      assert 1 ==
               length(
                 Collaboration.list_posts_for_user_in_page_section(
                   section.id,
                   resource.id,
                   user.id,
                   enter_time
                 )
               )
    end

    test "list_posts_for_user_in_page_section/4 do not return posts before the enter time" do
      enter_time = tomorrow()

      user = insert(:user)
      section = insert(:section)
      resource = insert(:resource)

      insert(:post, user: user, section: section, resource: resource)

      assert 0 ==
               length(
                 Collaboration.list_posts_for_user_in_page_section(
                   section.id,
                   resource.id,
                   user.id,
                   enter_time
                 )
               )
    end

    test "list_posts_for_instructor_in_page_section/2 returns posts meeting the criteria" do
      section = insert(:section)
      resource = insert(:resource)

      parent_post = insert(:post, section: section, resource: resource)
      insert(:post, thread_root: parent_post, section: section, resource: resource)

      insert(:post,
        thread_root: parent_post,
        section: section,
        resource: resource,
        status: :deleted
      )

      insert(:post,
        thread_root: parent_post,
        section: section,
        resource: resource,
        status: :submitted
      )

      insert(:post,
        thread_root: parent_post,
        section: section,
        resource: resource,
        status: :archived
      )

      insert(:post, section: section, resource: resource, status: :archived)
      insert(:post, section: section, resource: resource, status: :submitted)
      insert(:post, section: section, resource: resource, status: :deleted)

      insert(:post, section: section)
      insert(:post, resource: resource)

      posts = Collaboration.list_posts_for_instructor_in_page_section(section.id, resource.id)

      assert 6 == length(posts)
      assert 3 == posts |> Enum.filter(&(&1.thread_root_id == parent_post.id)) |> length()
    end

    test "list_posts_for_instructor_in_page_section/2 returns empty when no posts meets the criteria" do
      section = insert(:section)
      resource = insert(:resource)

      insert_pair(:post)

      assert [] ==
               Collaboration.list_posts_for_instructor_in_page_section(section.id, resource.id)
    end

    test "delete_posts/1 delete the posts successfully" do
      section = insert(:section)
      resource = insert(:resource)

      parent_post = insert(:post, section: section, resource: resource)
      reply = insert(:post, section: section, resource: resource, thread_root: parent_post)
      post = insert(:post, section: section, resource: resource)

      {number, nil} = Collaboration.delete_posts(parent_post)

      assert 2 == number

      assert %Post{status: :deleted} = Collaboration.get_post_by(%{id: parent_post.id})
      assert %Post{status: :deleted} = Collaboration.get_post_by(%{id: reply.id})
      assert %Post{status: :approved} = Collaboration.get_post_by(%{id: post.id})
    end
  end
end
