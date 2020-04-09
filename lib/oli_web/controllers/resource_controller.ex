defmodule OliWeb.ResourceController do
  use OliWeb, :controller

  alias Oli.Editing.ResourceEditor
  import OliWeb.ProjectPlugs

  plug :fetch_project when action not in [:view, :update]
  plug :authorize_project when action not in [:view, :update]

  def view(conn, %{"project_id" => _project_id}) do
    render conn, "page.html", title: "Page", active: :page
  end

  def edit(conn, %{"project_id" => project_slug, "revision_slug" => revision_slug}) do

    case ResourceEditor.create_context(project_slug, revision_slug, conn.assigns[:current_author]) do
      {:ok, context} -> render conn, "edit.html", title: "Resource Editor", context: Jason.encode!(context)
      {:error, :not_found} -> render conn, OliWeb.SharedView, "_not_found.html"
    end

  end

  def update(conn, %{"project" => project_slug, "resource" => resource_slug, "update" => update }) do

    author = conn.assigns[:current_author]

    IO.inspect author
    IO.inspect update

    case ResourceEditor.edit(project_slug, resource_slug, author.email, update) do

      {:ok, revision} -> json conn, %{ "type" => "success", "revision_slug" => revision.slug}
      {:error, {:lock_not_acquired}} -> error(conn, 423, "locked")
      {:error, {:not_found}} -> error(conn, 404, "not found")
      {:error, {:not_authorized}} -> error(conn, 403, "unauthorized")
      _ -> error(conn, 500, "server error")
    end

  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end

end
