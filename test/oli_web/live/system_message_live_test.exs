defmodule OliWeb.SystemMessageLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Notifications
  alias Oli.Notifications.SystemMessage

  @live_view_index_route Routes.live_path(OliWeb.Endpoint, OliWeb.SystemMessageLive.IndexView)

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the index view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authors/log_in"}}} =
        live(conn, @live_view_index_route)
    end
  end

  describe "user cannot access when is logged in as an author but is not a system admin" do
    setup [:author_conn]

    test "returns forbidden when accessing the index view", %{conn: conn} do
      conn = get(conn, @live_view_index_route)

      assert redirected_to(conn) == ~p"/workspaces/course_author"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not authorized to access this page."
    end
  end

  describe "index" do
    setup [:admin_conn, :set_timezone]

    test "loads correctly when there are no system messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_index_route)

      refute has_element?(view, "#system_message_active")
      assert render(view) =~ "Create"
    end

    test "lists all existing system messages", %{conn: conn} do
      system_message = insert(:system_message)
      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert view
             |> element(
               "form[phx-submit=\"save\"] textarea[id=\"system_message_message_#{system_message.id}\"]"
             )
             |> render() =~ system_message.message
    end

    test "displays start and end datetimes using the local timezone", %{
      conn: conn,
      ctx: ctx
    } do
      system_message = insert(:system_message)
      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert view
             |> element("#system_message_start")
             |> render() =~
               utc_datetime_to_localized_datestring(system_message.start, ctx.local_tz)

      assert view
             |> element("#system_message_end")
             |> render() =~
               utc_datetime_to_localized_datestring(system_message.end, ctx.local_tz)
    end

    test "creates new system message when data is valid", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_index_route)

      params = params_for(:system_message)

      view
      |> element("form[phx-submit=\"create\"")
      |> render_submit(%{
        system_message: params
      })

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "System message successfully created."

      [%SystemMessage{message: message} | _tail] = Notifications.list_system_messages()

      assert ^message = params.message
    end

    test "displays error message when data is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_index_route)

      view
      |> element("form[phx-submit=\"create\"")
      |> render_submit(%{system_message: %{message: ""}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "System message couldn&#39;t be created: message can&#39;t be blank."

      assert [] = Notifications.list_system_messages()
    end

    test "updates system message correctly when data is valid", %{
      conn: conn
    } do
      system_message = insert(:system_message)
      {:ok, view, _html} = live(conn, @live_view_index_route)

      new_attributes = params_for(:system_message)

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{system_message: new_attributes})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "System message successfully updated."

      %SystemMessage{message: new_message} = Notifications.get_system_message(system_message.id)

      assert new_attributes.message == new_message
    end

    test "displays confirmation modal when updating a message status", %{
      conn: conn
    } do
      insert(:active_system_message)
      {:ok, view, _html} = live(conn, @live_view_index_route)

      new_attributes = params_for(:system_message, active: false)

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{system_message: new_attributes})

      assert has_element?(view, "#dialog")

      assert view
             |> element("#dialog")
             |> render() =~
               "Are you sure that you wish to <b>hide</b>\n    this message to all users in the system?"
    end

    test "deletes the system message successfully", %{
      conn: conn
    } do
      %SystemMessage{id: id} = insert(:system_message)
      {:ok, view, _html} = live(conn, @live_view_index_route)

      view
      |> element("button[phx-click=\"delete\"]")
      |> render_click()

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "System message successfully deleted."

      assert nil == Notifications.get_system_message(id)
    end
  end

  describe "show" do
    setup [:create_active_system_message]

    test "displays system message when user is not logged in", %{
      conn: conn,
      system_message: system_message
    } do
      conn = get(conn, Routes.static_page_path(conn, :index))

      assert html_response(conn, 200) =~ system_message.message
    end

    test "displays system message when user is logged in as an author", context do
      {:ok, conn: conn, author: _} = author_conn(context)
      conn = get(conn, Routes.static_page_path(conn, :index))

      assert html_response(conn, 200) =~ context.system_message.message
    end

    test "displays system message when user is logged in as an instructor", context do
      {:ok, conn: conn, user: _} = user_conn(context)
      conn = get(conn, Routes.static_page_path(conn, :index))

      assert html_response(conn, 200) =~ context.system_message.message
    end

    test "displays more than one system message if exist", %{
      conn: conn,
      system_message: system_message
    } do
      other_system_message = insert(:active_system_message)

      conn = get(conn, Routes.static_page_path(conn, :index))

      assert html_response(conn, 200) =~ system_message.message
      assert html_response(conn, 200) =~ other_system_message.message
    end
  end

  def create_active_system_message(_context) do
    system_message = insert(:active_system_message)

    {:ok, system_message: system_message}
  end
end
