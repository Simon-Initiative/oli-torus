defmodule OliWeb.Workspaces.StudentTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Accounts

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

    test "can access student workspace when is unlocked after being locked", %{
      conn: conn,
      user: user
    } do
      # Lock the user
      {:ok, date, _timezone} = DateTime.from_iso8601("2019-05-22 20:30:00Z")
      {:ok, user} = Accounts.update_user(user, %{locked_at: date})

      # Unlock the user
      Accounts.unlock_user(user)

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

    test "does show sidebar if user can create_sections", ctx do
      {:ok, conn: conn, user: _} = user_conn(ctx, %{can_create_sections: true})
      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      assert render(view) =~ "desktop-workspace-nav-menu"
    end

    test "can not access student workspace when user has not confirmed email", %{
      conn: conn,
      user: user
    } do
      {:ok, user} = Accounts.update_user(user, %{email_confirmed_at: nil})

      section = insert(:section, open_and_free: true, skip_email_verification: false)

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:error, {:redirect, %{to: "/users/confirm"}}} = live(conn, ~p"/workspaces/student")
    end

    test "can access student workspace when user is enrolled in any section that omits email verification",
         %{conn: conn, user: user} do
      {:ok, user} = Accounts.update_user(user, %{email_confirmed_at: nil})

      section = insert(:section, open_and_free: true, skip_email_verification: true)

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      assert has_element?(view, "h3", "Courses available")
    end

    test "search form has hidden disabled button to prevent submission", %{conn: conn, user: user} do
      section = insert(:section, %{open_and_free: true, title: "Test Course"})
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      # Verify the hidden disabled button exists in the search form
      assert has_element?(
               view,
               "form[phx-change=search_section] button.hidden[name=submit][value=disabled][disabled]"
             )
    end

    test "can search sections with nil instructor names", %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "Course with Nil Instructor"})
      section_2 = insert(:section, %{open_and_free: true, title: "Course with Real Instructor"})

      # Create instructor with nil name
      instructor_nil = insert(:user, %{name: nil})
      instructor_real = insert(:user, %{name: "John Doe"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_learner)])

      Sections.enroll(instructor_nil.id, section_1.id, [
        ContextRoles.get_role(:context_instructor)
      ])

      Sections.enroll(instructor_real.id, section_2.id, [
        ContextRoles.get_role(:context_instructor)
      ])

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      # Both courses should be visible initially
      assert has_element?(view, "h5", "Course with Nil Instructor")
      assert has_element?(view, "h5", "Course with Real Instructor")

      # Search should still work for course title even with nil instructor
      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{text_search: "nil"})

      assert has_element?(view, "h5", "Course with Nil Instructor")
      refute has_element?(view, "h5", "Course with Real Instructor")

      # Search by real instructor name should work
      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{text_search: "doe"})

      refute has_element?(view, "h5", "Course with Nil Instructor")
      assert has_element?(view, "h5", "Course with Real Instructor")
    end

    test "can search sections with empty instructor names", %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "Course with Empty Instructor"})
      section_2 = insert(:section, %{open_and_free: true, title: "Course with Real Instructor"})

      # Create instructor with empty name
      instructor_empty = insert(:user, %{name: ""})
      instructor_real = insert(:user, %{name: "Jane Smith"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_learner)])

      Sections.enroll(instructor_empty.id, section_1.id, [
        ContextRoles.get_role(:context_instructor)
      ])

      Sections.enroll(instructor_real.id, section_2.id, [
        ContextRoles.get_role(:context_instructor)
      ])

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      # Both courses should be visible initially
      assert has_element?(view, "h5", "Course with Empty Instructor")
      assert has_element?(view, "h5", "Course with Real Instructor")

      # Search should work for course title even with empty instructor
      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{text_search: "empty"})

      assert has_element?(view, "h5", "Course with Empty Instructor")
      refute has_element?(view, "h5", "Course with Real Instructor")

      # Search by real instructor name should work
      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{text_search: "smith"})

      refute has_element?(view, "h5", "Course with Empty Instructor")
      assert has_element?(view, "h5", "Course with Real Instructor")
    end

    test "search handles mixed instructor name types correctly", %{conn: conn, user: user} do
      section = insert(:section, %{open_and_free: true, title: "Mixed Instructor Course"})

      # Create instructors with different name types
      instructor_nil = insert(:user, %{name: nil})
      instructor_empty = insert(:user, %{name: ""})
      instructor_real = insert(:user, %{name: "Alice Johnson"})

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      Sections.enroll(instructor_nil.id, section.id, [ContextRoles.get_role(:context_instructor)])

      Sections.enroll(instructor_empty.id, section.id, [
        ContextRoles.get_role(:context_instructor)
      ])

      Sections.enroll(instructor_real.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/workspaces/student")

      # Course should be visible initially
      assert has_element?(view, "h5", "Mixed Instructor Course")

      # Search by course title should work
      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{text_search: "mixed"})

      assert has_element?(view, "h5", "Mixed Instructor Course")

      # Search by real instructor name should work
      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{text_search: "alice"})

      assert has_element?(view, "h5", "Mixed Instructor Course")

      # Search by non-existent term should hide course
      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{text_search: "nonexistent"})

      refute has_element?(view, "h5", "Mixed Instructor Course")
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
