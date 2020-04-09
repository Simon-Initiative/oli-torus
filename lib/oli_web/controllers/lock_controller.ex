defmodule OliWeb.LockController do
  use OliWeb, :controller

  alias Oli.Editing.ResourceEditor

  def acquire(conn, %{"project" => project_slug, "resource" => resource_slug}) do

    author = conn.assigns[:current_author]

    case ResourceEditor.acquire_lock(project_slug, resource_slug, author.email) do
      {:acquired} -> json conn, %{ "type" => "acquired"}
      {:lock_not_acquired, user} -> json conn, %{ "type" => "not_acquired", "user" => user}
      {:error, {:not_found}} -> error(conn, 404, "not found")
      {:error, {:not_authorized}} -> error(conn, 403, "unauthorized")
      {:error, {:error}} -> error(conn, 500, "server error")
    end
  end

  def release(conn, %{"project" => project_slug, "resource" => resource_slug}) do
    author = conn.assigns[:current_author]

    case ResourceEditor.release_lock(project_slug, resource_slug, author.email) do
      {:ok, {:released}} -> json conn, %{ "type" => "released"}
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
