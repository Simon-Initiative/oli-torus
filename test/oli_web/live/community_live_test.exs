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

  defp live_view_members_index_route(community_id) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.MembersIndexView, community_id)
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

    test "applies filtering", %{conn: conn} do
      c1 = insert(:community)
      c2 = insert(:community, status: :deleted)

      {:ok, view, _html} = live(conn, @live_view_index_route)

      assert has_element?(view, "##{c1.id}")
      refute has_element?(view, "##{c2.id}")

      view
      |> element("#community-filters form")
      |> render_change(%{"filter" => %{"status" => "active,deleted"}})

      assert has_element?(view, "##{c1.id}")
      assert has_element?(view, "##{c2.id}")
    end

    test "applies searching", %{conn: conn} do
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

    test "displays error message when community name already exists with leading or trailing whitespaces",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_new_route)

      community = insert(:community)

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{community: %{name: community.name <> " "}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Community couldn&#39;t be created. Please check the errors below."

      assert has_element?(view, "span", "has already been taken")
      assert 1 = Groups.list_communities() |> length()
    end

    test "saves new community when data is valid", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_new_route)

      params = params_for(:community)

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{
        community: params
      })

      flash = assert_redirected(view, @live_view_index_route)
      assert flash["info"] == "Community successfully created."

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

    test "displays error message when updating a community and the name already exists with leading or trailing whitespaces",
         %{conn: conn, community: %Community{id: id}} do
      {:ok, view, _html} = live(conn, live_view_show_route(id))

      community = insert(:community)
      new_attributes = params_for(:community, name: community.name <> " ")

      view
      |> element("form[phx-submit=\"save\"")
      |> render_submit(%{community: new_attributes})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Community couldn&#39;t be updated. Please check the errors below."

      assert has_element?(view, "span", "has already been taken")
      assert 2 = Groups.list_communities() |> length()
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
      |> element("form[phx-submit=\"add_admin\"")
      |> render_submit(%{collaborator: %{email: author.email}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Community admin(s) successfully added."

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
      |> element("form[phx-submit=\"add_admin\"")
      |> render_submit(%{collaborator: %{email: author.email}})

      error_message =
        "Some of the community admins couldn&#39;t be added because the users don&#39;t exist in the system or are already associated."

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~ error_message

      view
      |> element("form[phx-submit=\"add_admin\"")
      |> render_submit(%{collaborator: %{email: "wrong@example.com"}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~ error_message

      assert 1 == length(Groups.list_community_admins(community.id))
    end

    test "adds more than one community admin correctly", %{
      conn: conn,
      community: community
    } do
      emails = insert_pair(:author) |> Enum.map(& &1.email)
      insert(:community_account, %{community: community})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      assert 1 == length(Groups.list_community_admins(community.id))

      view
      |> element("form[phx-submit=\"add_admin\"")
      |> render_submit(%{collaborator: %{email: Enum.join(emails, ",")}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Community admin(s) successfully added."

      assert 3 == length(Groups.list_community_admins(community.id))
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
      |> element("button[phx-click=\"remove_admin\"")
      |> render_click(%{"collaborator-id" => author.id})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Community admin successfully removed."

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
      |> element("button[phx-click=\"remove_admin\"")
      |> render_click(%{"collaborator-id" => 12345})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Community admin couldn&#39;t be removed."

      assert 1 == length(Groups.list_community_admins(community.id))
    end

    test "suggests community admin correctly", %{
      conn: conn,
      community: community
    } do
      author = insert(:author)

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      view
      |> element("form[phx-change=\"suggest_admin\"")
      |> render_change(%{collaborator: %{email: author.name}})

      assert view
             |> element("#admin_matches")
             |> render() =~
               author.email

      view
      |> element("form[phx-change=\"suggest_admin\"")
      |> render_change(%{collaborator: %{email: "other_name"}})

      refute view
             |> element("#admin_matches")
             |> render() =~
               author.email
    end

    test "adds community member correctly", %{
      conn: conn,
      community: community
    } do
      user = insert(:user)
      insert(:community_member_account, %{community: community})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      assert 1 == length(Groups.list_community_members(community.id))

      view
      |> element("form[phx-submit=\"add_member\"")
      |> render_submit(%{collaborator: %{email: user.email}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Community member(s) successfully added."

      assert 2 == length(Groups.list_community_members(community.id))
    end

    test "displays error messages when adding community member fails", %{
      conn: conn,
      community: community
    } do
      user = build(:user)
      insert(:community_member_account, %{community: community, user: user})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      view
      |> element("form[phx-submit=\"add_member\"")
      |> render_submit(%{collaborator: %{email: user.email}})

      error_message =
        "Some of the community members couldn&#39;t be added because the users don&#39;t exist in the system or are already associated."

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~ error_message

      view
      |> element("form[phx-submit=\"add_member\"")
      |> render_submit(%{collaborator: %{email: "wrong@example.com"}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~ error_message

      assert 1 == length(Groups.list_community_members(community.id))
    end

    test "adds more than one community member correctly", %{
      conn: conn,
      community: community
    } do
      emails = insert_pair(:user) |> Enum.map(& &1.email)
      insert(:community_member_account, %{community: community})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      assert 1 == length(Groups.list_community_members(community.id))

      view
      |> element("form[phx-submit=\"add_member\"")
      |> render_submit(%{collaborator: %{email: Enum.join(emails, ",")}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Community member(s) successfully added."

      assert 3 == length(Groups.list_community_members(community.id))
    end

    test "removes community member correctly", %{
      conn: conn,
      community: community
    } do
      user = insert(:user)
      insert(:community_member_account, %{community: community, user: user})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      assert 1 == length(Groups.list_community_members(community.id))

      view
      |> element("button[phx-click=\"remove_member\"")
      |> render_click(%{"collaborator-id" => user.id})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Community member successfully removed."

      assert 0 == length(Groups.list_community_admins(community.id))
    end

    test "displays error messages when removing community member fails", %{
      conn: conn,
      community: community
    } do
      user = insert(:user)
      insert(:community_member_account, %{community: community, user: user})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      assert 1 == length(Groups.list_community_members(community.id))

      view
      |> element("button[phx-click=\"remove_member\"")
      |> render_click(%{"collaborator-id" => 12345})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Community member couldn&#39;t be removed."

      assert 1 == length(Groups.list_community_members(community.id))
    end

    test "suggests community member correctly", %{
      conn: conn,
      community: community
    } do
      user = insert(:user)

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      view
      |> element("form[phx-change=\"suggest_member\"")
      |> render_change(%{collaborator: %{email: user.name}})

      assert view
             |> element("#member_matches")
             |> render() =~
               user.email

      view
      |> element("form[phx-change=\"suggest_member\"")
      |> render_change(%{collaborator: %{email: "other_name"}})

      refute view
             |> element("#member_matches")
             |> render() =~
               user.email
    end

    test "adds community institution correctly", %{
      conn: conn,
      community: community
    } do
      institution = insert(:institution)
      insert(:community_institution, %{community: community})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      assert 1 == length(Groups.list_community_institutions(community.id))

      view
      |> element("form[phx-submit=\"add_institution\"")
      |> render_submit(%{institution: %{name: institution.name}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Community institution(s) successfully added."

      assert 2 == length(Groups.list_community_institutions(community.id))
    end

    test "displays error messages when adding community institution fails", %{
      conn: conn,
      community: community
    } do
      institution = build(:institution)
      insert(:community_institution, %{community: community, institution: institution})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      view
      |> element("form[phx-submit=\"add_institution\"")
      |> render_submit(%{institution: %{name: institution.name}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Some of the community institutions couldn&#39;t be added because the institutions don&#39;t exist in the system or are already associated."

      view
      |> element("form[phx-submit=\"add_institution\"")
      |> render_submit(%{institution: %{name: "Bad institution"}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Some of the community institutions couldn&#39;t be added because the institutions don&#39;t exist in the system or are already associated."

      assert 1 == length(Groups.list_community_institutions(community.id))
    end

    test "adds more than one community institution correctly", %{
      conn: conn,
      community: community
    } do
      names = insert_pair(:institution) |> Enum.map(& &1.name)
      insert(:community_institution, %{community: community})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      assert 1 == length(Groups.list_community_institutions(community.id))

      view
      |> element("form[phx-submit=\"add_institution\"")
      |> render_submit(%{institution: %{name: Enum.join(names, ",")}})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Community institution(s) successfully added."

      assert 3 == length(Groups.list_community_institutions(community.id))
    end

    test "removes community institution correctly", %{
      conn: conn,
      community: community
    } do
      institution = insert(:institution)
      insert(:community_institution, %{community: community, institution: institution})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      assert 1 == length(Groups.list_community_institutions(community.id))

      view
      |> element("button[phx-click=\"remove_institution\"")
      |> render_click(%{"collaborator-id" => institution.id})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Community institution successfully removed."

      assert [] == Groups.list_community_institutions(community.id)
    end

    test "displays error messages when removing community institution fails", %{
      conn: conn,
      community: community
    } do
      institution = insert(:institution)
      insert(:community_institution, %{community: community, institution: institution})

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      assert 1 == length(Groups.list_community_institutions(community.id))

      view
      |> element("button[phx-click=\"remove_institution\"")
      |> render_click(%{"collaborator-id" => 12345})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "Community institution couldn&#39;t be removed."

      assert 1 == length(Groups.list_community_institutions(community.id))
    end

    test "suggests community institution correctly", %{
      conn: conn,
      community: community
    } do
      institution = insert(:institution)

      {:ok, view, _html} = live(conn, live_view_show_route(community.id))

      view
      |> element("form[phx-change=\"suggest_institution\"")
      |> render_change(%{institution: %{name: institution.name}})

      assert view
             |> element("#institution_matches")
             |> render() =~
               institution.name

      view
      |> element("form[phx-change=\"suggest_institution\"")
      |> render_change(%{institution: %{name: "other_name"}})

      refute view
             |> element("#institution_matches")
             |> render() =~
               institution.name
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

    test "lists projects and products that aren't related to any community", %{
      conn: conn,
      community: community
    } do
      associated_project = insert(:project)
      associated_product = insert(:section)
      insert(:community_visibility, %{community: community, project: associated_project})
      insert(:community_visibility, %{community: community, section: associated_product})

      project = insert(:project)
      product = insert(:section)

      {:ok, view, _html} = live(conn, live_view_associated_new_route(community.id))

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
               "Association to project successfully added."

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

  describe "members index" do
    setup [:admin_conn, :create_community]

    test "loads correctly when there are no members associated to the community", %{
      conn: conn,
      community: %Community{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_members_index_route(id))

      assert has_element?(view, "p", "None exist")
    end

    test "lists community members", %{conn: conn, community: community} do
      user = insert(:user)
      insert(:community_member_account, %{user: user, community: community})

      {:ok, view, _html} = live(conn, live_view_members_index_route(community.id))

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               user.name
    end

    test "lists community members with no name", %{conn: conn, community: community} do
      user = insert(:user, name: nil)
      insert(:community_member_account, %{user: user, community: community})

      {:ok, view, _html} = live(conn, live_view_members_index_route(community.id))

      assert view
             |> element("tr:first-child > td:nth-child(2)")
             |> render() =~
               user.email
    end

    test "removes community member", %{conn: conn, community: community} do
      user = insert(:user)
      insert(:community_member_account, %{user: user, community: community})

      {:ok, view, _html} = live(conn, live_view_members_index_route(community.id))

      view
      |> element("tr:first-child > td:last-child > button")
      |> render_click(%{"id" => user.id})

      assert view
             |> element("div.alert.alert-info")
             |> render() =~
               "Community member successfully removed."

      assert has_element?(view, "p", "None exist")
    end

    test "applies searching", %{conn: conn, community: community} do
      user_1 = insert(:user, %{name: "Testing"})
      user_2 = insert(:user)
      insert(:community_member_account, %{user: user_1, community: community})
      insert(:community_member_account, %{user: user_2, community: community})

      {:ok, view, _html} = live(conn, live_view_members_index_route(community.id))

      view
      |> element("input[phx-blur=\"change_search\"]")
      |> render_blur(%{value: "testing"})

      view
      |> element("button[phx-click=\"apply_search\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"apply_search\"]")
      |> render_click()

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               user_1.name

      refute view
             |> element("tr:last-child > td:first-child")
             |> render() =~
               user_2.name

      view
      |> element("button[phx-click=\"reset_search\"]")
      |> render_click()

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               user_1.name

      assert view
             |> element("tr:last-child > td:first-child")
             |> render() =~
               user_2.name
    end

    test "applies sorting", %{conn: conn, community: community} do
      user_1 = insert(:user, %{name: "Testing A"})
      user_2 = insert(:user, %{name: "Testing B"})
      insert(:community_member_account, %{user: user_1, community: community})
      insert(:community_member_account, %{user: user_2, community: community})

      {:ok, view, _html} = live(conn, live_view_members_index_route(community.id))

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

    test "applies paging", %{conn: conn, community: community} do
      [first_cma | tail] =
        insert_list(21, :community_member_account, %{community: community})
        |> Enum.sort_by(& &1.user.name)

      last_cma = List.last(tail)

      {:ok, view, _html} = live(conn, live_view_members_index_route(community.id))

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               first_cma.user.name

      refute view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               last_cma.user.name

      view
      |> element("a[phx-click=\"page_change\"]", "2")
      |> render_click()

      refute view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               first_cma.user.name

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               last_cma.user.name
    end
  end
end
