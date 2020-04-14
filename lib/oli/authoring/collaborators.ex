defmodule Oli.Authoring.Collaborators do
  alias Oli.Authoring.Authors.{AuthorProject, ProjectRole}
  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Authoring.Course
  import Oli.Utils

  def change_collaborator(email, project_slug) do
    with {:ok, author} <- Accounts.get_author_by_email(email) |> trap_nil(),
      {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
      {:ok, project_role} <- Repo.get_by(
        ProjectRole, %{type:
        if Enum.empty?(Repo.preload(project, [:authors]).authors)
          do "owner"
          else "contributor"
        end }) |> trap_nil()
    do
      %AuthorProject{}
      |> AuthorProject.changeset(%{
        author_id: author.id,
        project_id: project.id,
        project_role_id: project_role.id,
      })
    else
      error -> {:error, error}
    end
  end

  def add_collaborator(author = %Accounts.Author{}, project_slug) when is_binary(project_slug) do
    add_collaborator(author.email, project_slug)
  end
  def add_collaborator(email, project = %Course.Project{}) when is_binary(email) do
    add_collaborator(email, project.slug)
  end
  def add_collaborator(author = %Accounts.Author{}, project = %Course.Project{}) do
    add_collaborator(author.email, project.slug)
  end
  def add_collaborator(email, project_slug) when is_binary(email) and is_binary(project_slug) do
    change_collaborator(email, project_slug)
    |> Repo.insert
  end

  def remove_collaborator(email, project_slug) when is_binary(email) and is_binary(project_slug) do
    with {:ok, author} <- Accounts.get_author_by_email(email) |> trap_nil(),
         {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok, author_project} <- Repo.get_by(AuthorProject, %{
          author_id: author.id,
          project_id: project.id,
        }) |> trap_nil()
    do
      project_role_type = Repo.preload(author_project, [:project_role]).project_role.type

      if (project_role_type) == "owner"
        do {:error, "Cannot remove the project owner"}
        else Repo.delete(author_project)
      end

    else
      error -> {:error, "Author not found in project"}
    end
  end
end
