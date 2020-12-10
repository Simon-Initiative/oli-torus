defmodule OliWeb.CollaboratorController do
  use OliWeb, :controller
  alias Oli.Authoring.Collaborators

  def create(conn, %{"email" => email, "g-recaptcha-response" => g_recaptcha_response}) do
    project_id = conn.params["project_id"]

    case Oli.Utils.Recaptcha.verify(g_recaptcha_response) do
      {:success, :true} ->
        add_collaborator(conn, email, project_id)
      {:success, :false} ->
        conn
        |> put_flash(:error, "reCaptcha failed, please try again")
        |> redirect(to: Routes.project_path(conn, :overview, project_id))
    end
  end

  def update(_conn, %{"author" => _author}) do
    # For later use -> change author role within project
  end

  def delete(conn, %{"project_id" => project_id, "author_email" => author_email}) do
    case Collaborators.remove_collaborator(author_email, project_id) do
      {:ok, _} ->
        redirect conn, to: Routes.project_path(conn, :overview, project_id)
      {:error, message} ->
        conn
          |> put_flash(:error, "We couldn't remove that author from the project. #{message}")
          |> redirect(to: Routes.project_path(conn, :overview, project_id))
    end
  end

  defp add_collaborator(conn, email, project_id) do
    case Collaborators.add_collaborator(conn, email, project_id) do
      {:ok, _results} ->
        redirect conn, to: Routes.project_path(conn, :overview, project_id)
      {:error, message} ->
        conn
        |> put_flash(:error, "We couldn't add that author to the project. #{message}")
        |> redirect(to: Routes.project_path(conn, :overview, project_id))
    end
  end

end
