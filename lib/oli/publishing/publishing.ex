defmodule Oli.Publishing do
  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Publishing.{Publication, ResourceMapping, ActivityMapping, ObjectiveMapping}
  alias Oli.Course.Project
  alias Oli.Accounts.Author

  @doc """
  Returns the list of publications available to an author. If no author is specified,
  then it will only return publicly available open and free publications
  """
  def available_publications() do
    Repo.all(Publication, open_and_free: true) |> Repo.preload([:project])
  end

  def available_publications(%Author{} = author) do
    Repo.all from pub in Publication,
      join: proj in Project, on: pub.project_id == proj.id,
      left_join: a in assoc(proj, :authors),
      where: a.id == ^author.id or pub.open_and_free == true,
      preload: [:project],
      select: pub
  end

  def get_unpublished_publication(project_slug, _author_id) do
    Repo.one from pub in Publication,
      join: proj in Project, on: pub.project_id == proj.id,
      where: proj.slug == ^project_slug and pub.published == false,
      select: pub
  end

  def get_publication!(id), do: Repo.get!(Publication, id)

  def create_publication(attrs \\ %{}) do
    %Publication{}
    |> Publication.changeset(attrs)
    |> Repo.insert()
  end

  def new_project_publication(resource, project) do
    %Publication{}
      |> Publication.changeset(%{
        description: "Initial project creation",
        root_resources: [resource.id],
        project_id: project.id
      })
  end

  @doc """
  Get unpublished publication for a project. This assumes there is only one unpublished publication per project.
  """
  def get_unpublished_publication(project_id) do
    Repo.one(
      from p in "publications",
      where: p.project_id == ^project_id and p.published == false,
      select: p.id)
  end

  def get_resource_mapping!(id), do: Repo.get!(ResourceMapping, id)

  def get_resource_mapping!(publication_id, resource_id) do
    Repo.one!(from p in ResourceMapping, where: p.publication_id == ^publication_id and p.resource_id == ^resource_id)
  end

  def create_resource_mapping(attrs \\ %{}) do
    %ResourceMapping{}
    |> ResourceMapping.changeset(attrs)
    |> Repo.insert()
  end

  def update_resource_mapping(%ResourceMapping{} = resource_mapping, attrs) do
    resource_mapping
    |> ResourceMapping.changeset(attrs)
    |> Repo.update()
  end

  def get_resource_mappings_by_publication(publication_id) do
    from(p in ResourceMapping, where: p.publication_id == ^publication_id, preload: [:resource, :revision])
    |> Repo.all()
  end

  def get_activity_mapping!(id), do: Repo.get!(ActivityMapping, id)

  def create_activity_mapping(attrs \\ %{}) do
    %ActivityMapping{}
    |> ActivityMapping.changeset(attrs)
    |> Repo.insert()
  end

  def get_objective_mappings_by_publication(publication_id) do
    from(p in ObjectiveMapping, where: p.publication_id == ^publication_id, preload: [:objective, :revision])
    |> Repo.all()
  end

  def get_objective_mapping!(id), do: Repo.get!(ObjectiveMapping, id)

  def create_objective_mapping(attrs \\ %{}) do
    %ObjectiveMapping{}
    |> ObjectiveMapping.changeset(attrs)
    |> Repo.insert()
  end

  def change_objective_mapping(%ObjectiveMapping{} = objective_mapping) do
    ObjectiveMapping.changeset(objective_mapping, %{})
  end
end
