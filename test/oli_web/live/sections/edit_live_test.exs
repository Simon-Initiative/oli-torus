defmodule OliWeb.Sections.EditLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.ContextRoles

  defp live_view_edit_route(section_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EditView, section_slug)
  end

  defp create_section(_conn) do
    section = insert(:section)

    [section: section]
  end

  describe "user cannot access when is not logged in" do
    setup [:create_section]

    test "redirects to new session when accessing the section edit view", %{
      conn: conn,
      section: section
    } do
      section_slug = section.slug

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section_slug}%2Fedit&section=#{section_slug}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_edit_route(section.slug))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :create_section]

    test "redirects to new session when accessing the section edit view", %{
      conn: conn,
      section: section
    } do
      conn = get(conn, live_view_edit_route(section.slug))

      redirect_path = "/session/new?request_path=%2Fsections%2F#{section.slug}%2Fedit"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user cannot access when is logged in as an instructor but is not enrolled in the section" do
    setup [:user_conn]

    test "redirects to new session when accessing the section edit view", %{
      conn: conn
    } do
      section = insert(:section, %{type: :enrollable})

      conn = get(conn, live_view_edit_route(section.slug))

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user cannot access when is logged in as a student and is enrolled in the section" do
    setup [:user_conn]

    test "redirects to new session when accessing the section edit view", %{
      conn: conn,
      user: user
    } do
      section = insert(:section, %{type: :enrollable})
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, live_view_edit_route(section.slug))

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user can access when is logged in as an instructor and is enrolled in the section" do
    setup [:user_conn]

    test "loads correctly", %{
      conn: conn,
      user: user
    } do
      section = insert(:section, %{type: :enrollable})
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_instructor)])

      {:ok, _view, html} = live(conn, live_view_edit_route(section.slug))

      refute html =~ "Admin"
      assert html =~ "Edit Section Details"
      assert html =~ "Settings"
    end
  end

  describe "edit live view" do
    setup [:admin_conn, :create_section]

    test "returns 404 when section not exists", %{conn: conn} do
      conn = get(conn, live_view_edit_route("not_exists"))

      assert response(conn, 404)
    end

    test "loads section data correctly", %{conn: conn} do
      section = insert(:section, open_and_free: true)

      {:ok, view, html} = live(conn, live_view_edit_route(section.slug))

      assert html =~ "Admin"
      assert html =~ "Edit Section Details"
      assert html =~ "Settings"
      assert html =~ "Manage the course section settings"
      assert html =~ "Direct Delivery"
      assert html =~ "Direct Delivery section settings"
      assert has_element?(view, "input[value=\"#{section.title}\"]")
      assert has_element?(view, "input[value=\"#{section.description}\"]")

      assert view
             |> element("option[value=\"\"]")
             |> render() =~
               "None"
    end

    test "loads section data correctly when is created with a brand", %{conn: conn} do
      brand = insert(:brand)
      section = insert(:section, %{brand: brand})

      {:ok, view, _html} = live(conn, live_view_edit_route(section.slug))

      assert render(view) =~ "Settings"

      assert view
             |> element("option[selected=\"selected\"][value=\"#{section.brand_id}\"]")
             |> render() =~
               "#{brand.name}"
    end
  end
end
