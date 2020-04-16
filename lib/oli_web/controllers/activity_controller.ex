defmodule OliWeb.ActivityController do
  use OliWeb, :controller

  alias Oli.Editing.ActivityEditor

  def create(conn, %{"project" => project_slug, "activity_type" => activity_type_slug, "model" => model }) do

    author = conn.assigns[:current_author]

    case ActivityEditor.create(project_slug, activity_type_slug, author, model) do
      {:ok, %{slug: slug}} -> json conn, %{ "type" => "success", "revisionSlug" => slug}
      {:error, {:not_found}} -> error(conn, 404, "not found")
      {:error, {:not_authorized}} -> error(conn, 403, "unauthorized")
      _ -> error(conn, 500, "server error")
    end

  end

  def update(conn, %{"project" => project_slug, "activity" => activity_slug, "model" => model }) do

    author = conn.assigns[:current_author]

  end

  def delete(conn, %{"project" => project_slug, "activity" => activity_slug }) do

    author = conn.assigns[:current_author]

  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end

end
