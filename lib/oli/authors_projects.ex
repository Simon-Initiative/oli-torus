defmodule Oli.AuthorsProjects do
  alias Oli.Accounts.AuthorProject
  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Course

  def author_project(email, project_slug) do
    author = Accounts.get_author_by_email(email)
    project = Course.get_project_by_slug(project_slug)
    project_role = Oli.Repo.get_by(
      Oli.Accounts.ProjectRole,
      %{type:
        case length(Repo.preload(project, [:authors]).authors) do
          0 -> "owner"
          _ -> "contributor"
        end
      })

    %AuthorProject{}
    |> AuthorProject.changeset(%{
      author_id: if author do author.id else nil end,
      project_id: if project do project.id else nil end,
      project_role_id: if project_role do project_role.id else nil end,
    })
  end

  def create_author_project(email, project_slug) do
    author_project(email, project_slug)
    |> Repo.insert
  end

  def delete_author_project(author_email, project_id) do
    author = Accounts.get_author_by_email(author_email)
    project = Course.get_project_by_slug(project_id)
    if is_nil(author) || is_nil(project)
      do
        {:error, "Author or project not found"}
      else
        author_project = Repo.get_by(AuthorProject, %{
          author_id: author.id,
          project_id: project.id,
        })
        if author_project do
          project_role_type = Repo.preload(author_project, [:project_role]).project_role.type
          if (project_role_type) == "owner"
            do {:error, "Cannot remove the project owner"}
            else Repo.delete(author_project)
          end
        else {:error, "Author not found in project"}
        end
      end
  end
end
