defmodule Oli.Publishing do

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Authoring.Course.Project
  alias Oli.Accounts.Author
  alias Oli.Delivery.Sections
  alias Oli.Publishing.{Publication, PublishedResource}


  @doc """
  Returns the activity revisions for a list of activity ids
  that pertain to a given publication.
  """
  def get_published_activity_revisions(publication_id, activity_ids) do

    activity = Oli.Resources.ResourceType.get_id_by_type("activity")

    Repo.all(from mapping in PublishedResource,
      join: rev in Oli.Resources.Revision, on: mapping.revision_id == rev.id,
      where: rev.resource_type_id == ^activity and mapping.publication_id == ^publication_id and mapping.resource_id in ^activity_ids,
      select: rev) |> Repo.preload(:activity_type)
  end

  # For a project, return the all the current revisions associated
  # with the unpublished publication for a list of resource_ids
  def get_unpublished_revisions(project, resource_ids) do

    project_id = project.id

    revisions = Repo.all(from m in Oli.Publishing.PublishedResource,
      join: rev in Oli.Resources.Revision, on: rev.id == m.revision_id,
      join: p in Oli.Publishing.Publication, on: p.id == m.publication_id,
      where: p.published == false and m.resource_id in ^resource_ids and p.project_id == ^project_id,
      select: rev)

    # order them according to the resource_ids
    map = Enum.reduce(revisions, %{}, fn e, m -> Map.put(m, e.resource_id, e) end)
    Enum.map(resource_ids, fn resource_id -> Map.get(map, resource_id) end)

  end



  @doc """
  Returns the list of publications.
  ## Examples
      iex> list_publications()
      [%Publication{}, ...]
  """
  def list_publications do
    Repo.all(Publication)
  end

  @doc """
  Returns the list of publications available to an author. If no author is specified,
  then it will only return publicly available open and free publications

  ## Examples
      iex> available_publications(author)
      [%Publication{}, ...]
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

  @doc """
  Gets the ID of the unpublished publication for a project. This assumes there is only one unpublished publication per project.
   ## Examples

      iex> get_unpublished_publication_id!(123)
      %Publication{}

      iex> get_unpublished_publication_id!(456)
      ** (Ecto.NoResultsError)
  """
  def get_unpublished_publication_id!(project_id)do
    Repo.one(
      from p in Publication,
      where: p.project_id == ^project_id and p.published == false,
      select: p.id)
  end

  def initial_publication_setup(project, resource, resource_revision) do
    Repo.transaction(fn ->
      with {:ok, publication} <- create_publication(%{
          project_id: project.id,
          root_resource_id: resource.id,
        }),
        {:ok, resource_mapping} <- create_resource_mapping(%{
          publication_id: publication.id,
          resource_id: resource.id,
          revision_id: resource_revision.id,
        })
        # {:ok, objective_mapping} <- create_objective_mapping(%{
        #   publication_id: publication.id,
        #   objective_id: objective.id,
        #   revision_id: objective_revision.id,
        # })
      do
        %{}
        |> Map.put(:publication, publication)
        |> Map.put(:resource_mapping, resource_mapping)
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Get unpublished publication for a project from slug. This assumes there is only one unpublished publication per project.
   ## Examples

      iex> get_unpublished_publication_by_slug!("my-project-slug")
      %Publication{}

      iex> get_unpublished_publication_by_slug!("invalid-slug")
      ** (Ecto.NoResultsError)
  """
  def get_unpublished_publication_by_slug!(project_slug) do
    Repo.one from pub in Publication,
      join: proj in Project, on: pub.project_id == proj.id,
      where: proj.slug == ^project_slug and pub.published == false,
      select: pub
  end

  @doc """
  Gets the latest published publication for a project from slug.
   ## Examples

      iex> get_latest_published_publication_by_slug!("my-project-slug")
      %Publication{}

      iex> get_latest_published_publication_by_slug!("invalid-slug")
      ** (Ecto.NoResultsError)
  """
  def get_latest_published_publication_by_slug!(project_slug) do
    Repo.one from pub in Publication,
      join: proj in Project, on: pub.project_id == proj.id,
      where: proj.slug == ^project_slug and pub.published == true,
      order_by: [desc: pub.updated_at], limit: 1,
      select: pub
  end

  @doc """
  Gets a single publication.
  Raises `Ecto.NoResultsError` if the Publication does not exist.
  ## Examples
      iex> get_publication!(123)
      %Publication{}
      iex> get_publication!(456)
      ** (Ecto.NoResultsError)
  """
  def get_publication!(id), do: Repo.get!(Publication, id)

  @doc """
  Creates a publication.
  ## Examples
      iex> create_publication(%{field: value})
      {:ok, %Publication{}}
      iex> create_publication(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_publication(attrs \\ %{}) do
    %Publication{}
    |> Publication.changeset(attrs)
    |> Repo.insert()
  end

  def new_project_publication(resource, project) do
    %Publication{}
    |> Publication.changeset(%{
      description: "Initial project creation",
      root_resource_id: resource.id,
      project_id: project.id
    })
  end

  @doc """
  Updates a publication.
  ## Examples
      iex> update_publication(publication, %{field: new_value})
      {:ok, %Publication{}}
      iex> update_publication(publication, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_publication(%Publication{} = publication, attrs) do
    publication
    |> Publication.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a publication.
  ## Examples
      iex> delete_publication(publication)
      {:ok, %Publication{}}
      iex> delete_publication(publication)
      {:error, %Ecto.Changeset{}}
  """
  def delete_publication(%Publication{} = publication) do
    Repo.delete(publication)
  end

  @doc """
  Get unpublished publication for a project. This assumes there is only one unpublished publication per project.
  """
  @spec get_unpublished_publication(String.t) :: any
  def get_unpublished_publication(project_slug) do
    Repo.one from pub in Publication,
          join: proj in Project, on: pub.project_id == proj.id,
          where: proj.slug == ^project_slug and pub.published == false,
          select: pub
  end


  def get_published_objective_details(publication_id) do

    objective = Oli.Resources.ResourceType.get_id_by_type("objective")

    Repo.all from mapping in PublishedResource,
      join: rev in Oli.Resources.Revision, on: mapping.revision_id == rev.id,
      where: rev.resource_type_id == ^objective and mapping.publication_id == ^publication_id,
      select: map(rev, [:slug, :title])
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking publication changes.
  ## Examples
      iex> change_publication(publication)
      %Ecto.Changeset{source: %Publication{}}
  """

  def change_publication(%Publication{} = publication) do
    Publication.changeset(publication, %{})
  end

  @doc """
  Returns the list of resource_mappings.
  ## Examples
      iex> list_resource_mappings()
      [%ResourceMapping{}, ...]
  """
  def list_resource_mappings do
    Repo.all(PublishedResource)
  end

  @doc """
  Returns the list of resource_mappings for a given publication.

  ## Examples

      iex> get_resource_mappings_for_publication()
      [%ResourceMapping{}, ...]

  """
  def get_resource_mappings_by_publication(publication_id) do
    from(p in PublishedResource, where: p.publication_id == ^publication_id, preload: [:resource, :revision])
    |> Repo.all()
  end

  @doc """
  Gets a single resource_mapping.
  Raises `Ecto.NoResultsError` if the Resource mapping does not exist.
  ## Examples
      iex> get_resource_mapping!(123)
      %ResourceMapping{}
      iex> get_resource_mapping!(456)
      ** (Ecto.NoResultsError)
  """
  def get_resource_mapping!(id), do: Repo.get!(PublishedResource, id)

  def get_resource_mapping!(publication_id, resource_id) do
    Repo.one!(from p in PublishedResource, where: p.publication_id == ^publication_id and p.resource_id == ^resource_id)
  end

  def get_resource_mapping(publication_id, resource_id) do
    Repo.one(from p in PublishedResource, where: p.publication_id == ^publication_id and p.resource_id == ^resource_id)
  end

  @doc """
  Creates a new, or updates the existing published resource
  for the given publication and revision.
  """
  def upsert_published_resource(%Publication{} = publication, revision) do
    case get_resource_mapping(publication.id, revision.resource_id) do
      nil -> create_resource_mapping(%{publication_id: publication.id, resource_id: revision.resource_id, revision_id: revision.id})
      mapping -> update_resource_mapping(mapping, %{resource_id: revision.resource_id, revision_id: revision.id})
    end
  end

  def publish_new_revision(previous_revision, changes, publication, author_id) do

    changes = Map.merge(changes, %{author_id: author_id})

    {:ok, revision} = Oli.Resources.create_revision_from_previous(previous_revision, changes)
    {:ok, _} = upsert_published_resource(publication, revision)

    revision
  end

  @doc """
  Creates a resource_mapping.
  ## Examples
      iex> create_resource_mapping(%{field: value})
      {:ok, %ResourceMapping{}}
      iex> create_resource_mapping(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_resource_mapping(attrs \\ %{}) do
    %PublishedResource{}
    |> PublishedResource.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a resource_mapping.
  ## Examples
      iex> update_resource_mapping(resource_mapping, %{field: new_value})
      {:ok, %ResourceMapping{}}
      iex> update_resource_mapping(resource_mapping, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource_mapping(%PublishedResource{} = resource_mapping, attrs) do
    resource_mapping
    |> PublishedResource.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource_mapping changes.
  ## Examples
      iex> change_resource_mapping(resource_mapping)
      %Ecto.Changeset{source: %ResourceMapping{}}
  """
  def change_resource_mapping(%PublishedResource{} = resource_mapping) do
    PublishedResource.changeset(resource_mapping, %{})
  end

  @doc """
  Deletes a resource_mapping.
  ## Examples
      iex> delete_resource_mapping(resource_mapping)
      {:ok, %ResourceMapping{}}
      iex> delete_resource_mapping(resource_mapping)
      {:error, %Ecto.Changeset{}}
  """
  def delete_resource_mapping(%PublishedResource{} = resource_mapping) do
    Repo.delete(resource_mapping)
  end


  @doc """
  Returns the list of objectives (their slugs and titles)
  that pertain to a given publication.
  """
  def get_published_revision(publication_id, resource_id) do
    Repo.one from mapping in PublishedResource,
      join: rev in Oli.Resources.Revision, on: mapping.revision_id == rev.id,
      where: mapping.resource_id == ^resource_id and mapping.publication_id == ^publication_id,
      select: rev
  end

  @doc """
  Publishes the active publication and creates a new working unpublished publication for a project.
  Returns the published publication

  ## Examples

      iex> publish_project(project)
      {:ok, %Publication{}}
  """
  def publish_project(project) do
    active_publication = get_unpublished_publication_by_slug!(project.slug)

    # create a new publication to capture all further edits
    {:ok, new_publication} = create_publication(%{
      description: active_publication.description,
      published: false,
      open_and_free: active_publication.open_and_free,
      root_resource_id: active_publication.root_resource_id,
      project_id: active_publication.project_id,
    })

    # create new mappings for the new publication
    resource_mappings = get_resource_mappings_by_publication(active_publication.id)

    # create a copy_mapping function bound to new_publication
    copy_mapping_fn = &(copy_mapping_for_publication &1, new_publication)

    # copy mappings for resources, activities, and objectives
    Enum.map(resource_mappings, copy_mapping_fn)

    # set the active publication to published
    update_publication(active_publication, %{published: true})
  end

  defp copy_mapping_for_publication(%PublishedResource{} = resource_mapping, publication) do
    {:ok, new_mapping} = create_resource_mapping(%{
      publication_id: publication.id,
      resource_id: resource_mapping.resource_id,
      revision_id: resource_mapping.revision_id,
    })
    new_mapping
  end


  def update_all_section_publications(project, publication) do
    Sections.get_sections_by_project(project)
    |> Enum.map(fn section ->
      Sections.update_section(section, %{publication_id: publication.id})
    end)
  end

  def diff_publications(p1, p2) do
    all_resource_revisions_p1 = get_resource_revisions_for_publication(p1)
    all_resource_revisions_p2 = get_resource_revisions_for_publication(p2)

    # go through every resource in p1 to identify any resources that are identical, changed, or deleted in p2
    {visited, changes} = Map.keys(all_resource_revisions_p1)
    |> Enum.reduce({%{}, %{}}, fn id, {visited, acc} ->
      if Map.has_key?(all_resource_revisions_p2, id) do
        {_res_p1, rev_p1} = all_resource_revisions_p1[id]
        {res_p2, rev_p2} = all_resource_revisions_p2[id]
        if rev_p1.id == rev_p2.id do
          {Map.put(visited, id, true), Map.put_new(acc, id, {:identical, %{resource: res_p2, revision: rev_p2}})}
        else
          {Map.put(visited, id, true), Map.put_new(acc, id, {:changed, %{resource: res_p2, revision: rev_p2}})}
        end
      else
        {res_p1, rev_p1} = all_resource_revisions_p1[id]
        {visited, Map.put_new(acc, id, {:deleted, %{resource: res_p1, revision: rev_p1}})}
      end
    end)

    # go through every resource in p2 that wasn't in p1 to identify new resources
    changes = Map.keys(all_resource_revisions_p2)
    |> Enum.filter(fn id -> !Map.has_key?(visited, id) end)
    |> Enum.reduce(changes, fn id, acc ->
      {res_p2, rev_p2} = all_resource_revisions_p2[id]
      Map.put_new(acc, id, {:added, %{resource: res_p2, revision: rev_p2}})
    end)

    changes
  end

  defp get_resource_revisions_for_publication(publication) do
    resource_mappings = get_resource_mappings_by_publication(publication.id)

    # filter out revisions that are marked as deleted, then convert
    # to a map of resource_ids to {resource, revision} tuples
    resource_mappings
    |> Enum.filter(fn mapping -> mapping.revision.deleted == false end)
    |> Enum.reduce(%{}, fn m, acc -> Map.put_new(acc, m.resource_id, {m.resource, m.revision}) end)
  end
end
