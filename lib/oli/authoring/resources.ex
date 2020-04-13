defmodule Oli.Authoring.Resources do
  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Resources.{Resource, ResourceRevision, ResourceFamily, ResourceType}

  def create_resource_family(attrs \\ %{}) do
    %ResourceFamily{}
    |> ResourceFamily.changeset(attrs)
    |> Repo.insert()
  end

  def new_resource_family() do
    %ResourceFamily{}
      |> ResourceFamily.changeset(%{})
  end

  def list_resources do
    Repo.all(Resource)
  end

  def get_resource!(id), do: Repo.get!(Resource, id)

  @spec get_resource_from_slugs(String.t, String.t) :: any
  def get_resource_from_slugs(project, revision) do
    query = from r in Resource,
          distinct: r.id,
          join: p in Project, on: r.project_id == p.id,
          join: v in ResourceRevision, on: v.resource_id == r.id,
          where: p.slug == ^project and v.slug == ^revision,
          select: r
    Repo.one(query)
  end

  def new_project_resource(project, family) do
    %Resource{}
      |> Resource.changeset(%{
        project_id: project.id, family_id: family.id
      })
  end

  def update_resource(%Resource{} = resource, attrs) do
    resource
    |> Resource.changeset(attrs)
    |> Repo.update()
  end

  def list_resource_types do
    Repo.all(ResourceType)
  end

  def get_resource_revision!(id), do: Repo.get!(ResourceRevision, id)

  def create_resource_revision(attrs \\ %{}) do
    %ResourceRevision{}
    |> ResourceRevision.changeset(attrs)
    |> Repo.insert()
  end

  def new_project_resource_revision(author, project, resource) do
    %ResourceRevision{}
      |> ResourceRevision.changeset(%{
        slug: project.slug <> "_root_container",
        title: project.title <> " root container",
        author_id: author.id,
        resource_id: resource.id,
        resource_type_id: Repo.one!(
          from rt in "resource_types",
          where: rt.type == "container",
          select: rt.id)
      })
  end

  def update_resource_revision(%ResourceRevision{} = resource_revision, attrs) do
    resource_revision
    |> ResourceRevision.changeset(attrs)
    |> Repo.update()
  end

end
