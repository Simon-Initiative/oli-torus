defmodule OliWeb.ProjectController do
  use OliWeb, :controller

  alias Oli.Auditing.Context
  alias Oli.Qa

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
    author = conn.assigns.current_author

    case Oli.Authoring.Audited.create_project(
           Context.for_actor(author, source: :ui),
           title,
           author
         ) do
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
    author = conn.assigns.current_author
    context = Context.for_actor(author, source: :ui)

    case Oli.Authoring.Audited.duplicate_project(context, conn.assigns.project.slug, author) do
      {:ok, project} ->
        conn
        |> put_flash(:info, "Project duplicated. You've been redirected to your new project.")
        |> redirect(to: ~p"/workspaces/course_author/#{project.slug}/overview")

      {:error, reason} ->
        project = conn.assigns.project

        conn
        |> put_flash(:error, "Project could not be copied: " <> copy_error(reason))
        |> redirect(to: ~p"/workspaces/course_author/#{project.slug}/overview")
    end
  end

  def enable_triggers(conn, _project_params) do
    context = Context.for_actor(conn.assigns.current_author, source: :ui)
    project = conn.assigns.project

    case Oli.Authoring.Audited.enable_triggers(context, project.id) do
      {:ok, project} ->
        conn
        |> put_flash(:info, "AI Activation Points enabled.")
        |> redirect(to: ~p"/workspaces/course_author/#{project.slug}/overview")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Project could not be edited.")
        |> redirect(to: ~p"/workspaces/course_author/#{project.slug}/overview")
    end
  end

  defp copy_error(message) when is_binary(message), do: message
  defp copy_error(_reason), do: "please try again"
end
