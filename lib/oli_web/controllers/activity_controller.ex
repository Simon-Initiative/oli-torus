defmodule OliWeb.ActivityController do
  use OliWeb, :controller

  alias Oli.Editing.ActivityEditor

  import OliWeb.ProjectPlugs

  plug :fetch_project when action in [:edit]
  plug :authorize_project when action in [:edit]

  def edit(conn, %{"project_id" => project_slug, "revision_slug" => revision_slug, "activity_slug" => activity_slug}) do

    case ActivityEditor.create_context(project_slug, revision_slug, activity_slug, conn.assigns[:current_author]) do
      {:ok, context} -> render(conn, "edit.html", title: "Activity Editor", script: context.authoringScript, context: Jason.encode!(context))
      {:error, :not_found} -> render conn, OliWeb.SharedView, "_not_found.html"
    end

  end

  def create(conn, %{"project" => project_slug, "activity_type" => activity_type_slug, "model" => model }) do

    author = conn.assigns[:current_author]

    case ActivityEditor.create(project_slug, activity_type_slug, author, model) do
      {:ok, %{slug: slug}} -> json conn, %{ "type" => "success", "revisionSlug" => slug}
      {:error, {:not_found}} -> error(conn, 404, "not found")
      {:error, {:not_authorized}} -> error(conn, 403, "unauthorized")
      _ -> error(conn, 500, "server error")
    end

  end

  def update(conn, %{"project" => _project_slug, "activity" => _activity_slug, "model" => _model }) do

    _author = conn.assigns[:current_author]

  end

  def delete(conn, %{"project" => _project_slug, "activity" => _activity_slug }) do

    _author = conn.assigns[:current_author]

  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end

end
