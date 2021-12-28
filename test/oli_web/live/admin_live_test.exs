defmodule OliWeb.AdminLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  @live_view_route Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the admin view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authoring/session/new?request_path=%2Fadmin"}}} =
        live(conn, @live_view_route)
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn]

    test "returns forbidden when accessing the admin view", %{conn: conn} do
      conn = get(conn, @live_view_route)

      assert response(conn, 403)
    end
  end

  describe "view" do
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
end
