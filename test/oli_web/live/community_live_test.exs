defmodule OliWeb.CommunityLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Groups
  alias Oli.Groups.Community

  @live_view_index_route Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.Index)
  @live_view_new_route Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.New)

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the index view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authoring/session/new?request_path=%2Fadmin%2Fcommunities"}}} =
        live(conn, @live_view_index_route)
    end

    test "redirects to new session when accessing the create view", %{conn: conn} do
      {:error,
       {:redirect, %{to: "/authoring/session/new?request_path=%2Fadmin%2Fcommunities%2Fnew"}}} =
        live(conn, @live_view_new_route)
    end
  end

  describe "user cannot access when is logged in and is not an admin" do
    setup [:author_conn]

    test "returns forbidden when accessing the index view", %{conn: conn} do
      conn = get(conn, @live_view_index_route)

      assert response(conn, 403)
    end

    test "returns forbidden when accessing the create view", %{conn: conn} do
      conn = get(conn, @live_view_new_route)

      assert response(conn, 403)
    end
  end

  describe "index" do
    setup [:admin_conn]

    test "loads correctly when there are no communities", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert has_element?(view, "#communities-table")
      assert has_element?(view, "p", "None exist")
      assert has_element?(view, "a[href=\"#{@live_view_index_route}/new\"]")
    end

    test "lists all communities", %{conn: conn} do
      c1 = insert(:community)
      c2 = insert(:community)

      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert has_element?(view, "#communities-table")
      assert has_element?(view, "##{c1.id}")
      assert has_element?(view, "##{c2.id}")
    end

    test "applies filtering", %{conn: conn} do
      c1 = insert(:community, %{name: "Testing"})
      c2 = insert(:community)

      {:ok, view, _html} = live(conn, @live_view_index_route)

      view
      |> element("input[phx-blur=\"change_filter\"]")
      |> render_blur(%{value: "testing"})

      view
      |> element("button[phx-click=\"apply_filter\"]")
      |> render_click()

      assert has_element?(view, "##{c1.id}")
      refute has_element?(view, "##{c2.id}")

      view
      |> element("button[phx-click=\"reset_filter\"]")
      |> render_click()

      assert has_element?(view, "##{c1.id}")
      assert has_element?(view, "##{c2.id}")
    end

    test "applies sorting", %{conn: conn} do
      insert(:community, %{name: "Testing A"})
      insert(:community, %{name: "Testing B"})

      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Testing A"

      view
      |> element("th[phx-click=\"sort\"]:first-of-type")
      |> render_click(%{sort_by: "name"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Testing B"
    end

    test "applies paging", %{conn: conn} do
      [first_c | tail] = insert_list(21, :community) |> Enum.sort_by(& &1.name)
      last_c = List.last(tail)

      conn = get(conn, @live_view_index_route)
      {:ok, view, _html} = live(conn)

      assert has_element?(view, "##{first_c.id}")
      refute has_element?(view, "##{last_c.id}")

      view
      |> element("a[phx-click=\"page_change\"]", "2")
      |> render_click()

      refute has_element?(view, "##{first_c.id}")
      assert has_element?(view, "##{last_c.id}")
    end
  end

  describe "new" do
    setup [:admin_conn]

    test "loads correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_new_route)

      assert has_element?(view, "h5", "New Community")
      assert has_element?(view, "form[phx-submit=\"save\"")
    end

    test "displays error message when data is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_new_route)

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{community: %{name: ""}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Community couldn&#39;t be created. Please check the errors below."

      assert has_element?(view, "span", "can't be blank")

      assert [] = Groups.list_communities()
    end

    test "saves new community when data is valid", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_new_route)

      params = params_for(:community)

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{
        community: params
      })

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Community succesfully created."

      [%Community{name: name} | _tail] = Groups.list_communities()

      assert ^name = params.name
    end
  end
end
