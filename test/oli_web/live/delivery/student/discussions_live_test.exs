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

  defp expand_post(view, post_id) do
    view
    |> element(
      "div[id=\"post-#{post_id}\"] div[role=\"post footer\"] button[phx-click=\"expand_post\"]"
    )
    |> render_click
  end

  defp collapse_post(view, post_id) do
    view
    |> element("div[id=\"post-#{post_id}\"] button[phx-click=\"collapse_post\"]")
    |> render_click
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
    {:ok, _} = Sections.update_page_to_container_map(section)

    # enable course collab space
    root_container_sr =
      Oli.Delivery.Sections.get_section_resource(section.id, container_revision.resource_id)

    {:ok, _} =
      Oli.Delivery.Sections.update_section_resource(root_container_sr, %{
        collab_space_config: build(:collab_space_config, status: :enabled)
      })

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
      student_2: student_2,
      root_container_sr: root_container_sr
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

  describe "student with course collab space enabled" do
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

    test "can create a new discussion", %{
      conn: conn,
      student: student,
      section: section,
      root_container: root_container
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      refute render(view) =~ "My first discussion :)"

      form(view, "form[id=\"new_discussion_form\"]")
      |> render_submit(%{
        post: %{
          user_id: student.id,
          section_id: section.id,
          resource_id: root_container.resource_id,
          content: %{message: "My first discussion :)"},
          status: :approved,
          anonymous: false
        }
      })

      assert render(view) =~ "My first discussion :)"
    end

    test "can create a new discussion anonymously", %{
      conn: conn,
      student: student,
      section: section,
      root_container: root_container
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      refute render(view) =~ "My first anon discussion :)"

      form(view, "form[id=\"new_discussion_form\"]")
      |> render_submit(%{
        post: %{
          user_id: student.id,
          section_id: section.id,
          resource_id: root_container.resource_id,
          content: %{message: "My first anon discussion :)"},
          status: :approved,
          anonymous: true
        }
      })

      assert render(view) =~ "My first anon discussion :)"
      assert render(view) =~ "Lionel Messi (anonymously)"
    end

    test "can reply to a discussion", %{
      conn: conn,
      section: section,
      root_container: root_container,
      student: student,
      student_2: student_2
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      course_discussion =
        insert(:post, %{
          section: section,
          resource: root_container.resource,
          user: student_2,
          content: %{message: "My first discussion"},
          inserted_at: ~U[2023-12-01 00:00:00Z],
          updated_at: ~U[2023-12-01 00:00:00Z]
        })

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      expand_post(view, course_discussion.id)

      refute render(view) =~ "This is a reply"

      form(view, "form[id=\"post_reply_form_#{course_discussion.id}\"]")
      |> render_submit(%{
        anonymous: false,
        content: %{message: "This is a reply"},
        parent_post_id: course_discussion.id,
        thread_root_id: course_discussion.id
      })

      assert render(view) =~ "This is a reply"
    end

    test "can expand and collapse discussions", %{
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

      _reply =
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

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      assert render(view) =~ "My first discussion"
      refute render(view) =~ "This is a reply to the first discussion"

      expand_post(view, course_discussion.id)

      assert render(view) =~ "My first discussion"
      assert render(view) =~ "This is a reply to the first discussion"

      collapse_post(view, course_discussion.id)

      assert render(view) =~ "My first discussion"
      refute render(view) =~ "This is a reply to the first discussion"
    end

    test "can expand and collapse a reply in a discussion", %{
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

      reply =
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

      _reply_to_reply =
        insert(:post,
          section: section,
          resource: root_container.resource,
          user: student,
          content: %{message: "This is a reply to the reply"},
          thread_root_id: course_discussion.id,
          parent_post_id: reply.id,
          inserted_at: ~U[2023-12-03 00:00:00Z],
          updated_at: ~U[2023-12-03 00:00:00Z]
        )

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      assert render(view) =~ "My first discussion"
      refute render(view) =~ "This is a reply to the first discussion"
      refute render(view) =~ "This is a reply to the reply"

      expand_post(view, course_discussion.id)

      assert render(view) =~ "My first discussion"
      assert render(view) =~ "This is a reply to the first discussion"
      refute render(view) =~ "This is a reply to the reply"

      expand_post(view, reply.id)

      assert render(view) =~ "My first discussion"
      assert render(view) =~ "This is a reply to the first discussion"
      assert render(view) =~ "This is a reply to the reply"

      collapse_post(view, reply.id)

      assert render(view) =~ "My first discussion"
      assert render(view) =~ "This is a reply to the first discussion"
      refute render(view) =~ "This is a reply to the reply"
    end

    test "can navigate to a page from a page post", %{
      conn: conn,
      student: student,
      section: section,
      page_1: page_1
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      page_post =
        insert(:post, %{
          section: section,
          resource: page_1.resource,
          user: student,
          content: %{message: "A page post"},
          inserted_at: ~U[2023-12-01 00:00:00Z],
          updated_at: ~U[2023-12-01 00:00:00Z]
        })

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      view
      |> element("div[id=\"post-#{page_post.id}\"] a[id=\"page_link_#{page_post.id}\"]")
      |> render_click

      assert_redirect(
        view,
        ~p"/sections/#{section.slug}/page/#{page_1.slug}"
      )
    end

    test "can not see the name of an anonymous post of other student", %{
      conn: conn,
      student: student,
      student_2: student_2,
      section: section,
      root_container: root_container
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      _course_discussion =
        insert(:post, %{
          section: section,
          resource: root_container.resource,
          user: student_2,
          content: %{message: "My first anonymous discussion"},
          inserted_at: ~U[2023-12-01 00:00:00Z],
          updated_at: ~U[2023-12-01 00:00:00Z],
          anonymous: true
        })

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))
      assert render(view) =~ "My first anonymous discussion"
      assert render(view) =~ "Anonymous User"
    end

    test "can see the `no posts` message when there are no posts", %{
      conn: conn,
      student: student,
      section: section
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      assert render(view) =~ "There are no discussions to show."
    end

    test "can see the `unread replies` divider above the FIRST unread post when expanding a discussion",
         %{
           conn: conn,
           student: student,
           section: section,
           student_2: student_2,
           root_container: root_container
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

      first_not_read_reply =
        insert(:post,
          section: section,
          resource: root_container.resource,
          user: student_2,
          content: %{message: "This is an unread reply"},
          thread_root_id: course_discussion.id,
          parent_post_id: course_discussion.id,
          inserted_at: ~U[2023-12-03 00:00:00Z],
          updated_at: ~U[2023-12-03 00:00:00Z]
        )

      second_not_read_reply =
        insert(:post,
          section: section,
          resource: root_container.resource,
          user: student_2,
          content: %{message: "This is another unread reply"},
          thread_root_id: course_discussion.id,
          parent_post_id: course_discussion.id,
          inserted_at: ~U[2023-12-03 00:00:00Z],
          updated_at: ~U[2023-12-03 00:00:00Z]
        )

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      expand_post(view, course_discussion.id)

      assert has_element?(
               view,
               "div[id=\"unread-division-post-#{first_not_read_reply.id}\"]",
               "UNREAD REPLIES"
             )

      refute has_element?(
               view,
               "div[id=\"unread-division-post-#{second_not_read_reply.id}\"]",
               "UNREAD REPLIES"
             )
    end

    test "can filter by unread posts", %{
      conn: conn,
      student: student,
      section: section,
      root_container: root_container,
      student_2: student_2
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      read_discussion =
        insert(:post, %{
          section: section,
          resource: root_container.resource,
          user: student,
          content: %{message: "This is a read discussion"}
        })

      read_reply =
        insert(:post,
          section: section,
          resource: root_container.resource,
          user: student_2,
          content: %{message: "This is a read reply"},
          thread_root_id: read_discussion.id,
          parent_post_id: read_discussion.id
        )

      Collaboration.mark_posts_as_read([read_reply], student.id)

      unread_discussion =
        insert(:post, %{
          section: section,
          resource: root_container.resource,
          user: student_2,
          content: %{message: "This is an unread discussion"}
        })

      _unread_reply =
        insert(:post,
          section: section,
          resource: root_container.resource,
          user: student_2,
          content: %{message: "This is an unread reply"},
          thread_root_id: unread_discussion.id,
          parent_post_id: unread_discussion.id
        )

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      assert has_element?(
               view,
               "div[id=\"post-#{read_discussion.id}\"]",
               "This is a read discussion"
             )

      assert has_element?(
               view,
               "div[id=\"post-#{unread_discussion.id}\"]",
               "This is an unread discussion"
             )

      view
      |> element("button[role=\"dropdown-item Unread\"]")
      |> render_click()

      refute has_element?(
               view,
               "div[id=\"post-#{read_discussion.id}\"]",
               "This is a read discussion"
             )

      assert has_element?(
               view,
               "div[id=\"post-#{unread_discussion.id}\"]",
               "This is an unread discussion"
             )
    end

    test "can filter by my activity (discussions student created or student replied to)", %{
      conn: conn,
      student: student,
      section: section,
      root_container: root_container,
      student_2: student_2
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      my_discussion =
        insert(:post, %{
          section: section,
          resource: root_container.resource,
          user: student,
          content: %{message: "This is a discussion I started"}
        })

      other_discussion =
        insert(:post, %{
          section: section,
          resource: root_container.resource,
          user: student_2,
          content: %{message: "This is a discussion started by other student"}
        })

      other_discussion_i_replied_to =
        insert(:post, %{
          section: section,
          resource: root_container.resource,
          user: student_2,
          content: %{message: "This is a discussion started by other student and I replied to"}
        })

      _my_reply =
        insert(:post,
          section: section,
          resource: root_container.resource,
          user: student,
          content: %{message: "This is my reply"},
          thread_root_id: other_discussion_i_replied_to.id,
          parent_post_id: other_discussion_i_replied_to.id
        )

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      assert has_element?(
               view,
               "div[id=\"post-#{my_discussion.id}\"]",
               "This is a discussion I started"
             )

      assert has_element?(
               view,
               "div[id=\"post-#{other_discussion.id}\"]",
               "This is a discussion started by other student"
             )

      assert has_element?(
               view,
               "div[id=\"post-#{other_discussion_i_replied_to.id}\"]",
               "This is a discussion started by other student and I replied to"
             )

      view
      |> element("button[role=\"dropdown-item My Activity\"]")
      |> render_click()

      assert has_element?(
               view,
               "div[id=\"post-#{my_discussion.id}\"]",
               "This is a discussion I started"
             )

      refute has_element?(
               view,
               "div[id=\"post-#{other_discussion.id}\"]",
               "This is a discussion started by other student"
             )

      assert has_element?(
               view,
               "div[id=\"post-#{other_discussion_i_replied_to.id}\"]",
               "This is a discussion started by other student and I replied to"
             )
    end

    test "can filter by Course discussions and Page discussions", %{
      conn: conn,
      student: student,
      section: section,
      root_container: root_container,
      student_2: student_2,
      page_1: page_1
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      _course_discussion =
        insert(:post, %{
          section: section,
          resource: root_container.resource,
          user: student,
          content: %{message: "This is a course discussion"}
        })

      _page_discussion =
        insert(:post, %{
          section: section,
          resource: page_1.resource,
          user: student_2,
          content: %{message: "This is a page discussion"}
        })

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      assert render(view) =~ "This is a course discussion"
      assert render(view) =~ "This is a page discussion"

      view
      |> element("button[role=\"dropdown-item Course Discussions\"]")
      |> render_click()

      assert render(view) =~ "This is a course discussion"
      refute render(view) =~ "This is a page discussion"

      view
      |> element("button[role=\"dropdown-item Page Discussions\"]")
      |> render_click()

      refute render(view) =~ "This is a course discussion"
      assert render(view) =~ "This is a page discussion"
    end

    test "can read more posts (until there are no more left)", %{
      conn: conn,
      student: student,
      section: section,
      root_container: root_container
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      Enum.each(
        1..11,
        fn i ->
          insert(:post, %{
            section: section,
            resource: root_container.resource,
            user: student,
            content: %{message: "Discussion #{i} :)"},
            inserted_at: DateTime.new!(Date.new!(2023, 12, i), ~T[00:00:00]),
            updated_at: DateTime.new!(Date.new!(2023, 12, i), ~T[00:00:00])
          })
        end
      )

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      refute render(view) =~ "Discussion 1 :)"
      refute render(view) =~ "Discussion 2 :)"
      refute render(view) =~ "Discussion 3 :)"
      refute render(view) =~ "Discussion 4 :)"
      refute render(view) =~ "Discussion 5 :)"
      refute render(view) =~ "Discussion 6 :)"
      assert render(view) =~ "Discussion 7 :)"
      assert render(view) =~ "Discussion 8 :)"
      assert render(view) =~ "Discussion 9 :)"
      assert render(view) =~ "Discussion 10 :)"
      assert render(view) =~ "Discussion 11 :)"

      render_click(element(view, "button[phx-click=\"load_more_posts\"]"))

      refute render(view) =~ "Discussion 1 :)"
      assert render(view) =~ "Discussion 2 :)"
      assert render(view) =~ "Discussion 3 :)"
      assert render(view) =~ "Discussion 4 :)"
      assert render(view) =~ "Discussion 6 :)"
      assert render(view) =~ "Discussion 7 :)"
      assert render(view) =~ "Discussion 8 :)"
      assert render(view) =~ "Discussion 9 :)"
      assert render(view) =~ "Discussion 10 :)"
      assert render(view) =~ "Discussion 11 :)"

      render_click(element(view, "button[phx-click=\"load_more_posts\"]"))

      assert render(view) =~ "Discussion 1 :)"
      assert render(view) =~ "Discussion 2 :)"
      assert render(view) =~ "Discussion 3 :)"
      assert render(view) =~ "Discussion 4 :)"
      assert render(view) =~ "Discussion 6 :)"
      assert render(view) =~ "Discussion 7 :)"
      assert render(view) =~ "Discussion 8 :)"
      assert render(view) =~ "Discussion 9 :)"
      assert render(view) =~ "Discussion 10 :)"
      assert render(view) =~ "Discussion 11 :)"

      refute has_element?(view, "button[phx-click=\"load_more_posts\"]", "Load more posts")
    end
  end

  describe "student with course collab space disabled" do
    setup attrs do
      {:ok, conn: conn, user: user} = user_conn(attrs, %{name: "Lionel Messi"})

      Map.merge(%{conn: conn, student: user}, create_elixir_project(conn))
    end

    test "can not initiate a new course discussion if that option is disabled", %{
      conn: conn,
      student: student,
      section: section,
      root_container_sr: root_container_sr
    } do
      Sections.enroll(student.id, section.id, [ContextRoles.get_role(:context_learner)])
      # this prevents being redirected to the onboarding wizard
      Sections.mark_section_visited_for_student(section, student)

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))

      assert has_element?(view, "button[role=\"new discussion\"]", "New Discussion")

      {:ok, _root_container_sr} =
        Oli.Delivery.Sections.update_section_resource(root_container_sr, %{
          collab_space_config: build(:collab_space_config, status: :disabled)
        })

      {:ok, view, _html} = live(conn, live_view_discussions_live_route(section.slug))
      refute has_element?(view, "button[role=\"new discussion\"]", "New Discussion")
    end
  end
end
