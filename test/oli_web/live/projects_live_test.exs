defmodule OliWeb.Projects.ProjectsLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias OliWeb.Endpoint
  alias OliWeb.Projects.ProjectsLive

  describe "author cannot access when is not logged in" do
    test "redirects to new session when accessing the index view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authors/log_in"}}} =
        live(conn, Routes.live_path(Endpoint, ProjectsLive))
    end
  end

  describe "projects live as admin" do
    setup [:admin_conn, :set_timezone]

    test "loads correctly when there are no projects", %{conn: conn} do
      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, ProjectsLive))

      assert has_element?(view, "#projects-table")
      assert has_element?(view, "p", "None exist")
      assert has_element?(view, "#button-new-project")
    end

    test "lists projects", %{conn: conn, admin: admin, ctx: ctx} do
      project = create_project_with_owner(admin)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, ProjectsLive))

      project_row =
        view
        |> element("##{project.id}")
        |> render()

      assert project_row =~ project.title
      assert project_row =~ OliWeb.Common.Utils.render_date(project, :inserted_at, ctx)
      assert project_row =~ admin.name
      assert project_row =~ admin.email
      assert project_row =~ "Active"
    end

    test "applies show-all filter", %{conn: conn, admin: admin} do
      admin_project = create_project_with_owner(admin)
      project = insert(:author) |> create_project_with_owner()

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, ProjectsLive))

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

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, ProjectsLive))

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

    test "applies paging", %{conn: conn, admin: admin} do
      [first_p | tail] =
        insert_list(26, :project, authors: [admin])
        |> Enum.sort_by(& &1.title)

      last_p = List.last(tail)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, ProjectsLive))

      assert has_element?(view, "##{first_p.id}")
      refute has_element?(view, "##{last_p.id}")

      view
      |> element("#footer_paging button[phx-click='paged_table_page_change']", "2")
      |> render_click()

      refute has_element?(view, "##{first_p.id}")
      assert has_element?(view, "##{last_p.id}")
    end

    test "applies sorting", %{conn: conn} do
      insert(:project, %{title: "Testing A"})
      insert(:project, %{title: "Testing B"})

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, ProjectsLive))

      view
      |> element("th[phx-click='paged_table_sort'][phx-value-sort_by='title']")
      |> render_click()

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Testing A"

      view
      |> element("th[phx-click='paged_table_sort'][phx-value-sort_by='title']")
      |> render_click()

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Testing B"
    end
  end

  describe "projects live as author" do
    setup [:author_conn, :set_timezone]

    test "loads correctly when there are no projects", %{conn: conn} do
      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, ProjectsLive))

      assert has_element?(view, "#projects-table")
      assert has_element?(view, "p", "None exist")
      assert has_element?(view, "#button-new-project")
    end

    test "lists only projects the author owns", %{conn: conn, author: author} do
      author_project = create_project_with_owner(author)
      another_project = insert(:author) |> create_project_with_owner()

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, ProjectsLive))

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

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, ProjectsLive))

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

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, ProjectsLive))

      assert has_element?(view, "##{first_p.id}")
      refute has_element?(view, "##{last_p.id}")

      view
      |> element("#footer_paging button[phx-click='paged_table_page_change']", "2")
      |> render_click()

      refute has_element?(view, "##{first_p.id}")
      assert has_element?(view, "##{last_p.id}")
    end

    test "applies sorting", %{conn: conn, author: author} do
      create_project_with_owner(author, %{title: "Testing A"})
      create_project_with_owner(author, %{title: "Testing B"})

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, ProjectsLive))

      view
      |> element("th[phx-click='paged_table_sort'][phx-value-sort_by='title']")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Testing A"

      view
      |> element("th[phx-click='paged_table_sort'][phx-value-sort_by='title']")
      |> render_click(%{sort_by: "title"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~
               "Testing B"
    end
  end

  defp create_project_with_owner(owner, attrs \\ %{}) do
    project = insert(:project, attrs)
    insert(:author_project, project_id: project.id, author_id: owner.id)
    project
  end
end
