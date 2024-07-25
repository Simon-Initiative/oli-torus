defmodule OliWeb.Delivery.OpenAndFreeIndexTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Accounts
  alias OliWeb.Pow.UserContext

  describe "user cannot access when is not logged in" do
    test "redirects to new session", %{
      conn: conn
    } do
      redirect_path = "/session/new?request_path=%2Fsections"

      {:error, {:redirect, %{to: ^redirect_path}}} = live(conn, ~p"/sections")
    end
  end

  describe "user" do
    setup [:user_conn]

    #### Student Workspace ####
    test "can access student workspace when logged in", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=student_workspace")

      assert has_element?(view, "h3", "Courses available")
      assert has_element?(view, "p", "You are not enrolled in any courses.")
    end

    test "can access student workspace when not enrolled to any section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=student_workspace")

      assert has_element?(view, "p", "You are not enrolled in any courses.")
    end

    test "cannot access student workspace when locked", %{conn: conn, user: user} do
      UserContext.lock(user)

      {:error,
       {:redirect,
        %{
          to: "/session/new",
          flash: %{"error" => "Sorry, your account is locked. Please contact support."}
        }}} = live(conn, ~p"/sections")
    end

    test "can access student workspace when is unlocked after being locked", %{
      conn: conn,
      user: user
    } do
      # Lock the user
      {:ok, date, _timezone} = DateTime.from_iso8601("2019-05-22 20:30:00Z")
      {:ok, user} = Accounts.update_user(user, %{locked_at: date})

      # Unlock the user
      UserContext.unlock(user)

      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=student_workspace")

      assert has_element?(view, "h3", "Courses available")
      assert has_element?(view, "p", "You are not enrolled in any courses.")
    end

    test "can see product title, image and description in sections index with a link to access to it in the student workspace",
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

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} =
        live(conn, ~p"/sections?active_workspace=student_workspace&sidebar_expanded=true")

      assert render(view) =~
               ~s|style=\"background-image: url(&#39;https://example.com/some-image-url.png&#39;);\"|

      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, ~s{a[href="/sections/#{section.slug}?sidebar_expanded=true"]})
    end

    test "if no cover image is set, renders default image in enrollment page in the student workspace",
         %{
           conn: conn,
           user: user
         } do
      section = insert(:section, %{open_and_free: true})

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=student_workspace")

      assert render(view) =~
               ~s|style=\"background-image: url(&#39;/images/course_default.png&#39;);\"|
    end

    test "can search by course name in student workspace", %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=student_workspace")

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

    test "can search by instructor name in student workspace", %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})
      section_3 = insert(:section, %{open_and_free: true, title: "Elixir"})

      instructor_1 = insert(:user, %{name: "Lionel Messi"})
      instructor_2 = insert(:user, %{name: "Angel Di Maria"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_3.id, [ContextRoles.get_role(:context_learner)])

      Sections.enroll(instructor_1.id, section_1.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(instructor_1.id, section_2.id, [ContextRoles.get_role(:context_instructor)])

      Sections.enroll(instructor_2.id, section_2.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(instructor_2.id, section_3.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=student_workspace")

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

    test "only sees sections enrolled as student on student workspace", %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=student_workspace")

      assert has_element?(view, "h5", "The best course ever!")
      refute has_element?(view, "h5", "Maths")
    end

    #### Instructor Workspace ####

    test "can access instructor workspace when logged in", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=instructor_workspace")

      assert has_element?(view, "h1", "Instructor Dashboard")
      assert has_element?(view, "p", "You are not enrolled in any courses as an instructor.")
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
        live(conn, ~p"/sections?active_workspace=instructor_workspace&sidebar_expanded=true")

      assert render(view) =~
               ~s|style=\"background-image: url(&#39;https://example.com/some-image-url.png&#39;);\"|

      assert has_element?(view, "h5", "The best course ever!")

      assert has_element?(
               view,
               ~s{a[href="/sections/#{section.slug}/instructor_dashboard/manage?sidebar_expanded=true"]}
             )
    end

    test "if no cover image is set, renders default image in enrollment page on instructor workspace",
         %{
           conn: conn,
           user: user
         } do
      section = insert(:section, %{open_and_free: true})

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=student_workspace")

      assert render(view) =~
               ~s|style=\"background-image: url(&#39;/images/course_default.png&#39;);\"|
    end

    test "can search by course name in instructor workspace", %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=instructor_workspace")

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

      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=instructor_workspace")

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

      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=instructor_workspace")

      refute has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "h5", "Maths")
    end

    test "can not create sections on instructor worskpace when logged in as student", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=instructor_workspace")

      assert has_element?(
               view,
               "div[role='create section instructions']",
               "To create course sections,"
             )

      assert has_element?(
               view,
               "div[role='create section instructions'] button[onclick='window.showHelpModal();']",
               "contact support."
             )

      assert has_element?(view, "a[href='#']", "Create New Section")
    end

    test "can navigate between the different workspaces through the left navbar", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=student_workspace")

      assert has_element?(
               view,
               "a[href='/authoring/projects?active_workspace=course_author_workspace&sidebar_expanded=true']",
               "Course Author"
             )

      assert has_element?(
               view,
               "a[href='/sections?active_workspace=instructor_workspace&sidebar_expanded=true']",
               "Instructor"
             )

      assert has_element?(
               view,
               "a[href='/sections?active_workspace=student_workspace&sidebar_expanded=true']",
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
        ~p"/sections?active_workspace=instructor_workspace&sidebar_expanded=true"
      )

      {:ok, view, _html} =
        live(conn, ~p"/sections?active_workspace=instructor_workspace&sidebar_expanded=true")

      assert has_element?(view, "h1", "Instructor Dashboard")
      refute has_element?(view, "h3", "Courses available")

      # we go back to the student workspace
      view
      |> element(~s{nav[id=desktop-workspace-nav-menu] a}, "Student")
      |> render_click()

      assert_redirected(
        view,
        ~p"/sections?active_workspace=student_workspace&sidebar_expanded=true"
      )

      {:ok, view, _html} =
        live(conn, ~p"/sections?active_workspace=student_workspace&sidebar_expanded=true")

      refute has_element?(view, "h1", "Instructor Dashboard")
      assert has_element?(view, "h3", "Courses available")

      # we go to the course author workspace
      view
      |> element(~s{nav[id=desktop-workspace-nav-menu] a}, "Course Author")
      |> render_click()

      assert_redirected(
        view,
        ~p"/authoring/projects?active_workspace=course_author_workspace&sidebar_expanded=true"
      )
    end

    test "can see expanded/collapsed sidebar nav", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/sections")

      assert has_element?(view, ~s{nav[id=desktop-workspace-nav-menu][aria-expanded=true]})

      labels = ["Course Author", "Instructor", "Student"]

      Enum.each(labels, fn label ->
        assert view
               |> element(~s{nav[id=desktop-workspace-nav-menu]})
               |> render() =~ label
      end)

      {:ok, view, _html} = live(conn, ~p"/sections?sidebar_expanded=false")

      assert has_element?(view, ~s{nav[id=desktop-workspace-nav-menu][aria-expanded=false]})

      Enum.each(labels, fn label ->
        refute view
               |> element(~s{nav[id=desktop-workspace-nav-menu]})
               |> render() =~ label
      end)
    end

    test "navbar expanded or collapsed state is kept after navigating to other menu link", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/sections?sidebar_expanded=true")

      assert has_element?(view, ~s{nav[id=desktop-workspace-nav-menu][aria-expanded=true]})

      view
      |> element(~s{nav[id=desktop-workspace-nav-menu] a}, "Student")
      |> render_click()

      assert_redirect(view, "/sections?active_workspace=student_workspace&sidebar_expanded=true")

      {:ok, view, _html} = live(conn, ~p"/sections?sidebar_expanded=false")

      assert has_element?(view, ~s{nav[id=desktop-workspace-nav-menu][aria-expanded=false]})

      view
      |> element(~s{nav[id=desktop-workspace-nav-menu] a[id="student_workspace_nav_link"]})
      |> render_click()

      assert_redirect(view, "/sections?active_workspace=student_workspace&sidebar_expanded=false")
    end

    test "if user is only a student, display student workspace with hidden sidebar",
         %{
           conn: conn,
           user: user
         } do
      section = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} = live(conn, ~p"/sections")

      assert has_element?(view, "h3", "Courses available")
      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, ~s{a[href="/sections/#{section.slug}?sidebar_expanded=false"]})

      assert has_element?(view, ~s{nav[id=desktop-workspace-nav-menu][aria-expanded=false]})
    end
  end

  describe "user as instructor" do
    setup [:instructor_conn]

    #### Instructor Workspace ####

    test "can create sections on instructor worskpace when logged in", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/sections?active_workspace=instructor_workspace")

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

      assert has_element?(view, "a[href='/sections/independent/create']", "Create New Section")
    end
  end
end
