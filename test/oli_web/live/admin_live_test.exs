defmodule OliWeb.AdminLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import OliWeb.Common.Properties.Utils

  @live_view_route Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)
  @live_view_users_route Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersView)

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the admin index view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authoring/session/new?request_path=%2Fadmin"}}} =
        live(conn, @live_view_route)
    end

    test "redirects to new session when accessing the admin users view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authoring/session/new?request_path=%2Fadmin%2Fusers"}}} =
        live(conn, @live_view_users_route)
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn]

    test "returns forbidden when accessing the admin index view", %{conn: conn} do
      conn = get(conn, @live_view_route)

      assert response(conn, 403)
    end

    test "returns forbidden when accessing the admin users view", %{conn: conn} do
      conn = get(conn, @live_view_users_route)

      assert response(conn, 403)
    end
  end

  describe "index" do
    setup [:admin_conn]

    test "loads account management links correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_route)

      assert view
             |> element(".alert")
             |> render() =~
               "All administrative actions taken in the system are logged for auditing purposes."

      assert view
             |> render() =~
               "Account Management"

      assert view
             |> render() =~
               "Access and manage all users and authors"

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersView)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsView)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.institution_path(OliWeb.Endpoint, :index)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.invite_path(OliWeb.Endpoint, :index)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.IndexView)}\"]"
             )
    end

    test "loads content management links correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_route)

      assert view
             |> render() =~
               "Content Management"

      assert view
             |> render() =~
               "Access and manage created content"

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Products.ProductsView)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.SectionsView)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.admin_open_and_free_path(OliWeb.Endpoint, :index)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.ingest_path(OliWeb.Endpoint, :index)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.brand_path(OliWeb.Endpoint, :index)}\"]"
             )
    end

    test "loads system management links correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_route)

      assert view
             |> render() =~
               "System Management"

      assert view
             |> render() =~
               "Manage and support system level functionality"

      assert has_element?(
               view,
               "a[href=\"#{Routes.activity_manage_path(OliWeb.Endpoint, :index)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.RegistrationsView)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Features.FeaturesLive)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.ApiKeys.ApiKeysLive)}\"]"
             )
    end
  end

  describe "users index" do
    setup [:admin_conn]

    test "loads correctly when there are no users in the system", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, @live_view_users_route)

      assert has_element?(view, "p", "None exist")
    end

    test "lists users", %{conn: conn} do
      user = insert(:user)

      {:ok, view, _html} = live(conn, @live_view_users_route)

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "#{user.family_name}, #{user.given_name}"
    end

    test "applies filtering", %{conn: conn} do
      user_1 = insert(:user)
      user_2 = insert(:user, guest: true)

      {:ok, view, _html} = live(conn, @live_view_users_route)

      assert has_element?(view, "##{user_1.id}")
      refute has_element?(view, "##{user_2.id}")

      view
      |> element("input[phx-click=\"include_guests\"]")
      |> render_click()

      assert has_element?(view, "##{user_1.id}")
      assert has_element?(view, "##{user_2.id}")
    end

    test "applies searching", %{conn: conn} do
      user_1 = insert(:user, %{given_name: "Testing"})
      user_2 = insert(:user)

      {:ok, view, _html} = live(conn, @live_view_users_route)

      view
      |> render_hook("text_search_change", %{value: "testing"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               user_1.given_name

      refute view
             |> element("tr:last-child > td:first-child")
             |> render() =~
               user_2.given_name

      view
      |> render_hook("text_search_change", %{value: ""})

      assert view
             |> render() =~
               user_1.given_name

      assert view
             |> render() =~
               user_2.given_name
    end

    test "applies sorting", %{conn: conn} do
      user_1 = insert(:user, %{given_name: "Testing A"})
      user_2 = insert(:user, %{given_name: "Testing B"})

      {:ok, view, _html} = live(conn, @live_view_users_route)

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               user_1.given_name

      view
      |> element("th[phx-click=\"paged_table_sort\"]:first-of-type")
      |> render_click(%{sort_by: "name"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               user_2.given_name
    end

    test "applies paging", %{conn: conn} do
      [first_user | tail] = insert_list(26, :user) |> Enum.sort_by(& &1.given_name)
      last_user = List.last(tail)

      {:ok, view, _html} = live(conn, @live_view_users_route)

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               first_user.given_name

      refute view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               last_user.given_name

      view
      |> element("#header_paging a[phx-click=\"paged_table_page_change\"]", "2")
      |> render_click()

      refute view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               first_user.given_name

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               last_user.given_name
    end
  end
end
