defmodule OliWeb.Workspaces.InstructorTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Accounts
  alias Oli.Delivery.Sections

  describe "user logged in as student" do
    setup [:user_conn]

    test "can access instructor workspace", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      assert has_element?(view, "h1", "Instructor Dashboard")
      assert has_element?(view, "p", "You are not enrolled in any courses as an instructor.")
    end

    test "does not see any label on user menu", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      refute has_element?(view, "div[role='account label']")
    end

    test "can see product title, image and description in sections index with a link to manage it on instructor workspace",
         %{
           conn: conn,
           user: user
         } do
      section =
        insert(:section, %{
          open_and_free: true,
          cover_image: "https://example.com/some-image-url.png",
          description: "This is a description",
          title: "The best course ever!"
        })

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} =
        live(conn, ~p"/workspaces/instructor?sidebar_expanded=true")

      assert render(view) =~
               ~s|style=\"background-image: url(&#39;https://example.com/some-image-url.png&#39;);\"|

      assert has_element?(view, "h5", "The best course ever!")

      assert has_element?(
               view,
               ~s{a[href="/sections/#{section.slug}/manage?sidebar_expanded=true"]}
             )
    end

    test "if no cover image is set, renders default image in enrollment page on instructor workspace",
         %{
           conn: conn,
           user: user
         } do
      section = insert(:section, %{open_and_free: true})

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      assert render(view) =~
               ~s|style=\"background-image: url(&#39;/images/course_default.png&#39;);\"|
    end

    test "can search by course name in instructor workspace", %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "h5", "Maths")

      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{text_search: "best"})

      assert has_element?(view, "h5", "The best course ever!")
      refute has_element?(view, "h5", "Maths")

      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{text_search: ""})

      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "h5", "Maths")

      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{text_search: "a not existing course"})

      refute has_element?(view, "h5", "The best course ever!")
      refute has_element?(view, "h5", "Maths")
    end

    test "can search by instructor name in instructor workspace", %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})
      section_3 = insert(:section, %{open_and_free: true, title: "Elixir"})

      instructor_1 = insert(:user, %{name: "Lionel Messi"})
      instructor_2 = insert(:user, %{name: "Angel Di Maria"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user.id, section_3.id, [ContextRoles.get_role(:context_instructor)])

      Sections.enroll(instructor_1.id, section_1.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(instructor_1.id, section_2.id, [ContextRoles.get_role(:context_instructor)])

      Sections.enroll(instructor_2.id, section_2.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(instructor_2.id, section_3.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "h5", "Maths")
      assert has_element?(view, "h5", "Elixir")

      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{text_search: "messi"})

      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "h5", "Maths")
      refute has_element?(view, "h5", "Elixir")

      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{text_search: "maria"})

      refute has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "h5", "Maths")
      assert has_element?(view, "h5", "Elixir")

      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{text_search: "a not existing instructor"})

      refute has_element?(view, "h5", "The best course ever!")
      refute has_element?(view, "h5", "Maths")
      refute has_element?(view, "h5", "Elixir")
    end

    test "only sees sections enrolled as instructor on instructor workspace", %{
      conn: conn,
      user: user
    } do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      refute has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "h5", "Maths")
    end

    test "can not create sections on instructor worskpace when logged in as student", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      assert has_element?(
               view,
               "div[role='create section instructions']",
               "To create course sections,"
             )

      assert has_element?(view, "a[href='#']", "Create New Section")
    end

    test "can navigate between the different workspaces through the left navbar", %{
      conn: conn,
      user: user
    } do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      assert has_element?(
               view,
               "a[href='/workspaces/course_author?sidebar_expanded=true']",
               "Course Author"
             )

      assert has_element?(
               view,
               "a[href='/workspaces/instructor?sidebar_expanded=true']",
               "Instructor"
             )

      assert has_element?(
               view,
               "a[href='/workspaces/student?sidebar_expanded=true']",
               "Student"
             )

      # we are currently on the student workspace
      refute has_element?(view, "h1", "Instructor Dashboard")
      assert has_element?(view, "h3", "Courses available")

      # we go to the instructor workspace
      view
      |> element(~s{nav[id=desktop-workspace-nav-menu] a}, "Instructor")
      |> render_click()

      assert_redirected(
        view,
        ~p"/workspaces/instructor?sidebar_expanded=true"
      )

      {:ok, view, _html} =
        live(conn, ~p"/workspaces/instructor?sidebar_expanded=true")

      assert has_element?(view, "h1", "Instructor Dashboard")
      refute has_element?(view, "h3", "Courses available")

      # we go back to the student workspace
      view
      |> element(~s{nav[id=desktop-workspace-nav-menu] a}, "Student")
      |> render_click()

      assert_redirected(
        view,
        ~p"/workspaces/student?sidebar_expanded=true"
      )

      {:ok, view, _html} =
        live(conn, ~p"/workspaces/student?sidebar_expanded=true")

      refute has_element?(view, "h1", "Instructor Dashboard")
      assert has_element?(view, "h3", "Courses available")

      # we go to the course author workspace
      view
      |> element(~s{nav[id=desktop-workspace-nav-menu] a}, "Course Author")
      |> render_click()

      assert_redirected(
        view,
        ~p"/workspaces/course_author?sidebar_expanded=true"
      )
    end

    test "can see expanded/collapsed sidebar nav", %{
      conn: conn,
      user: user
    } do
      Accounts.update_user(user, %{can_create_sections: true})

      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      assert has_element?(view, ~s{nav[id=desktop-workspace-nav-menu][aria-expanded=true]})

      labels = ["Course Author", "Instructor", "Student"]

      Enum.each(labels, fn label ->
        assert view
               |> element(~s{nav[id=desktop-workspace-nav-menu]})
               |> render() =~ label
      end)

      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor?sidebar_expanded=false")

      assert has_element?(view, ~s{nav[id=desktop-workspace-nav-menu][aria-expanded=false]})

      Enum.each(labels, fn label ->
        refute view
               |> element(~s{nav[id=desktop-workspace-nav-menu]})
               |> render() =~ label
      end)
    end

    test "navbar expanded or collapsed state is kept after navigating to other menu link", %{
      conn: conn,
      user: user
    } do
      Accounts.update_user(user, %{can_create_sections: true})

      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor?sidebar_expanded=true")

      assert has_element?(view, ~s{nav[id=desktop-workspace-nav-menu][aria-expanded=true]})

      view
      |> element(~s{nav[id=desktop-workspace-nav-menu] a}, "Student")
      |> render_click()

      assert_redirect(view, "/workspaces/student?sidebar_expanded=true")

      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor?sidebar_expanded=false")

      assert has_element?(view, ~s{nav[id=desktop-workspace-nav-menu][aria-expanded=false]})

      view
      |> element(
        ~s{nav[id=desktop-workspace-nav-menu] a[id="desktop_student_workspace_nav_link"]}
      )
      |> render_click()

      assert_redirect(view, "/workspaces/student?sidebar_expanded=false")
    end
  end

  describe "user as instructor" do
    setup [:instructor_conn]

    test "can create sections on instructor worskpace when logged in", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      refute has_element?(
               view,
               "div[role='create section instructions']",
               "To create course sections,"
             )

      refute has_element?(
               view,
               "div[role='create section instructions'] button[onclick='window.showHelpModal();']",
               "contact support."
             )

      assert has_element?(view, "a[href='/sections/new']", "Create New Section")
    end

    test "sees the instructor label on user menu", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      assert has_element?(view, "div[role='account label']", "Instructor")
    end

    test "sees linked account email on user menu", %{conn: conn, instructor: instructor} do
      author = insert(:author)
      Accounts.link_user_author_account(instructor, author)

      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      assert has_element?(
               view,
               "div[id='workspace-user-menu-dropdown'] div[role='linked authoring account email']",
               author.email
             )
    end

    test "can see title, description, start date, end date and instructors in instructor workspace",
         %{
           conn: conn,
           instructor: instructor
         } do
      section =
        insert(:section, %{
          open_and_free: true,
          title: "The best course ever!",
          description: "This is a description",
          start_date: ~U[2025-01-01 00:00:00Z],
          end_date: ~U[2026-01-01 00:00:00Z]
        })

      instructor_1 = insert(:user, %{name: "Lionel Messi"})
      instructor_2 = insert(:user, %{name: "Angel Di Maria"})

      Sections.enroll(instructor.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(instructor_1.id, section.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(instructor_2.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/instructor")

      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "p", "This is a description")
      assert has_element?(view, "div[role='start_end_date']", "Jan 2025 - Jan 2026")

      assert has_element?(
               view,
               "div[role='instructors']",
               ~r/Instructors:\s*#{instructor.name},\s*Lionel Messi,\s*Angel Di Maria/
             )
    end
  end
end
