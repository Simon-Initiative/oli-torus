defmodule Oli.Authoring.Course do

  import Ecto.Query, warn: false
  import Ecto.Multi
  alias Oli.Repo
  alias Oli.Publishing
  alias Oli.Authoring.{Resources, Collaborators}
  alias Oli.Authoring.Course.{Utils, Project, Family}

  def list_projects do
    Repo.all(Project)
  end

  def get_project!(id), do: Repo.get!(Project, id)
  def get_project_by_slug(slug) do
    if is_nil(slug) do
      nil
    else
      Repo.get_by(Project, slug: slug)
    end
  end

  def create_project(title, author) do
    new()
    |> insert(:family, default_family(title))
    |> merge(fn %{family: family} ->
      new()
      |> insert(:project, default_project(title, family)) end)
    |> merge(fn %{project: project} ->
      new()
      |> insert(:collaborator, Collaborators.change_collaborator(author.email, project.slug)) end)
    |> insert(:resource_family, Resources.new_resource_family())
    |> merge(fn %{resource_family: resource_family, project: project} ->
      new()
      |> insert(:resource, Resources.new_project_resource(project, resource_family)) end)
    |> merge(fn %{project: project, resource: resource} ->
      new()
      |> insert(:resource_revision, Resources.new_project_resource_revision(author, project, resource))
      |> insert(:publication, Publishing.new_project_publication(resource, project)) end)
    |> Repo.transaction
  end

  defp default_project(title, family) do
    %Project{}
      |> Project.changeset(%{
        title: title,
        slug: Utils.generate_slug("projects", title),
        version: "1.0.0",
        family_id: family.id
      })
  end

  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  def get_family!(id), do: Repo.get!(Family, id)

  def create_family(attrs \\ %{}) do
    %Family{}
    |> Family.changeset(attrs)
    |> Repo.insert()
  end

  def update_family(%Family{} = family, attrs) do
    family
    |> Family.changeset(attrs)
    |> Repo.update()
  end

  defp default_family(title) do
    %Family{}
      |> Family.changeset(%{
        title: title,
        slug: Utils.generate_slug("families", title),
        description: "New family from project creation"
      })
  end
end
