defmodule OliWeb.Delivery.Student.DiscussionsLiveTest do
  use ExUnit.Case, async: true
  alias Oli.Resources.Collaboration
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import Ecto.Query, warn: false

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Resources.ResourceType

  defp live_view_discussions_live_route(section_slug) do
    ~p"/sections/#{section_slug}/discussions"
  end

  defp create_elixir_project(_) do
    author = insert(:author)
    project = insert(:project, authors: [author])

    # revisions...
    ## pages...
    page_1_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Start here",
        collab_space_config: build(:collab_space_config, status: :enabled)
      )

    page_2_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 2",
        collab_space_config: build(:collab_space_config, status: :enabled)
      )

    page_3_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 3",
        collab_space_config: build(:collab_space_config, status: :enabled)
      )

    page_4_revision =
      insert(:revision,
        resource_type_id: ResourceType.get_id_by_type("page"),
        title: "Page 4",
        collab_space_config: build(:collab_space_config, status: :enabled)
      )

    ## modules...
    module_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_1_revision.resource_id, page_2_revision.resource_id],
        title: "How to use this course"
      })

    module_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [page_3_revision.resource_id],
        title: "Configure your setup"
      })

    ## units...
    unit_1_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_1_revision.resource_id],
        title: "Introduction"
      })

    unit_2_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [module_2_revision.resource_id],
        title: "Building a Phoenix app"
      })

    ## root container...
    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        children: [
          unit_1_revision.resource_id,
          unit_2_revision.resource_id,
          page_4_revision.resource_id
        ],
        title: "Root Container",
        collab_space_config: build(:collab_space_config, status: :enabled)
      })

    all_revisions =
      [
        page_1_revision,
        page_2_revision,
        page_3_revision,
        page_4_revision,
        module_1_revision,
        module_2_revision,
        unit_1_revision,
        unit_2_revision,
        container_revision
      ]

    # asociate resources to project
    Enum.each(all_revisions, fn revision ->
      insert(:project_resource, %{
        project_id: project.id,
        resource_id: revision.resource_id
      })
    end)

    # publish project
    publication =
      insert(:publication, %{project: project, root_resource_id: container_revision.resource_id})

    # publish resources
    Enum.each(all_revisions, fn revision ->
      insert(:published_resource, %{
        publication: publication,
        resource: revision.resource,
        revision: revision,
        author: author
      })
    end)

    # create section...
    section =
      insert(:section,
        base_project: project,
        title: "The best course ever!"
      )

    {:ok, section} = Sections.create_section_resources(section, publication)
    {:ok, _} = Sections.rebuild_contained_pages(section)
    {:ok, _} = Sections.update_resource_to_container_map(section)
    {:ok, _} = Sections.rebuild_full_hierarchy(section)

    # enroll another student to the section
    student_2 = insert(:user, %{name: "Angel Di Maria"})
    Sections.enroll(student_2.id, section.id, [ContextRoles.get_role(:context_learner)])

    %{
      section: section,
      page_1: page_1_revision,
      page_2: page_2_revision,
      page_3: page_3_revision,
      page_4: page_4_revision,
      module_1: module_1_revision,
      module_2: module_2_revision,
      unit_1: unit_1_revision,
      unit_2: unit_2_revision,
      root_container: container_revision,
      student_2: student_2
    }
  end

  describe "user" do
    test "can not access page when it is not logged in", %{conn: conn} do
      section = insert(:section)
      student = insert(:user)

      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:error, {:redirect, %{to: redirect_path}}} =
        live(conn, live_view_discussions_live_route(section.slug))

      assert redirect_path ==
               "/session/new?request_path=%2Fsections%2F#{section.slug}%2Fdiscussions&section=#{section.slug}"
    end
  end

  describe "student" do
    setup attrs do
      {:ok, conn: conn, user: user} = user_conn(attrs, %{name: "Lionel Messi"})

      Map.merge(%{conn: conn, student: user}, create_elixir_project(conn))
    end

    test "can not access when not enrolled to course", %{conn: conn, section: section} do
      {:error, {:redirect, %{to: redirect_path, flash: _flash_msg}}} =
        live(conn, live_view_discussions_live_route(section.slug))

      assert redirect_path == "/unauthorized"
    end

    test "can access when enrolled to course", %{
      conn: conn,
      student: student,
      section: section
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      assert has_element?(view, ~s{section[id="posts"] div[role="posts header"] h3}, "Posts")
    end

    test "can see course discussion and page posts", %{
      conn: conn,
      student: student,
      section: section,
      root_container: root_container,
      page_1: page_1,
      student_2: student_2
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      page_post =
        insert(:post, %{
          section: section,
          resource: page_1.resource,
          user: student_2,
          content: %{message: "My first page post"}
        })

      course_discussion =
        insert(:post, %{
          section: section,
          resource: root_container.resource,
          user: student,
          content: %{message: "My first discussion"}
        })

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      assert view
             |> element("div[id=\"post-#{page_post.id}\"]")
             |> render() =~ "My first page post"

      assert view
             |> element("div[id=\"post-#{course_discussion.id}\"]")
             |> render() =~ "My first discussion"
    end

    test "can see all details for a course discussion", %{
      conn: conn,
      student: student,
      section: section,
      root_container: root_container,
      student_2: student_2
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      course_discussion =
        insert(:post, %{
          section: section,
          resource: root_container.resource,
          user: student,
          content: %{message: "My first discussion"},
          inserted_at: ~U[2023-12-01 00:00:00Z],
          updated_at: ~U[2023-12-01 00:00:00Z]
        })

      already_read_reply =
        insert(:post,
          section: section,
          resource: root_container.resource,
          user: student_2,
          content: %{message: "This is a reply to the first discussion"},
          thread_root_id: course_discussion.id,
          parent_post_id: course_discussion.id,
          inserted_at: ~U[2023-12-02 00:00:00Z],
          updated_at: ~U[2023-12-02 00:00:00Z]
        )

      Collaboration.mark_posts_as_read([already_read_reply], student.id)

      _not_read_reply =
        insert(:post,
          section: section,
          resource: root_container.resource,
          user: student_2,
          content: %{message: "This is another reply to the first discussion"},
          thread_root_id: course_discussion.id,
          parent_post_id: course_discussion.id,
          inserted_at: ~U[2023-12-03 00:00:00Z],
          updated_at: ~U[2023-12-03 00:00:00Z]
        )

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      ## post header
      # student name
      assert view
             |> element(
               "div[id=\"post-#{course_discussion.id}\"] div[role=\"post header\"] span[role=\"user name\"]"
             )
             |> render() =~ "Lionel Messi"

      # avatar initials
      assert view
             |> element(
               "div[id=\"post-#{course_discussion.id}\"] div[role=\"post header\"] span[role=\"avatar initials\"]"
             )
             |> render() =~ "LM"

      # date posted
      assert view
             |> element(
               "div[id=\"post-#{course_discussion.id}\"] div[role=\"post header\"] span[role=\"posted at\"]"
             )
             |> render() =~ "Fri, Dec 1, 2023"

      ## post content
      # message
      assert view
             |> element("div[id=\"post-#{course_discussion.id}\"] div[role=\"post content\"]")
             |> render() =~ "My first discussion"

      ## post footer
      # replies count
      assert view
             |> element(
               "div[id=\"post-#{course_discussion.id}\"] div[role=\"post footer\"] span[role=\"replies count\"]"
             )
             |> render() =~ "2"

      # unread replies count
      assert view
             |> element(
               "div[id=\"post-#{course_discussion.id}\"] div[role=\"post footer\"] span[role=\"unread count\"]"
             )
             |> render() =~ "1"

      # last reply date
      assert view
             |> element(
               "div[id=\"post-#{course_discussion.id}\"] div[role=\"post footer\"] div[role=\"last reply date\"]"
             )
             |> render() =~ "Sun, Dec 3, 2023"
    end

    test "can see all details for a page post", %{
      conn: conn,
      student: student,
      section: section,
      page_1: page_1,
      student_2: student_2
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      page_post =
        insert(:post, %{
          section: section,
          resource: page_1.resource,
          user: student,
          content: %{message: "My first page post"},
          inserted_at: ~U[2023-12-01 00:00:00Z],
          updated_at: ~U[2023-12-01 00:00:00Z]
        })

      already_read_reply =
        insert(:post,
          section: section,
          resource: page_1.resource,
          user: student_2,
          content: %{message: "This is a reply to the first page post"},
          thread_root_id: page_post.id,
          parent_post_id: page_post.id,
          inserted_at: ~U[2023-12-02 00:00:00Z],
          updated_at: ~U[2023-12-02 00:00:00Z]
        )

      Collaboration.mark_posts_as_read([already_read_reply], student.id)

      _not_read_reply =
        insert(:post,
          section: section,
          resource: page_1.resource,
          user: student_2,
          content: %{message: "This is another reply to the first page post"},
          thread_root_id: page_post.id,
          parent_post_id: page_post.id,
          inserted_at: ~U[2023-12-03 00:00:00Z],
          updated_at: ~U[2023-12-03 00:00:00Z]
        )

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      ## post header
      # student name
      assert view
             |> element(
               "div[id=\"post-#{page_post.id}\"] div[role=\"post header\"] span[role=\"user name\"]"
             )
             |> render() =~ "Lionel Messi"

      # avatar initials
      assert view
             |> element(
               "div[id=\"post-#{page_post.id}\"] div[role=\"post header\"] span[role=\"avatar initials\"]"
             )
             |> render() =~ "LM"

      # date posted
      assert view
             |> element(
               "div[id=\"post-#{page_post.id}\"] div[role=\"post header\"] span[role=\"posted at\"]"
             )
             |> render() =~ "Fri, Dec 1, 2023"

      ## post content
      # page numbering
      assert view
             |> element(
               "div[id=\"post-#{page_post.id}\"] div[role=\"post location\"] span[role=\"numbering\"]"
             )
             |> render() =~ "Module 1: Page 1"

      # page title
      assert view
             |> element(
               "div[id=\"post-#{page_post.id}\"] div[role=\"post location\"] span[role=\"page title\"]"
             )
             |> render() =~ "Start here"

      # message
      assert view
             |> element("div[id=\"post-#{page_post.id}\"] div[role=\"post content\"]")
             |> render() =~ "My first page post"

      ## post footer
      # replies count
      assert view
             |> element(
               "div[id=\"post-#{page_post.id}\"] div[role=\"post footer\"] span[role=\"replies count\"]"
             )
             |> render() =~ "2"

      # unread replies count
      assert view
             |> element(
               "div[id=\"post-#{page_post.id}\"] div[role=\"post footer\"] span[role=\"unread count\"]"
             )
             |> render() =~ "1"

      # last reply date
      assert view
             |> element(
               "div[id=\"post-#{page_post.id}\"] div[role=\"post footer\"] div[role=\"last reply date\"]"
             )
             |> render() =~ "Sun, Dec 3, 2023"
    end

    # can create a new discussion

    # can expand and collapse discussions

    # can expand and collapse replies

    # can navigate to a page from a page post
  end
end
