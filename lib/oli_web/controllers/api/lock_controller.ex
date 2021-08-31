defmodule OliWeb.Api.LockController do
  use OliWeb, :controller

  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Publishing.AuthoringResolver

  def acquire(conn, %{"project" => project_slug, "resource" => resource_slug} = params) do
    author = conn.assigns[:current_author]

    fetch_revision = Map.get(params, "fetch_revision", "false")

    case PageEditor.acquire_lock(project_slug, resource_slug, author.email) do
      {:acquired} ->
        result = %{"type" => "acquired"}

        case fetch_revision do
          "true" ->
            revision = AuthoringResolver.from_revision_slug(project_slug, resource_slug)

            json(
              conn,
              Map.put(
                result,
                "revision",
                %{
                  content: revision.content,
                  objectives: revision.objectives,
                  title: revision.title
                }
              )
            )

          _ ->
            json(conn, result)
        end

      {:lock_not_acquired, {user, _updated_at}} ->
        json(conn, %{"type" => "not_acquired", "user" => user})

      {:error, {:not_found}} ->
        error(conn, 404, "not found")

      {:error, {:not_authorized}} ->
        error(conn, 403, "unauthorized")

      {:error, {:error}} ->
        error(conn, 500, "server error")
    end
  end

  def release(conn, %{"project" => project_slug, "resource" => resource_slug}) do
    author = conn.assigns[:current_author]

    case PageEditor.release_lock(project_slug, resource_slug, author.email) do
      {:ok, {:released}} -> json(conn, %{"type" => "released"})
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
