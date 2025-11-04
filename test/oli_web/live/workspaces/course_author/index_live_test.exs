defmodule OliWeb.Workspaces.CourseAuthor.IndexLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  describe "author cannot access when is not logged in" do
    test "redirects to new session when accessing the index view", %{conn: conn} do
      {:error, {:redirect, %{to: "/authors/log_in"}}} = live(conn, ~p"/workspaces/course_author")
    end
  end

  describe "projects live as admin" do
    setup [:admin_conn, :set_project_timezone]

    test "loads correctly when there are no projects", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, "#projects-table")
      assert has_element?(view, "p", "None exist")
      assert has_element?(view, "#button-new-project")
    end

    test "lists projects", %{conn: conn, admin: admin} do
      project = create_project_with_owner(admin)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      project_row =
        view
        |> element("##{project.id}")
        |> render()

      assert project_row =~ project.title
      assert project_row =~ admin.name
      assert project_row =~ "Active"
    end

    test "applies show-all filter", %{conn: conn, admin: admin} do
      admin_project = create_project_with_owner(admin)
      project = insert(:author) |> create_project_with_owner()

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, "##{admin_project.id}")
      assert has_element?(view, "##{project.id}")

      view
      |> element("#allCheck")
      |> render_click()

      assert has_element?(view, "##{admin_project.id}")
      refute has_element?(view, "##{project.id}")
    end

    test "applies show-deleted filter", %{conn: conn, admin: admin} do
      active_project = create_project_with_owner(admin)
      deleted_project = insert(:project, status: :deleted)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, "##{active_project.id}")
      refute has_element?(view, "##{deleted_project.id}")

      view
      |> element("#deletedCheck")
      |> render_click()

      assert has_element?(view, "##{active_project.id}")
      assert has_element?(view, "##{deleted_project.id}")
    end

    test "applies paging", %{conn: conn, admin: admin} do
      [first_p | tail] =
        insert_list(26, :project, authors: [admin])
        |> Enum.sort_by(& &1.title)

      last_p = List.last(tail)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      view
      |> element("th[phx-click='paged_table_sort'][phx-value-sort_by='title']")
      |> render_click(%{"sort_by" => "title"})

      assert has_element?(view, "##{first_p.id}")
      refute has_element?(view, "##{last_p.id}")

      view
      |> element("#projects-table button[phx-click='paged_table_page_change']", "2")
      |> render_click(%{"limit" => "20", "offset" => "20"})

      refute has_element?(view, "##{first_p.id}")
      assert has_element?(view, "##{last_p.id}")
    end

    test "applies sorting", %{conn: conn} do
      insert(:project, %{title: "Testing A"})
      insert(:project, %{title: "Testing B"})

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      view
      |> element("th[phx-click='paged_table_sort'][phx-value-sort_by='title']")
      |> render_click(%{"sort_by" => "title"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ "Testing A"

      view
      |> element("th[phx-click='paged_table_sort'][phx-value-sort_by='title']")
      |> render_click(%{"sort_by" => "title"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ "Testing B"
    end

    test "search filters across multiple fields with highlighting", %{conn: conn, admin: admin} do
      project =
        admin
        |> create_project_with_owner(%{
          slug: "search-slug",
          title: "Searchable Project"
        })

      other_project =
        admin
        |> create_project_with_owner(%{
          slug: "other-project",
          title: "Other Listing"
        })

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      view
      |> element("form[phx-change=\"text_search_change\"]")
      |> render_change(%{"project_name" => "se"})

      rows = view_assigns(view).table_model.rows
      assert Enum.any?(rows, &(&1.id == project.id))
      assert Enum.any?(rows, &(&1.id == other_project.id))
      refute render(view) =~ "search-highlight"

      view
      |> element("form[phx-change=\"text_search_change\"]")
      |> render_change(%{"project_name" => "search"})

      rows = view_assigns(view).table_model.rows
      assert Enum.any?(rows, &(&1.id == project.id))
      refute Enum.any?(rows, &(&1.id == other_project.id))
      assert render(view) =~ "search-highlight"

      view
      |> element("form[phx-change=\"text_search_change\"]")
      |> render_change(%{"project_name" => ""})

      rows = view_assigns(view).table_model.rows
      assert Enum.any?(rows, &(&1.id == project.id))
      assert Enum.any?(rows, &(&1.id == other_project.id))
      refute render(view) =~ "search-highlight"

      view
      |> element("form[phx-change=\"text_search_change\"]")
      |> render_change(%{"project_name" => admin.email})

      rows = view_assigns(view).table_model.rows
      assert Enum.any?(rows, &(&1.id == project.id))
      assert render(view) =~ admin.email
    end

    test "shows filter indicator when filters are active", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, ~p"/workspaces/course_author?filter_status=deleted&show_deleted=true")

      assert has_element?(view, "#projects-filter-panel span.inline-flex", "1")
    end

    test "clear all filters resets indicator", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, ~p"/workspaces/course_author?filter_status=deleted&show_deleted=true")

      assert has_element?(view, "#projects-filter-panel span.inline-flex", "1")

      view
      |> element("#projects-filter-panel button", "Clear All Filters")
      |> render_click()

      refute has_element?(view, "#projects-filter-panel span.inline-flex")
    end
  end

  describe "projects live as author" do
    setup [:author_conn, :set_project_timezone]

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
      assert author_project_row =~ "Active"

      refute has_element?(view, "##{another_project.id}")
    end

    test "applies show-deleted filter", %{conn: conn, author: author} do
      active_project = create_project_with_owner(author)
      deleted_project = create_project_with_owner(author, %{status: :deleted})

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, "##{active_project.id}")
      refute has_element?(view, "##{deleted_project.id}")

      view
      |> element("#deletedCheck")
      |> render_click()

      assert has_element?(view, "##{active_project.id}")
      assert has_element?(view, "##{deleted_project.id}")
    end

    test "applies paging", %{conn: conn, author: author} do
      first_p =
        insert(:project,
          title: "First Project",
          inserted_at: project_yesterday(),
          authors: [author]
        )

      last_p =
        insert(:project,
          title: "Last Project",
          inserted_at: project_tomorrow(),
          authors: [author]
        )

      insert_list(26, :project, inserted_at: DateTime.now!("Etc/UTC"), authors: [author])

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, "##{last_p.id}")
      refute has_element?(view, "##{first_p.id}")

      view
      |> element("#projects-table button[phx-click='paged_table_page_change']", "2")
      |> render_click(%{"limit" => "20", "offset" => "20"})

      refute has_element?(view, "##{last_p.id}")
      assert has_element?(view, "##{first_p.id}")
    end

    test "applies sorting", %{conn: conn, author: author} do
      create_project_with_owner(author, %{title: "Testing A"})
      create_project_with_owner(author, %{title: "Testing B"})

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      view
      |> element("th[phx-click='paged_table_sort'][phx-value-sort_by='title']")
      |> render_click(%{"sort_by" => "title"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ "Testing A"

      view
      |> element("th[phx-click='paged_table_sort'][phx-value-sort_by='title']")
      |> render_click(%{"sort_by" => "title"})

      assert view
             |> element("tr:first-child > td:first-child")
             |> render() =~ "Testing B"
    end
  end

  describe "projects with tags as admin user" do
    setup [:admin_conn, :set_project_timezone]

    test "displays project tags in table", %{conn: conn, admin: admin} do
      project = create_project_with_owner(admin)

      {:ok, biology_tag} = Oli.Tags.create_tag(%{name: "Biology"})
      {:ok, chemistry_tag} = Oli.Tags.create_tag(%{name: "Chemistry"})
      {:ok, _} = Oli.Tags.associate_tag_with_project(project, biology_tag)
      {:ok, _} = Oli.Tags.associate_tag_with_project(project, chemistry_tag)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      project_row = view |> element("##{project.id}") |> render()
      assert project_row =~ "Biology"
      assert project_row =~ "Chemistry"
    end

    test "displays empty tags column when project has no tags", %{conn: conn, admin: admin} do
      project = create_project_with_owner(admin)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      project_row = view |> element("##{project.id}") |> render()
      refute project_row =~ "bg-[#f7def8]"
    end

    test "tags component is rendered in table cell", %{conn: conn, admin: admin} do
      _project = create_project_with_owner(admin)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")
      assert has_element?(view, "div[phx-hook='TagsComponent']")
    end

    test "tags column header is present for admin users", %{conn: conn, admin: admin} do
      _project = create_project_with_owner(admin)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      assert has_element?(view, "th", "Tags")
    end
  end

  describe "projects with tags as regular author" do
    setup [:author_conn, :set_project_timezone]

    test "does not display tags column for regular authors", %{conn: conn, author: author} do
      project = create_project_with_owner(author)

      {:ok, biology_tag} = Oli.Tags.create_tag(%{name: "Biology"})
      {:ok, chemistry_tag} = Oli.Tags.create_tag(%{name: "Chemistry"})
      {:ok, _} = Oli.Tags.associate_tag_with_project(project, biology_tag)
      {:ok, _} = Oli.Tags.associate_tag_with_project(project, chemistry_tag)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      project_row = view |> element("##{project.id}") |> render()
      refute project_row =~ "Biology"
      refute project_row =~ "Chemistry"
    end

    test "tags column header is not present for regular authors", %{conn: conn, author: author} do
      _project = create_project_with_owner(author)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      refute has_element?(view, "th", "Tags")
    end

    test "tags component is not rendered for regular authors", %{conn: conn, author: author} do
      _project = create_project_with_owner(author)

      {:ok, view, _html} = live(conn, ~p"/workspaces/course_author")

      refute has_element?(view, "div[phx-hook='TagsComponent']")
    end
  end

  describe "projects csv export" do
    setup [:admin_conn, :set_project_timezone]

    test "download csv link includes applied filters", %{conn: conn} do
      {:ok, view, _html} =
        live(conn, ~p"/workspaces/course_author?filter_visibility=selected&show_all=true")

      assert view
             |> element("a", "Download CSV")
             |> render() =~ "filter_visibility=selected"
    end
  end

  defp create_project_with_owner(author, attrs \\ %{}) do
    insert(:project, Map.merge(%{authors: [author]}, attrs))
  end

  defp set_project_timezone(%{conn: conn}) do
    {:ok, %{conn: Plug.Conn.put_session(conn, :time_zone, "Etc/UTC")}}
  end

  defp view_assigns(view) do
    :sys.get_state(view.pid).socket.assigns
  end

  defp project_yesterday do
    DateTime.add(DateTime.utc_now(), -86_400, :second)
  end

  defp project_tomorrow do
    DateTime.add(DateTime.utc_now(), 86_400, :second)
  end
end
