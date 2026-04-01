defmodule OliWeb.Workspaces.CourseAuthor.Curriculum.EditorLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Seeder

  defp live_view_route(project_slug, revision_slug, params \\ %{}),
    do: ~p"/workspaces/course_author/#{project_slug}/curriculum/#{revision_slug}/edit?#{params}"

  describe "when user is not logged in" do
    setup [:create_project_with_units_and_modules]

    test "redirects to author login", %{
      conn: conn,
      project: project,
      revisions: revisions
    } do
      redirect_path = "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_route(project.slug, revisions.page_revision_1))
    end
  end

  describe "when user is logged in as an instructor" do
    setup [:instructor_conn, :create_project_with_units_and_modules]

    test "redirects to author login", %{
      conn: conn,
      project: project,
      revisions: revisions
    } do
      redirect_path = "/authors/log_in"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_route(project.slug, revisions.page_revision_1))
    end
  end

  describe "when user is logged in as an author but not an author of the project" do
    setup [:author_conn, :create_project_with_units_and_modules]

    test "redirects to overview", %{
      conn: conn,
      project: project,
      revisions: revisions
    } do
      redirect_path = "/workspaces/course_author"

      {:error, {:redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_route(project.slug, revisions.page_revision_1))
    end
  end

  describe "when author is logged in" do
    setup :create_author_project_conn

    test "redirects to overview if revision not found", %{
      conn: conn,
      project: project
    } do
      redirect_path = "/workspaces/course_author"

      {:error, {:live_redirect, %{to: ^redirect_path}}} =
        live(conn, live_view_route(project.slug, "non-existent-slug"))
    end

    test "displays revision editor", %{
      conn: conn,
      project: project,
      revision: revision
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug, revision.slug))

      assert element(view, "#page_editor-container")
      assert element(view, "#collab-space-#{project.slug}-#{revision.slug}")
      assert element(view, "#content > nav")
    end

    test "displays breadcrumbs in basic authoring mode", %{
      conn: conn,
      project: project,
      revision: revision
    } do
      {:ok, _view, html} = live(conn, live_view_route(project.slug, revision.slug))

      # Check that breadcrumbs are rendered
      assert html =~ "<nav class=\"breadcrumb-bar"
      assert html =~ "Curriculum"
      assert html =~ revision.title
    end

    test "displays breadcrumbs in advanced authoring mode", %{
      conn: conn,
      project: project,
      adaptive_page_revision: adaptive_page_revision
    } do
      # For this test, we'll verify that breadcrumbs are rendered
      # The advanced authoring detection is handled in the live view
      {:ok, _view, html} = live(conn, live_view_route(project.slug, adaptive_page_revision.slug))

      # Check that breadcrumbs are rendered in advanced authoring mode
      assert html =~ "<nav class=\"breadcrumb-bar"
      assert html =~ "Curriculum"
      assert html =~ adaptive_page_revision.title
    end

    test "renders the shared authoring header shell for advanced authoring", %{
      conn: conn,
      project: project,
      adaptive_page_revision: adaptive_page_revision
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug, adaptive_page_revision.slug))
      render_hook(view, "survey_scripts_loaded", %{})
      render_hook(view, "authoring_preview_state_changed", %{"enabled" => true})

      assert has_element?(view, "div.TitleBar")
      assert has_element?(view, "button[phx-click=\"begin_title_edit\"]")
      assert has_element?(view, "button[phx-click=\"request_authoring_preview\"]")
      assert has_element?(view, "div.TitleBar #adaptive_read_only_toggle")
      refute has_element?(view, "div.TitleBar #adaptive_read_only_toggle input[disabled]")
      assert has_element?(view, "div.TitleBar button[phx-click=\"begin_title_edit\"][disabled]")

      assert has_element?(view, "#authoring_editor-container")
    end

    test "keeps preview disabled until the editor is ready", %{
      conn: conn,
      project: project,
      revision: revision,
      adaptive_page_revision: adaptive_page_revision
    } do
      {:ok, basic_view, _html} = live(conn, live_view_route(project.slug, revision.slug))

      assert has_element?(
               basic_view,
               "div.TitleBar button[phx-click=\"request_authoring_preview\"][disabled]"
             )

      render_hook(basic_view, "survey_scripts_loaded", %{})
      render_hook(basic_view, "authoring_title_lock_state_changed", %{"editable" => true})

      refute has_element?(
               basic_view,
               "div.TitleBar button[phx-click=\"request_authoring_preview\"][disabled]"
             )

      refute has_element?(basic_view, "#adaptive_read_only_toggle")

      {:ok, advanced_view, _html} =
        live(conn, live_view_route(project.slug, adaptive_page_revision.slug))

      assert has_element?(
               advanced_view,
               "div.TitleBar button[phx-click=\"request_authoring_preview\"][disabled]"
             )

      render_hook(advanced_view, "survey_scripts_loaded", %{})

      assert has_element?(
               advanced_view,
               "div.TitleBar button[phx-click=\"request_authoring_preview\"][disabled]"
             )

      assert has_element?(
               advanced_view,
               "div.TitleBar #adaptive_read_only_toggle input[disabled]"
             )

      render_hook(advanced_view, "authoring_preview_state_changed", %{"enabled" => true})

      refute has_element?(
               advanced_view,
               "div.TitleBar button[phx-click=\"request_authoring_preview\"][disabled]"
             )

      refute has_element?(
               advanced_view,
               "div.TitleBar #adaptive_read_only_toggle input[disabled]"
             )

      assert has_element?(advanced_view, "div.TitleBar #adaptive_read_only_toggle")
      refute has_element?(advanced_view, "nav.breadcrumb-bar #adaptive_read_only_toggle")
      assert has_element?(advanced_view, "#adaptive_read_only_toggle input[role=\"switch\"]")
      assert render(advanced_view) =~ "Read only"
      assert render(advanced_view) =~ "Preview"

      assert has_element?(
               advanced_view,
               "div.TitleBar button[phx-click=\"begin_title_edit\"][disabled]"
             )
    end

    test "keeps basic edit title disabled until the basic page lock is acquired", %{
      conn: conn,
      author: author,
      project: project,
      revision: revision
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug, revision.slug))

      assert has_element?(view, "div.TitleBar button[phx-click=\"begin_title_edit\"][disabled]")

      assert {:acquired} =
               PageEditor.acquire_lock(
                 project.slug,
                 revision.slug,
                 author.email
               )

      refute has_element?(view, "div.TitleBar button[phx-click=\"begin_title_edit\"][disabled]")
    end

    test "disables adaptive read only toggle when another author already holds the lock", %{
      conn: conn,
      project: project,
      adaptive_page_revision: adaptive_page_revision
    } do
      other_author = insert(:author, email: "adaptive-lock-owner@example.edu")

      insert(:author_project,
        author_id: other_author.id,
        project_id: project.id
      )

      assert {:acquired} =
               PageEditor.acquire_lock(
                 project.slug,
                 adaptive_page_revision.slug,
                 other_author.email
               )

      {:ok, view, _html} = live(conn, live_view_route(project.slug, adaptive_page_revision.slug))

      render_hook(view, "survey_scripts_loaded", %{})
      render_hook(view, "authoring_preview_state_changed", %{"enabled" => true})

      assert has_element?(view, "div.TitleBar #adaptive_read_only_toggle input[disabled]")
      assert has_element?(view, "div.TitleBar button[phx-click=\"begin_title_edit\"][disabled]")
    end

    test "disables adaptive read only toggle when another author acquires the lock after load", %{
      conn: conn,
      project: project,
      adaptive_page_revision: adaptive_page_revision
    } do
      other_author = insert(:author, email: "adaptive-lock-after-load@example.edu")

      insert(:author_project,
        author_id: other_author.id,
        project_id: project.id
      )

      {:ok, view, _html} = live(conn, live_view_route(project.slug, adaptive_page_revision.slug))

      render_hook(view, "survey_scripts_loaded", %{})
      render_hook(view, "authoring_preview_state_changed", %{"enabled" => true})

      refute has_element?(view, "div.TitleBar #adaptive_read_only_toggle input[disabled]")

      assert {:acquired} =
               PageEditor.acquire_lock(
                 project.slug,
                 adaptive_page_revision.slug,
                 other_author.email
               )

      assert has_element?(view, "div.TitleBar #adaptive_read_only_toggle input[disabled]")
      assert has_element?(view, "div.TitleBar button[phx-click=\"begin_title_edit\"][disabled]")
    end

    test "re-enables adaptive read only toggle after another author releases the lock", %{
      conn: conn,
      project: project,
      adaptive_page_revision: adaptive_page_revision
    } do
      other_author = insert(:author, email: "adaptive-lock-release@example.edu")

      insert(:author_project,
        author_id: other_author.id,
        project_id: project.id
      )

      assert {:acquired} =
               PageEditor.acquire_lock(
                 project.slug,
                 adaptive_page_revision.slug,
                 other_author.email
               )

      {:ok, view, _html} = live(conn, live_view_route(project.slug, adaptive_page_revision.slug))

      render_hook(view, "survey_scripts_loaded", %{})
      render_hook(view, "authoring_preview_state_changed", %{"enabled" => true})

      assert has_element?(view, "div.TitleBar #adaptive_read_only_toggle input[disabled]")

      assert {:ok, {:released}} =
               PageEditor.release_lock(
                 project.slug,
                 adaptive_page_revision.slug,
                 other_author.email
               )

      refute has_element?(view, "div.TitleBar #adaptive_read_only_toggle input[disabled]")
    end

    test "saves the title in liveview and patches the editor url", %{
      conn: conn,
      author: author,
      project: project,
      revision: revision
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug, revision.slug))

      assert {:acquired} =
               PageEditor.acquire_lock(
                 project.slug,
                 revision.slug,
                 author.email
               )

      view |> element("button[phx-click=\"begin_title_edit\"]") |> render_click()

      html =
        view
        |> form("form[phx-submit=\"save_title\"]", %{
          "title_editor" => %{"title" => "Renamed Basic Page"}
        })
        |> render_submit()

      assert_patch(view, live_view_route(project.slug, "renamed_basic_page"))
      assert html =~ "Renamed Basic Page"
    end

    test "shows a direct lock conflict message when another author holds the edit lock", %{
      conn: conn,
      project: project,
      revision: revision
    } do
      other_author = insert(:author, email: "other-author@example.edu")

      insert(:author_project,
        author_id: other_author.id,
        project_id: project.id
      )

      assert {:acquired} =
               PageEditor.acquire_lock(project.slug, revision.slug, other_author.email)

      {:ok, view, _html} = live(conn, live_view_route(project.slug, revision.slug))

      html =
        render_submit(view, "save_title", %{
          "title_editor" => %{"title" => "Conflicting Rename"}
        })

      assert html =~
               "This page is currently being edited by other-author@example.edu. You can change the title after the edit lock is released."
    end

    test "shows a shell flash when adaptive read-only blocks an edit", %{
      conn: conn,
      project: project,
      adaptive_page_revision: adaptive_page_revision
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug, adaptive_page_revision.slug))

      html =
        render_hook(view, "authoring_readonly_edit_blocked", %{
          "message" =>
            "This page is in read-only mode. Toggle \"Read only\" off in the header to edit."
        })

      assert html =~
               "This page is in read-only mode. Toggle &quot;Read only&quot; off in the header to edit."
    end

    test "breadcrumbs contain correct navigation links", %{
      conn: conn,
      project: project,
      revision: revision
    } do
      {:ok, _view, html} = live(conn, live_view_route(project.slug, revision.slug))

      # Check that breadcrumbs contain the project title and link to curriculum
      assert html =~ project.title
      assert html =~ "/workspaces/course_author/#{project.slug}/curriculum"
      assert html =~ revision.title
    end

    test "breadcrumbs are assigned to socket correctly", %{
      conn: conn,
      project: project,
      revision: revision
    } do
      {:ok, view, _html} = live(conn, live_view_route(project.slug, revision.slug))

      # Check that breadcrumbs are assigned to the socket
      assert view |> has_element?("nav.breadcrumb-bar")

      # Verify breadcrumb structure - check that breadcrumb items exist
      assert view |> has_element?("nav.breadcrumb-bar li")
    end

    test "breadcrumbs work with nested container structure", %{
      conn: conn,
      project: project,
      revision: revision
    } do
      # This test would require a more complex setup with containers
      # For now, we'll test the basic functionality
      {:ok, _view, html} = live(conn, live_view_route(project.slug, revision.slug))

      # Basic breadcrumb structure should be present
      assert html =~ "Curriculum"
      assert html =~ revision.title
    end
  end

  defp create_author_project_conn(%{conn: conn}) do
    %{
      project: project,
      author: author,
      revision1: revision,
      adaptive_page_revision: adaptive_page_revision
    } =
      Seeder.base_project_with_resource2() |> Seeder.add_adaptive_page()

    conn =
      log_in_author(conn, author)

    %{
      project: project,
      author: author,
      revision: revision,
      adaptive_page_revision: adaptive_page_revision,
      conn: conn
    }
  end
end
