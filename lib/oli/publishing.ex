defmodule Oli.Publishing do

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Course.ProjectVisibility
  alias Oli.Accounts.Author
  alias Oli.Authoring.Locks
  alias Oli.Delivery.Sections
  alias Oli.Resources.{Revision, ResourceType}
  alias Oli.Publishing.{Publication, PublishedResource}
  alias Oli.Institutions.Institution

  def query_unpublished_revisions_by_type(project_slug, type) do
    publication_id = get_unpublished_publication_by_slug!(project_slug).id
    resource_type_id = ResourceType.get_id_by_type(type)

    from rev in Revision,
      join: mapping in PublishedResource,
      on: mapping.revision_id == rev.id,
      distinct: rev.resource_id,
      where: mapping.publication_id == ^publication_id
        and rev.resource_type_id == ^resource_type_id
        and rev.deleted == false,
      select: rev
  end

  def get_unpublished_revisions_by_type(project_slug, type) do
    Repo.all(query_unpublished_revisions_by_type(project_slug, type))
    |> Repo.preload(:resource_type)
  end

  @doc """
  Returns the activity revisions for a list of activity ids
  that pertain to a given publication.
  """
  def get_published_activity_revisions(publication_id, activity_ids) do

    activity = ResourceType.get_id_by_type("activity")

    Repo.all(from mapping in PublishedResource,
      join: rev in Revision, on: mapping.revision_id == rev.id,
      where: rev.resource_type_id == ^activity and mapping.publication_id == ^publication_id and mapping.resource_id in ^activity_ids,
      select: rev) |> Repo.preload(:activity_type)
  end

  # For a project, return the all the current revisions associated
  # with the unpublished publication for a list of resource_ids
  def get_unpublished_revisions(project, resource_ids) do

    project_id = project.id

    revisions = Repo.all(from m in Oli.Publishing.PublishedResource,
      join: rev in Revision, on: rev.id == m.revision_id,
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
    subquery = from t in Publication,
      select: %{project_id: t.project_id, max_date: max(t.updated_at)},
      where: t.published == true,
      group_by: t.project_id

    query = from pub in Publication,
      join: u in subquery(subquery), on: pub.project_id == u.project_id and u.max_date == pub.updated_at,
      join: proj in Project, on: pub.project_id == proj.id,
      where: pub.open_and_free == true or proj.visibility == :global,
      preload: [:project],
      distinct: true,
      select: pub

    Repo.all(query)
  end

  @spec available_publications(Oli.Accounts.Author.t(), Oli.Institutions.Institution.t()) :: any
  def available_publications(%Author{} = author, %Institution{} = institution) do

    subquery = from t in Publication,
      select: %{project_id: t.project_id, max_date: max(t.updated_at)},
      where: t.published == true,
      group_by: t.project_id

    query = from pub in Publication,
      join: u in subquery(subquery), on: pub.project_id == u.project_id and u.max_date == pub.updated_at,
      join: proj in Project, on: pub.project_id == proj.id,
      left_join: a in assoc(proj, :authors),
      left_join: v in ProjectVisibility, on: proj.id == v.project_id,
      where: a.id == ^author.id or pub.open_and_free == true or proj.visibility == :global or (proj.visibility == :selected and (v.author_id == ^author.id or v.institution_id == ^institution.id)),
      preload: [:project],
      distinct: true,
      select: pub

    Repo.all(query)

  end

  @doc """
  Gets the ID of the unpublished publication for a project. This assumes there is only one unpublished publication per project.
   ## Examples

      iex> get_unpublished_publication_id!(123)
      %Publication{}

      iex> get_unpublished_publication_id!(456)
      ** (Ecto.NoResultsError)
  """
  def get_unpublished_publication_id!(project_id) do
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

  def get_published_objective_details(publication_id) do

    objective = ResourceType.get_id_by_type("objective")

    Repo.all from mapping in PublishedResource,
      join: rev in Revision, on: mapping.revision_id == rev.id,
      where: rev.deleted == false and rev.resource_type_id == ^objective and mapping.publication_id == ^publication_id,
      select: map(rev, [:title, :resource_id, :children])
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

  def get_objective_mappings_by_publication(publication_id) do

    objective = ResourceType.get_id_by_type("objective")

    Repo.all(from mapping in PublishedResource,
      join: rev in Revision, on: mapping.revision_id == rev.id,
      where: rev.deleted == false and rev.resource_type_id == ^objective and mapping.publication_id == ^publication_id,
      select: mapping,
      preload: [:resource, :revision])

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
  def change_resource_mapping(%PublishedResource{} = resource_mapping, attrs \\ %{}) do
    PublishedResource.changeset(resource_mapping, attrs)
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
      join: rev in Revision, on: mapping.revision_id == rev.id,
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
    result = update_publication(active_publication, %{published: true})

    # push forward all existing sections to this newly published publication
    update_all_section_publications(project, active_publication)

    Oli.Authoring.Broadcaster.broadcast_publication(result, project.slug)

    result
  end

  def get_all_mappings_for_resource(resource_id, project_slug) do

    Repo.all(from mapping in PublishedResource,
      join: p in Publication, on: mapping.publication_id == p.id,
      join: project in Project, on: p.project_id == project.id,
      where: mapping.resource_id == ^resource_id and project.slug == ^project_slug,
      select: mapping,
      preload: [:publication, :revision])

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

  def get_published_revisions(publication) do
    get_resource_mappings_by_publication(publication.id)
    |> Enum.map(& Repo.preload(&1, :revision))
    |> Enum.map(& Map.get(&1, :revision))
    |> Enum.filter(& !&1.deleted)
  end

  @doc """
  Returns a map of resource ids to {resource, revision} tuples for a publication

  ## Examples
      iex> get_resource_revisions_for_publication(123)
      %{124 => [{%Resource{}, %Revision{}}], ...}
  """
  def get_resource_revisions_for_publication(publication) do
    resource_mappings = get_resource_mappings_by_publication(publication.id)

    # filter out revisions that are marked as deleted, then convert
    # to a map of resource_ids to {resource, revision} tuples
    resource_mappings
    |> Enum.filter(fn mapping -> mapping.revision.deleted == false end)
    |> Enum.reduce(%{}, fn m, acc -> Map.put_new(acc, m.resource_id, {m.resource, m.revision}) end)
  end


  @doc """
  For a given objective resource id and a given project's publication id,
  this function will find all pages and activities that have the objective
  attached to it.

  This function will return an activity more than once if that activity
  contains multiple parts with the objective attached to it.

  The return value is a list of maps of the following format:
  %{
    id: the revision id
    resource_id: the resource id
    title: the title of the resource
    slug: the slug of the revision
    part: the part name, or "attached" if pertaining to a page
  }
  """
  def find_objective_attachments(resource_id, publication_id) do

    page_id = ResourceType.get_id_by_type("page")
    activity_id = ResourceType.get_id_by_type("activity")

    sql =
      """
      select
        revisions.id, revisions.resource_id, revisions.title, revisions.slug, part
      FROM revisions, jsonb_object_keys(revisions.objectives) p(part)
      WHERE
        revisions.id IN (SELECT revision_id
        FROM published_resources
         WHERE publication_id = #{publication_id})
         AND (
           (revisions.resource_type_id = #{activity_id} AND revisions.objectives->part @> '[#{resource_id}]')
           OR
           (revisions.resource_type_id = #{page_id} AND revisions.objectives->'attached' @> '[#{resource_id}]')
         )
      """

    {:ok, %{rows: results }} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

    results
    |> Enum.map(fn [id, resource_id, title, slug, part] ->
      %{
        id: id,
        resource_id: resource_id,
        title: title,
        slug: slug,
        part: part
      }
    end)
  end

  @doc """
  For a given list of resource ids and a given project publication id,
  retrieve the corresponding published resource record, preloading the
  locked_by_id to allow access to the user that might have the resource locked.

  This only returns those records that have an active lock associated with them.
  """
  def retrieve_lock_info(resource_ids, publication_id) do

    Repo.all(from mapping in PublishedResource,
      where: mapping.publication_id == ^publication_id and mapping.resource_id in ^resource_ids,
      select: mapping,
      preload: [:author])

    |> Enum.filter(fn m -> !Locks.expired_or_empty?(m) end)

  end

  @doc """
  For a given list of activity resource ids and a given project publication id,
  find and retrieve all revisions for the pages that contain the activities.

  Returns a map of activity_ids to a map containing the slug and resource id of the
  page that encloses it
  """
  def determine_parent_pages(activity_resource_ids, publication_id) do

    page_id = ResourceType.get_id_by_type("page")

    activities = MapSet.new(activity_resource_ids)

    sql =
      """
      select
        rev.resource_id,
        rev.slug,
        jsonb_path_query(content, '$.model[*] ? (@.type == "activity-reference")')
      from published_resources as mapping
      join revisions as rev
      on mapping.revision_id = rev.id
      where mapping.publication_id = #{publication_id}
        and rev.resource_type_id = #{page_id}
        and rev.deleted is false
      """

    {:ok, %{rows: results }} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

    Enum.filter(results, fn [_, _, %{"activity_id" => activity_id}] -> MapSet.member?(activities, activity_id) end)
    |> Enum.reduce(%{}, fn [id, slug, %{"activity_id" => activity_id}], map -> Map.put(map, activity_id, %{slug: slug, id: id}) end)

  end

  @doc """
  Creates a course builder course visibility mapping
  """
  def insert_visibility(attrs) do
    %ProjectVisibility{}
    |> ProjectVisibility.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Removes a course builder course visibility mapping
  """
  def remove_visibility(%ProjectVisibility{} = project_visibility) do
    Repo.delete(project_visibility)
  end

  @doc """
  Returns a map containing mappings for which users or institutions have course build access to the project
  """
  def get_all_project_visibilities(project_id) do
    Repo.all from v in ProjectVisibility,
      where: v.project_id == ^project_id,
      left_join: author in Author, on: v.author_id == author.id,
      left_join: institution in Institution, on: v.institution_id == institution.id,
      select: %{
        visibility: v,
        author: author,
        institution: institution
      }
  end

end
