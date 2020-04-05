defmodule OliWeb.AuthorProjectController do
  use OliWeb, :controller
  alias Oli.AuthorsProjects

  def create(conn, %{"email" => email} = params) do
    project_id = conn.params["project_id"]
    case AuthorsProjects.new_collaborator(email, project_id) do

      {:ok, _results} ->
        redirect conn, to: Routes.project_path(conn, :overview, project_id)
      {:error, _error} ->
        conn
          |> put_flash(:error, "Could not add author to project - are you sure the email is correct?")
          |> redirect(to: Routes.project_path(conn, :overview, project_id))
    end
  end

  def update(conn, %{"author" => author}) do
    # For later use -> change author role within project
  end

  def delete(conn, %{"project_id" => project_id, "author_email" => author_email}) do
    case AuthorsProjects.remove_project_from_author(author_email, project_id) do
      # FIXME -> change to :ok, results when deleting one author_project
      {n, _results} ->
        redirect conn, to: Routes.project_path(conn, :overview, project_id)
      {:error, _} ->
        conn
          |> put_flash(:error, "Could not remove author from project. Please try again")
          |> redirect(to: Routes.project_path(conn, :overview, project_id))
    end
  end
end
