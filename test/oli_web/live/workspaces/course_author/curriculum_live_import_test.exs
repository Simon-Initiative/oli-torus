defmodule OliWeb.Workspaces.CourseAuthor.CurriculumLiveImportTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Authoring.Authors.ProjectRole
  alias Oli.Resources.Revision
  alias Oli.Seeder
  alias OliWeb.Workspaces.CourseAuthor.Curriculum.EditorLive

  @import_form_key "import_google_doc"

  describe "import control visibility" do
    setup %{conn: conn} do
      original_config = Application.get_env(:oli, :google_docs_import, [])

      on_exit(fn ->
        Application.put_env(:oli, :google_docs_import, original_config)
      end)

      map = Seeder.base_project_with_resource2()

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)

      {:ok, conn: conn, project: map.project, author: map.author}
    end

    test "non-admin authors do not see import action", %{
      conn: conn,
      project: project,
      author: author
    } do
      conn =
        conn
        |> log_in_author(author)
        |> get(~p"/workspaces/course_author/#{project.slug}/curriculum")

      {:ok, view, _html} = live(conn)

      refute has_element?(
               view,
               "button[phx-click=\"show_import_modal\"]",
               "Import from Google Docs"
             )
    end

    test "content admins can open import modal and see validation", %{
      conn: conn,
      project: project
    } do
      content_admin =
        insert(:author,
          system_role_id: Oli.Accounts.SystemRole.role_id().content_admin
        )

      insert(:author_project,
        author_id: content_admin.id,
        project_id: project.id,
        project_role_id: ProjectRole.role_id().owner
      )

      conn =
        conn
        |> log_in_author(content_admin)
        |> get(~p"/workspaces/course_author/#{project.slug}/curriculum")

      {:ok, view, _html} = live(conn)

      assert has_element?(
               view,
               "button[phx-click=\"show_import_modal\"]",
               "Import from Google Docs"
             )

      view
      |> element("button[phx-click=\"show_import_modal\"]")
      |> render_click()

      assert has_element?(view, "#google_docs_import_modal-container")

      view
      |> form("#google-docs-import-form", %{@import_form_key => %{"file_id" => ""}})
      |> render_submit()

      assert render(view) =~ "Enter the FILE_ID from the Google Docs URL."

      view
      |> form("#google-docs-import-form", %{
        @import_form_key => %{"file_id" => "https://docs.google.com"}
      })
      |> render_submit()

      assert render(view) =~ "Provide only the FILE_ID portion, not the full Google Docs URL."
    end
  end

  describe "import success and error flows" do
    setup %{conn: conn} do
      original_config = Application.get_env(:oli, :google_docs_import, [])

      on_exit(fn ->
        Application.put_env(:oli, :google_docs_import, original_config)
      end)

      map = Seeder.base_project_with_resource2()

      conn =
        Plug.Test.init_test_session(conn, lti_session: nil)

      content_admin =
        insert(:author,
          system_role_id: Oli.Accounts.SystemRole.role_id().content_admin
        )

      insert(:author_project,
        author_id: content_admin.id,
        project_id: map.project.id,
        project_role_id: ProjectRole.role_id().owner
      )

      conn =
        conn
        |> log_in_author(content_admin)
        |> get(~p"/workspaces/course_author/#{map.project.slug}/curriculum")

      {:ok, view, _html} = live(conn)

      # open modal once for later tests
      view
      |> element("button[phx-click=\"show_import_modal\"]")
      |> render_click()

      {:ok, view: view, project: map.project, content_admin: content_admin}
    end

    test "successful import surfaces warnings and enables navigation", %{
      view: view,
      project: project
    } do
      Application.put_env(:oli, :google_docs_import, importer: __MODULE__.SuccessImporter)

      file_id = "123SuccessfulDoc"

      view
      |> form("#google-docs-import-form", %{@import_form_key => %{"file_id" => file_id}})
      |> render_submit()

      # Allow async task to finish
      assert render(view) =~ "Imported &quot;Imported #{file_id}&quot; successfully."

      assert has_element?(
               view,
               "ul[role='status'] li[data-warning-index='0']",
               "Simulated warning"
             )

      view
      |> element("button[phx-click=\"open_imported_page\"]")
      |> render_click()

      expected_slug = "imported-#{file_id}"

      assert_redirect(view, Routes.live_path(@endpoint, EditorLive, project.slug, expected_slug))
    end

    test "import error displays descriptive message", %{view: view} do
      Application.put_env(:oli, :google_docs_import, importer: __MODULE__.ErrorImporter)

      view
      |> form("#google-docs-import-form", %{@import_form_key => %{"file_id" => "InvalidDoc"}})
      |> render_submit()

      assert render(view) =~ "FILE_ID looks invalid. Use the value between"
      refute has_element?(view, "button[phx-click=\"open_imported_page\"]")
    end

    test "redirect error instructs user to adjust sharing", %{view: view} do
      Application.put_env(:oli, :google_docs_import, importer: __MODULE__.RedirectImporter)

      view
      |> form("#google-docs-import-form", %{@import_form_key => %{"file_id" => "RedirectDoc"}})
      |> render_submit()

      assert render(view) =~ "Google Docs redirected the request"
      refute has_element?(view, "button[phx-click=\"open_imported_page\"]")
    end
  end

  defmodule SuccessImporter do
    alias Oli.Resources.Revision

    def import(_project_slug, _container_slug, file_id, _author, _opts) do
      revision = %Revision{
        id: System.unique_integer([:positive]),
        resource_id: System.unique_integer([:positive]),
        slug: "imported-#{file_id}",
        title: "Imported #{file_id}"
      }

      warnings = [
        %{
          code: :media_dedupe_warning,
          message: "Simulated warning",
          severity: :info,
          metadata: %{}
        }
      ]

      {:ok, revision, warnings}
    end
  end

  defmodule ErrorImporter do
    def import(_project_slug, _container_slug, _file_id, _author, _opts) do
      {:error, {:invalid_file_id, :format}, []}
    end
  end

  defmodule RedirectImporter do
    alias Oli.GoogleDocs.Warnings

    def import(_project_slug, _container_slug, _file_id, _author, _opts) do
      warnings = [
        Warnings.build(:download_redirect, %{status: 307, location: "https://accounts.google.com"})
      ]

      {:error, {:http_redirect, 307, "https://accounts.google.com"}, warnings}
    end
  end
end
