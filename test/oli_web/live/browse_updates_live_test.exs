defmodule OliWeb.BrowseUpdatesLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  defp live_view_index_route(section_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Grades.BrowseUpdatesView, section_slug)
  end

  defp create_section(_conn) do
    section = insert(:section)

    [section: section]
  end

  describe "user cannot access when is not logged in" do
    setup [:create_section]

    test "redirects to new session when accessing the index view", %{conn: conn, section: section} do
      redirect_path =
        "/users/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_index_route(section.slug))
    end
  end

  describe "cannot access when is not admin or author of the section" do
    setup [:author_conn, :create_section]

    test "redirects to new session when accessing the index view", %{conn: conn, section: section} do
      redirect_path =
        "/users/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_index_route(section.slug))
    end
  end

  describe "cannot access when is not instructor of the section" do
    setup [:user_conn, :create_section]

    test "returns unauthorized when accessing the index view", %{conn: conn, section: section} do
      {:error, {:redirect, %{to: "/unauthorized"}}} =
        live(conn, live_view_index_route(section.slug))
    end
  end

  describe "user cannot access when the section does not exist" do
    setup [:user_conn, :create_section]

    test "returns forbidden when accessing the index view", %{conn: conn} do
      conn = get(conn, live_view_index_route("invalid"))

      assert response(conn, 404)
    end
  end

  describe "index" do
    setup [:admin_conn, :create_section]

    test "loads correctly when there are no grade updates", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_index_route(section.slug))

      assert has_element?(view, "p", "None exist")
    end

    test "applies searching", %{conn: conn} do
      u1 = insert(:lms_grade_update, result: :failure)
      u2 = insert(:lms_grade_update, resource_access: u1.resource_access)

      {:ok, view, _html} = live(conn, live_view_index_route(u1.resource_access.section.slug))

      view
      |> element("#text-search-input")
      |> render_hook("text_search_change", %{value: "failure"})

      assert has_element?(view, "##{u1.id}")
      refute has_element?(view, "##{u2.id}")

      view
      |> element("#text-search-input")
      |> render_hook("text_search_change", %{value: ""})

      assert has_element?(view, "##{u1.id}")
      assert has_element?(view, "##{u2.id}")
    end

    test "applies sorting", %{conn: conn} do
      old_update =
        insert(:lms_grade_update, inserted_at: DateTime.utc_now() |> DateTime.add(-3600, :second))

      new_update = insert(:lms_grade_update, resource_access: old_update.resource_access)

      {:ok, view, _html} =
        live(conn, live_view_index_route(old_update.resource_access.section.slug))

      # newest first by default
      assert has_element?(view, "tbody tr:first-child.##{new_update.id}")

      # Sort by inserted_at asc
      view
      |> element("th[phx-click=\"paged_table_sort\"]:first-of-type")
      |> render_click(%{sort_by: "inserted_at"})

      assert has_element?(view, "tbody tr:first-child.##{old_update.id}")
    end

    test "applies paging", %{conn: conn} do
      ra = insert(:resource_access)

      old_update =
        insert(:lms_grade_update,
          resource_access: ra,
          inserted_at: DateTime.utc_now() |> DateTime.add(-3600, :second)
        )

      [first_u | _tail] = insert_list(25, :lms_grade_update, resource_access: ra)

      {:ok, view, _html} = live(conn, live_view_index_route(ra.section.slug))

      assert has_element?(view, "##{first_u.id}")
      refute has_element?(view, "##{old_update.id}")

      view
      |> element("#header_paging button[phx-click=\"paged_table_page_change\"]", "2")
      |> render_click()

      refute has_element?(view, "##{first_u.id}")
      assert has_element?(view, "##{old_update.id}")
    end
  end
end
