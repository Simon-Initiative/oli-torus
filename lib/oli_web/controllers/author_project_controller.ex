defmodule OliWeb.AuthorProjectController do
  use OliWeb, :controller
  alias Oli.AuthorsProjects

  def create(conn, %{"collaborator" => %{"project" => project, "author" => author}}) do
    case AuthorsProjects.add_project_to_author(author, project) do

      {:ok, %{project: project} = _results} ->
        redirect conn, to: Routes.project_path(conn, :overview, project)
      {:error, _} ->
        conn
          |> put_flash(:error, "Could not add author to project. Please try again")
          |> redirect(to: Routes.project_path(conn, :overview, project))
    end
  end

  def update(conn, %{"author" => author}) do
    # For later use -> change author role within project
  end

  def delete(conn, %{"author" => author, "project" => project}) do
    case AuthorsProjects.remove_project_from_author(author, project) do
      {:ok, %{project: project} = _results} ->
        redirect conn, to: Routes.project_path(conn, :overview, project)
      {:error, _} ->
        conn
          |> put_flash(:error, "Could not add author to project. Please try again")
          |> redirect(to: Routes.project_path(conn, :overview, project))
    end
  end
end
