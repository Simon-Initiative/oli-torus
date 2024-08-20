defmodule OliWeb.Workspace.CourseAuthorTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Oli.Factory
  import Phoenix.LiveViewTest

  alias OliWeb.Common.Utils

  describe "author not signed in" do
    test "can access page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, "div", "Course Author Sign In")
    end

    test "can signin and get redirected back to the authoring workspace", %{conn: conn} do
      expect_recaptcha_http_post()

      # create author account
      post(
        conn,
        Routes.authoring_pow_registration_path(OliWeb.Endpoint, :create),
        %{
          user: %{
            email: "my_author@test.com",
            email_confirmation: "my_author@test.com",
            given_name: "me",
            family_name: "too",
            password: "some_password",
            password_confirmation: "some_password"
          },
          "g-recaptcha-response": "any"
        }
      )

      # access without being singed in
      conn = Phoenix.ConnTest.build_conn()

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, "div", "Course Author Sign In")

      # we sign in and get redirected back to the authoring workspace
      conn =
        conn
        |> post(
          Routes.authoring_pow_session_path(OliWeb.Endpoint, :create,
            request_path: ~p"/workspaces/course_author"
          ),
          user: %{email: "my_author@test.com", password: "some_password"}
        )

      assert conn.assigns.current_author.email == "my_author@test.com"
      assert redirected_to(conn) == ~p"/workspaces/course_author"

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      # author is signed in
      refute has_element?(view, "div", "Course Author Sign In")
      assert has_element?(view, "h1", "Course Author")
    end

    test "can NOT create an authoring account if the current user already has an author account linked",
         %{conn: conn} do
      author = insert(:author)
      user_with_account_linked = insert(:user, author: author)

      conn =
        Pow.Plug.assign_current_user(
          conn,
          user_with_account_linked,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")
      assert has_element?(view, "div", "Course Author Sign In")
      refute has_element?(view, "a", "Create Account")
    end

    test "can create an account if the current user does not yet have an author linked account",
         %{conn: conn} do
      user_with_no_account_linked = insert(:user, author: nil)

      conn =
        Pow.Plug.assign_current_user(
          conn,
          user_with_no_account_linked,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")
      assert has_element?(view, "div", "Course Author Sign In")
      assert has_element?(view, "a", "Create Account")
    end

    test "on account creation account gets linked automatically if current user has no linked authoring account",
         %{conn: conn} do
      user_with_no_account_linked = insert(:user, email: "some_user@test.com", author: nil)

      conn =
        Pow.Plug.assign_current_user(
          conn,
          user_with_no_account_linked,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      element(view, "a", "Create Account")
      |> render_click()

      assert_redirected(
        view,
        "/authoring/registration/new?link_to_user_account%3F=true&request_path=%2Fworkspaces%2Fcourse_author"
      )

      # create new author account
      expect_recaptcha_http_post()

      conn =
        Phoenix.ConnTest.build_conn()
        |> Pow.Plug.assign_current_user(
          user_with_no_account_linked,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )
        |> post(
          Routes.authoring_pow_registration_path(OliWeb.Endpoint, :create,
            link_to_user_account?: "true",
            request_path: ~p"/workspaces/course_author"
          ),
          %{
            user: %{
              email: "my_author@test.com",
              email_confirmation: "my_author@test.com",
              given_name: "me",
              family_name: "too",
              password: "some_password",
              password_confirmation: "some_password"
            },
            "g-recaptcha-response": "any"
          }
        )

      # user gets redirected back to the authoring workspace and the account is linked
      author_account = Oli.Accounts.get_author_by_email("my_author@test.com")
      user_account = Oli.Accounts.get_user!(user_with_no_account_linked.id)
      assert redirected_to(conn) == ~p"/workspaces/course_author"
      assert user_account.author_id == author_account.id
    end

    test "can create an account if there is no current user already signed in", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")
      assert has_element?(view, "div", "Course Author Sign In")
      assert has_element?(view, "a", "Create Account")
    end
  end

  describe "course author workspace as author" do
    setup [:author_conn, :set_timezone]

    test "shows course author header if is logged in", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, "h1", "Course Author")

      assert has_element?(
               view,
               "h2",
               "Create, deliver, and continuously improve course materials."
             )
    end

    test "loads correctly when there are no projects", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, "#projects-table")
      assert has_element?(view, "p", "None exist")
      assert has_element?(view, "#button-new-project")
    end

    test "lists only projects the author owns", %{conn: conn, author: author} do
      author_project = create_project_with_owner(author)
      another_project = insert(:author) |> create_project_with_owner()

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      author_project_row =
        view
        |> element("##{author_project.id}")
        |> render()

      assert author_project_row =~ author_project.title
      assert author_project_row =~ author.name
      assert author_project_row =~ author.email
      assert author_project_row =~ "Active"

      refute has_element?(view, "##{another_project.id}")
    end

    test "applies show-deleted filter", %{conn: conn, author: author} do
      active_project = create_project_with_owner(author)
      deleted_project = create_project_with_owner(author, %{status: :deleted})

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      # shows only active projects by default
      assert has_element?(view, "##{active_project.id}")
      refute has_element?(view, "##{deleted_project.id}")

      view
      |> element("#deletedCheck")
      |> render_click()

      # shows both active and deleted projects
      assert has_element?(view, "##{active_project.id}")
      assert has_element?(view, "##{deleted_project.id}")
    end

    test "applies paging", %{conn: conn, author: author} do
      [first_p | tail] =
        1..26
        |> Enum.map(fn _ -> create_project_with_owner(author) end)
        |> Enum.sort_by(& &1.title)

      last_p = List.last(tail)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, "##{first_p.id}")
      refute has_element?(view, "##{last_p.id}")

      view
      |> element("#header_paging button[phx-click=\"paged_table_page_change\"]", "2")
      |> render_click()

      refute has_element?(view, "##{first_p.id}")
      assert has_element?(view, "##{last_p.id}")
    end

    test "applies sorting", %{conn: conn, author: author} do
      create_project_with_owner(author, %{title: "Testing A"})
      create_project_with_owner(author, %{title: "Testing B"})

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Testing A"

      view
      |> element("th[phx-click=\"paged_table_sort\"]:first-of-type")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Testing B"
    end

    test "can signout from authoring account and return to course author workspace (and user account stays signed in)",
         %{conn: conn} do
      user = insert(:user, email: "user_not_author@test.com")

      conn =
        Pow.Plug.assign_current_user(
          conn,
          user,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")
      assert conn.assigns.current_author
      assert conn.assigns.current_user
      refute has_element?(view, "div", "Course Author Sign In")

      view
      |> element("div[id='workspace-user-menu-dropdown'] a", "Sign out")
      |> render_click()

      assert_redirected(
        view,
        "/authoring/signout?type=author&target=%2Fworkspaces%2Fcourse_author"
      )

      conn = delete(conn, "/authoring/signout?type=author&target=%2Fworkspaces%2Fcourse_author")

      assert redirected_to(conn) == ~p"/workspaces/course_author"
      refute conn.assigns.current_author
      assert conn.assigns.current_user

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")
      assert has_element?(view, "div", "Course Author Sign In")
    end
  end

  describe "course author workspace as admin" do
    setup [:admin_conn, :set_timezone]

    test "loads correctly when there are no projects", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, "#projects-table")
      assert has_element?(view, "p", "None exist")
      assert has_element?(view, "#button-new-project")
    end

    test "lists projects", %{conn: conn, admin: admin, ctx: ctx} do
      project = create_project_with_owner(admin)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      project_row =
        view
        |> element("##{project.id}")
        |> render()

      assert project_row =~ project.title
      assert project_row =~ Utils.render_date(project, :inserted_at, ctx)
      assert project_row =~ admin.name
      assert project_row =~ admin.email
      assert project_row =~ "Active"
    end

    test "applies show-all filter", %{conn: conn, admin: admin} do
      admin_project = create_project_with_owner(admin)
      project = insert(:author) |> create_project_with_owner()

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      # shows all projects by default
      assert has_element?(view, "##{admin_project.id}")
      assert has_element?(view, "##{project.id}")

      view
      |> element("#allCheck")
      |> render_click()

      # shows only admin projects
      assert has_element?(view, "##{admin_project.id}")
      refute has_element?(view, "##{project.id}")
    end

    test "applies show-deleted filter", %{conn: conn, admin: admin} do
      active_project = create_project_with_owner(admin)
      deleted_project = insert(:project, status: :deleted)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      # shows only active projects by default
      assert has_element?(view, "##{active_project.id}")
      refute has_element?(view, "##{deleted_project.id}")

      view
      |> element("#deletedCheck")
      |> render_click()

      # shows both active and deleted projects
      assert has_element?(view, "##{active_project.id}")
      assert has_element?(view, "##{deleted_project.id}")
    end

    test "applies paging", %{conn: conn} do
      [first_p | tail] = insert_list(26, :project) |> Enum.sort_by(& &1.title)
      last_p = List.last(tail)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, "##{first_p.id}")
      refute has_element?(view, "##{last_p.id}")

      view
      |> element("#header_paging button[phx-click=\"paged_table_page_change\"]", "2")
      |> render_click()

      refute has_element?(view, "##{first_p.id}")
      assert has_element?(view, "##{last_p.id}")
    end

    test "applies sorting", %{conn: conn} do
      insert(:project, %{title: "Testing A"})
      insert(:project, %{title: "Testing B"})

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Testing A"

      view
      |> element("th[phx-click=\"paged_table_sort\"]:first-of-type")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Testing B"
    end

    test "admin menu is shown in all workspaces (even if the conn has a user account)", %{
      conn: conn
    } do
      user = insert(:user)

      conn =
        Pow.Plug.assign_current_user(
          conn,
          user,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      [
        ~p"/workspaces/course_author",
        ~p"/workspaces/instructor",
        ~p"/workspaces/student"
      ]
      |> Enum.each(fn workspace ->
        {:ok, view, _html} = live(conn, workspace)
        assert has_element?(view, "button[id=workspace-user-menu]", "TA")
        assert has_element?(view, "div[role='account label']", "Admin")
      end)
    end

    test "can signout from ADMIN authoring account and return to course author workspace (and user account stays signed in)",
         %{conn: conn} do
      user = insert(:user, email: "user_not_author@test.com")

      conn =
        Pow.Plug.assign_current_user(
          conn,
          user,
          OliWeb.Pow.PowHelpers.get_pow_config(:user)
        )

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")
      assert conn.assigns.current_author
      assert conn.assigns.current_user
      refute has_element?(view, "div", "Course Author Sign In")

      view
      |> element("div[id='workspace-user-menu-dropdown'] a", "Sign out")
      |> render_click()

      assert_redirected(
        view,
        "/authoring/signout?type=author&target=%2Fworkspaces%2Fcourse_author"
      )

      conn = delete(conn, "/authoring/signout?type=author&target=%2Fworkspaces%2Fcourse_author")

      assert redirected_to(conn) == ~p"/workspaces/course_author"
      refute conn.assigns.current_author
      assert conn.assigns.current_user

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")
      assert has_element?(view, "div", "Course Author Sign In")
    end
  end

  defp create_project_with_owner(owner, attrs \\ %{}) do
    project = insert(:project, attrs)
    insert(:author_project, project_id: project.id, author_id: owner.id)
    project
  end
end
