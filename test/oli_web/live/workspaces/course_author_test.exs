defmodule OliWeb.Workspaces.CourseAuthorTest do
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
            password_confirmation: "some_password",
            email_confirmed_at: Timex.now()
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

  describe "project sidebar" do
    setup [:admin_conn, :set_timezone, :base_project_with_curriculum]

    test "entering a project works well by navigating to the project overview", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      view
      |> element("a", project.title)
      |> render_click()

      assert_redirected(view, "/workspaces/course_author/#{project.slug}/overview")
    end

    test "exit project button works well by navigating to course author index", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      view
      |> element(~s(a[id=exit_course_button]))
      |> render_click()

      assert_redirected(view, "/workspaces/course_author?sidebar_expanded=true")

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")
      assert has_element?(view, "h1", "Course Author")

      assert has_element?(
               view,
               "h2",
               "Create, deliver, and continuously improve course materials."
             )

      assert has_element?(view, "h3", "Projects")
    end

    test "project name is shown in the sidebar and in the top bar", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      assert has_element?(view, "div", project.title)
    end

    test "sidebar is expanded by default", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, ~s(#desktop-workspace-nav-menu[aria-expanded=true]))
    end

    test "menus are shown correctly", %{conn: conn, project: project} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      assert has_element?(view, "div", "Overview")

      assert has_element?(view, "div", "Create")
      assert has_element?(view, "div", "Objectives")
      assert has_element?(view, "div", "Activity Bank")
      assert has_element?(view, "div", "Experiments")
      assert has_element?(view, "div", "Bibliography")
      assert has_element?(view, "div", "Curriculum")
      assert has_element?(view, "div", "All Pages")
      assert has_element?(view, "div", "All Activities")

      assert has_element?(view, "div", "Publish")
      assert has_element?(view, "div", "Review")
      assert has_element?(view, "div", "Publish")
      assert has_element?(view, "div", "Products")

      assert has_element?(view, "div", "Improve")
      assert has_element?(view, "div", "Insights")
    end

    test "overview menu is shown correctly", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/overview")

      assert has_element?(view, ~s(div[class="overview container mx-auto p-8"]))
      assert has_element?(view, "h4", "Details")
      assert has_element?(view, "h4", "Project Attributes")
      assert has_element?(view, "h4", "Content Types")
      assert has_element?(view, "h4", "Project Labels")
      assert has_element?(view, "h4", "Collaborators")
      assert has_element?(view, "h4", "Advanced Activities")
      assert has_element?(view, "h4", "Allow Duplication")
      assert has_element?(view, "h4", "Notes")
      assert has_element?(view, "h4", "Course Discussions")
      assert has_element?(view, "h4", "Required Survey")
      assert has_element?(view, "h4", "Transfer Payment Codes")
      assert has_element?(view, "h4", "Actions")
    end

    test "objectives menu is shown correctly", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/objectives")

      assert has_element?(view, "h3", "Learning Objectives")

      assert has_element?(
               view,
               "p",
               "Learning objectives help you to organize course content and determine appropriate assessments and instructional strategies."
             )

      assert has_element?(view, "button", "Create new Objective")
    end

    test "activity bank menu is shown correctly", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/activity_bank")

      # Since the Activity Bank liveview renders a React component, we can only check for the presence of the div that contains the React component
      assert has_element?(view, ~s(#activity-bank))
      assert has_element?(view, ~s(div[data-live-react-class='Components.ActivityBank']))
    end

    test "experiments menu is shown correctly", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/experiments")

      assert has_element?(view, "h3", "A/B Testing with UpGrade")

      assert has_element?(
               view,
               "p",
               "To support A/B testing, Torus integrates with the A/B testing platform"
             )

      assert has_element?(view, "label", "Enable A/B testing with UpGrade")
    end

    test "review menu is shown correctly", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/review")

      assert has_element?(
               view,
               "p",
               "Run an automated review before publishing to check for broken links and other common issues that may be present in your course."
             )

      assert has_element?(view, "button", "Run Review")
      assert has_element?(view, "a", "Preview Course")
    end

    test "all activities menu is shown correctly", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/activities")

      assert has_element?(view, "h3", "Browse All Activities")
      assert has_element?(view, ~s(input[id='text-search-input']))
      assert has_element?(view, "a", "Open Sync View")
    end

    test "publish menu is shown correctly", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/publish")
      assert has_element?(view, "h5", "Publication Details")

      assert has_element?(
               view,
               "div",
               "Publish your project to give instructors access to the latest changes."
             )

      assert has_element?(view, "button", "Connect with LTI 1.3")
      assert has_element?(view, "button", "Publish")
    end

    test "insights menu is shown correctly", %{
      conn: conn,
      project: project
    } do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author/#{project.slug}/insights")

      assert has_element?(
               view,
               "p",
               "Insights can help you improve your course by providing a statistical analysis of\n    the skills covered by each question to find areas where students are struggling."
             )

      assert has_element?(view, "button", "Raw Analytics")

      assert has_element?(
               view,
               "div",
               "Project must be published to generate an analytics snapshot."
             )

      assert has_element?(view, "button", "By Activity")
      assert has_element?(view, "button", "By Page")
      assert has_element?(view, "button", "By Objective")
    end
  end

  defp create_project_with_owner(owner, attrs \\ %{}) do
    project = insert(:project, attrs)
    insert(:author_project, project_id: project.id, author_id: owner.id)
    project
  end
end
