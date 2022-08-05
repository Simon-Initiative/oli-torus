defmodule Oli.Publishing do
  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Course.ProjectVisibility
  alias Oli.Accounts.Author
  alias Oli.Authoring.Locks
  alias Oli.Delivery.Sections.Section
  alias Oli.Authoring.Course.ProjectResource
  alias Oli.Resources.{Revision, ResourceType}

  alias Oli.Publishing.{
    Publication,
    PublishedResource,
    PartMappingRefreshAdapter,
    PartMappingRefreshAsync
  }

  alias Oli.Institutions.Institution
  alias Oli.Authoring.Clone
  alias Oli.Publishing
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Authoring.Authors.AuthorProject
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Groups

  @doc """
  Returns true if editing this revision requires the creation of a new revision first.

  A new revision is needed if there exists either:
  1. A published resource record with this revision ID that pertains to a published publication for this project
  2. A published resource record with this revision ID for a publication (published or not) for any other project.

  """
  def needs_new_revision_for_edit?(project_slug, resource_revision_id) do
    query =
      from pr in PublishedResource,
        join: pub in Publication,
        on: pr.publication_id == pub.id,
        join: proj in Project,
        on: proj.id == pub.project_id,
        where:
          (proj.slug != ^project_slug or
             (proj.slug == ^project_slug and not is_nil(pub.published))) and
            pr.revision_id == ^resource_revision_id,
        select: count(pr.id)

    Repo.one(query) > 0
  end

  def get_publication_id_for_resource(section_slug, resource_id) do
    spp =
      from(s in Section,
        join: spp in SectionsProjectsPublications,
        on: spp.section_id == s.id,
        join: pr in ProjectResource,
        on: pr.project_id == spp.project_id,
        where: s.slug == ^section_slug and pr.resource_id == ^resource_id,
        select: spp
      )
      |> Repo.all()
      |> hd

    spp.publication_id
  end

  def query_unpublished_revisions_by_type(project_slug, type) do
    publication_id = project_working_publication(project_slug).id
    resource_type_id = ResourceType.get_id_by_type(type)

    from rev in Revision,
      join: mapping in PublishedResource,
      on: mapping.revision_id == rev.id,
      distinct: rev.resource_id,
      where:
        mapping.publication_id == ^publication_id and
          rev.resource_type_id == ^resource_type_id and
          rev.deleted == false,
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

    Repo.all(
      from mapping in PublishedResource,
        join: rev in Revision,
        on: mapping.revision_id == rev.id,
        where:
          rev.resource_type_id == ^activity and mapping.publication_id == ^publication_id and
            mapping.resource_id in ^activity_ids,
        select: rev
    )
    |> Repo.preload(:activity_type)
  end

  # For a project, return the all the current revisions associated
  # with the unpublished publication for a list of resource_ids
  def get_unpublished_revisions(project, resource_ids) do
    project_id = project.id

    revisions =
      Repo.all(
        from m in Oli.Publishing.PublishedResource,
          join: rev in Revision,
          on: rev.id == m.revision_id,
          join: p in Oli.Publishing.Publication,
          on: p.id == m.publication_id,
          where:
            is_nil(p.published) and m.resource_id in ^resource_ids and
              p.project_id == ^project_id,
          select: rev
      )

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
  then it will only return publicly available publications.

  ## Examples
      iex> available_publications()
      [%Publication{}, ...]

      iex> available_publications(author, institution)
      [%Publication{}, ...]
  """
  def available_publications() do
    available_publications(nil, nil)
  end

  def available_publications(author, institution, include_global \\ true) do
    subquery =
      from t in Publication,
        select: max(t.id),
        where: not is_nil(t.published),
        group_by: t.project_id

    by_active_project =
      dynamic([pub, p, _, _], p.status == :active and pub.id in subquery(subquery))

    by_visibility =
      case {author, institution} do
        {nil, nil} ->
          dynamic([_, p, _], ^include_global and p.visibility == :global)

        {%Author{id: id}, nil} ->
          dynamic(
            [_, p, ap, v],
            (^include_global and p.visibility == :global) or ap.author_id == ^id or
              (p.visibility == :selected and v.author_id == ^id)
          )

        {nil, %Institution{id: id}} ->
          dynamic(
            [_, p, _, v],
            (^include_global and p.visibility == :global) or
              (p.visibility == :selected and v.institution_id == ^id)
          )

        {%Author{id: author_id}, %Institution{id: id}} ->
          dynamic(
            [_, p, ap, v],
            (^include_global and p.visibility == :global) or ap.author_id == ^author_id or
              (p.visibility == :selected and v.institution_id == ^id) or
              (p.visibility == :selected and v.author_id == ^author_id)
          )
      end

    query =
      Publication
      |> join(:left, [p, _], proj in Project, on: p.project_id == proj.id)
      |> join(:left, [_, p], a in AuthorProject, on: p.id == a.project_id)
      |> join(:left, [_, p, _], v in ProjectVisibility, on: v.project_id == p.id)
      |> where(^by_active_project)
      |> where(^by_visibility)
      |> preload([_, p, _, _], project: p)
      |> distinct([p, _, _, _], p.project_id)
      |> select([p, _, _, _], p)

    Repo.all(query)
  end

  @doc """
  Returns the list of all available publications.

  ## Examples
      iex> all_available_publications()
      [%Publication{}, ...]
  """
  def all_available_publications() do
    subquery =
      from t in Publication,
        select: %{project_id: t.project_id, max_date: max(t.published)},
        where: not is_nil(t.published),
        group_by: t.project_id

    query =
      from pub in Publication,
        join: u in subquery(subquery),
        on: pub.project_id == u.project_id and u.max_date == pub.published,
        join: proj in Project,
        on: pub.project_id == proj.id,
        where: not is_nil(pub.published) and proj.status == :active,
        preload: [:project],
        distinct: true,
        select: pub

    Repo.all(query)
  end

  @doc """
  Get all the available publications and products based on:
    - User's linked author
    - User's institution
    - User's permission to access global content

  ## Examples

      iex> list_available_publications_and_products(nil, nil, false)
      []

      iex> list_available_publications_and_products(123, 1, true)
      [{%Publication{project: %Project{}}, %Section{}}, ...]
  """
  def list_available_publications_and_products(nil, nil, false), do: []

  def list_available_publications_and_products(author, institution, include_global) do
    by_visibility =
      case {author, institution} do
        {nil, nil} ->
          dynamic([project, _, _, _, _, _], ^include_global and project.visibility == :global)

        {%Author{id: a_id}, nil} ->
          dynamic(
            [project, _, _, _, author, project_visibility],
            (^include_global and project.visibility == :global) or author.id == ^a_id or
              (project.visibility == :selected and project_visibility.author_id == ^a_id)
          )

        {nil, %Institution{id: i_id}} ->
          dynamic(
            [project, _, _, _, _, project_visibility],
            (^include_global and project.visibility == :global) or
              (project.visibility == :selected and project_visibility.institution_id == ^i_id)
          )

        {%Author{id: a_id}, %Institution{id: i_id}} ->
          dynamic(
            [project, _, _, _, author, project_visibility],
            (^include_global and project.visibility == :global) or author.id == ^a_id or
              (project.visibility == :selected and project_visibility.author_id == ^a_id) or
              (project.visibility == :selected and project_visibility.institution_id == ^i_id)
          )
      end

    from(
      project in Project,
      left_join: section in Section,
      on:
        project.id == section.base_project_id and section.type == :blueprint and
          section.status == :active,
      join: last_publication in subquery(last_publication_query()),
      on:
        last_publication.project_id == project.id or
          last_publication.project_id == section.base_project_id,
      join: publication in Publication,
      on: publication.id == last_publication.id,
      left_join: author in assoc(project, :authors),
      left_join: project_visibility in ProjectVisibility,
      on: project.id == project_visibility.project_id,
      where: not is_nil(publication.published) and project.status == :active,
      where: ^by_visibility,
      select: {%{publication | project: project}, section},
      distinct: true
    )
    |> Repo.all()
  end

  @doc """
  Retrieves all the publications a user can see:
    - Associated to a community assigned to their institution
    - Associated to a community they are assigned as a user
    - If they have a linked author account
      - They are an author of the publication
      - An author has made publication visible to their institution
      - Another author has shared publication with them
    - Global -> will see them when they are not associated to any community, or one of the associated communities allows it

  ## Examples

      iex> retrieve_visible_publications(%User{}, %Institution{})
      [%Publication{project: %Project{}}, ...]

      iex> retrieve_visible_publications(%User{}, %Institution{})
      []
  """
  def retrieve_visible_publications(user, institution) do
    (Groups.list_community_associated_publications(user.id, institution) ++
       available_publications(
         user.author,
         institution,
         can_access_global_content(user, institution)
       ))
    |> Enum.uniq()
    |> Enum.sort_by(fn r -> get_title(r) end, :asc)
  end

  @doc """
  Retrieves all the publications and products an user can see:
    - Associated to a community assigned to their institution
    - Associated to a community they are assigned as a user
    - If they have a linked author account
      - They are an author of the publication/product
      - An author has made publication/product visible to their institution
      - Another author has shared publication/product with them
    - Global -> will see them when they are not associated to any community, or one of the associated communities allows it

  ## Examples

      iex> retrieve_visible_sources(%User{}, %Institution{})
      [%Publication{project: %Project{}}, %Section{}, ...]

      iex> retrieve_visible_sources(%User{}, %Institution{})
      []
  """
  def retrieve_visible_sources(user, institution) do
    sources =
      Groups.list_community_associated_publications_and_products(user.id, institution) ++
        list_available_publications_and_products(
          user.author,
          institution,
          can_access_global_content(user, institution)
        )

    {publication_list, section_list} =
      Enum.reduce(
        sources,
        {[], []},
        fn
          {publication, nil}, {publication_list, section_list} ->
            {[publication | publication_list], section_list}

          {%Publication{project: nil}, section}, {publication_list, section_list} ->
            {publication_list, [section | section_list]}

          {publication, section}, {publication_list, section_list} ->
            {[publication | publication_list], [section | section_list]}
        end
      )

    filtered_publications =
      Blueprint.filter_for_free_projects(
        section_list,
        publication_list
      )

    (filtered_publications ++ section_list)
    |> Enum.uniq()
    |> Enum.sort_by(fn r -> get_title(r) end, :asc)
  end

  defp can_access_global_content(user, institution) do
    associated_communities = Groups.list_associated_communities(user.id, institution)

    associated_communities == [] or
      Enum.any?(associated_communities, fn community -> community.global_access end)
  end

  defp get_title(pub_or_prod) do
    case Map.get(pub_or_prod, :title) do
      nil -> pub_or_prod.project.title
      title -> title
    end
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
        where: p.project_id == ^project_id and is_nil(p.published),
        select: p.id
    )
  end

  def initial_publication_setup(project, resource, resource_revision) do
    Repo.transaction(fn ->
      with {:ok, publication} <-
             create_publication(%{
               project_id: project.id,
               root_resource_id: resource.id
             }),
           {:ok, published_resource} <-
             create_published_resource(%{
               publication_id: publication.id,
               resource_id: resource.id,
               revision_id: resource_revision.id
             }) do
        %{}
        |> Map.put(:publication, publication)
        |> Map.put(:published_resource, published_resource)
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Get unpublished publication for a project from slug. This assumes there is only one unpublished publication per project.
   ## Examples

      iex> project_working_publication("my-project-slug")
      %Publication{}

      iex> project_working_publication("invalid-slug")
      nil
  """
  def project_working_publication(project_slug) do
    Repo.one(
      from pub in Publication,
        join: proj in Project,
        on: pub.project_id == proj.id,
        where: proj.slug == ^project_slug and is_nil(pub.published),
        select: pub
    )
  end

  @doc """
  Gets the latest published publication for a project from slug.
   ## Examples

      iex> get_latest_published_publication_by_slug("my-project-slug")
      %Publication{}

      iex> get_latest_published_publication_by_slug("invalid-slug")
      nil
  """
  def get_latest_published_publication_by_slug(project_slug) do
    Repo.one(
      from pub in Publication,
        join: proj in Project,
        on: pub.project_id == proj.id,
        where: proj.slug == ^project_slug and not is_nil(pub.published),
        # secondary sort by id is required here to guarantee a deterministic latest record
        # (esp. important in unit tests where subsequent publications can be published instantly)
        order_by: [desc: pub.published, desc: pub.id],
        limit: 1,
        select: pub
    )
  end

  def last_publication_query(),
    do:
      from(p in Publication,
        select: %{id: max(p.id), project_id: p.project_id},
        where: not is_nil(p.published),
        group_by: p.project_id
      )

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

  def update_publication(
        %Publication{} = publication,
        attrs,
        adapter \\ refresh_adapter()
      ) do
    publication
    |> Publication.changeset(attrs)
    |> Repo.update()
    |> adapter.maybe_refresh_part_mapping()
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
    publication
    |> Repo.delete()
    |> refresh_adapter().maybe_refresh_part_mapping()
  end

  def get_published_objective_details(publication_id) do
    objective = ResourceType.get_id_by_type("objective")

    Repo.all(
      from mapping in PublishedResource,
        join: rev in Revision,
        on: mapping.revision_id == rev.id,
        where:
          rev.deleted == false and rev.resource_type_id == ^objective and
            mapping.publication_id == ^publication_id,
        select: map(rev, [:title, :resource_id, :children])
    )
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
  Returns the list of published_resources.
  ## Examples
      iex> list_published_resources()
      [%PublishedResource{}, ...]
  """
  def list_published_resources do
    Repo.all(PublishedResource)
  end

  @doc """
  Returns the list of published_resources for a given publication.

  ## Examples

      iex> get_published_resources_for_publication()
      [%PublishedResource{}, ...]

  """
  def get_published_resources_by_publication(publication_ids, opts \\ [])

  def get_published_resources_by_publication(publication_ids, opts)
      when is_list(publication_ids) do
    preload = Keyword.get(opts, :preload, [:resource, :revision, :publication])

    PublishedResource
    |> where([pr], pr.publication_id in ^publication_ids)
    |> maybe_preload(preload)
    |> Repo.all()
  end

  def get_published_resources_by_publication(publication_id, opts) do
    get_published_resources_by_publication([publication_id], opts)
  end

  defp maybe_preload(query, preload) do
    Enum.reduce(preload, query, fn rel_table, acc_query ->
      acc_query
      |> join(:left, [pr, ...], rel in assoc(pr, ^rel_table))
      |> preload([pr, ..., rel], [{^rel_table, rel}])
    end)
  end

  @doc """
  Returns a map of publication_id to published_resources for a given list of publication_ids,
  where published_resources are a map keyed by resource_id.

  ## Examples

      iex> get_published_resources_for_publications(publication_ids)
      %{1 => %{2 => %PublishedResource{resource_id: 2}, ...}, ...}

  """
  def get_published_resources_for_publications(publication_ids, opts \\ []) do
    get_published_resources_by_publication(publication_ids, opts)
    |> Enum.reduce(%{}, fn pr, acc ->
      prs_by_resource_id =
        case acc[pr.publication_id] do
          nil -> %{}
          map -> map
        end
        |> Map.put_new(pr.resource_id, pr)

      Map.put(acc, pr.publication_id, prs_by_resource_id)
    end)
  end

  def get_objective_mappings_by_publication(publication_id) do
    objective = ResourceType.get_id_by_type("objective")

    Repo.all(
      from mapping in PublishedResource,
        join: rev in Revision,
        on: mapping.revision_id == rev.id,
        where:
          rev.deleted == false and rev.resource_type_id == ^objective and
            mapping.publication_id == ^publication_id,
        select: mapping,
        preload: [:resource, :revision]
    )
  end

  @doc """
  Gets a single published_resource.
  Raises `Ecto.NoResultsError` if the Resource mapping does not exist.
  ## Examples
      iex> get_published_resource!(123)
      %PublishedResource{}
      iex> get_published_resource!(456)
      ** (Ecto.NoResultsError)
  """
  def get_published_resource!(id), do: Repo.get!(PublishedResource, id)

  def get_published_resource!(publication_id, resource_id) do
    Repo.one!(
      from p in PublishedResource,
        where: p.publication_id == ^publication_id and p.resource_id == ^resource_id
    )
  end

  def get_published_resource(publication_id, resource_ids) when is_list(resource_ids) do
    Repo.all(
      from p in PublishedResource,
        where: p.publication_id == ^publication_id and p.resource_id in ^resource_ids
    )
  end

  def get_published_resource(publication_id, resource_id) do
    Repo.one(
      from p in PublishedResource,
        where: p.publication_id == ^publication_id and p.resource_id == ^resource_id
    )
  end

  @doc """
  Creates a new, or updates the existing published resource
  for the given publication and revision.
  """
  def upsert_published_resource(%Publication{} = publication, revision) do
    case get_published_resource(publication.id, revision.resource_id) do
      nil ->
        create_published_resource(%{
          publication_id: publication.id,
          resource_id: revision.resource_id,
          revision_id: revision.id
        })

      mapping ->
        update_published_resource(mapping, %{
          resource_id: revision.resource_id,
          revision_id: revision.id
        })
    end
  end

  def publish_new_revision(previous_revision, changes, publication, author_id) do
    changes = Map.merge(changes, %{author_id: author_id})

    {:ok, revision} = Oli.Resources.create_revision_from_previous(previous_revision, changes)
    {:ok, _} = upsert_published_resource(publication, revision)

    revision
  end

  @doc """
  Creates a published_resource.
  ## Examples
      iex> create_published_resource(%{field: value})
      {:ok, %PublishedResource{}}
      iex> create_published_resource(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_published_resource(attrs \\ %{}) do
    %PublishedResource{}
    |> PublishedResource.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a published_resource.
  ## Examples
      iex> update_published_resource(published_resource, %{field: new_value})
      {:ok, %PublishedResource{}}
      iex> update_published_resource(published_resource, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_published_resource(%PublishedResource{} = published_resource, attrs) do
    published_resource
    |> PublishedResource.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking published_resource changes.
  ## Examples
      iex> change_published_resource(published_resource)
      %Ecto.Changeset{source: %PublishedResource{}}
  """
  def change_published_resource(%PublishedResource{} = published_resource, attrs \\ %{}) do
    PublishedResource.changeset(published_resource, attrs)
  end

  @doc """
  Deletes a published_resource.
  ## Examples
      iex> delete_published_resource(published_resource)
      {:ok, %PublishedResource{}}
      iex> delete_published_resource(published_resource)
      {:error, %Ecto.Changeset{}}
  """
  def delete_published_resource(%PublishedResource{} = published_resource) do
    Repo.delete(published_resource)
  end

  @doc """
  Returns the revision that pertains to a given publication and a resource id.
  """
  def get_published_revision(publication_id, resource_id) do
    Repo.one(
      from mapping in PublishedResource,
        join: rev in Revision,
        on: mapping.revision_id == rev.id,
        where: mapping.resource_id == ^resource_id and mapping.publication_id == ^publication_id,
        select: rev
    )
  end

  @doc """
  Publishes the active publication and creates a new working unpublished publication for a project.
  Returns the published publication

  ## Examples

      iex> publish_project(project)
      {:ok, %Publication{}}
  """
  @spec publish_project(%Project{}, String.t(), PartMappingRefreshAdapter | nil) ::
          {:error, String.t()} | {:ok, %Publication{}}
  def publish_project(project, description, refresh_adapter \\ refresh_adapter()) do
    Repo.transaction(fn ->
      with active_publication <- project_working_publication(project.slug),
           latest_published_publication <-
             Publishing.get_latest_published_publication_by_slug(project.slug),
           now <- DateTime.utc_now(),

           # diff publications to determine the new version number
           {{_, {edition, major, minor}}, _changes} <-
             diff_publications(latest_published_publication, active_publication),

           # create a new publication to capture all further edits
           {:ok, new_publication} <-
             create_publication(%{
               root_resource_id: active_publication.root_resource_id,
               project_id: active_publication.project_id
             }),

           # Locks must be released so that users who have acquired a resource lock
           # will be forced to re-acquire the lock with the new publication and
           # create a new revision under that publication
           _ <- Locks.release_all(active_publication.id),

           # clone mappings for resources, activities, and objectives. This removes
           # all active locks, forcing the user to refresh the page to re-acquire the lock.
           _ <- Clone.clone_all_published_resources(active_publication.id, new_publication.id),

           # set the active publication to published
           {:ok, publication} <-
             update_publication(
               active_publication,
               %{
                 published: now,
                 description: description,
                 edition: edition,
                 major: major,
                 minor: minor
               },
               refresh_adapter
             ) do
        Oli.Authoring.Broadcaster.broadcast_publication(publication, project.slug)

        publication
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  def get_all_mappings_for_resource(resource_id, project_slug) do
    Repo.all(
      from mapping in PublishedResource,
        join: p in Publication,
        on: mapping.publication_id == p.id,
        join: project in Project,
        on: p.project_id == project.id,
        where: mapping.resource_id == ^resource_id and project.slug == ^project_slug,
        select: mapping,
        preload: [:publication, :revision]
    )
  end

  @doc """
  Diff two publications of the same project and returns an overall change status (:major|:minor|:no_changes)
  with a version number and a map that contains any changes where the key is the resource id which points to
  a tuple with the first element being the change status (:changed|:added|:deleted) and the second is a
  map containing the resource and revision e.g. {:changed, %{resource: res_p2, revision: rev_p2}}

  ## Examples

      iex> diff_publications(publication1, publication2)
      {{:major, {0, 1, 0}}, %{
        23 => {:changed, %{resource: res1, revision: rev1}}
        24 => {:added, %{resource: res2, revision: rev2}}
        24 => {:added, %{resource: res3, revision: rev3}}
        24 => {:deleted, %{resource: res4, revision: rev4}}
      }}

      iex> diff_publications(publication2, publication3)
      {{:minor, {0, 0, 1}}, %{
        23 => {:changed, %{resource: res1, revision: rev1}}
        24 => {:changed, %{resource: res2, revision: rev2}}
      }}

      iex> diff_publications(publication1, publication1)
      {:no_changes, %{}}
  """
  def diff_publications(p1, p2) do
    all_resource_revisions_p1 = get_resource_revisions_for_publication(p1)
    all_resource_revisions_p2 = get_resource_revisions_for_publication(p2)

    # go through every resource in p1 to identify any resources that are identical, changed, or deleted in p2
    {visited, changes} =
      Map.keys(all_resource_revisions_p1)
      |> Enum.reduce({%{}, %{}}, fn id, {visited, acc} ->
        if Map.has_key?(all_resource_revisions_p2, id) do
          {_res_p1, rev_p1} = all_resource_revisions_p1[id]
          {res_p2, rev_p2} = all_resource_revisions_p2[id]

          # if the resource revision has changed, add it to the change tracker
          if rev_p1.id != rev_p2.id do
            {Map.put(visited, id, true),
             Map.put_new(acc, id, {:changed, %{resource: res_p2, revision: rev_p2}})}
          else
            {Map.put(visited, id, true), acc}
          end
        else
          {res_p1, rev_p1} = all_resource_revisions_p1[id]
          {visited, Map.put_new(acc, id, {:deleted, %{resource: res_p1, revision: rev_p1}})}
        end
      end)

    # go through every resource in p2 that wasn't in p1 to identify new resources
    changes =
      Map.keys(all_resource_revisions_p2)
      |> Enum.filter(fn id -> !Map.has_key?(visited, id) end)
      |> Enum.reduce(changes, fn id, acc ->
        {res_p2, rev_p2} = all_resource_revisions_p2[id]
        Map.put_new(acc, id, {:added, %{resource: res_p2, revision: rev_p2}})
      end)

    {edition, major, minor} =
      case p1 do
        nil ->
          {0, 0, 0}

        p1 ->
          {p1.edition, p1.major, p1.minor}
      end

    {version_change(changes, {edition, major, minor}), changes}
  end

  # classify the changes as either :major, :minor, or :no_changes and return the new version number
  # result e.g. {:major, {1, 0}}
  defp version_change(changes, {edition, major, minor} = _current_version) do
    changes
    |> Enum.reduce({:no_changes, {edition, major, minor}}, fn {_id,
                                                               {_type,
                                                                %{resource: _res, revision: rev}}},
                                                              {previous, _} = acc ->
      resource_type = Oli.Resources.ResourceType.get_type_by_id(rev.resource_type_id)

      cond do
        # if a container resource has changed, return major
        resource_type == "container" ->
          {:major, {edition, major + 1, 0}}

        # if any other type of change occurred and none of the previous were major
        previous != :major ->
          {:minor, {edition, major, minor + 1}}

        # otherwise, continue with the existing classification
        true ->
          acc
      end
    end)
  end

  def get_published_revisions(publication) do
    get_published_resources_by_publication(publication.id)
    |> Enum.map(&Map.get(&1, :revision))
  end

  @doc """
  Returns a map of resource ids to {resource, revision} tuples for a publication

  ## Examples
      iex> get_resource_revisions_for_publication(123)
      %{124 => [{%Resource{}, %Revision{}}], ...}
  """
  def get_resource_revisions_for_publication(publication) do
    case publication do
      nil ->
        %{}

      publication ->
        published_resources = get_published_resources_by_publication(publication.id)

        # filter out revisions that are marked as deleted, then convert
        # to a map of resource_ids to {resource, revision} tuples
        published_resources
        |> Enum.filter(fn mapping -> mapping.revision.deleted == false end)
        |> Enum.reduce(%{}, fn m, acc ->
          Map.put_new(acc, m.resource_id, {m.resource, m.revision})
        end)
    end
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
    scope: the scope of the activity
  }
  """
  def find_objective_attachments(resource_id, publication_id) do
    page_id = ResourceType.get_id_by_type("page")
    activity_id = ResourceType.get_id_by_type("activity")

    sql = """
    select
      revisions.scope, revisions.id, revisions.resource_id, revisions.title, revisions.slug, part
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

    {:ok, %{rows: results}} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

    results
    |> Enum.map(fn [scope, id, resource_id, title, slug, part] ->
      %{
        id: id,
        resource_id: resource_id,
        title: title,
        slug: slug,
        part: part,
        scope: scope
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
    Repo.all(
      from mapping in PublishedResource,
        where: mapping.publication_id == ^publication_id and mapping.resource_id in ^resource_ids,
        select: mapping,
        preload: [:author]
    )
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

    sql = """
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

    {:ok, %{rows: results}} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

    Enum.filter(results, fn [_, _, %{"activity_id" => activity_id}] ->
      MapSet.member?(activities, activity_id)
    end)
    |> Enum.reduce(%{}, fn [id, slug, %{"activity_id" => activity_id}], map ->
      Map.put(map, activity_id, %{slug: slug, id: id})
    end)
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
    Repo.all(
      from v in ProjectVisibility,
        where: v.project_id == ^project_id,
        left_join: author in Author,
        on: v.author_id == author.id,
        left_join: institution in Institution,
        on: v.institution_id == institution.id,
        select: %{
          visibility: v,
          author: author,
          institution: institution
        }
    )
  end

  def find_objective_in_selections(objective_id, publication_id) do
    page_id = ResourceType.get_id_by_type("page")

    sql = """
    select rev.slug, rev.title
    from published_resources as mapping
    join revisions as rev
    on mapping.revision_id = rev.id
    where mapping.publication_id = #{publication_id}
      and rev.resource_type_id = #{page_id}
      and rev.deleted is false
      and jsonb_path_exists(rev.content, '$.**.conditions.** ? (@.fact == "objectives").value ? (@ == #{objective_id})')
    """

    {:ok, %{rows: results}} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

    Enum.map(results, fn [slug, title] -> %{slug: slug, title: title} end)
  end

  @spec refresh_adapter() :: PartMappingRefreshAdapter
  defp refresh_adapter() do
    :oli
    |> Application.get_env(Oli.Publishing)
    |> Keyword.get(:refresh_adapter, PartMappingRefreshAsync)
  end
end
