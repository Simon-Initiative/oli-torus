defmodule Oli.AuthorsProjects do
  alias Oli.Accounts.AuthorProject
  alias Oli.Repo
  alias Oli.Accounts.Author
  alias Oli.Accounts
  alias Oli.Course
  import Ecto.Query

  # VERY important -> all author projects must be passed into the :projects
  # change, or else the other assocations will be deleted
  # defp update_projects_for_author(author, projects) do
  #   author
  #   |> Author.changeset(%{ projects: projects})
  #   |> Ecto.Changeset.put_assoc(:projects, projects)
  # end

  def new_collaborator(email, project_id) do
    author = Accounts.get_author_by_email(email)
    project = Course.get_project_by_slug(project_id)
    project_role = Oli.Repo.get_by(
      Oli.Accounts.ProjectRole,
      type: "contributor")

    %AuthorProject{}
    |> AuthorProject.changeset(%{
      author_id: author.id,
      project_id: project.id,
      project_role_id: project_role.id,
    })
    |> Repo.insert()
  end

  def add_project_to_author(author, project) do
    author = Repo.preload(author, [:projects])
    projects = [project | author.projects]

    author
    |> Author.changeset(%{ projects: projects})
    |> Ecto.Changeset.put_assoc(:projects, projects)
  end

  def remove_project_from_author(author_email, project_id) do
    author = Accounts.get_author_by_email(author_email)
    project = Course.get_project_by_slug(project_id)
    # FIXME -> When we have uniqueness constraints on author_projects, change to Repo.get_by
    Repo.delete_all(
        Ecto.Query.from(ap in AuthorProject,
        where: ap.author_id == ^author.id and
        ap.project_id == ^project.id))
  end
end
