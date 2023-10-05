defmodule OliWeb.Delivery.OpenAndFreeIndexTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Accounts
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

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

    test "can access when logged in as student", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sections")

      assert has_element?(view, "h3", "My Courses")
      assert has_element?(view, "p", "You are not enrolled in any courses.")
    end

    test "can access when user is not enrolled to any section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sections")

      assert has_element?(view, "p", "You are not enrolled in any courses.")
    end

    test "gets the 'instructor' label role in the user account menu if the user with platform_role=student can create sections",
         %{
           conn: conn,
           user: user
         } do
      Accounts.update_user(
        user,
        %{can_create_sections: true}
      )

      Accounts.update_user_platform_roles(
        user,
        [
          Lti_1p3.Tool.PlatformRoles.get_role(:institution_student)
        ]
      )

      {:ok, view, _html} = live(conn, ~p"/sections")

      assert render(view)
             |> Floki.parse_document!()
             |> Floki.find(~s{div[data-live-react-class="Components.UserAccountMenu"]})
             |> Floki.attribute("data-live-react-props")
             |> hd =~
               ~s{\"roleColor\":\"#2ecc71\",\"roleLabel\":\"Instructor\"}
    end

    test "gets the 'student' label role in the user account menu if the user with platform_role=student can not create sections",
         %{
           conn: conn,
           user: user
         } do
      Accounts.update_user_platform_roles(
        user,
        [
          Lti_1p3.Tool.PlatformRoles.get_role(:institution_student)
        ]
      )

      {:ok, view, _html} = live(conn, ~p"/sections")

      assert render(view)
             |> Floki.parse_document!()
             |> Floki.find(~s{div[data-live-react-class="Components.UserAccountMenu"]})
             |> Floki.attribute("data-live-react-props")
             |> hd =~
               ~s{\"roleColor\":\"#3498db\",\"roleLabel\":\"Student\"}
    end

    test "renders product title, image and description in sections index with a link to acces to it",
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

      {:ok, view, _html} = live(conn, ~p"/sections")

      assert render(view) =~ ~s|src="https://example.com/some-image-url.png"|
      assert render(view) =~ "This is a description"
      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, ~s{a[href="/sections/#{section.slug}/overview"]})
    end

    test "section badge gets rendered correctly considering the user role",
         %{
           conn: conn,
           user: user
         } do
      section_1 =
        insert(:section, %{
          open_and_free: true,
          description: "This is a description",
          title: "The best course ever!"
        })

      section_2 =
        insert(:section, %{
          open_and_free: true,
          description: "This is another description",
          title: "Advanced Elixir"
        })

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/sections")

      assert has_element?(
               view,
               ~s{a[href="/sections/#{section_1.slug}/overview"] span.badge},
               "student"
             )

      assert has_element?(
               view,
               ~s{a[href="/sections/#{section_2.slug}/overview"] span.badge},
               "instructor"
             )
    end

    test "if no cover image is set, renders default image in enrollment page", %{
      conn: conn,
      user: user
    } do
      section = insert(:section, %{open_and_free: true})

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} = live(conn, ~p"/sections")

      assert render(view) =~ ~s|src="/images/course_default.jpg"|
    end

    test "can search by course name", %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_learner)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, view, _html} = live(conn, ~p"/sections")

      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "h5", "Maths")

      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{search: "best"})

      assert has_element?(view, "h5", "The best course ever!")
      refute has_element?(view, "h5", "Maths")

      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{search: ""})

      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "h5", "Maths")

      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{search: "a not existing course"})

      refute has_element?(view, "h5", "The best course ever!")
      refute has_element?(view, "h5", "Maths")
    end

    test "can search by instructor name", %{conn: conn, user: user} do
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

      {:ok, view, _html} = live(conn, ~p"/sections")

      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "h5", "Maths")
      assert has_element?(view, "h5", "Elixir")

      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{search: "messi"})

      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "h5", "Maths")
      refute has_element?(view, "h5", "Elixir")

      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{search: "maria"})

      refute has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, "h5", "Maths")
      assert has_element?(view, "h5", "Elixir")

      view
      |> form("form[phx-change=search_section]")
      |> render_change(%{search: "a not existing instructor"})

      refute has_element?(view, "h5", "The best course ever!")
      refute has_element?(view, "h5", "Maths")
      refute has_element?(view, "h5", "Elixir")
    end
  end
end
