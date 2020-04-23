defmodule Oli.Authoring.Course do

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Publishing
  alias Oli.Authoring.{Collaborators}
  alias Oli.Authoring.Course.{Utils, Project, Family, ProjectResource}

  def create_project_resource(attrs) do
    %ProjectResource{}
    |> ProjectResource.changeset(attrs)
    |> Repo.insert()
  end

  def list_projects do
    Repo.all(Project)
  end

  def get_project!(id), do: Repo.get!(Project, id)
  def get_project_by_slug(nil), do: nil
  def get_project_by_slug(slug) when is_binary(slug), do: Repo.get_by(Project, slug: slug)


  def create_and_attach_resource(project, attrs) do
    {:ok, %{resource: resource, revision: revision}} = Oli.Resources.create_resource_and_revision(attrs)
    {:ok, project_resource} = attach_to_project(resource, project)

    {:ok, %{resource: resource, revision: revision, project_resource: project_resource}}
  end

  def attach_to_project(%{resource: resource}, project) do
    attach_to_project(resource, project)
  end

  def attach_to_project(resource, project) do
    create_project_resource(%{project_id: project.id, resource_id: resource.id})
  end


  def initial_resource_setup(author, project) do

    attrs = %{
      title: project.title <> " root container",
      author_id: author.id,
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container")
    }
    create_and_attach_resource(project, attrs)

  end


  def create_project(title, author) do
    Repo.transaction(fn ->
      with {:ok, project_family} <- create_family(default_family(title)),
           {:ok, project} <- create_project(default_project(title, project_family)),
           {:ok, collaborator} <- Collaborators.add_collaborator(author, project),
           {:ok, %{resource: resource, revision: resource_revision}}
              <- initial_resource_setup(author, project),
           {:ok, %{publication: publication, resource_mapping: resource_mapping}}
              <- Publishing.initial_publication_setup(project, resource, resource_revision)
      do
        %{
          project_family: project_family,
          project: project,
          author_project: collaborator,
          resource: resource,
          resource_revision: resource_revision,
          publication: publication,
          resource_mapping: resource_mapping,
        }
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  defp create_project(attrs) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
  end

  defp default_project(title, family) do
    %{
      title: title,
      slug: Utils.generate_slug("projects", title),
      version: "1.0.0",
      family_id: family.id
    }
  end

  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  def get_family!(id), do: Repo.get!(Family, id)

  def update_family(%Family{} = family, attrs) do
    family
    |> Family.changeset(attrs)
    |> Repo.update()
  end

  def create_family(attrs \\ %{}) do
    %Family{}
    |> Family.changeset(attrs)
    |> Repo.insert()
  end

  defp default_family(title) do
    %{
      title: title,
      slug: Utils.generate_slug("families", title),
      description: "New family from project creation",
    }
  end
end
