defmodule Oli.Resources do
  import Ecto.Query, warn: false
  alias Oli.Publishing.Publications.Publication
  alias Oli.Authoring.Course.ProjectResource
  alias Oli.Repo

  # Resources only know about Resources.  Resources
  # should not have a dependency on a Project or Publication
  # or Page or Container or any other higher level construct
  alias Oli.Resources.Resource
  alias Oli.Resources.ScoringStrategy
  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType
  alias Oli.Rendering.Content.ResourceSummary

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
      from(r in Resource,
        distinct: r.id,
        join: v in Revision,
        on: v.resource_id == r.id,
        where: v.slug == ^revision,
        select: r
      )

    Repo.one(query)
  end

  @doc """
  Gets a list of resources, based on a list of revision slugs.
  """
  @spec get_resources_from_slug([]) :: any
  def get_resources_from_slug(revisions) do
    query =
      from(r in Resource,
        distinct: r.id,
        join: v in Revision,
        on: v.resource_id == r.id,
        where: v.slug in ^revisions,
        select: r
      )

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
      from(r in Revision,
        where: r.slug in ^revision_slugs,
        group_by: [r.slug, r.resource_id],
        select: map(r, [:slug, :resource_id])
      )

    Repo.all(query)
  end

  @doc """
  Gets a list of slugs and resources_ids, based on a list of resource ids.
  """
  def map_slugs_from_resources_ids(revision_resources_ids) do
    query =
      from(r in Revision,
        where: r.resource_id in ^revision_resources_ids,
        group_by: [r.resource_id, r.slug],
        select: {r.resource_id, r.slug}
      )

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

  def activity_references(%{content: content} = _page),
    do: activity_references_from_content(content)

  defp activity_references_from_content(content) do
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
          ids_added: previous_revision.ids_added,
          slug: previous_revision.slug,
          title: previous_revision.title,
          graded: previous_revision.graded,
          duration_minutes: previous_revision.duration_minutes,
          batch_scoring: previous_revision.batch_scoring,
          replacement_strategy: previous_revision.replacement_strategy,
          intro_content: previous_revision.intro_content,
          intro_video: previous_revision.intro_video,
          poster_image: previous_revision.poster_image,
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
          assessment_mode: previous_revision.assessment_mode,
          parameters: previous_revision.parameters,
          legacy: previous_revision.legacy |> convert_legacy,
          tags: previous_revision.tags,
          explanation_strategy: previous_revision.explanation_strategy,
          collab_space_config: previous_revision.collab_space_config,
          purpose: previous_revision.purpose,
          relates_to: previous_revision.relates_to,
          full_progress_pct: previous_revision.full_progress_pct,
          activity_refs: previous_revision.activity_refs
        },
        convert_strings_to_atoms(attrs)
      )
      |> Map.merge(convert_strings_to_atoms(attrs))

    create_revision(attrs)
  end

  defp convert_legacy(nil), do: nil
  defp convert_legacy(legacy) when is_struct(legacy), do: Map.from_struct(legacy)
  defp convert_legacy(legacy) when is_map(legacy), do: legacy
  defp convert_legacy(item), do: item

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

  @doc """
  Returns a resource summary for a given resource_id, project or section slug and resolver.
  """
  def resource_summary(resource_id, project_or_section_slug, resolver) do
    resolver.from_resource_id(project_or_section_slug, resource_id)
    |> then(fn %Revision{title: title, slug: slug} ->
      %ResourceSummary{title: title, slug: slug}
    end)
  end

  @doc """
  Returns a list of alternatives groups for a given project or section slug and resolver.
  """
  def alternatives_groups(project_or_section_slug, resolver) do
    case resolver.revisions_of_type(
           project_or_section_slug,
           ResourceType.id_for_alternatives()
         ) do
      alternatives when is_list(alternatives) ->
        {:ok,
         Enum.map(alternatives, fn a ->
           %{
             id: a.resource_id,
             title: a.title,
             options: a.content["options"],
             strategy: Map.get(a.content, "strategy", "user_section_preference")
           }
         end)}

      error ->
        error
    end
  end

  @doc """
  Returns the revision slug of the curriculum for the given revision id.
  """

  def get_revision_root_slug(revision_id) do
    from(r in Revision,
      join: pr in ProjectResource,
      on: r.resource_id == pr.resource_id,
      where: r.id == ^revision_id,
      join: pub in Publication,
      on: pr.project_id == pub.project_id,
      join: r2 in Revision,
      on: pub.root_resource_id == r2.resource_id,
      select: r2.slug,
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Returns a list of revisions for the given resource ids.
  """
  def get_revisions_by_resource_id(resource_ids) do
    from(r in Revision,
      where: r.resource_id in ^resource_ids,
      select: r
    )
    |> Repo.all()
  end

  @doc """
  Returns an activity registration for the given resource id.
  """
  def get_activity_registration_by_resource_id(resource_id) do
    from(rev in Revision,
      join: res in Resource,
      on: res.id == rev.resource_id,
      join: reg in Oli.Activities.ActivityRegistration,
      on: rev.activity_type_id == reg.id,
      where: res.id == ^resource_id,
      select: reg,
      limit: 1
    )
    |> Repo.one()
  end

  def get_report_activities(project_id) do
    query =
      Revision
      |> join(:left, [rev], pr in Oli.Publishing.PublishedResource, on: pr.revision_id == rev.id)
      |> join(:left, [_, pr], pub in Oli.Publishing.Publications.Publication,
        on: pr.publication_id == pub.id
      )
      |> join(:left, [_, _, pub], proj in Oli.Authoring.Course.Project,
        on: pub.project_id == proj.id
      )
      |> join(:left, [rev, _, _, _], reg in Oli.Activities.ActivityRegistration,
        on: rev.activity_type_id == reg.id
      )
      |> where(
        [rev, _, pub, proj, reg],
        proj.id == ^project_id and is_nil(pub.published) and
          reg.generates_report == true
      )
      |> select([rev, _, _, _, reg], %{
        id: rev.resource_id,
        type: reg.slug,
        title: rev.title
      })

    Repo.all(query)
  end

  @doc """
  Gets bank entries for a given publication ID.

  Returns a list of maps containing resource_id, tags, objectives, and activity_type_id
  for all banked activities in the given publication.
  """
  def get_bank_entries(publication_id) do
    activity_type_id = ResourceType.id_for_activity()

    from(r in Revision,
      join: pr in Oli.Publishing.PublishedResource,
      on: pr.revision_id == r.id,
      where: pr.publication_id == ^publication_id,
      where: r.deleted == false,
      where: r.resource_type_id == ^activity_type_id,
      where: r.scope == :banked,
      select: %{
        resource_id: pr.resource_id,
        tags: r.tags,
        objectives: r.objectives,
        activity_type_id: r.activity_type_id
      }
    )
    |> Repo.all()
  end
end
