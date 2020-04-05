defmodule Oli.AuthorsProjects do
  alias Oli.Accounts.AuthorProject
  alias Oli.Repo

  # VERY important -> all author projects must be passed into the :projects
  # change, or else the other assocations will be deleted
  # defp update_projects_for_author(author, projects) do
  #   author
  #   |> Author.changeset(%{ projects: projects})
  #   |> Ecto.Changeset.put_assoc(:projects, projects)
  # end

  def add_project_to_author(author, project) do
    %AuthorProject{}
    |> AuthorProject.changeset(%{
      author_id: author.id,
      project_id: project.id,
      project_role_id: Oli.Repo.get_by(
        Oli.Accounts.ProjectRole,
        type: "contributor").id
    })
  end

  def remove_project_from_author(author, project) do
    Repo.delete(
      Repo.get_by(
        AuthorProject,
        author_id: author.id,
        project_id: project.id))
  end
end
