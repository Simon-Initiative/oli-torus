defmodule OliWeb.AdminLiveTest do
  use ExUnit.Case
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory
  import OliWeb.Common.FormatDateTime

  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}

  @live_view_route Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.AdminView)
  @live_view_users_route Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersView)
  @live_view_authors_route Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsView)

  defp live_view_user_detail_route(user_id) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, user_id)
  end

  defp live_view_author_detail_route(author_id) do
    Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsDetailView, author_id)
  end

  defp create_user(_conn) do
    user = insert(:user)

    [user: user]
  end

  defp create_author(_conn) do
    author = insert(:author)

    [author: author]
  end

  describe "user cannot access when is not logged in" do
    test "redirects to new session when accessing the admin index view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authoring/session/new?request_path=%2Fadmin"}}} =
        live(conn, @live_view_route)
    end

    test "redirects to new session when accessing the admin users view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authoring/session/new?request_path=%2Fadmin%2Fusers"}}} =
        live(conn, @live_view_users_route)
    end

    test "redirects to new session when accessing the user detail view", %{conn: conn} do
      user_id = insert(:user).id

      redirect_path = "/authoring/session/new?request_path=%2Fadmin%2Fusers%2F#{user_id}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_user_detail_route(user_id))
    end

    test "redirects to new session when accessing the admin authors view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authoring/session/new?request_path=%2Fadmin%2Fauthors"}}} =
        live(conn, @live_view_authors_route)
    end

    test "redirects to new session when accessing the author detail view", %{conn: conn} do
      author_id = insert(:author).id

      redirect_path = "/authoring/session/new?request_path=%2Fadmin%2Fauthors%2F#{author_id}"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_author_detail_route(author_id))
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

    test "returns forbidden when accessing the admin authors view", %{conn: conn} do
      conn = get(conn, @live_view_authors_route)

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

      assert render(view) =~ "Account Management"
      assert render(view) =~ "Access and manage all users and authors"

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

      assert render(view) =~ "Content Management"
      assert render(view) =~ "Access and manage created content"

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
               "a[href=\"#{Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.Ingest)}\"]"
             )

      assert has_element?(
               view,
               "a[href=\"#{Routes.brand_path(OliWeb.Endpoint, :index)}\"]"
             )
    end

    test "loads system management links correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_route)

      assert render(view) =~ "System Management"
      assert render(view) =~ "Manage and support system level functionality"

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

      render_hook(view, "text_search_change", %{value: "testing"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               user_1.given_name

      refute view
             |> element("tr:last-child > td:first-child")
             |> render() =~
               user_2.given_name

      render_hook(view, "text_search_change", %{value: ""})

      assert render(view) =~ user_1.given_name
      assert render(view) =~ user_2.given_name
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

  describe "user detail" do
    setup [:admin_conn, :create_user]

    test "loads correctly with user data", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, live_view_user_detail_route(user.id))

      assert has_element?(view, "input[value=\"#{user.sub}\"]")
      assert has_element?(view, "input[value=\"#{user.name}\"]")
      assert has_element?(view, "input[value=\"#{user.given_name}\"]")
      assert has_element?(view, "input[value=\"#{user.family_name}\"]")
      assert has_element?(view, "input[value=\"#{user.email}\"]")
      assert has_element?(view, "input[value=\"#{user.guest}\"]")
      assert has_element?(view, "#user_independent_learner")
      assert has_element?(view, "#user_can_create_sections")
      assert has_element?(view, "input[value=\"#{user.research_opt_out}\"]")
      assert has_element?(view, "input[value=\"#{user.email_confirmed_at}\"]")
      assert has_element?(view, "input[value=\"#{date(user.inserted_at)}\"]")
      assert has_element?(view, "input[value=\"#{date(user.updated_at)}\"]")
    end

    test "displays error message when submit fails", %{
      conn: conn,
      user: %User{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_user_detail_route(id))

      view
      |> element("form[phx-submit=\"submit\"")
      |> render_submit(%{user: %{email: ""}})

      assert view
             |> element("div.alert.alert-danger")
             |> render() =~
               "User couldn&#39;t be updated."

      refute Accounts.get_user!(id).name == ""
    end

    test "updates a user correctly when data is valid", %{
      conn: conn,
      user: %User{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_user_detail_route(id))

      new_attributes = params_for(:user)

      view
      |> element("form[phx-submit=\"submit\"")
      |> render_submit(%{user: new_attributes})

      %User{name: new_name} = Accounts.get_user!(id)
      assert new_attributes.name == new_name
    end

    test "redirects to index view and displays error message when user does not exist", %{
      conn: conn
    } do
      assert {:error, {:redirect, %{to: "/not_found"}}} =
               live(conn, live_view_user_detail_route(1000))
    end

    test "displays a confirm modal before deleting a user", %{
      conn: conn,
      user: %User{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_user_detail_route(id))

      view
      |> element("button[phx-click=\"show_delete_account_modal\"]")
      |> render_click()

      assert view
             |> element("h5.modal-title")
             |> render() =~
               "Delete Account"
    end

    test "deletes the user and redirects to the index page", %{
      conn: conn,
      user: %User{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_user_detail_route(id))

      view
      |> element("button[phx-click=\"show_delete_account_modal\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"delete_account\"]")
      |> render_click()

      flash = assert_redirected(view, @live_view_users_route)
      assert flash["info"] == "User successfully deleted."

      assert_raise Ecto.NoResultsError,
                   ~r/^expected at least one result but got none in query/,
                   fn -> Accounts.get_user!(id) end
    end

    test "locks the user", %{
      conn: conn,
      user: %User{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_user_detail_route(id))

      view
      |> element("button[phx-click=\"show_lock_account_modal\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"lock_account\"]")
      |> render_click()

      %User{locked_at: date} = Accounts.get_user!(id)
      assert not is_nil(date)
    end

    test "unlocks the user", %{
      conn: conn
    } do
      {:ok, date, _timezone} = DateTime.from_iso8601("2019-05-22 20:30:00Z")
      %User{id: id} = insert(:user, %{locked_at: date})

      {:ok, view, _html} = live(conn, live_view_user_detail_route(id))

      view
      |> element("button[phx-click=\"show_unlock_account_modal\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"unlock_account\"]")
      |> render_click()

      assert %User{locked_at: nil} = Accounts.get_user!(id)
    end

    test "confirms user email", %{
      conn: conn
    } do
      %User{id: id} = insert(:user, %{email_confirmation_token: "token"})

      {:ok, view, _html} = live(conn, live_view_user_detail_route(id))

      view
      |> element("button[phx-click=\"show_confirm_email_modal\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"confirm_email\"]")
      |> render_click()

      %User{email_confirmed_at: date} = Accounts.get_user!(id)
      assert not is_nil(date)
    end
  end

  describe "authors index" do
    setup [:admin_conn]

    # At least the system admin from the seeds and the admin created by
    # admin_conn for being able to access the view will be listed

    test "lists authors", %{conn: conn, admin: admin} do
      {:ok, view, _html} = live(conn, @live_view_authors_route)

      assert view
             |> element("tr:last-child > td:first-child")
             |> render() =~
               "#{admin.family_name}, #{admin.given_name}"
    end

    test "applies searching", %{conn: conn} do
      author_1 = insert(:author, %{given_name: "Testing"})
      author_2 = insert(:author)

      {:ok, view, _html} = live(conn, @live_view_authors_route)

      render_hook(view, "text_search_change", %{value: "testing"})

      assert render(view) =~ author_1.given_name
      refute render(view) =~ author_2.given_name

      render_hook(view, "text_search_change", %{value: ""})

      assert render(view) =~ author_1.given_name
      assert render(view) =~ author_2.given_name
    end

    test "applies sorting", %{conn: conn} do
      {:ok, view, _html} = live(conn, @live_view_authors_route)

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Administrator"

      view
      |> element("th[phx-click=\"paged_table_sort\"]:first-of-type")
      |> render_click(%{sort_by: "name"})

      refute view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Administrator"

      assert view
             |> element("tr:last-child > td:first-child")
             |> render() =~
               "Administrator"
    end

    test "applies paging", %{conn: conn} do
      [first_author | _tail] = insert_list(24, :author) |> Enum.sort_by(& &1.given_name)

      {:ok, view, _html} = live(conn, @live_view_authors_route)

      assert render(view) =~ first_author.given_name

      view
      |> element("#header_paging a[phx-click=\"paged_table_page_change\"]", "2")
      |> render_click()

      refute render(view) =~ first_author.given_name
    end

    test "shows confirmation pending message when author account was created but not confirmed yet",
         %{conn: conn} do
      non_confirmed_author = insert(:author, email_confirmation_token: "token")

      {:ok, view, _html} = live(conn, @live_view_authors_route)

      assert view
             |> element("##{non_confirmed_author.id} span[data-toggle=\"tooltip\"")
             |> render() =~ "Confirmation Pending"
    end

    test "shows email confirmed message when author account was created and confirmed", %{
      conn: conn
    } do
      confirmed_author = insert(:author, email_confirmed_at: Timex.now())
      {:ok, view, _html} = live(conn, @live_view_authors_route)

      assert view
             |> element("##{confirmed_author.id} span[data-toggle=\"tooltip\"")
             |> render() =~ "Email Confirmed"
    end

    test "shows invitation pending message when author was invited by an admin and has not accepted yet",
         %{conn: conn} do
      invited_and_not_accepted_author = insert(:author, invitation_token: "token")
      {:ok, view, _html} = live(conn, @live_view_authors_route)

      assert view
             |> element("##{invited_and_not_accepted_author.id} span[data-toggle=\"tooltip\"")
             |> render() =~ "Invitation Pending"
    end

    test "shows invitation accepted message when author was invited by an admin and accepted", %{
      conn: conn
    } do
      invited_author =
        insert(:author, invitation_token: "token", invitation_accepted_at: Timex.now())

      {:ok, view, _html} = live(conn, @live_view_authors_route)

      assert view
             |> element("##{invited_author.id} span[data-toggle=\"tooltip\"")
             |> render() =~ "Invitation Accepted"
    end

    test "shows confirmation pending message when author was invited by an admin and accepted with a different email, but has not confirmed yet",
         %{conn: conn} do
      accepted_with_different_email_author =
        insert(:author,
          email_confirmation_token: "token",
          unconfirmed_email: "other_email",
          invitation_token: "token",
          invitation_accepted_at: Timex.now()
        )

      {:ok, view, _html} = live(conn, @live_view_authors_route)

      assert view
             |> element(
               "##{accepted_with_different_email_author.id} span[data-toggle=\"tooltip\""
             )
             |> render() =~ "Confirmation Pending"
    end

    test "shows email confirmed message when author was invited by an admin and accepted with a different email, and has confirmed his account",
         %{conn: conn} do
      accepted_and_confirmed_with_different_email_author =
        insert(:author,
          email_confirmed_at: Timex.now(),
          invitation_token: "token",
          invitation_accepted_at: Timex.now()
        )

      {:ok, view, _html} = live(conn, @live_view_authors_route)

      assert view
             |> element(
               "##{accepted_and_confirmed_with_different_email_author.id} span[data-toggle=\"tooltip\""
             )
             |> render() =~ "Email Confirmed"
    end
  end

  describe "author detail" do
    setup [:admin_conn, :create_author]

    test "loads correctly with author data", %{conn: conn, author: author} do
      {:ok, view, _html} = live(conn, live_view_author_detail_route(author.id))

      assert has_element?(view, "input[value=\"#{author.name}\"]")
      assert has_element?(view, "input[value=\"#{author.given_name}\"]")
      assert has_element?(view, "input[value=\"#{author.family_name}\"]")
      assert has_element?(view, "input[value=\"#{author.email}\"]")
      assert has_element?(view, "input[value=\"Author\"]")
    end

    test "redirects to index view and displays error message when author does not exist", %{
      conn: conn
    } do
      assert {:error, {:redirect, %{to: "/not_found"}}} =
               live(conn, live_view_author_detail_route(1000))
    end

    test "displays a confirm modal before deleting a author", %{
      conn: conn,
      author: %Author{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_author_detail_route(id))

      view
      |> element("button[phx-click=\"show_delete_account_modal\"]")
      |> render_click()

      assert view
             |> element("h5.modal-title")
             |> render() =~
               "Delete Account"
    end

    test "deletes the author and redirects to the index page", %{
      conn: conn,
      author: %Author{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_author_detail_route(id))

      view
      |> element("button[phx-click=\"show_delete_account_modal\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"delete_account\"]")
      |> render_click()

      flash = assert_redirected(view, @live_view_authors_route)
      assert flash["info"] == "Author successfully deleted."

      assert_raise Ecto.NoResultsError,
                   ~r/^expected at least one result but got none in query/,
                   fn -> Accounts.get_author!(id) end
    end

    test "locks the author", %{
      conn: conn,
      author: %Author{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_author_detail_route(id))

      view
      |> element("button[phx-click=\"show_lock_account_modal\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"lock_account\"]")
      |> render_click()

      %Author{locked_at: date} = Accounts.get_author!(id)
      assert not is_nil(date)
    end

    test "unlocks the author", %{
      conn: conn
    } do
      {:ok, date, _timezone} = DateTime.from_iso8601("2019-05-22 20:30:00Z")
      %Author{id: id} = insert(:author, %{locked_at: date})

      {:ok, view, _html} = live(conn, live_view_author_detail_route(id))

      view
      |> element("button[phx-click=\"show_unlock_account_modal\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"unlock_account\"]")
      |> render_click()

      assert %Author{locked_at: nil} = Accounts.get_author!(id)
    end

    test "confirms author email", %{
      conn: conn
    } do
      %Author{id: id} = insert(:author, %{email_confirmation_token: "token"})

      {:ok, view, _html} = live(conn, live_view_author_detail_route(id))

      view
      |> element("button[phx-click=\"show_confirm_email_modal\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"confirm_email\"]")
      |> render_click()

      %Author{email_confirmed_at: date} = Accounts.get_author!(id)
      assert not is_nil(date)
    end

    test "grant admin to author", %{
      conn: conn,
      author: %Author{id: id}
    } do
      {:ok, view, _html} = live(conn, live_view_author_detail_route(id))

      view
      |> element("button[phx-click=\"show_grant_admin_modal\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"grant_admin\"]")
      |> render_click()

      admin_role = Oli.Accounts.SystemRole.role_id().admin
      assert %Author{system_role_id: ^admin_role} = Accounts.get_author!(id)
    end

    test "revoke admin to author", %{
      conn: conn
    } do
      %Author{id: id} =
        insert(:author, %{system_role_id: Oli.Accounts.SystemRole.role_id().admin})

      {:ok, view, _html} = live(conn, live_view_author_detail_route(id))

      view
      |> element("button[phx-click=\"show_revoke_admin_modal\"]")
      |> render_click()

      view
      |> element("button[phx-click=\"revoke_admin\"]")
      |> render_click()

      author_role = Oli.Accounts.SystemRole.role_id().author
      assert %Author{system_role_id: ^author_role} = Accounts.get_author!(id)
    end

    test "shows email confirmation buttons when author account was created but not confirmed yet",
         %{conn: conn} do
      non_confirmed_author = insert(:author, email_confirmation_token: "token")

      {:ok, view, _html} = live(conn, live_view_author_detail_route(non_confirmed_author.id))

      html = render(view)

      assert html =~ "Resend confirmation link"
      assert html =~ "Confirm email"
    end

    test "does not show email confirmation buttons when author account was created and confirmed",
         %{conn: conn} do
      confirmed_author = insert(:author, email_confirmed_at: Timex.now())

      {:ok, view, _html} = live(conn, live_view_author_detail_route(confirmed_author.id))

      html = render(view)

      refute html =~ "Resend confirmation link"
      refute html =~ "Confirm email"
    end

    test "does not show email confirmation buttons when author was invited by an admin and has not accepted yet",
         %{conn: conn} do
      invited_and_not_accepted_author = insert(:author, invitation_token: "token")

      {:ok, view, _html} =
        live(conn, live_view_author_detail_route(invited_and_not_accepted_author.id))

      html = render(view)

      refute html =~ "Resend confirmation link"
      refute html =~ "Confirm email"
    end

    test "does not show email confirmation buttons when author was invited by an admin and accepted",
         %{conn: conn} do
      invited_author =
        insert(:author, invitation_token: "token", invitation_accepted_at: Timex.now())

      {:ok, view, _html} = live(conn, live_view_author_detail_route(invited_author.id))

      html = render(view)

      refute html =~ "Resend confirmation link"
      refute html =~ "Confirm email"
    end

    test "shows email confirmation buttons when author was invited by an admin and accepted with a different email, but has not confirmed yet",
         %{conn: conn} do
      accepted_with_different_email_author =
        insert(:author,
          email_confirmation_token: "token",
          unconfirmed_email: "other_email",
          invitation_token: "token",
          invitation_accepted_at: Timex.now()
        )

      {:ok, view, _html} =
        live(conn, live_view_author_detail_route(accepted_with_different_email_author.id))

      html = render(view)

      assert html =~ "Resend confirmation link"
      assert html =~ "Confirm email"
    end

    test "does not show email confirmation buttons when author was invited by an admin and accepted with a different email, and has confirmed his account",
         %{conn: conn} do
      accepted_and_confirmed_with_different_email_author =
        insert(:author,
          email_confirmed_at: Timex.now(),
          invitation_token: "token",
          invitation_accepted_at: Timex.now()
        )

      {:ok, view, _html} =
        live(
          conn,
          live_view_author_detail_route(accepted_and_confirmed_with_different_email_author.id)
        )

      html = render(view)

      refute html =~ "Resend confirmation link"
      refute html =~ "Confirm email"
    end
  end
end
