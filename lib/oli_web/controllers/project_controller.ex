defmodule OliWeb.ProjectController do
  use OliWeb, :controller

  alias Oli.Authoring.Course
  alias Oli.Qa
  alias Oli.Authoring.Clone

  def unpublished(pub), do: pub.published == nil

  def resource_editor(conn, _project_params) do
    render(conn, "resource_editor.html", title: "Resource Editor", active: :resource_editor)
  end

  def review_project(conn, _params) do
    project = conn.assigns.project
    Qa.review_project(project.slug)

    conn
    |> redirect(to: Routes.project_path(conn, :publish, project))
  end

  def create(conn, %{"project" => %{"title" => title} = _project_params}) do
    case Course.create_project(title, conn.assigns.current_author) do
      {:ok, %{project: project}} ->
        redirect(conn,
          to: ~p"/workspaces/course_author/#{project.slug}/overview"
        )

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Could not create project. Please try again")
        |> redirect(to: ~p"/workspaces/course_author")
    end
  end

  def clone_project(conn, _project_params) do
    case Clone.clone_project(conn.assigns.project.slug, conn.assigns.current_author) do
      {:ok, project} ->
        conn
        |> put_flash(:info, "Project duplicated. You've been redirected to your new project.")
        |> redirect(to: ~p"/workspaces/course_author/#{project.slug}/overview")

      {:error, message} ->
        project = conn.assigns.project

        conn
        |> put_flash(:error, "Project could not be copied: " <> message)
        |> redirect(to: ~p"/workspaces/course_author/#{project.slug}/overview")
    end
  end

  def enable_triggers(conn, _project_params) do
    case Oli.Authoring.Course.update_project(conn.assigns.project, %{allow_triggers: true}) do
      {:ok, project} ->
        conn
        |> put_flash(:info, "AI Activation Points enabled.")
        |> redirect(to: ~p"/workspaces/course_author/#{project.slug}/overview")

      {:error, message} ->
        project = conn.assigns.project

        conn
        |> put_flash(:error, "Project could not be edited: " <> message)
        |> redirect(to: ~p"/workspaces/course_author/#{project.slug}/overview")
    end
  end
end
