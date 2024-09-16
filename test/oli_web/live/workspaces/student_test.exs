defmodule OliWeb.Workspaces.StudentTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Accounts
  alias OliWeb.Pow.UserContext

  describe "user not signed in" do
    test "can access page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      assert has_element?(view, "span", "Welcome to")
      assert has_element?(view, "span", "OLI Torus")
    end

    test "can signin and get redirected back to the student workspace", %{conn: conn} do
      expect_recaptcha_http_post()

      # create student account
      post(
        conn,
        Routes.pow_registration_path(conn, :create),
        %{
          user: %{
            email: "my_student@test.com",
            email_confirmation: "my_student@test.com",
            given_name: "me",
            family_name: "too",
            password: "some_password",
            password_confirmation: "some_password"
          },
          "g-recaptcha-response": "any"
        }
      )

      # access without being singed in
      conn = Phoenix.ConnTest.build_conn()

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      assert has_element?(view, "div", "Student Sign In")

      # we sign in and get redirected back to the student workspace
      conn =
        conn
        |> post(
          Routes.session_path(conn, :signin,
            type: :user,
            after_sign_in_target: :student_workspace
          ),
          user: %{email: "my_student@test.com", password: "some_password"}
        )

      assert conn.assigns.current_user.email == "my_student@test.com"
      assert redirected_to(conn) == ~p"/workspaces/student"

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      # student is signed in
      refute has_element?(view, "div", "Student Sign In")
      assert has_element?(view, "p", "You are not enrolled in any courses.")
    end
  end

  describe "user" do
    setup [:user_conn]

    test "can access student workspace when logged in", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      assert has_element?(view, "h3", "Courses available")
      assert has_element?(view, "p", "You are not enrolled in any courses.")
    end

    test "does not see any label on user menu", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      refute has_element?(view, "div[role='account label']")
    end

    test "can access student workspace when not enrolled to any section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      assert has_element?(view, "p", "You are not enrolled in any courses.")
    end

    test "cannot access student workspace when locked", %{conn: conn, user: user} do
      UserContext.lock(user)

      {:error,
       {:redirect,
        %{
          to: "/session/new",
          flash: %{"error" => "Sorry, your account is locked. Please contact support."}
        }}} = live(conn, ~p"/workspaces/student")
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

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

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
        live(conn, ~p"/workspaces/student?sidebar_expanded=true")

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

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      assert render(view) =~
               ~s|style=\"background-image: url(&#39;/images/course_default.png&#39;);\"|
    end

    test "can search by course name in student workspace", %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

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

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

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

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      assert has_element?(view, "h5", "The best course ever!")
      refute has_element?(view, "h5", "Maths")
    end

    test "shows sidebar if user is not only enrolled as student", %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      assert render(view) =~ "desktop-workspace-nav-menu"

      assert has_element?(view, "h5", "The best course ever!")
      refute has_element?(view, "h5", "Maths")
    end

    test "does not show sidebar if user is only enrolled as student", %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      refute render(view) =~ "desktop-workspace-nav-menu"

      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "h5", "Maths")
    end

    test "can signout from student account and return to student workspace (and author account stays signed in)",
         %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_instructor)])

      author = insert(:author, email: "author_account@test.com")

      conn =
        Pow.Plug.assign_current_user(
          conn,
          author,
          OliWeb.Pow.PowHelpers.get_pow_config(:author)
        )

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")
      assert conn.assigns.current_author
      assert conn.assigns.current_user
      refute has_element?(view, "div", "Student Sign In")

      view
      |> element("div[id='workspace-user-menu-dropdown'] a", "Sign out")
      |> render_click()

      assert_redirected(
        view,
        "/course/signout?type=user&target=%2Fworkspaces%2Fstudent"
      )

      conn = delete(conn, "/course/signout?type=user&target=%2Fworkspaces%2Fstudent")

      assert redirected_to(conn) == ~p"/workspaces/student"
      assert conn.assigns.current_author
      refute conn.assigns.current_user

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")
      assert has_element?(view, "div", "Student Sign In")
    end
  end

  describe "admin" do
    setup [:admin_conn]

    test "can access student workspace when logged in", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      assert has_element?(
               view,
               "h3",
               "Student workspace with an admin account has not yet been developed."
             )
    end
  end
end
