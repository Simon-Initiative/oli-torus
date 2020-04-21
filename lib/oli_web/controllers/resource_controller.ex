defmodule OliWeb.ResourceController do
  use OliWeb, :controller

  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Authoring.Activities
  alias Oli.Authoring.Resources

  import OliWeb.ProjectPlugs

  plug :fetch_project when action not in [:view, :update]
  plug :authorize_project when action not in [:view, :update]

  def edit(conn, %{"project_id" => project_slug, "revision_slug" => revision_slug}) do

    case ResourceEditor.create_context(project_slug, revision_slug, conn.assigns[:current_author]) do
      {:ok, context} -> render(conn, "edit.html", title: "Resource Editor", context: Jason.encode!(context), scripts: get_scripts())
      {:error, :not_found} -> render conn, OliWeb.SharedView, "_not_found.html", title: "Not Found"
    end

  end

  defp get_scripts() do
    Activities.list_activity_registrations()
      |> Enum.map(fn r -> Map.get(r, :authoring_script) end)
  end

  def update(conn, %{"project" => project_slug, "resource" => resource_slug, "update" => update }) do

    author = conn.assigns[:current_author]

    case ResourceEditor.edit(project_slug, resource_slug, author.email, update) do

      {:ok, revision} -> json conn, %{ "type" => "success", "revision_slug" => revision.slug}
      {:error, {:lock_not_acquired}} -> error(conn, 423, "locked")
      {:error, {:not_found}} -> error(conn, 404, "not found")
      {:error, {:not_authorized}} -> error(conn, 403, "unauthorized")
      _ -> error(conn, 500, "server error")
    end

  end

  def delete(conn, %{"project_id" => project_slug, "revision_slug" => resource_slug }) do
    case Resources.mark_revision_deleted(project_slug, resource_slug, conn.assigns.current_author.id) do
      {:ok, _} ->
        redirect conn, to: Routes.curriculum_path(conn, :index, project_slug)
      {:error, message} ->
        conn
          |> put_flash(:error, "Error: #{message}. Please try again")
          |> redirect(to: Routes.curriculum_path(conn, :index, project_slug))
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end

end
