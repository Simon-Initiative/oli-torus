defmodule Oli.Resources.CollaborationTest do
  use Oli.DataCase

  import Oli.Factory
  import Oli.Utils.Seeder.Utils

  alias Oli.Utils.Seeder
  alias Oli.Resources
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.{CollabSpaceConfig, Post}
  alias Oli.Delivery.Sections
  alias Oli.Publishing.DeliveryResolver
  alias Lti_1p3.Roles.ContextRoles

  defp build_project_with_one_collab_space(published \\ nil) do
    page_revision_1 =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page(),
        collab_space_config: %CollabSpaceConfig{status: :enabled}
      )

    page_revision_2 =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page()
      )

    page_revision_3 =
      insert(:revision,
        resource_type_id: Oli.Resources.ResourceType.id_for_page()
      )

    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_container(),
        children: [
          page_revision_1.resource_id,
          page_revision_2.resource_id,
          page_revision_3.resource_id
        ],
        content: %{},
        deleted: false,
        slug: "root_container",
        title: "Root Container"
      })

    project = insert(:project)

    insert(:project_resource, %{project_id: project.id, resource_id: page_revision_1.resource_id})
    insert(:project_resource, %{project_id: project.id, resource_id: page_revision_2.resource_id})
    insert(:project_resource, %{project_id: project.id, resource_id: page_revision_3.resource_id})

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: container_revision.resource_id
    })

    # Publication of project with root container
    publication =
      insert(:publication, %{
        project: project,
        published: published,
        root_resource_id: container_revision.resource_id
      })

    # Publish resources
    insert(:published_resource, %{
      publication: publication,
      resource: container_revision.resource,
      revision: container_revision
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_revision_1.resource,
      revision: page_revision_1
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_revision_2.resource,
      revision: page_revision_2
    })

    insert(:published_resource, %{
      publication: publication,
      resource: page_revision_3.resource,
      revision: page_revision_3
    })

    %{project: project, publication: publication, page_revision_1: page_revision_1}
  end

  defp build_section_with_one_collab_space() do
    %{project: project, publication: publication, page_revision_1: page_revision_1} =
      build_project_with_one_collab_space(DateTime.utc_now())

    section = insert(:section, base_project: project)

    {:ok, section} = Sections.create_section_resources(section, publication)

    Sections.get_section_resource(section.id, page_revision_1.resource_id)
    |> Sections.update_section_resource(%{
      collab_space_config: %CollabSpaceConfig{status: :enabled}
    })

    Sections.get_section!(section.id)
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

      assert {0, []} == Collaboration.list_collaborative_spaces_in_section(section.slug)
    end

    test "list_collaborative_spaces_in_section/1 returns collab spaces correctly with posts configured in pages" do
      {:ok,
       %{
         page_revision_cs: page_revision_cs,
         collab_space_config: collab_space_config,
         section: section
       }} = create_project_with_collab_space_and_posts()

      assert {1,
              [
                %{
                  collab_space_config: returned_collab_space_config,
                  page: page,
                  number_of_posts: 2,
                  number_of_posts_pending_approval: 1,
                  most_recent_post: _most_recent_post,
                  section: returned_section
                }
              ]} = Collaboration.list_collaborative_spaces_in_section(section.slug)

      assert returned_collab_space_config["status"] |> String.to_atom() ==
               collab_space_config.status

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

    test "count_collab_spaces_enabled_in_pages_for_project/1 returns the correct count" do
      %{project: %{slug: project_slug}} = build_project_with_one_collab_space()

      assert {1, 3} ==
               Collaboration.count_collab_spaces_enabled_in_pages_for_project(project_slug)
    end

    test "count_collab_spaces_enabled_in_pages_for_section/1 returns the correct count" do
      section = build_section_with_one_collab_space()

      assert {1, 3} ==
               Collaboration.count_collab_spaces_enabled_in_pages_for_section(section.slug)
    end

    test "disable_all_page_collab_spaces_for_project/1 sets all collab spaces to status = disabled" do
      %{project: %{slug: project_slug}} = build_project_with_one_collab_space()

      {disabled_count, revisions} =
        Collaboration.disable_all_page_collab_spaces_for_project(project_slug)

      assert disabled_count == 3

      Enum.each(revisions, fn revision ->
        assert %CollabSpaceConfig{status: :disabled} = revision.collab_space_config
      end)

      assert {0, 3} ==
               Collaboration.count_collab_spaces_enabled_in_pages_for_project(project_slug)
    end

    test "disable_all_page_collab_spaces_for_section/1 sets all collab spaces to status = disabled" do
      section = build_section_with_one_collab_space()

      {disabled_count, section_resources} =
        Collaboration.disable_all_page_collab_spaces_for_section(section.slug)

      assert disabled_count == 3

      Enum.each(section_resources, fn section_resource ->
        assert %CollabSpaceConfig{status: :disabled} =
                 section_resource.collab_space_config
      end)

      assert {0, 3} ==
               Collaboration.count_collab_spaces_enabled_in_pages_for_section(section.slug)
    end

    test "enable_all_page_collab_spaces_for_project/2 enables all collab spaces with the given config" do
      %{project: %{slug: project_slug}} = build_project_with_one_collab_space()

      collab_space_config =
        %CollabSpaceConfig{status: :enabled, threaded: false}

      {enabled_count, revisions} =
        Collaboration.enable_all_page_collab_spaces_for_project(project_slug, collab_space_config)

      assert enabled_count == 3

      Enum.each(revisions, fn revision ->
        assert %CollabSpaceConfig{status: :enabled, threaded: false} =
                 revision.collab_space_config
      end)

      assert {3, 3} ==
               Collaboration.count_collab_spaces_enabled_in_pages_for_project(project_slug)
    end

    test "enable_all_page_collab_spaces_for_section/2 enables all collab spaces with the given config" do
      section = build_section_with_one_collab_space()

      collab_space_config =
        %CollabSpaceConfig{status: :enabled, threaded: false}

      {enabled_count, section_resources} =
        Collaboration.enable_all_page_collab_spaces_for_section(section.slug, collab_space_config)

      assert enabled_count == 3

      Enum.each(section_resources, fn section_resource ->
        assert %CollabSpaceConfig{status: :enabled, threaded: false} =
                 section_resource.collab_space_config
      end)

      assert {3, 3} ==
               Collaboration.count_collab_spaces_enabled_in_pages_for_section(section.slug)
    end
  end

  describe "soft_delete_post/2 authorization" do
    setup do
      section = insert(:section)
      owner = insert(:user)
      other_user = insert(:user)
      instructor = insert(:user)

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])

      post =
        insert(:post,
          user: owner,
          section: section
        )

      %{
        section: section,
        owner: owner,
        other_user: other_user,
        instructor: instructor,
        post: post
      }
    end

    test "allows owner to delete", %{owner: owner, post: post} do
      assert {1, _} = Collaboration.soft_delete_post(post.id, owner)
      assert %{status: :deleted} = Collaboration.get_post_by(%{id: post.id})
    end

    test "prevents other student from deleting", %{other_user: other_user, post: post} do
      assert {:error, :unauthorized} = Collaboration.soft_delete_post(post.id, other_user)
      assert %{status: :approved} = Collaboration.get_post_by(%{id: post.id})
    end

    test "allows instructor for the section to delete", %{instructor: instructor, post: post} do
      assert {1, _} = Collaboration.soft_delete_post(post.id, instructor)
      assert %{status: :deleted} = Collaboration.get_post_by(%{id: post.id})
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

      assert Enum.empty?(
               Collaboration.list_posts_for_user_in_page_section(
                 section.id,
                 resource.id,
                 user.id,
                 enter_time
               )
             )
    end

    test "count_posts_and_replies_for_user/3 returns correct counts for posts and replies" do
      user = insert(:user)
      other_user = insert(:user)
      section = insert(:section)
      other_section = insert(:section)
      resource = insert(:resource)
      other_resource = insert(:resource)

      # Create top-level posts for the user in the target section/resource
      parent_post1 = insert(:post, user: user, section: section, resource: resource)
      parent_post2 = insert(:post, user: user, section: section, resource: resource)

      # Create replies for the user in the target section/resource
      insert(:post,
        user: user,
        section: section,
        resource: resource,
        parent_post_id: parent_post1.id,
        thread_root_id: parent_post1.id
      )

      insert(:post,
        user: user,
        section: section,
        resource: resource,
        parent_post_id: parent_post1.id,
        thread_root_id: parent_post1.id
      )

      insert(:post,
        user: user,
        section: section,
        resource: resource,
        parent_post_id: parent_post2.id,
        thread_root_id: parent_post2.id,
        status: :submitted
      )

      # Create posts for other users (should not be counted)
      insert(:post, user: other_user, section: section, resource: resource)

      insert(:post,
        user: other_user,
        section: section,
        resource: resource,
        parent_post_id: parent_post1.id,
        thread_root_id: parent_post1.id
      )

      # Create posts in other sections (should not be counted)
      insert(:post, user: user, section: other_section, resource: resource)

      insert(:post,
        user: user,
        section: other_section,
        resource: resource,
        parent_post_id: parent_post1.id,
        thread_root_id: parent_post1.id
      )

      # Create posts in other resources (should not be counted)
      insert(:post, user: user, section: section, resource: other_resource)

      insert(:post,
        user: user,
        section: section,
        resource: other_resource,
        parent_post_id: parent_post1.id,
        thread_root_id: parent_post1.id
      )

      # Create deleted posts (should not be counted)
      insert(:post,
        user: user,
        section: section,
        resource: resource,
        status: :deleted
      )

      insert(:post,
        user: user,
        section: section,
        resource: resource,
        parent_post_id: parent_post1.id,
        thread_root_id: parent_post1.id,
        status: :deleted
      )

      {posts_count, replies_count} =
        Collaboration.count_posts_and_replies_for_user(section.id, resource.id, user.id)

      assert posts_count == 2
      assert replies_count == 3
    end

    test "count_posts_and_replies_for_user/3 returns {0, 0} when no posts exist" do
      user = insert(:user)
      section = insert(:section)
      resource = insert(:resource)

      {posts_count, replies_count} =
        Collaboration.count_posts_and_replies_for_user(section.id, resource.id, user.id)

      assert posts_count == 0
      assert replies_count == 0
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

  describe "audience" do
    setup do
      %{}
      |> Seeder.Project.create_author(author_tag: :author)
      |> Seeder.Project.create_sample_project(
        ref(:author),
        project_tag: :proj,
        publication_tag: :pub,
        curriculum_revision_tag: :curriculum,
        unscored_page1_tag: :page1
      )
      |> Seeder.Project.ensure_published(ref(:pub), publication_tag: :pub)
      |> Seeder.Section.create_section(
        ref(:proj),
        ref(:pub),
        nil,
        %{},
        section_tag: :section
      )
      |> Seeder.Section.create_and_enroll_learner(
        ref(:section),
        %{},
        user_tag: :student1
      )
      |> Seeder.Section.create_and_enroll_learner(
        ref(:section),
        %{},
        user_tag: :student2
      )
    end

    test "search_posts_for_user_in_point_block/6 returns all posts with given search term", %{
      section: section,
      page1: page1,
      student1: student1
    } do
      create_post(student1.id, section.id, page1.resource_id, "test")
      create_post(student1.id, section.id, page1.resource_id, "another test")
      create_post(student1.id, section.id, page1.resource_id, "no match")

      create_post(student1.id, section.id, page1.resource_id, "private note",
        visibility: :private
      )

      create_post(student1.id, section.id, page1.resource_id, "point block test",
        annotation_type: :point,
        annotated_block_id: "block1"
      )

      create_post(student1.id, section.id, page1.resource_id, "point block no match",
        annotation_type: :point,
        annotated_block_id: "block1"
      )

      create_post(student1.id, section.id, page1.resource_id, "my note",
        visibility: :private,
        annotation_type: :point,
        annotated_block_id: "block1"
      )

      # get all public notes for a resource
      results =
        Collaboration.search_posts_for_user_in_point_block(
          section.id,
          page1.resource_id,
          student1.id,
          :public,
          nil,
          "test"
        )

      assert length(results) == 3
      assert Enum.all?(results, &(&1.content.message =~ "test"))

      refute Enum.any?(results, &(&1.content.message =~ "no match"))

      # get all private notes for a resource
      results =
        Collaboration.search_posts_for_user_in_point_block(
          section.id,
          page1.resource_id,
          student1.id,
          :private,
          nil,
          "note"
        )

      assert length(results) == 2
      assert Enum.all?(results, &(&1.content.message =~ "note"))

      # get all public notes for a particular point block
      results =
        Collaboration.search_posts_for_user_in_point_block(
          section.id,
          page1.resource_id,
          student1.id,
          :public,
          "block1",
          "test"
        )

      assert length(results) == 1
      assert Enum.all?(results, &(&1.content.message =~ "test"))
    end

    test "list_posts_for_user_in_point_block/5 returns correct private notes and counts", %{
      section: section,
      page1: page1,
      student1: student1,
      student2: student2
    } do
      create_post(student1.id, section.id, page1.resource_id, "student 1 public note",
        visibility: :public
      )

      create_post(student1.id, section.id, page1.resource_id, "student 1 private note 1",
        visibility: :private,
        annotation_type: :point,
        annotated_block_id: "block1"
      )

      create_post(student1.id, section.id, page1.resource_id, "student 1 private note 2",
        visibility: :private,
        annotation_type: :point,
        annotated_block_id: "block1"
      )

      create_post(student1.id, section.id, page1.resource_id, "student 1 private note 3",
        visibility: :private,
        annotation_type: :point,
        annotated_block_id: "block1"
      )

      create_post(student2.id, section.id, page1.resource_id, "student 2 private note 1",
        visibility: :private,
        annotation_type: :point,
        annotated_block_id: "block1"
      )

      create_post(student2.id, section.id, page1.resource_id, "student 2 private note 2",
        visibility: :private,
        annotation_type: :point,
        annotated_block_id: "block1"
      )

      # get all private notes for a resource and student
      student1_private_notes =
        Collaboration.list_posts_for_user_in_point_block(
          section.id,
          page1.resource_id,
          student1.id,
          :private,
          nil
        )

      student1_private_notes_counts =
        Collaboration.list_post_counts_for_user_in_section(
          section.id,
          page1.resource_id,
          student1.id,
          :private
        )

      assert length(student1_private_notes) == 3
      assert Enum.all?(student1_private_notes, &(&1.content.message =~ "student 1 private note"))

      refute Enum.any?(student1_private_notes, &(&1.content.message =~ "student 1 public note"))

      assert %{"block1" => 3} == student1_private_notes_counts

      student2_private_notes =
        Collaboration.list_posts_for_user_in_point_block(
          section.id,
          page1.resource_id,
          student2.id,
          :private,
          nil
        )

      student2_private_notes_counts =
        Collaboration.list_post_counts_for_user_in_section(
          section.id,
          page1.resource_id,
          student2.id,
          :private
        )

      assert length(student2_private_notes) == 2
      assert Enum.all?(student2_private_notes, &(&1.content.message =~ "student 2 private note"))

      refute Enum.any?(student2_private_notes, &(&1.content.message =~ "student 2 public note"))

      assert %{"block1" => 2} == student2_private_notes_counts
    end

    test "get_total_count_of_unread_replies_for_root_discussions/2 returns unread reply counts for posts created by user",
         %{
           section: section,
           student1: student1,
           student2: student2
         } do
      %{resource_id: root_curriculum_resource_id} =
        DeliveryResolver.root_container(section.slug)

      create_post(
        student1.id,
        section.id,
        root_curriculum_resource_id,
        "student 1 root discussion"
      )

      create_post(
        student2.id,
        section.id,
        root_curriculum_resource_id,
        "student 2 root discussion"
      )

      {:ok, parent_post} =
        create_post(
          student1.id,
          section.id,
          root_curriculum_resource_id,
          "student 1 2nd root discussion"
        )

      create_post(
        student1.id,
        section.id,
        root_curriculum_resource_id,
        "student 1 2nd root discussion reply",
        parent_post_id: parent_post.id,
        thread_root_id: parent_post.id
      )

      create_post(
        student2.id,
        section.id,
        root_curriculum_resource_id,
        "student 2 2nd root discussion reply",
        parent_post_id: parent_post.id,
        thread_root_id: parent_post.id
      )

      unread_reply_counts =
        Collaboration.get_total_count_of_unread_replies_for_root_discussions(
          student1.id,
          root_curriculum_resource_id
        )

      assert unread_reply_counts == 1

      # mark reply as read
      Collaboration.mark_course_discussions_and_replies_read(
        student1.id,
        root_curriculum_resource_id
      )

      unread_reply_counts =
        Collaboration.get_total_count_of_unread_replies_for_root_discussions(
          student1.id,
          root_curriculum_resource_id
        )

      assert unread_reply_counts == 0

      # add two more replies
      create_post(
        student2.id,
        section.id,
        root_curriculum_resource_id,
        "student 2 2nd root discussion reply 2",
        parent_post_id: parent_post.id,
        thread_root_id: parent_post.id
      )

      create_post(
        student2.id,
        section.id,
        root_curriculum_resource_id,
        "student 2 2nd root discussion reply 3",
        parent_post_id: parent_post.id,
        thread_root_id: parent_post.id
      )

      unread_reply_counts =
        Collaboration.get_total_count_of_unread_replies_for_root_discussions(
          student1.id,
          root_curriculum_resource_id
        )

      assert unread_reply_counts == 2
    end

    test "get_unread_reply_counts_for_root_discussions/2 returns the root posts with unread replies flag",
         %{
           section: section,
           student1: student1,
           student2: student2
         } do
      %{resource_id: root_curriculum_resource_id} =
        DeliveryResolver.root_container(section.slug)

      # root posts
      {:ok, parent_post1} =
        create_post(
          student1.id,
          section.id,
          root_curriculum_resource_id,
          "student 1 root discussion"
        )

      {:ok, parent_post2} =
        create_post(
          student2.id,
          section.id,
          root_curriculum_resource_id,
          "student 2 root discussion"
        )

      {:ok, parent_post3} =
        create_post(
          student1.id,
          section.id,
          root_curriculum_resource_id,
          "student 1 2nd root discussion"
        )

      # create replies
      create_post(
        student1.id,
        section.id,
        root_curriculum_resource_id,
        "student 1 parent_post1 reply",
        parent_post_id: parent_post1.id,
        thread_root_id: parent_post1.id
      )

      create_post(
        student2.id,
        section.id,
        root_curriculum_resource_id,
        "student 2 parent_post1 reply",
        parent_post_id: parent_post1.id,
        thread_root_id: parent_post1.id
      )

      parent_post1_id = parent_post1.id

      assert Collaboration.get_unread_reply_counts_for_root_discussions(
               student1.id,
               root_curriculum_resource_id
             ) == %{
               parent_post1_id => 1
             }

      # add two more replies to the parent post 1 and a reply from student 1
      create_post(
        student2.id,
        section.id,
        root_curriculum_resource_id,
        "student 2 parent_post1 reply 2",
        parent_post_id: parent_post1.id,
        thread_root_id: parent_post1.id
      )

      create_post(
        student2.id,
        section.id,
        root_curriculum_resource_id,
        "student 2 parent_post1 reply 3",
        parent_post_id: parent_post1.id,
        thread_root_id: parent_post1.id
      )

      create_post(
        student1.id,
        section.id,
        root_curriculum_resource_id,
        "student 1 parent_post1 reply 1",
        parent_post_id: parent_post1.id,
        thread_root_id: parent_post1.id
      )

      assert Collaboration.get_unread_reply_counts_for_root_discussions(
               student1.id,
               root_curriculum_resource_id
             ) == %{
               parent_post1_id => 3
             }

      create_post(
        student2.id,
        section.id,
        root_curriculum_resource_id,
        "student 2 parent_post3 reply",
        parent_post_id: parent_post3.id,
        thread_root_id: parent_post3.id
      )

      parent_post3_id = parent_post3.id

      assert Collaboration.get_unread_reply_counts_for_root_discussions(
               student1.id,
               root_curriculum_resource_id
             ) == %{
               parent_post1_id => 3,
               parent_post3_id => 1
             }

      assert Collaboration.get_unread_reply_counts_for_root_discussions(
               student2.id,
               root_curriculum_resource_id
             ) == %{}

      create_post(
        student1.id,
        section.id,
        root_curriculum_resource_id,
        "student 1 parent_post2 reply",
        parent_post_id: parent_post2.id,
        thread_root_id: parent_post2.id
      )

      parent_post2_id = parent_post2.id

      assert Collaboration.get_unread_reply_counts_for_root_discussions(
               student2.id,
               root_curriculum_resource_id
             ) == %{parent_post2_id => 1}
    end

    test "list_root_posts_for_section/8 returns root posts with metadata",
         %{
           section: section,
           student1: student1,
           student2: student2
         } do
      %{resource_id: root_curriculum_resource_id} =
        DeliveryResolver.root_container(section.slug)

      # root posts
      {:ok, parent_post1} =
        create_post(
          student1.id,
          section.id,
          root_curriculum_resource_id,
          "student 1 root discussion"
        )

      {:ok, parent_post2} =
        create_post(
          student2.id,
          section.id,
          root_curriculum_resource_id,
          "student 2 root discussion"
        )

      {:ok, parent_post3} =
        create_post(
          student1.id,
          section.id,
          root_curriculum_resource_id,
          "student 1 root discussion 2"
        )

      # create replies
      create_post(
        student1.id,
        section.id,
        root_curriculum_resource_id,
        "student 1 parent_post1 reply",
        parent_post_id: parent_post1.id,
        thread_root_id: parent_post1.id
      )

      create_post(
        student2.id,
        section.id,
        root_curriculum_resource_id,
        "student 2 parent_post1 reply",
        parent_post_id: parent_post1.id,
        thread_root_id: parent_post1.id
      )

      parent_post1_id = parent_post1.id
      parent_post2_id = parent_post2.id
      parent_post3_id = parent_post3.id

      assert {[
                %Post{id: ^parent_post1_id, unread_replies_count: 1},
                %Post{id: ^parent_post3_id, unread_replies_count: 0},
                %Post{id: ^parent_post2_id, unread_replies_count: 0}
              ], _more_posts_exist?} =
               Collaboration.list_root_posts_for_section(
                 student1.id,
                 section.id,
                 root_curriculum_resource_id,
                 100,
                 0,
                 "unread",
                 :desc
               )
    end
  end

  defp create_post(user_id, section_id, resource_id, message, attrs \\ []) do
    attrs
    |> Enum.into(%{
      status: :approved,
      user_id: user_id,
      section_id: section_id,
      resource_id: resource_id,
      annotated_resource_id: resource_id,
      annotated_block_id: nil,
      annotation_type: :none,
      anonymous: true,
      visibility: :public,
      content: %Collaboration.PostContent{message: message}
    })
    |> Collaboration.create_post()
  end
end
