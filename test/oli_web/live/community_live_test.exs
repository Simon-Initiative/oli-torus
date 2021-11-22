defmodule OliWeb.CommunityLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Groups
  alias Oli.Groups.Community

  @live_view_index_route Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.IndexView)
  @live_view_new_route Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.NewView)
  @form_fields [:name, :description, :key_contact, :global_access]

  defp live_view_show_route(community_id) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.ShowView, community_id)
  end

  defp live_view_associated_index_route(community_id) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.Associated.IndexView, community_id)
  end

  defp live_view_associated_new_route(community_id) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.Associated.NewView, community_id)
  end

  defp create_community(_conn) do
    community = insert(:community)

    [community: community]
  end

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the index view", %{conn: conn} do
      {:error,
       {:redirect, %{to: "/authoring/session/new?request_path=%2Fauthoring%2Fcommunities"}}} =
        live(conn, @live_view_index_route)
    end

    test "redirects to new session when accessing the create view", %{conn: conn} do
      {:error,
       {:redirect, %{to: "/authoring/session/new?request_path=%2Fadmin%2Fcommunities%2Fnew"}}} =
        live(conn, @live_view_new_route)
    end

    test "redirects to new session when accessing the show view", %{conn: conn} do
      community_id = insert(:community).id

      redirect_path =
        "/authoring/session/new?request_path=%2Fauthoring%2Fcommunities%2F#{community_id}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_show_route(community_id))
    end
  end

  describe "user cannot access when is logged in as an author but is not a system or community admin" do
    setup [:author_conn]

    test "redirects to projects when accessing the index view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authoring/projects"}}} = live(conn, @live_view_index_route)
    end

    test "returns forbidden when accessing the create view", %{conn: conn} do
      conn = get(conn, @live_view_new_route)

      assert response(conn, 403)
    end

    test "redirects to projects when accessing the show view", %{conn: conn} do
      community = insert(:community)

      {:error, {:redirect, %{to: "/authoring/projects"}}} =
        live(conn, live_view_show_route(community.id))
    end

    test "redirects to communities when accessing a community that is not an admin", %{
      conn: conn,
      author: author
    } do
      insert(:community)
      insert(:community_account, %{author: author})

      {:error, {:redirect, %{to: "/authoring/communities"}}} =
        live(conn, live_view_show_route(123))
    end
  end

  describe "index" do
    setup [:admin_conn]

    test "loads correctly when there are no communities", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert has_element?(view, "#communities-table")
      assert has_element?(view, "p", "None exist")
      assert has_element?(view, "a[href=\"#{@live_view_new_route}\"]")
    end

    test "lists only active communities", %{conn: conn} do
      c1 = insert(:community)
      c2 = insert(:community, status: :deleted)

      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert has_element?(view, "#communities-table")
      assert has_element?(view, "##{c1.id}")
      refute has_element?(view, "##{c2.id}")
    end

    test "lists all communities when filter is applied", %{conn: conn} do
      c1 = insert(:community)
      c2 = insert(:community, status: :deleted)

      {:ok, view, _html} = live(conn, @live_view_index_route)

      view
      |> element("#community-filters form")
      |> render_change(%{"filter" => %{"status" => "active,deleted"}})

      assert has_element?(view, "#communities-table")
      assert has_element?(view, "##{c1.id}")
      assert has_element?(view, "##{c2.id}")
    end

    test "applies filtering", %{conn: conn} do
      c1 = insert(:community, %{name: "Testing"})
      c2 = insert(:community)

      {:ok, view, _html} = live(conn, @live_view_index_route)

      view
      |> element("input[phx-blur=\"change_search\"]")
      |> render_blur(%{value: "testing"})

      view
      |> element("button[phx-click=\"apply_search\"]")
      |> render_click()

      assert has_element?(view, "##{c1.id}")
      refute has_element?(view, "##{c2.id}")

      view
      |> element("button[phx-click=\"reset_search\"]")
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

  describe "show" do
    setup [:admin_conn, :create_community]

    defp render_delete_modal(view) do
      view
      |> element("button[phx-click=\"show_delete_modal\"]")
      |> render_click()
    end

    test "loads correctly with community data", %{conn: conn, community: community} do
      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      assert has_element?(view, "#community-overview")

      community
      |> Map.take(@form_fields)
      |> Map.update(:global_access, "checked", fn value -> if value, do: "checked", else: "" end)
      |> Enum.each(fn {field, value} ->
        assert view
               |> element("#community_#{field}")
               |> render() =~
                 value
      end)

      assert has_element?(view, "a[href=\"#{live_view_associated_index_route(community.id)}\"]")
    end

    test "displays error message when data is invalid", %{
      conn: conn,
      community: %Community{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{community: %{name: ""}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Community couldn&#39;t be updated. Please check the errors below."

      assert has_element?(view, "span", "can't be blank")

      refute Groups.get_community(id).name == ""
    end

    test "updates a community correctly when data is valid", %{
      conn: conn,
      community: %Community{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      new_attributes = params_for(:community)

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{community: new_attributes})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Community successfully updated."

      %Community{name: new_name} = Groups.get_community(id)

      assert new_attributes.name == new_name
    end

    test "redirects to index view and displays error message when community does not exist", %{
      conn: conn
    } do
      conn = get(conn, live_view_show_route(1000))

      assert conn.private.plug_session["phoenix_flash"]["info"] ==
               "That community does not exist or it was deleted."

      assert conn.resp_body =~ ~r/You are being.*redirected/
      assert conn.resp_body =~ "href=\"#{@live_view_index_route}\""
    end

    test "redirects to index view and displays error message when community has deleted status",
         %{
           conn: conn
         } do
      %Community{id: id} = insert(:community, status: :deleted)

      conn = get(conn, live_view_show_route(id))

      assert conn.private.plug_session["phoenix_flash"]["info"] ==
               "That community does not exist or it was deleted."

      assert conn.resp_body =~ ~r/You are being.*redirected/
      assert conn.resp_body =~ "href=\"#{@live_view_index_route}\""
    end

    test "displays a confirm modal before deleting a community", %{
      conn: conn,
      community: %Community{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      render_delete_modal(view)

      assert view
             |> element("#delete_community_modal h5.modal-title")
             |> render() =~
               "Are you absolutely sure?"
    end

    test "does not allow deleting the community if names do not match", %{
      conn: conn,
      community: %Community{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      render_delete_modal(view)

      view
      |> element("#delete_community_modal form")
      |> render_change(%{"community" => %{"name" => "invalid name"}})

      assert view
             |> element("#delete_community_modal form button")
             |> render() =~
               "disabled"
    end

    test "allows deleting the community if names match", %{
      conn: conn,
      community: %Community{id: id, name: name}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      render_delete_modal(view)

      view
      |> element("#delete_community_modal form")
      |> render_change(%{"community" => %{"name" => name}})

      refute view
             |> element("#delete_community_modal form button")
             |> render() =~
               "disabled"
    end

    test "deletes the community and redirects to the index page", %{
      conn: conn,
      community: %Community{id: id, name: name}
    } do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      render_delete_modal(view)

      view
      |> element("#delete_community_modal form")
      |> render_submit(%{"community" => %{"name" => name}})

      flash = assert_redirected(view, @live_view_index_route)
      assert flash["info"] == "Community successfully deleted."

      assert nil == Groups.get_community(id)
    end

    test "adds community admin correctly", %{
      conn: conn,
      community: community
    } do
      author = insert(:author)
      insert(:community_account, %{community: community})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      assert 1 == length(Groups.list_community_admins(community.id))

      view
      |> element("form[phx-submit=\"add_collaborator\"")
      |> render_submit(%{collaborator: %{email: author.email}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Admin successfully added."

      assert 2 == length(Groups.list_community_admins(community.id))
    end

    test "displays error messages when adding community admin fails", %{
      conn: conn,
      community: community
    } do
      author = build(:author)
      insert(:community_account, %{community: community, author: author})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      view
      |> element("form[phx-submit=\"add_collaborator\"")
      |> render_submit(%{collaborator: %{email: author.email}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Community admin couldn&#39;t be added. Author is already an admin or an unexpected error occurred."

      view
      |> element("form[phx-submit=\"add_collaborator\"")
      |> render_submit(%{collaborator: %{email: "wrong@example.com"}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Community admin couldn&#39;t be added. Author does not exist."

      assert 1 == length(Groups.list_community_admins(community.id))
    end

    test "removes community admin correctly", %{
      conn: conn,
      community: community
    } do
      author = insert(:author)
      insert(:community_account, %{community: community, author: author})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      assert 1 == length(Groups.list_community_admins(community.id))

      view
      |> element("button[phx-click=\"remove_collaborator\"")
      |> render_click(%{"collaborator-id" => author.id})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Admin successfully removed."

      assert 0 == length(Groups.list_community_admins(community.id))
    end

    test "displays error messages when removing community admin fails", %{
      conn: conn,
      community: community
    } do
      author = insert(:author)
      insert(:community_account, %{community: community, author: author})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      assert 1 == length(Groups.list_community_admins(community.id))

      view
      |> element("button[phx-click=\"remove_collaborator\"")
      |> render_click(%{"collaborator-id" => 12345})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Community admin couldn&#39;t be removed."

      assert 1 == length(Groups.list_community_admins(community.id))
    end
  end

  describe "associated index" do
    setup [:admin_conn, :create_community]

    test "loads correctly when there are no communities visibilities", %{
      conn: conn,
      community: %Community{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_associated_index_route(id))

      assert has_element?(view, "p", "None exist")
      assert has_element?(view, "a[href=\"#{live_view_associated_new_route(id)}\"]")
    end

    test "lists communities visibilities", %{conn: conn, community: community} do
      cv1 = insert(:community_visibility, %{community: community})
      cv2 = insert(:community_visibility, %{community: community})

      {:ok, view, _html} = live(conn, live_view_associated_index_route(community.id))

      assert has_element?(view, "##{cv1.id}")
      assert has_element?(view, "##{cv2.id}")
    end

    test "removes community visibility", %{conn: conn, community: community} do
      cv1 = insert(:community_visibility, %{community: community})

      {:ok, view, _html} = live(conn, live_view_associated_index_route(community.id))

      view
      |> element("tr:first-child > td:last-child > button")
      |> render_click(%{"id" => cv1.id})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Association successfully removed."

      refute has_element?(view, "##{cv1.id}")
      assert has_element?(view, "p", "None exist")
    end

    test "applies searching", %{conn: conn, community: community} do
      project = insert(:project, %{title: "Testing"})
      cv1 = insert(:community_visibility, %{community: community, project: project})
      cv2 = insert(:community_visibility, %{community: community})

      {:ok, view, _html} = live(conn, live_view_associated_index_route(community.id))

      view
      |> element("input[phx-blur=\"change_search\"]")
      |> render_blur(%{value: "testing"})

      view
      |> element("button[phx-click=\"apply_search\"]")
      |> render_click()

      assert has_element?(view, "##{cv1.id}")
      refute has_element?(view, "##{cv2.id}")

      view
      |> element("button[phx-click=\"reset_search\"]")
      |> render_click()

      assert has_element?(view, "##{cv1.id}")
      assert has_element?(view, "##{cv2.id}")
    end

    test "applies sorting", %{conn: conn, community: community} do
      project_1 = insert(:project, %{title: "Testing A"})
      project_2 = insert(:project, %{title: "Testing B"})
      insert(:community_visibility, %{community: community, project: project_1})
      insert(:community_visibility, %{community: community, project: project_2})

      {:ok, view, _html} = live(conn, live_view_associated_index_route(community.id))

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Testing A"

      view
      |> element("th[phx-click=\"sort\"]:first-of-type")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Testing B"
    end

    test "applies paging", %{conn: conn, community: community} do
      [first_cv | tail] =
        insert_list(21, :community_visibility, %{community: community}) |> Enum.sort()

      last_cv = List.last(tail)

      {:ok, view, _html} = live(conn, live_view_associated_index_route(community.id))

      assert has_element?(view, "##{first_cv.id}")
      refute has_element?(view, "##{last_cv.id}")

      view
      |> element("a[phx-click=\"page_change\"]", "2")
      |> render_click()

      refute has_element?(view, "##{first_cv.id}")
      assert has_element?(view, "##{last_cv.id}")
    end
  end

  describe "associated index new" do
    setup [:admin_conn, :create_community]

    test "loads correctly when there are no projects or products", %{
      conn: conn,
      community: %Community{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_associated_new_route(id))

      assert has_element?(view, "p", "None exist")
    end

    test "lists projects and products", %{conn: conn, community: %Community{id: id}} do
      project = insert(:project)
      product = insert(:section)

      {:ok, view, _html} = live(conn, live_view_associated_new_route(id))

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               project.title

      assert view
             |> element("tr:last-child > td:first-child")
             |> render() =~
               product.title
    end

    test "adds project to community", %{conn: conn, community: %Community{id: id}} do
      project = insert(:project)

      {:ok, view, _html} = live(conn, live_view_associated_new_route(id))

      view
      |> element("tr:first-child > td:last-child > button")
      |> render_click(%{"id" => project.id, "type" => "project"})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Association to project succesfully added."

      assert 1 == length(Groups.list_community_visibilities(id))
    end

    test "applies searching", %{conn: conn, community: %Community{id: id}} do
      project_1 = insert(:project, %{title: "Testing"})
      project_2 = insert(:project)

      {:ok, view, _html} = live(conn, live_view_associated_new_route(id))

      view
      |> element("input[phx-blur=\"change_search\"]")
      |> render_blur(%{value: "testing"})

      view
      |> element("button[phx-click=\"apply_search\"]")
      |> render_click()

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               project_1.title

      refute view
             |> element("tr:last-child > td:first-child")
             |> render() =~
               project_2.title

      view
      |> element("button[phx-click=\"reset_search\"]")
      |> render_click()

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               project_2.title

      assert view
             |> element("tr:last-child > td:first-child")
             |> render() =~
               project_1.title
    end

    test "applies sorting", %{conn: conn, community: %Community{id: id}} do
      insert(:section, %{title: "Testing B"})

      {:ok, view, _html} = live(conn, live_view_associated_new_route(id))

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Example Course"

      view
      |> element("th[phx-click=\"sort\"]:first-of-type")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Testing B"
    end

    test "applies paging", %{conn: conn, community: %Community{id: id}} do
      [first_project | _tail] = insert_list(19, :project)
      section = insert(:section)

      {:ok, view, _html} = live(conn, live_view_associated_new_route(id))

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               first_project.title

      refute view
             |> element("tr:last-child > td:first-child")
             |> render() =~
               section.title

      view
      |> element("a[phx-click=\"page_change\"]", "2")
      |> render_click()

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               section.title
    end
  end
end
