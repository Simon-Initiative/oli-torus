defmodule OliWeb.Projects.OverviewLiveTest do
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias OliWeb.Endpoint
  alias OliWeb.Projects.OverviewLive

  describe "author cannot access when is not logged in" do
    test "redirects to new session when accessing the index view", %{conn: conn} do
      {:error,
       {:redirect,
        %{
          flash: %{},
          to:
            "/authoring/session/new?request_path=%2Fauthoring%2Fproject%2Ftestproject%2Foverview"
        }}} = live(conn, Routes.live_path(Endpoint, OverviewLive, "testproject"))
    end
  end

  describe "project overview as author" do
    setup [:author_conn]

    test "loads the project correctly", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))
      assert has_element?(view, "h4", "Details")
      assert has_element?(view, "h4", "Project Attributes")
      assert has_element?(view, "h4", "Project Labels")
      assert has_element?(view, "h4", "Collaborators")
      assert has_element?(view, "h4", "Advanced Activities")
      assert has_element?(view, "h4", "Allow Duplication")
      assert has_element?(view, "h4", "Publishing Visibility")
      assert has_element?(view, "h4", "Collaboration Space")
      assert has_element?(view, "h4", "Actions")
    end

    test "project gets deleted correctly", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))

      {:ok, view, _html} =
        element(view, "form[phx-submit=\"delete\"]")
        |> render_submit()
        |> follow_redirect(conn, "/authoring/projects")

      assert Oli.Authoring.Course.get_project_by_slug(project.slug).status == :deleted
      assert has_element?(view, "button#button-new-project")
      refute has_element?(view, "a", project.title)
    end

    test "project gets updated correctly", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))

      element(view, "form[phx-submit=\"update\"]")
      |> render_submit(%{
        "project" => %{"title" => "updated title", "description" => "updated description"}
      })

      assert has_element?(view, "div.alert-info", "Project updated successfully.")
      assert has_element?(view, "input[name=\"project[title]\"][value=\"updated title\"]")
      assert has_element?(view, "textarea[name=\"project[description]\"]", "updated description")
    end

    test "project can enable required surveys", %{conn: conn, author: author} do
      project = create_project_with_author(author)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))

      refute has_element?(view, "input[name=\"survey\"][checked]")

      element(view, "form[phx-change=\"set-required-survey\"]")
      |> render_change(%{
        survey: "on"
      })

      updated_project = Oli.Authoring.Course.get_project!(project.id)
      assert updated_project.required_survey_resource_id != nil
      assert has_element?(view, "input[name=\"survey\"][checked]")
    end

    test "project can disable required surveys", %{conn: conn, author: author} do
      project = create_project_with_author(author)
      Oli.Authoring.Course.create_project_survey(project, author.id)

      {:ok, view, _html} = live(conn, Routes.live_path(Endpoint, OverviewLive, project.slug))

      assert has_element?(view, "input[name=\"survey\"][checked]")

      element(view, "form[phx-change=\"set-required-survey\"]")
      |> render_change(%{})

      updated_project = Oli.Authoring.Course.get_project!(project.id)
      assert updated_project.required_survey_resource_id == nil
      refute has_element?(view, "input[name=\"survey\"][checked]")
    end

    defp create_project_with_author(author) do
      %{project: project} = base_project_with_curriculum(nil)
      insert(:author_project, project_id: project.id, author_id: author.id)
      project
    end
  end
end
