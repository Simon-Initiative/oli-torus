defmodule OliWeb.Sections.InviteViewTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import OliWeb.Common.FormatDateTime

  alias Oli.Delivery.Sections
  alias Lti_1p3.Tool.ContextRoles

  defp live_view_invite_route(section_slug) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.InviteView, section_slug)
  end

  defp create_section(_conn) do
    section = insert(:section)

    [section: section]
  end

  describe "user cannot access when is not logged in" do
    setup [:create_section]

    test "redirects to new session when accessing the section invite view", %{
      conn: conn,
      section: section
    } do
      section_slug = section.slug

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section_slug}%2Finvitations&section=#{section_slug}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_invite_route(section.slug))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn, :create_section]

    test "redirects to new session when accessing the section invite view", %{
      conn: conn,
      section: section
    } do
      conn = get(conn, live_view_invite_route(section.slug))

      redirect_path =
        "/session/new?request_path=%2Fsections%2F#{section.slug}%2Finvitations&section=#{section.slug}"

      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user cannot access when is logged in as an instructor but is not enrolled in the section" do
    setup [:user_conn]

    test "redirects to new session when accessing the section invite view", %{
      conn: conn
    } do
      section = insert(:section, %{type: :enrollable})

      conn = get(conn, live_view_invite_route(section.slug))

      redirect_path = "/unauthorized"
      assert redirected_to(conn, 302) =~ redirect_path
    end
  end

  describe "user cannot access when is logged in as a student and is enrolled in the section" do
    setup [:user_conn]

    test "redirects to new session when accessing the section invite view", %{
      conn: conn,
      user: user
    } do
      section = insert(:section, %{type: :enrollable})
      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      conn = get(conn, live_view_invite_route(section.slug))

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

      {:ok, view, _html} = live(conn, live_view_invite_route(section.slug))

      assert render(view) =~
               "Create new invite link expiring after"
    end
  end

  describe "invite section live view" do
    setup [:admin_conn, :create_section]

    test "returns 404 when section not exists", %{conn: conn} do
      conn = get(conn, live_view_invite_route("not_exists"))

      assert response(conn, 404)
    end

    test "renders invite section page correctly", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_invite_route(section.slug))

      assert render(view) =~
               "Create new invite link expiring after"
    end

    test "creates an invitation link expiring after one day", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_invite_route(section.slug))

      assert view
             |> element("button[phx-value-option=\"one_day\"]")
             |> render_click(%{option: "one_day"})

      html = render(view)
      assert html =~ "Invitation created"
      assert html =~ "Time remaining: 23 hours"
    end

    test "creates an invitation link expiring after one week", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, live_view_invite_route(section.slug))

      assert view
             |> element("button[phx-value-option=\"one_week\"]")
             |> render_click(%{option: "one_week"})

      html = render(view)
      assert html =~ "Invitation created"
      assert html =~ "Time remaining: 6 days"
    end

    test "creates an invitation link expiring when the section starts", %{conn: conn} do
      section = insert(:section_with_dates)
      {:ok, view, _html} = live(conn, live_view_invite_route(section.slug))

      assert view
             |> element("button[phx-value-option=\"section_start\"]")
             |> render_click(%{option: "section_start"})

      html = render(view)
      assert html =~ "Invitation created"
      assert html =~ "Expires: #{date(section.start_date)}"
    end

    test "creates an invitation link expiring when the section ends", %{conn: conn} do
      section = insert(:section_with_dates)
      {:ok, view, _html} = live(conn, live_view_invite_route(section.slug))

      assert view
             |> element("button[phx-value-option=\"section_end\"]")
             |> render_click(%{option: "section_end"})

      html = render(view)
      assert html =~ "Invitation created"
      assert html =~ "Expires: #{date(section.end_date)}"
    end

    test "cannot create a section invite when the course registration is not open", %{conn: conn} do
      section = insert(:section, registration_open: false)
      {:ok, view, _html} = live(conn, live_view_invite_route(section.slug))

      assert view
             |> element("button[phx-value-option=\"one_day\"]")
             |> render_click(%{option: "one_day"})

      assert render(view) =~
               "Could not create invitation because the registration for the section is not open"
    end
  end
end
