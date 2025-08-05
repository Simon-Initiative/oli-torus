defmodule OliWeb.PublisherLiveTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Inventories
  alias Oli.Inventories.Publisher

  @live_view_index_route Routes.live_path(OliWeb.Endpoint, OliWeb.PublisherLive.IndexView)
  @live_view_new_route Routes.live_path(OliWeb.Endpoint, OliWeb.PublisherLive.NewView)
  @form_fields [:name, :email, :address, :main_contact, :website_url]

  defp live_view_show_route(publisher_id) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.PublisherLive.ShowView, publisher_id)
  end

  defp create_publisher(_conn) do
    publisher = insert(:publisher)

    [publisher: publisher]
  end

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the index view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authors/log_in"}}} =
        live(conn, @live_view_index_route)
    end

    test "redirects to new session when accessing the create view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authors/log_in"}}} =
        live(conn, @live_view_new_route)
    end

    test "redirects to new session when accessing the show view", %{conn: conn} do
      publisher_id = insert(:publisher).id

      redirect_path =
        "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_show_route(publisher_id))
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

    test "returns forbidden when accessing the create view", %{conn: conn} do
      conn = get(conn, @live_view_new_route)

      assert redirected_to(conn) == ~p"/workspaces/course_author"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not authorized to access this page."
    end

    test "returns forbidden when accessing the show view", %{conn: conn} do
      publisher = insert(:publisher)

      conn = get(conn, live_view_show_route(publisher.id))

      assert redirected_to(conn) == ~p"/workspaces/course_author"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You are not authorized to access this page."
    end
  end

  describe "index" do
    setup [:admin_conn]

    test "loads correctly when there is only the default publisher", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert has_element?(view, "a[href=\"#{@live_view_new_route}\"]")

      assert view
             |> element("#publishers-table")
             |> render() =~ "Torus Publisher"

      assert view
             |> element("#publishers-table span.badge")
             |> render() =~ "default"
    end

    test "applies searching", %{conn: conn} do
      p1 = insert(:publisher, %{name: "Testing"})
      p2 = insert(:publisher)

      {:ok, view, _html} = live(conn, @live_view_index_route)

      view
      |> element("input[phx-blur=\"change_search\"]")
      |> render_blur(%{value: "testing"})

      view
      |> element("button[phx-click=\"apply_search\"]")
      |> render_click()

      assert has_element?(view, "##{p1.id}")
      refute has_element?(view, "##{p2.id}")

      view
      |> element("button[phx-click=\"reset_search\"]")
      |> render_click()

      assert has_element?(view, "##{p1.id}")
      assert has_element?(view, "##{p2.id}")
    end

    test "applies sorting", %{conn: conn} do
      insert(:publisher, %{name: "A Publisher"})
      insert(:publisher, %{name: "Z Publisher"})

      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "A Publisher"

      view
      |> element("th[phx-click=\"sort\"]:first-of-type")
      |> render_click(%{sort_by: "name"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Z Publisher"
    end

    test "applies sorting by created at", %{conn: conn} do
      Oli.Inventories.Publisher
      |> Oli.Repo.get_by!(email: "publisher@cmu.edu")
      |> Oli.Repo.delete()

      now = DateTime.utc_now()
      two_months_later = DateTime.add(now, 60, :day)

      insert(:publisher, %{name: "A Publisher", inserted_at: now})
      insert(:publisher, %{name: "Z Publisher", inserted_at: two_months_later})

      {:ok, view, _html} = live(conn, @live_view_index_route)

      view
      |> element("th[phx-click=\"sort\"]:first-of-type")
      |> render_click(%{sort_by: "inserted_at"})

      assert view |> element("tr:first-child > td:first-child") |> render() =~
               "A Publisher"

      assert view |> element("tr:last-child > td:first-child") |> render() =~
               "Z Publisher"

      view
      |> element("th[phx-click=\"sort\"]:first-of-type")
      |> render_click(%{sort_by: "inserted_at"})

      assert view |> element("tr:first-child > td:first-child") |> render() =~
               "Z Publisher"

      assert view |> element("tr:last-child > td:first-child") |> render() =~
               "A Publisher"
    end

    test "applies paging", %{conn: conn} do
      [first_p | tail] = insert_list(21, :publisher) |> Enum.sort_by(& &1.name)
      last_p = List.last(tail)

      conn = get(conn, @live_view_index_route)
      {:ok, view, _html} = live(conn)

      assert has_element?(view, "##{first_p.id}")
      refute has_element?(view, "##{last_p.id}")

      view
      |> element("button[phx-click=\"page_change\"]", "2")
      |> render_click()

      refute has_element?(view, "##{first_p.id}")
      assert has_element?(view, "##{last_p.id}")
    end

    test "renders datetimes using the local timezone", context do
      {:ok, conn: conn, ctx: session_context} = set_timezone(context)
      publisher = Inventories.default_publisher()

      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert view
             |> element("tr##{publisher.id}")
             |> render() =~
               OliWeb.Common.Utils.render_date(publisher, :inserted_at, session_context)
    end
  end

  describe "new" do
    setup [:admin_conn]

    test "loads correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_new_route)

      assert has_element?(view, "h5", "New Publisher")
      assert has_element?(view, "form[phx-submit=\"save\"")
    end

    test "displays error message when data is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_new_route)

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{publisher: %{name: ""}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Publisher couldn&#39;t be created. Please check the errors below."

      assert has_element?(view, "p", "can't be blank")
      # Only the default publisher
      assert 1 = Inventories.list_publishers() |> length()
    end

    test "displays error message when publisher name already exists with leading or trailing whitespaces",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_new_route)

      publisher = insert(:publisher)

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{
        publisher: %{name: publisher.name <> " ", email: "test@email.com", default: false}
      })

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Publisher couldn&#39;t be created. Please check the errors below."

      assert has_element?(view, "p", "has already been taken")
      # There are 2 considering the default publisher
      assert 2 = Inventories.list_publishers() |> length()
    end

    test "saves new publisher when data is valid", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_new_route)

      params = params_for(:publisher)

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{
        publisher: params
      })

      flash = assert_redirected(view, @live_view_index_route)
      assert flash["info"] == "Publisher successfully created."

      %Publisher{name: name} = Inventories.get_publisher_by(name: params[:name])

      assert ^name = params.name
    end
  end

  describe "show" do
    setup [:admin_conn, :create_publisher]

    defp render_delete_modal(view) do
      view
      |> element("button[phx-click=\"show_delete_modal\"]")
      |> render_click()
    end

    defp render_set_default_modal(view) do
      view
      |> element("button[phx-click=\"show_set_default_modal\"]")
      |> render_click()
    end

    test "loads correctly with publisher data", %{conn: conn, publisher: publisher} do
      {:ok, view, _html} = live(conn, live_view_show_route(publisher.id))

      assert has_element?(view, "#publisher-overview")

      publisher
      |> Map.take(@form_fields)
      |> Enum.each(fn {field, value} ->
        assert view
               |> element("#publisher_#{field}")
               |> render() =~
                 value
      end)
    end

    test "displays default badge when visiting the default publisher show page", %{conn: conn} do
      %Publisher{id: id} = Inventories.default_publisher()
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      assert view
             |> element("#publisher-overview span")
             |> render() =~ "default"
    end

    test "displays error message when data is invalid", %{
      conn: conn,
      publisher: %Publisher{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{publisher: %{name: ""}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Publisher couldn&#39;t be updated. Please check the errors below."

      assert has_element?(view, "p", "can't be blank")
      refute Inventories.get_publisher(id).name == ""
    end

    test "updates a publisher correctly when data is valid", %{
      conn: conn,
      publisher: %Publisher{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      new_attributes =
        params_for(:publisher,
          knowledge_base_link: "https://updated.kb.com",
          support_email: "updated-support@example.com"
        )

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{publisher: new_attributes})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Publisher successfully updated."

      %Publisher{
        name: new_name,
        knowledge_base_link: new_kb,
        support_email: new_email
      } = Inventories.get_publisher(id)

      assert new_attributes.name == new_name
      assert new_attributes.knowledge_base_link == new_kb
      assert new_attributes.support_email == new_email
    end

    test "displays error message when updating a publisher and the name already exists with leading or trailing whitespaces",
         %{conn: conn, publisher: %Publisher{id: id}} do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      publisher = insert(:publisher)
      new_attributes = params_for(:publisher, name: publisher.name <> " ")

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{publisher: new_attributes})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Publisher couldn&#39;t be updated. Please check the errors below."

      assert has_element?(view, "p", "has already been taken")
      assert 3 = Inventories.list_publishers() |> length()
    end

    test "redirects to index view and displays error message when publisher does not exist", %{
      conn: conn
    } do
      conn = get(conn, live_view_show_route(-1))

      assert conn.private.plug_session["phoenix_flash"]["info"] ==
               "That publisher does not exist or it was deleted."

      assert conn.resp_body =~ ~r/You are being.*redirected/
      assert conn.resp_body =~ "href=\"#{@live_view_index_route}\""
    end

    test "displays a confirm modal before deleting a publisher", %{
      conn: conn,
      publisher: %Publisher{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      render_delete_modal(view)

      assert view
             |> element("#delete_publisher_modal h5.modal-title")
             |> render() =~
               "Are you absolutely sure?"
    end

    test "disables the default publisher deletion", %{
      conn: conn
    } do
      default_publisher = Inventories.default_publisher()

      {:ok, view, _html} = live(conn, live_view_show_route(default_publisher.id))

      refute has_element?(view, "button[phx-click=\"show_delete_modal\"]")
    end

    test "does not allow deleting the publisher if names do not match", %{
      conn: conn,
      publisher: %Publisher{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      render_delete_modal(view)

      view
      |> element("#delete_publisher_modal form")
      |> render_change(%{"publisher" => %{"name" => "invalid name"}})

      assert view
             |> element("#delete_publisher_modal form button")
             |> render() =~
               "disabled"
    end

    test "allows deleting the publisher if names match", %{
      conn: conn,
      publisher: %Publisher{id: id, name: name}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      render_delete_modal(view)

      view
      |> element("#delete_publisher_modal form")
      |> render_change(%{"name" => name})

      refute view
             |> element("#delete_publisher_modal form button")
             |> render() =~
               "disabled"
    end

    test "deletes the publisher and redirects to the index page", %{
      conn: conn,
      publisher: %Publisher{id: id, name: name}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      render_delete_modal(view)

      view
      |> element("#delete_publisher_modal form")
      |> render_submit(%{"publisher" => %{"name" => name}})

      flash = assert_redirected(view, @live_view_index_route)
      assert flash["info"] == "Publisher successfully deleted."
      assert nil == Inventories.get_publisher(id)
    end

    test "displays a confirm modal before setting a publisher as default", %{
      conn: conn,
      publisher: %Publisher{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      render_set_default_modal(view)

      assert view
             |> element("#set_default_modal h5.modal-title")
             |> render() =~
               "Confirm Default"
    end

    test "sets the publisher as the default", %{
      conn: conn,
      publisher: %Publisher{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      render_set_default_modal(view)

      view
      |> element("button[phx-click=\"set_default\"]")
      |> render_click()

      assert render(view) =~ "Publisher successfully set as the default."

      assert view
             |> element("#publisher-overview span")
             |> render() =~ "default"
    end

    test "disables setting the publisher as the default when it is already the default", %{
      conn: conn
    } do
      default_publisher = Inventories.default_publisher()

      {:ok, view, _html} = live(conn, live_view_show_route(default_publisher.id))

      refute has_element?(view, "button[phx-click=\"show_set_default_modal\"]")
    end

    test "makes a publisher unavailable via API", %{
      conn: conn,
      publisher: %Publisher{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      view
      |> element("form[phx-change=\"save\"")
      |> render_change(%{publisher: %{available_via_api: false}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Publisher successfully updated."

      assert %Publisher{available_via_api: false} = Inventories.get_publisher(id)
    end

    test "displays error message when updating with invalid support_email", %{
      conn: conn,
      publisher: %Publisher{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      invalid_attributes = params_for(:publisher, support_email: "invalid-email")

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{publisher: invalid_attributes})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Publisher couldn&#39;t be updated. Please check the errors below."

      assert has_element?(view, "p", "must have the @ sign and no spaces")
    end
  end
end
