defmodule OliWeb.Delivery.OpenAndFreeIndexTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections
  alias Oli.Seeder
  alias Oli.Delivery.Attempts.Core

  defp set_progress(section_id, resource_id, user_id, progress, revision) do
    {:ok, resource_access} =
      Core.track_access(resource_id, section_id, user_id)
      |> Core.update_resource_access(%{progress: progress})

    insert(:resource_attempt, %{
      resource_access: resource_access,
      revision: revision,
      lifecycle_state: :evaluated
    })
  end

  defp section_with_progress_for_user(user_id, progress) do
    map = Seeder.base_project_with_larger_hierarchy()
    {:ok, _} = Sections.rebuild_contained_pages(map.section)
    Sections.enroll(user_id, map.section.id, [ContextRoles.get_role(:context_learner)])

    Sections.fetch_all_pages(map.section.slug)
    |> Enum.each(fn page_revision ->
      set_progress(map.section.id, page_revision.resource_id, user_id, progress, page_revision)
    end)

    map.section
  end

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

      assert has_element?(view, "h3", "Courses available")
      assert has_element?(view, "p", "You are not enrolled in any courses.")
    end

    test "can access when user is not enrolled to any section", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/sections")

      assert has_element?(view, "p", "You are not enrolled in any courses.")
    end

    test "renders product title, image and description in sections index with a link to access to it",
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

      assert render(view) =~ ~s|bg-[url(&#39;https://example.com/some-image-url.png&#39;)]|
      assert has_element?(view, "h5", "The best course ever!")
      assert has_element?(view, ~s{a[href="/sections/#{section.slug}"]})
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
               ~s{a[href="/sections/#{section_1.slug}"] span.badge},
               "student"
             )

      assert has_element?(
               view,
               ~s{a[href="/sections/#{section_2.slug}"] span.badge},
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

      assert render(view) =~ ~s|bg-[url(&#39;/images/course_default.jpg&#39;)]|
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

    test "sees the correct course progress if enrolled as student", %{conn: conn, user: user} do
      section_1 = section_with_progress_for_user(user.id, 1.0)
      section_2 = section_with_progress_for_user(user.id, 0.5)
      section_3 = section_with_progress_for_user(user.id, 0.0)

      {:ok, view, _html} = live(conn, ~p"/sections")

      assert view
             |> element("div[role=\"progress_for_section_#{section_1.id}\"]")
             |> render() =~ "100%"

      assert view
             |> element("div[role=\"progress_for_section_#{section_2.id}\"]")
             |> render() =~ "50%"

      assert view
             |> element("div[role=\"progress_for_section_#{section_3.id}\"]")
             |> render() =~ "0%"
    end

    test "does not see the course progress if enrolled as instuctor", %{conn: conn, user: user} do
      section_1 = insert(:section, %{open_and_free: true, title: "The best course ever!"})
      section_2 = insert(:section, %{open_and_free: true, title: "Maths"})

      Sections.enroll(user.id, section_1.id, [ContextRoles.get_role(:context_instructor)])
      Sections.enroll(user.id, section_2.id, [ContextRoles.get_role(:context_learner)])

      {:ok, view, _html} = live(conn, ~p"/sections")

      refute has_element?(view, "div[role=\"progress_for_section_#{section_1.id}\"]")
      assert has_element?(view, "div[role=\"progress_for_section_#{section_2.id}\"]")
    end

    test "does see the complete badge on section card if progress = 100", %{
      conn: conn,
      user: user
    } do
      section_1 = section_with_progress_for_user(user.id, 1.0)
      section_2 = section_with_progress_for_user(user.id, 0.5)

      {:ok, view, _html} = live(conn, ~p"/sections")

      assert has_element?(
               view,
               ~s{span[role="complete_badge_for_section_#{section_1.id}"]},
               "Complete"
             )

      refute has_element?(
               view,
               ~s{span[role="complete_badge_for_section_#{section_2.id}"]},
               "Complete"
             )
    end
  end
end
