defmodule OliWeb.ProjectsControllerTest do
  use OliWeb.ConnCase

  import Oli.TestHelpers

  alias Oli.Accounts.SystemRole
  alias Oli.Authoring.Course

  defp create_projects(prefix, count, author) do
    1..count
    |> Enum.map(fn i ->
      {:ok, %{project: project}} = Course.create_project("#{prefix} Project #{i}", author)
      project
    end)
  end

  describe "export_csv/2" do
    setup do
      admin =
        Oli.AccountsFixtures.author_fixture(%{system_role_id: SystemRole.role_id().system_admin})

      author = Oli.AccountsFixtures.author_fixture(%{system_role_id: SystemRole.role_id().author})

      # Create test projects
      admin_projects = create_projects("Admin", 3, admin)
      author_projects = create_projects("Author", 2, author)

      # Create a deleted project
      {:ok, %{project: deleted_project}} = Course.create_project("Deleted Project", author)
      Course.update_project(deleted_project, %{status: :deleted})

      %{
        admin: admin,
        author: author,
        admin_projects: admin_projects,
        author_projects: author_projects,
        deleted_project: deleted_project
      }
    end

    test "admin can export all projects", %{conn: conn, admin: admin} do
      conn = log_in_author(conn, admin)

      conn = get(conn, ~p"/authoring/projects/export")

      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["text/csv"]
      assert get_resp_header(conn, "content-disposition") != []

      csv_content = response(conn, 200)
      assert String.contains?(csv_content, "Title,Created,Created By,Status")
      assert String.contains?(csv_content, "Admin Project")
      assert String.contains?(csv_content, "Author Project")
    end

    test "author can only export their own projects", %{conn: conn, author: author} do
      conn = log_in_author(conn, author)

      conn = get(conn, ~p"/authoring/projects/export")

      assert response(conn, 200)
      csv_content = response(conn, 200)
      assert String.contains?(csv_content, "Author Project")
      refute String.contains?(csv_content, "Admin Project")
    end

    test "exports respect text search filter", %{conn: conn, admin: admin} do
      conn = log_in_author(conn, admin)

      conn = get(conn, ~p"/authoring/projects/export?text_search=Admin")

      assert response(conn, 200)
      csv_content = response(conn, 200)
      assert String.contains?(csv_content, "Admin Project")
      refute String.contains?(csv_content, "Author Project")
    end

    test "exports respect show_deleted filter", %{conn: conn, admin: admin} do
      # Without show_deleted
      conn = log_in_author(conn, admin)
      conn = get(conn, ~p"/authoring/projects/export?show_deleted=false")
      csv_content = response(conn, 200)
      refute String.contains?(csv_content, "Deleted Project")

      # With show_deleted - get fresh connection
      conn = build_conn() |> log_in_author(admin)
      conn = get(conn, ~p"/authoring/projects/export?show_deleted=true")
      csv_content = response(conn, 200)
      assert String.contains?(csv_content, "Deleted Project")
    end

    test "exports respect show_all filter for admin", %{conn: conn, admin: admin} do
      conn = log_in_author(conn, admin)

      # show_all=false should show only admin's projects
      conn = get(conn, ~p"/authoring/projects/export?show_all=false")
      csv_content = response(conn, 200)
      assert String.contains?(csv_content, "Admin Project")
      refute String.contains?(csv_content, "Author Project")
    end

    test "exports respect sorting parameters", %{conn: conn, admin: admin} do
      conn = log_in_author(conn, admin)

      # Test ascending sort
      conn =
        get(conn, ~p"/authoring/projects/export?sort_by=title&sort_order=asc&text_search=Admin")

      csv_content = response(conn, 200)
      lines = String.split(csv_content, "\n")
      [_header | data_lines] = lines
      valid_lines = Enum.filter(data_lines, &(&1 != ""))

      # Should be sorted by title ascending
      titles =
        Enum.map(valid_lines, fn line ->
          [title | _] = String.split(line, ",")
          String.replace(title, "\"", "")
        end)

      assert titles == Enum.sort(titles)
    end

    test "CSV format is valid", %{conn: conn, admin: admin} do
      conn = log_in_author(conn, admin)

      conn = get(conn, ~p"/authoring/projects/export")
      csv_content = response(conn, 200)

      lines = String.split(csv_content, "\n")
      [header | _] = lines

      # Check header format
      assert header == "Title,Created,Created By,Status"

      # Check that all non-empty lines have 4 columns
      lines
      |> Enum.filter(&(&1 != ""))
      |> Enum.each(fn line ->
        columns = String.split(line, ",")
        assert length(columns) == 4
      end)
    end

    test "CSV properly escapes special characters", %{conn: conn, admin: admin} do
      # Create project with special characters
      {:ok, %{project: _project}} =
        Course.create_project("Project, with \"quotes\" and\nnewlines", admin)

      conn = log_in_author(conn, admin)
      conn = get(conn, ~p"/authoring/projects/export?text_search=quotes")
      csv_content = response(conn, 200)

      # Should properly escape the title with quotes
      assert String.contains?(csv_content, "\"Project, with \"\"quotes\"\" and\nnewlines\"")
    end

    test "filename includes current date", %{conn: conn, admin: admin} do
      conn = log_in_author(conn, admin)

      conn = get(conn, ~p"/authoring/projects/export")

      [disposition_header] = get_resp_header(conn, "content-disposition")
      assert String.contains?(disposition_header, "projects-")
      assert String.contains?(disposition_header, ".csv")

      # Should contain current year
      current_year = Date.utc_today().year |> to_string()
      assert String.contains?(disposition_header, current_year)
    end

    test "handles invalid sort parameters gracefully", %{conn: conn, admin: admin} do
      conn = log_in_author(conn, admin)

      # Try invalid sort_by and sort_order parameters
      conn = get(conn, ~p"/authoring/projects/export?sort_by=invalid&sort_order=invalid")

      assert response(conn, 200)
      csv_content = response(conn, 200)

      # Should still work and return valid CSV
      assert String.contains?(csv_content, "Title,Created,Created By,Status")
    end
  end
end
