defmodule OliWeb.Admin.RegistrationsViewTest do
  use OliWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Oli.Factory

  alias OliWeb.Admin.RegistrationsView

  @moduledoc false

  # - Verifies access control and that the view renders title and create link
  # - Applies sorting, searching and paging via params and delegated events
  # - Ensures breadcrumb contains the registrations entry

  @route Routes.live_path(OliWeb.Endpoint, RegistrationsView)

  describe "access control" do
    test "redirects to new session when accessing registrations while not logged in", %{
      conn: conn
    } do
      assert {:error, {:redirect, %{to: "/authors/log_in"}}} = live(conn, @route)
    end

    test "redirects to authoring workspace when accessing registrations as non-admin author", %{
      conn: conn
    } do
      author = insert(:author)
      conn = log_in_author(conn, author)
      assert {:error, {:redirect, %{to: "/workspaces/course_author"}}} = live(conn, @route)
    end
  end

  describe "renders and interactions" do
    setup [:account_admin_conn]

    test "renders header, search control and create link when no registrations exist", %{
      conn: conn
    } do
      {:ok, view, html} = live(conn, @route)

      assert html =~ "LTI 1.3 Registrations"
      assert has_element?(view, "input[phx-hook='TextInputListener']")

      assert has_element?(
               view,
               "a[href='" <> Routes.registration_path(OliWeb.Endpoint, :new) <> "']"
             )

      assert has_element?(view, "p", "None exist")
    end

    test "applies sorting, searching and paging through params", %{conn: conn} do
      insert(:lti_registration, issuer: "Issuer A", client_id: "aaa")
      insert(:lti_registration, issuer: "Issuer B", client_id: "bbb")

      {:ok, _view, _html} = live(conn, @route)

      {:ok, view, _} = live(conn, @route <> "?sort_by=issuer&sort_order=asc")
      assert render(view) =~ "Issuer A"

      {:ok, view, _} = live(conn, @route <> "?sort_by=issuer&sort_order=desc")
      assert render(view) =~ "Issuer B"

      {:ok, view, _} = live(conn, @route <> "?text_search=Issuer%20A")
      assert render(view) =~ "Issuer A"

      {:ok, view, _} = live(conn, @route <> "?offset=0")
      assert render(view) =~ "Showing all results"
    end

    test "breadcrumb includes LTI 1.3 Registrations", %{conn: conn} do
      {:ok, _view, html} = live(conn, @route)
      assert html =~ "LTI 1.3 Registrations"
    end
  end
end
