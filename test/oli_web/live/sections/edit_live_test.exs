defmodule OliWeb.Sections.EditLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.ContextRoles

  defp live_view_edit_route(section_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.EditView, section_slug)
  end

  defp live_view_edit_section_route(section_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, section_slug)
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
      section = insert(:section, requires_payment: true)

      {:ok, view, html} = live(conn, live_view_edit_route(section.slug))

      assert html =~ "Edit Section Details"
      assert html =~ "Payment Settings"
      assert has_element?(view, "input[name=\"section[pay_by_institution]\"]")
    end

    test "loads open and free section data correctly", %{conn: conn} do
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

    test "loads open and free section datetimes correctly using the local timezone", context do
      {:ok, conn: conn, context: _} = set_timezone(context)
      timezone = Plug.Conn.get_session(conn, :browser_timezone)

      section = insert(:section_with_dates, open_and_free: true)

      {:ok, view, _html} = live(conn, live_view_edit_route(section.slug))

      assert view
             |> element("#section_start_date")
             |> render() =~
               utc_datetime_to_localized_datestring(section.start_date, timezone)

      assert view
             |> element("#section_end_date")
             |> render() =~
               utc_datetime_to_localized_datestring(section.end_date, timezone)

      assert view
             |> element("small")
             |> render() =~ "Timezone: " <> timezone
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

    test "save event updates curriculum numbering visibility", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_edit_route(section.slug))
      assert section.display_curriculum_item_numbering

      assert view
             |> element("#section_display_curriculum_item_numbering")
             |> render() =~ "checked"

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{
        "section" => %{"display_curriculum_item_numbering" => "false"}
      })

      updated_section = Sections.get_section!(section.id)
      refute updated_section.display_curriculum_item_numbering

      refute view
             |> element("#section_display_curriculum_item_numbering")
             |> render() =~ "checked"
    end

    test "update section with a long title shows an error alert", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_edit_section_route(section.slug))

      long_title =
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum"

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{section: %{title: long_title}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Couldn&#39;t update product title"

      assert view
             |> element("#section_title")
             |> render() =~ long_title

      assert has_element?(view, "span", "Title should be at most 255 character(s)")

      updated_section = Sections.get_section!(section.id)
      refute updated_section.title == long_title
    end

    test "update section with a valid title shows an info alert", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_edit_section_route(section.slug))

      valid_title = "Valid title"

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{section: %{title: valid_title}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Product changes saved"

      assert view
             |> element("#section_title")
             |> render() =~ valid_title

      updated_section = Sections.get_section!(section.id)
      assert updated_section.title == valid_title
    end
  end
end
