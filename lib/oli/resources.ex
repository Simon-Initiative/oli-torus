defmodule Oli.Resources do
  import Ecto.Query, warn: false
  alias Oli.Repo

  # Resources only know about Resources.  Resources
  # should not have a dependency on a Project or Publication
  # or Page or Container or any other higher level construct
  alias Oli.Resources.Resource
  alias Oli.Resources.ScoringStrategy
  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType

  @doc """
  Create a new resource with given attributes of a specific resource tyoe.

  Returns {:ok, revision}
  """
  def create_new(attrs, resource_type_id) do
    {:ok, resource} = create_new_resource()

    with_type =
      convert_strings_to_atoms(attrs)
      |> Map.put(:resource_type_id, resource_type_id)
      |> Map.put(:resource_id, resource.id)

    create_revision(with_type)
  end

  @doc """
  Returns the list of resources.
  ## Examples
      iex> list_resources()
      [%Resource{}, ...]
  """
  def list_resources do
    Repo.all(Resource)
  end

  @doc """
  Gets a single resource.
  Raises `Ecto.NoResultsError` if the Resource does not exist.
  ## Examples
      iex> get_resource!(123)
      %Resource{}
      iex> get_resource!(456)
      ** (Ecto.NoResultsError)
  """
  def get_resource!(id), do: Repo.get!(Resource, id)

  @doc """
  Gets a single resource.
  Returns nil if resource does not exist.
  ## Examples
      iex> get_resource(123)
      %Resource{}
      iex> get_resource(456)
      nil
  """
  def get_resource(id), do: Repo.get(Resource, id)

  @doc """
  Gets a single resource, based on a revision  slug.
  """
  @spec get_resource_from_slug(String.t()) :: any
  def get_resource_from_slug(revision) do
    query =
      from r in Resource,
        distinct: r.id,
        join: v in Revision,
        on: v.resource_id == r.id,
        where: v.slug == ^revision,
        select: r

    Repo.one(query)
  end

  @doc """
  Gets a list of resources, based on a list of revision slugs.
  """
  @spec get_resources_from_slug([]) :: any
  def get_resources_from_slug(revisions) do
    query =
      from r in Resource,
        distinct: r.id,
        join: v in Revision,
        on: v.resource_id == r.id,
        where: v.slug in ^revisions,
        select: r

    resources = Repo.all(query)

    # order them according to the input revisions
    map = Enum.reduce(resources, %{}, fn e, m -> Map.put(m, e.id, e) end)
    Enum.map(revisions, fn r -> Map.get(map, r.resource_id) end)
  end

  @doc """
  Gets a list of resource ids and slugs, based on a list of revision slugs.
  """
  def map_resource_ids_from_slugs(revision_slugs) do
    query =
      from r in Revision,
        where: r.slug in ^revision_slugs,
        group_by: [r.slug, r.resource_id],
        select: map(r, [:slug, :resource_id])

    Repo.all(query)
  end

  def create_new_resource() do
    %Resource{}
    |> Resource.changeset(%{})
    |> Repo.insert()
  end

  @doc """
  Creates a new resource and revision pair, returning both newly
  created constructs.
  ## Examples
      iex> create_resource_and_revision(%{title: "title", resource_type_id: 1})
      {:ok, %{%Resource{}, %Revision{}}
      iex> create_resource_and_revision(resource, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_resource_and_revision(attrs) do
    case create_new_resource() do
      {:ok, resource} ->
        case Map.merge(attrs, %{resource_id: resource.id})
             |> create_revision() do
          {:ok, revision} -> {:ok, %{resource: resource, revision: revision}}
          error -> error
        end

      error ->
        error
    end
  end

  # returns a list of resource ids that refer to activity references in a page
  def activity_references(%Revision{content: content} = _page) do
    Oli.Resources.PageContent.flat_filter(content, &(&1["type"] == "activity-reference"))
    |> Enum.map(& &1["activity_id"])
  end

  @doc """
  Updates a resource.
  ## Examples
      iex> update_resource(resource, %{field: new_value})
      {:ok, %Resource{}}
      iex> update_resource(resource, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource(%Resource{} = resource, attrs) do
    resource
    |> Resource.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource changes.
  ## Examples
      iex> change_resource(resource)
      %Ecto.Changeset{source: %Resource{}}
  """
  def change_resource(%Resource{} = resource) do
    Resource.changeset(resource, %{})
  end

  @doc """
  Returns the list of resource_types.
  ## Examples
      iex> list_resource_types()
      [%ResourceType{}, ...]
  """
  def list_resource_types do
    Repo.all(ResourceType)
  end

  @doc """
  Gets a single resource_type.
  Raises `Ecto.NoResultsError` if the Resource type does not exist.
  ## Examples
      iex> get_resource_type!(123)
      %ResourceType{}
      iex> get_resource_type!(456)
      ** (Ecto.NoResultsError)
  """
  def get_resource_type!(id), do: Repo.get!(ResourceType, id)

  @doc """
  Creates a resource_type.
  ## Examples
      iex> create_resource_type(%{field: value})
      {:ok, %ResourceType{}}
      iex> create_resource_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_resource_type(attrs \\ %{}) do
    %ResourceType{}
    |> ResourceType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a scoring strategy.
  ## Examples
      iex> create_scoring_strategy(%{field: value})
      {:ok, %ScoringStrategy{}}
      iex> create_scoring_strategy(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_scoring_strategy(attrs \\ %{}) do
    %ScoringStrategy{}
    |> ScoringStrategy.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a resource_type.
  ## Examples
      iex> update_resource_type(resource_type, %{field: new_value})
      {:ok, %ResourceType{}}
      iex> update_resource_type(resource_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource_type(%ResourceType{} = resource_type, attrs) do
    resource_type
    |> ResourceType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource_type changes.
  ## Examples
      iex> change_resource_type(resource_type)
      %Ecto.Changeset{source: %ResourceType{}}
  """
  def change_resource_type(%ResourceType{} = resource_type) do
    ResourceType.changeset(resource_type, %{})
  end

  @doc """
  Returns the list of revisions.
  ## Examples
      iex> list_revisions()
      [%Revision{}, ...]
  """
  def list_revisions do
    Repo.all(Revision)
  end

  @doc """
  Gets a single revision.
  Raises `Ecto.NoResultsError` if the Resource revision does not exist.
  ## Examples
      iex> get_revision!(123)
      %Revision{}
      iex> get_revision!(456)
      ** (Ecto.NoResultsError)
  """
  def get_revision!(id), do: Repo.get!(Revision, id)

  @doc """
  Creates a revision.
  ## Examples
      iex> create_revision(%{field: value})
      {:ok, %Revision{}}
      iex> create_revision(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_revision(attrs \\ %{}) do
    %Revision{}
    |> Revision.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a revision.
  ## Examples
      iex> update_revision(revision, %{field: new_value})
      {:ok, %Revision{}}
      iex> update_revision(revision, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_revision(revision, attrs) do
    Revision.changeset(revision, attrs)
    |> Repo.update()
  end

  def create_revision_from_previous(previous_revision, attrs) do
    attrs =
      Map.merge(
        %{
          content: previous_revision.content,
          objectives: previous_revision.objectives,
          children: previous_revision.children,
          deleted: previous_revision.deleted,
          slug: previous_revision.slug,
          title: previous_revision.title,
          graded: previous_revision.graded,
          author_id: previous_revision.author_id,
          resource_id: previous_revision.resource_id,
          previous_revision_id: previous_revision.id,
          resource_type_id: previous_revision.resource_type_id,
          activity_type_id: previous_revision.activity_type_id,
          scoring_strategy_id: previous_revision.scoring_strategy_id,
          primary_resource_id: previous_revision.primary_resource_id,
          max_attempts: previous_revision.max_attempts,
          recommended_attempts: previous_revision.recommended_attempts,
          time_limit: previous_revision.time_limit,
          scope: previous_revision.scope,
          retake_mode: previous_revision.retake_mode,
          tags: previous_revision.tags
        },
        convert_strings_to_atoms(attrs)
      )

    create_revision(attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking revision changes.
  ## Examples
      iex> change_revision(revision, params)
      %Ecto.Changeset{source: %Revision{}}
  """
  def change_revision(revision, params \\ %{}) do
    Revision.changeset(revision, params)
  end

  defp convert_strings_to_atoms(attrs) do
    Map.keys(attrs)
    |> Enum.reduce(%{}, fn k, m ->
      case k do
        s when is_binary(s) -> Map.put(m, String.to_existing_atom(s), Map.get(attrs, s))
        atom -> Map.put(m, atom, Map.get(attrs, atom))
      end
    end)
  end
end
