defmodule Oli.Delivery.Sections do
  @moduledoc """
  The Sections context.
  """
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Enrollment
  alias Lti_1p3.Tool.ContextRole
  alias Lti_1p3.DataProviders.EctoProvider
  alias Oli.Lti_1p3.Tool.Deployment
  alias Oli.Lti_1p3.Tool.Registration
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Publishing
  alias Oli.Publishing.Publication
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Resources.Numbering
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.ResourceType
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Revision
  alias Oli.Publishing.PublishedResource
  alias Oli.Accounts.User
  alias Lti_1p3.Tool.ContextRoles
  alias Lti_1p3.Tool.PlatformRoles
  alias Oli.Delivery.Updates.Broadcaster
  alias Oli.Delivery.Sections.EnrollmentBrowseOptions

  require Logger

  def browse_enrollments(
        %Section{id: section_id},
        %Paging{limit: limit, offset: offset},
        %Sorting{field: field, direction: direction},
        %EnrollmentBrowseOptions{} = options
      ) do
    instructor_role_id = ContextRoles.get_role(:context_instructor).id

    filter_by_role =
      case options do
        %EnrollmentBrowseOptions{is_student: true} ->
          dynamic(
            [e, u],
            fragment(
              "(NOT EXISTS (SELECT 1 FROM enrollments_context_roles r WHERE r.enrollment_id = ? AND r.context_role_id = ?))",
              e.id,
              ^instructor_role_id
            )
          )

        %EnrollmentBrowseOptions{is_instructor: true} ->
          dynamic(
            [e, u],
            fragment(
              "(EXISTS (SELECT 1 FROM enrollments_context_roles r WHERE r.enrollment_id = ? AND r.context_role_id = ?))",
              e.id,
              ^instructor_role_id
            )
          )

        _ ->
          true
      end

    filter_by_text =
      if options.text_search == "" or is_nil(options.text_search) do
        true
      else
        dynamic(
          [_, s],
          ilike(s.name, ^"%#{options.text_search}%") or
            ilike(s.email, ^"%#{options.text_search}%") or
            ilike(s.given_name, ^"%#{options.text_search}%") or
            ilike(s.family_name, ^"%#{options.text_search}%") or
            ilike(s.name, ^"#{options.text_search}") or
            ilike(s.email, ^"#{options.text_search}") or
            ilike(s.given_name, ^"#{options.text_search}") or
            ilike(s.family_name, ^"#{options.text_search}")
        )
      end

    query =
      Enrollment
      |> join(:left, [e], u in User, on: u.id == e.user_id)
      |> join(:left, [e, _], p in "payments", on: p.enrollment_id == e.id)
      |> where(^filter_by_text)
      |> where(^filter_by_role)
      |> where([e, _], e.section_id == ^section_id)
      |> limit(^limit)
      |> offset(^offset)
      |> group_by([e, u, p], [e.id, u.id, p.id])
      |> select([_, u], u)
      |> select_merge([e, _, p], %{
        total_count: fragment("count(*) OVER()"),
        enrollment_date: e.inserted_at,
        payment_date: p.application_date,
        payment_id: p.id
      })

    query =
      case field do
        :enrollment_date -> order_by(query, [e, _, _], {^direction, e.inserted_at})
        _ -> order_by(query, [_, u, _], {^direction, field(u, ^field)})
      end

    Repo.all(query)
  end

  @doc """
  Determines if a user is an instructor in a given section.
  """
  def is_instructor?(nil, _) do
    false
  end

  def is_instructor?(%User{id: id} = user, section_slug) do
    is_enrolled?(id, section_slug) && has_instructor_role?(user, section_slug)
  end

  @doc """
  Determines if user has instructor role.
  """
  def has_instructor_role?(%User{} = user, section_slug) do
    ContextRoles.has_role?(
      user,
      section_slug,
      ContextRoles.get_role(:context_instructor)
    )
  end

  @doc """
  Determines if a user is a platform (institution) instructor.
  """
  def is_institution_instructor?(%User{} = user) do
    PlatformRoles.has_roles?(
      Repo.preload(user, :platform_roles),
      [
        PlatformRoles.get_role(:institution_instructor)
      ],
      :any
    )
  end

  @doc """
  Can a user create independent, enrollable sections through OLI's LMS?
  (user has the institution instructor platform role and user.can_create_sections is true)
  """
  def is_independent_instructor?(%User{} = user) do
    is_institution_instructor?(user) && user.can_create_sections
  end

  @doc """
  Determines if a user is an administrator in a given section.
  """
  def is_admin?(nil, _) do
    false
  end

  def is_admin?(%User{} = user, section_slug) do
    PlatformRoles.has_roles?(
      user,
      [
        PlatformRoles.get_role(:system_administrator),
        PlatformRoles.get_role(:institution_administrator)
      ],
      :any
    ) ||
      ContextRoles.has_role?(user, section_slug, ContextRoles.get_role(:context_administrator))
  end

  @doc """
  Enrolls a user in a course section
  ## Examples
      iex> enroll(user_id, section_id, [%ContextRole{}])
      {:ok, %Enrollment{}} # Inserted or updated with success

      iex> enroll(user_id, section_id, :open_and_free)
      {:error, changeset} # Something went wrong
  """
  @spec enroll(number(), number(), [%ContextRole{}]) :: {:ok, %Enrollment{}}
  def enroll(user_id, section_id, context_roles) do
    context_roles = EctoProvider.Marshaler.to(context_roles)

    case Repo.one(
           from(e in Enrollment,
             preload: [:context_roles],
             where: e.user_id == ^user_id and e.section_id == ^section_id,
             select: e
           )
         ) do
      # Enrollment doesn't exist, we are creating it
      nil -> %Enrollment{user_id: user_id, section_id: section_id}
      # Enrollment exists, we are potentially just updating it
      e -> e
    end
    |> Enrollment.changeset(%{section_id: section_id})
    |> Ecto.Changeset.put_assoc(:context_roles, context_roles)
    |> Repo.insert_or_update()
  end

  @doc """
  Unenrolls a user from a section by removing the provided context roles. If no context roles are provided, no change is made. If all context roles are removed from the user, the enrollment is deleted.

  To unenroll a student, use unenrolle_learner/2
  """
  def unenroll(user_id, section_id, context_roles) do
    context_roles = EctoProvider.Marshaler.to(context_roles)

    case Repo.one(
           from(e in Enrollment,
             preload: [:context_roles],
             where: e.user_id == ^user_id and e.section_id == ^section_id,
             select: e
           )
         ) do
      nil ->
        # Enrollment not found
        {:error, nil}

      enrollment ->
        other_context_roles =
          Enum.filter(enrollment.context_roles, &(!Enum.member?(context_roles, &1)))

        if Enum.count(other_context_roles) == 0 do
          Repo.delete(enrollment)
        else
          enrollment
          |> Enrollment.changeset(%{section_id: section_id})
          |> Ecto.Changeset.put_assoc(:context_roles, other_context_roles)
          |> Repo.update()
        end
    end
  end

  @doc """
  Unenrolls a student from a section by removing the :context_learner role. If this is their only context_role, the enrollment is deleted.
  """
  def unenroll_learner(user_id, section_id) do
    unenroll(user_id, section_id, [ContextRoles.get_role(:context_learner)])
  end

  @doc """
  Determines if a particular user is enrolled in a section.

  """
  def is_enrolled?(user_id, section_slug) do
    query =
      from(
        e in Enrollment,
        join: s in Section,
        on: e.section_id == s.id,
        where: e.user_id == ^user_id and s.slug == ^section_slug and s.status != :deleted
      )

    case Repo.one(query) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Returns a listing of all enrollments for a given section.

  """
  def list_enrollments(section_slug) do
    query =
      from(
        e in Enrollment,
        join: s in Section,
        on: e.section_id == s.id,
        where: s.slug == ^section_slug and s.status != :deleted,
        preload: [:user, :context_roles],
        select: e
      )

    Repo.all(query)
  end

  def get_enrollment(section_slug, user_id) do
    query =
      from(
        e in Enrollment,
        join: s in Section,
        on: e.section_id == s.id,
        where: e.user_id == ^user_id and s.slug == ^section_slug and s.status != :deleted,
        select: e
      )

    Repo.one(query)
  end

  def update_enrollment(%Enrollment{} = e, attrs) do
    e
    |> Enrollment.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Returns a listing of all open and free sections for a given user.
  """
  def list_user_open_and_free_sections(%{id: user_id} = _user) do
    query =
      from(
        s in Section,
        join: e in Enrollment,
        on: e.section_id == s.id,
        where: e.user_id == ^user_id and s.open_and_free == true and s.status != :deleted,
        preload: [:base_project],
        select: s
      )

    Repo.all(query)
  end

  @doc """
  Returns the list of sections.
  ## Examples
      iex> list_sections()
      [%Section{}, ...]
  """
  def list_sections do
    Repo.all(Section)
  end

  @doc """
  List all sections of type blueprint.
  """
  def list_blueprint_sections do
    list_by_type(:blueprint)
  end

  @doc """
  List all sections of type enrollable.
  """
  def list_enrollable_sections do
    list_by_type(:enrollable)
  end

  defp list_by_type(type) do
    Repo.all(
      from(
        s in Section,
        where: s.type == ^type,
        select: s
      )
    )
  end

  @doc """
  Returns the list of open and free sections.
  ## Examples
      iex> list_open_and_free_sections()
      [%Section{}, ...]
  """
  def list_open_and_free_sections() do
    Repo.all(
      from(
        s in Section,
        where: s.open_and_free == true and s.status != :deleted,
        select: s
      )
    )
  end

  @doc """
  Gets a single section.
  Raises `Ecto.NoResultsError` if the Section does not exist.
  ## Examples
      iex> get_section!(123)
      %Section{}
      iex> get_section!(456)
      ** (Ecto.NoResultsError)
  """
  def get_section!(id), do: Repo.get!(Section, id)

  @doc """
  Gets a single section with preloaded associations.
  Raises `Ecto.NoResultsError` if the Section does not exist.
  ## Examples
      iex> get_section_preloaded!(123)
      %Section{}
      iex> get_section_preloaded!(456)
      ** (Ecto.NoResultsError)
  """
  def get_section_preloaded!(id) do
    from(s in Section,
      left_join: b in assoc(s, :brand),
      where: s.id == ^id,
      preload: [brand: b]
    )
    |> Repo.one!()
  end

  @doc """
  Gets a single section by query parameter
  ## Examples
      iex> get_section_by(slug: "123")
      %Section{}
      iex> get_section_by(slug: "111")
      nil
  """
  def get_section_by(clauses) do
    Repo.get_by(Section, clauses)
  end

  @doc """
  Gets a single section by slug and preloads associations
  ## Examples
      iex> get_section_by_slug"123")
      %Section{}
      iex> get_section_by_slug("111")
      nil
  """
  def get_section_by_slug(slug) do
    from(s in Section,
      left_join: b in assoc(s, :brand),
      left_join: d in assoc(s, :lti_1p3_deployment),
      left_join: r in assoc(d, :registration),
      left_join: i in assoc(d, :institution),
      left_join: default_brand in assoc(i, :default_brand),
      where: s.slug == ^slug,
      preload: [
        brand: b,
        lti_1p3_deployment: {d, institution: {i, default_brand: default_brand}}
      ]
    )
    |> Repo.one()
  end

  @doc """
  Gets a section using the given LTI params

  ## Examples
      iex> get_section_from_lti_params(lti_params)
      %Section{}
      iex> get_section_from_lti_params(lti_params)
      nil
  """
  def get_section_from_lti_params(lti_params) do
    context_id =
      Map.get(lti_params, "https://purl.imsglobal.org/spec/lti/claim/context")
      |> Map.get("id")

    issuer = lti_params["iss"]
    client_id = lti_params["aud"]

    Repo.all(
      from(s in Section,
        join: d in Deployment,
        on: s.lti_1p3_deployment_id == d.id,
        join: r in Registration,
        on: d.registration_id == r.id,
        where:
          s.context_id == ^context_id and s.status != :deleted and r.issuer == ^issuer and
            r.client_id == ^client_id,
        order_by: [asc: :id],
        limit: 1,
        select: s
      )
    )
    |> one_or_warn(context_id)
  end

  defp one_or_warn(result, context_id) do
    case result do
      [] ->
        nil

      [first] ->
        first

      [first | _] ->
        Logger.warn("More than one active section was returned for context_id #{context_id}")

        first
    end
  end

  @doc """
  Gets the associated deployment and registration from the given section

  ## Examples
      iex> get_deployment_registration_from_section(section)
      {%Deployment{}, %Registration{}}
      iex> get_deployment_registration_from_section(section)
      nil
  """
  def get_deployment_registration_from_section(%Section{
        lti_1p3_deployment_id: lti_1p3_deployment_id
      }) do
    Repo.one(
      from(d in Deployment,
        join: r in Registration,
        on: d.registration_id == r.id,
        where: ^lti_1p3_deployment_id == d.id,
        select: {d, r}
      )
    )
  end

  @doc """
  Gets all sections that use a particular publication

  ## Examples
      iex> get_sections_by_publication("123")
      [%Section{}, ...]

      iex> get_sections_by_publication("456")
      ** (Ecto.NoResultsError)
  """
  def get_sections_by_publication(publication) do
    from(s in Section,
      join: spp in SectionsProjectsPublications,
      on: s.id == spp.section_id,
      where: spp.publication_id == ^publication.id and s.status != :deleted
    )
    |> Repo.all()
  end

  @doc """
  Gets all sections that use a particular base project

  ## Examples
      iex> get_sections_by_base_project(project)
      [%Section{}, ...]

      iex> get_sections_by_base_project(invalid_project)
      ** (Ecto.NoResultsError)
  """
  def get_sections_by_base_project(project) do
    from(s in Section, where: s.base_project_id == ^project.id and s.status != :deleted)
    |> Repo.all()
  end

  @doc """
  Creates a section resource.
  ## Examples
      iex> create_section_resource(%{field: value})
      {:ok, %SectionResource{}}
      iex> create_section_resource(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_section_resource(attrs \\ %{}) do
    %SectionResource{}
    |> SectionResource.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a section resource.
  ## Examples
      iex> update_section_resource(section, %{field: new_value})
      {:ok, %SectionResource{}}
      iex> update_section_resource(section, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_section_resource(%SectionResource{} = section, attrs) do
    section
    |> SectionResource.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a section projects publication record.
  ## Examples
      iex> create_section_project_publication(%{field: value})
      {:ok, %SectionsProjectsPublications{}}
      iex> create_section_project_publication(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_section_project_publication(attrs \\ %{}) do
    %SectionsProjectsPublications{}
    |> SectionsProjectsPublications.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a section.
  ## Examples
      iex> create_section(%{field: value})
      {:ok, %Section{}}
      iex> create_section(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_section(attrs \\ %{}) do
    %Section{}
    |> Section.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a section.
  ## Examples
      iex> update_section(section, %{field: new_value})
      {:ok, %Section{}}
      iex> update_section(section, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_section(%Section{} = section, attrs) do
    section
    |> Section.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a section by marking the record as deleted.
  ## Examples
      iex> soft_delete_section(section)
      {:ok, %Section{}}
      iex> soft_delete_section(section)
      {:error, %Ecto.Changeset{}}
  """
  def soft_delete_section(%Section{} = section) do
    update_section(section, %{status: :deleted})
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking section changes.
  ## Examples
      iex> change_section(section)
      %Ecto.Changeset{source: %Section{}}
  """
  def change_section(%Section{} = section, attrs \\ %{}) do
    Section.changeset(section, attrs)
  end

  def change_independent_learner_section(%Section{} = section, attrs \\ %{}) do
    change_section(Map.merge(section, %{open_and_free: true, requires_enrollment: true}), attrs)
  end

  def change_open_and_free_section(%Section{} = section, attrs \\ %{}) do
    change_section(Map.merge(section, %{open_and_free: true}), attrs)
  end

  @doc """
  Create all section resources from the given section and publication using the
  root resource's revision tree. Returns the root section resource record.
  ## Examples
      iex> create_section_resources(section)
      {:ok, %Section{}}
  """
  def create_section_resources(
        %Section{} = section,
        %Publication{
          id: publication_id,
          root_resource_id: root_resource_id,
          project_id: project_id
        } = publication
      ) do
    Repo.transaction(fn ->
      published_resources_by_resource_id = published_resources_map(publication.id)

      numbering_tracker = Numbering.init_numbering_tracker()
      level = 0
      processed_ids = []

      %PublishedResource{revision: root_revision} =
        published_resources_by_resource_id[root_resource_id]

      {root_section_resource_id, _numbering_tracker, processed_ids} =
        create_section_resource(
          section,
          publication,
          published_resources_by_resource_id,
          processed_ids,
          root_revision,
          level,
          numbering_tracker
        )

      processed_ids = [root_resource_id | processed_ids]

      # create any remaining section resources which are not in the hierarchy
      create_nonstructural_section_resources(section.id, [publication_id],
        skip_resource_ids: processed_ids
      )

      update_section(section, %{root_section_resource_id: root_section_resource_id})
      |> case do
        {:ok, section} ->
          add_source_project(section, project_id, publication_id)

          Repo.preload(section, [:root_section_resource, :section_project_publications])

        e ->
          e
      end
    end)
  end

  # This function constructs a section resource record by recursively calling itself on all the
  # children for the revision, then inserting the resulting struct into the database and returning its id.
  # This may not be the most efficient way of doing this but it seems to be the only way to create the records
  # in one go, otherwise section record creation then constructing relationships by updating the children
  # for each record would have to be two separate traversals
  defp create_section_resource(
         section,
         publication,
         published_resources_by_resource_id,
         processed_ids,
         revision,
         level,
         numbering_tracker
       ) do
    {numbering_index, numbering_tracker} =
      Numbering.next_index(numbering_tracker, level, revision)

    {children, numbering_tracker, processed_ids} =
      Enum.reduce(
        revision.children,
        {[], numbering_tracker, processed_ids},
        fn resource_id, {children_ids, numbering_tracker, processed_ids} ->
          %PublishedResource{revision: child} = published_resources_by_resource_id[resource_id]

          {id, numbering_tracker, processed_ids} =
            create_section_resource(
              section,
              publication,
              published_resources_by_resource_id,
              processed_ids,
              child,
              level + 1,
              numbering_tracker
            )

          {[id | children_ids], numbering_tracker, [resource_id | processed_ids]}
        end
      )
      # it's more efficient to append to list using [id | children_ids] and
      # then reverse than to concat on every reduce call using ++
      |> then(fn {children, numbering_tracker, processed_ids} ->
        {Enum.reverse(children), numbering_tracker, processed_ids}
      end)

    %SectionResource{id: section_resource_id} =
      Oli.Repo.insert!(%SectionResource{
        numbering_index: numbering_index,
        numbering_level: level,
        children: children,
        slug: Oli.Utils.Slug.generate(:section_resources, revision.title),
        resource_id: revision.resource_id,
        project_id: publication.project_id,
        section_id: section.id
      })

    {section_resource_id, numbering_tracker, processed_ids}
  end

  def rebuild_section_resources(
        section: %Section{id: section_id} = section,
        publication: publication
      ) do
    section
    |> Section.changeset(%{root_section_resource_id: nil})
    |> Repo.update!()

    from(sr in SectionResource,
      where: sr.section_id == ^section_id
    )
    |> Repo.delete_all()

    from(spp in SectionsProjectsPublications,
      where: spp.section_id == ^section_id
    )
    |> Repo.delete_all()

    create_section_resources(section, publication)
  end

  @doc """
  Returns a map of project_id to the latest available publication for that project
  if a newer publication is available.
  """
  def check_for_available_publication_updates(%Section{id: section_id}) do
    from(spp in SectionsProjectsPublications,
      as: :spp,
      where: spp.section_id == ^section_id,
      join: current_pub in Publication,
      on: current_pub.id == spp.publication_id,
      join: proj in Project,
      on: proj.id == spp.project_id,
      inner_lateral_join:
        latest_pub in subquery(
          from(p in Publication,
            where: p.project_id == parent_as(:spp).project_id and not is_nil(p.published),
            group_by: p.id,
            # secondary sort by id is required here to guarantee a deterministic latest record
            # (esp. important in unit tests where subsequent publications can be published instantly)
            order_by: [desc: p.published, desc: p.id],
            limit: 1
          )
        ),
      preload: [:project],
      select: {spp, current_pub, latest_pub}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn {spp, current_pub, latest_pub}, acc ->
      if current_pub.id != latest_pub.id do
        latest_pub =
          latest_pub
          |> Map.put(:project, spp.project)

        Map.put(acc, spp.project_id, latest_pub)
      else
        acc
      end
    end)
  end

  @doc """
  Returns a map of publication ids as keys for which updates are in progress for the
  given section

  ## Examples
      iex> check_for_updates_in_progress(section)
      %{1 => true, 3 => true}
  """
  def check_for_updates_in_progress(%Section{slug: section_slug}) do
    Oban.Job
    |> where([j], j.state in ["available", "executing", "scheduled"])
    |> where([j], j.queue == "updates")
    |> where([j], fragment("?->>'section_slug' = ?", j.args, ^section_slug))
    |> Repo.all()
    |> Enum.reduce(%{}, fn %Oban.Job{args: %{"publication_id" => publication_id}}, acc ->
      Map.put_new(acc, publication_id, true)
    end)
  end

  @doc """
  Adds a source project to the section pinned to the specified publication.
  """
  def add_source_project(section, project_id, publication_id) do
    # create a section project publication association
    Ecto.build_assoc(section, :section_project_publications, %{
      project_id: project_id,
      publication_id: publication_id
    })
    |> Repo.insert!()
  end

  def get_current_publication(section_id, project_id) do
    from(spp in SectionsProjectsPublications,
      join: pub in Publication,
      on: spp.publication_id == pub.id,
      where: spp.section_id == ^section_id and spp.project_id == ^project_id,
      select: pub
    )
    |> Repo.one!()
  end

  @doc """
  Updates a single project in a section to use the specified publication
  """
  def update_section_project_publication(
        %Section{id: section_id},
        project_id,
        publication_id
      ) do
    from(spp in SectionsProjectsPublications,
      where: spp.section_id == ^section_id and spp.project_id == ^project_id
    )
    |> Repo.update_all(set: [publication_id: publication_id])
  end

  @doc """
  Rebuilds a section curriculum by upserting any new or existing section resources
  and removing any deleted section resources based on the given hierarchy. Also updates
  the project publication mappings based on the given project_publications map.

  project_publications is a map of the project id to the pinned publication for the section.
  %{1 => %Publication{project_id: 1, ...}, ...}
  """
  def rebuild_section_curriculum(
        %Section{id: section_id},
        %HierarchyNode{} = hierarchy,
        project_publications
      ) do
    Repo.transaction(fn ->
      previous_section_resource_ids =
        from(sr in SectionResource,
          where: sr.section_id == ^section_id,
          select: sr.id
        )
        |> Repo.all()

      # ensure there are no duplicate resources so as to not violate the
      # section_resource [section_id, resource_id] database constraint
      hierarchy = Hierarchy.purge_duplicate_resources(hierarchy)

      # ensure hierarchy numberings are all up to date
      {hierarchy, _numberings} = Numbering.renumber_hierarchy(hierarchy)

      # generate a new set of section resources based on the hierarchy
      {section_resources, _} = collapse_section_hierarchy(hierarchy, section_id)

      # upsert all hierarchical section resources. some of these records will have
      # just been created, but that's okay we will just update them again
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      placeholders = %{timestamp: now}

      section_resources
      |> Enum.map(fn section_resource ->
        %{
          SectionResource.to_map(section_resource)
          | inserted_at: {:placeholder, :timestamp},
            updated_at: {:placeholder, :timestamp}
        }
      end)
      |> then(
        &Repo.insert_all(SectionResource, &1,
          placeholders: placeholders,
          on_conflict: {:replace_all_except, [:inserted_at]},
          conflict_target: [:section_id, :resource_id]
        )
      )

      # cleanup any deleted or non-hierarchical section resources
      processed_section_resources_by_id =
        section_resources
        |> Enum.reduce(%{}, fn sr, acc -> Map.put_new(acc, sr.id, sr) end)

      section_resource_ids_to_delete =
        previous_section_resource_ids
        |> Enum.filter(fn sr_id -> !Map.has_key?(processed_section_resources_by_id, sr_id) end)

      from(sr in SectionResource,
        where: sr.id in ^section_resource_ids_to_delete
      )
      |> Repo.delete_all()

      # upsert section project publications ensure section project publication mappings are up to date
      project_publications
      |> Enum.map(fn {project_id, pub} ->
        %{
          section_id: section_id,
          project_id: project_id,
          publication_id: pub.id,
          inserted_at: {:placeholder, :timestamp},
          updated_at: {:placeholder, :timestamp}
        }
      end)
      |> then(
        &Repo.insert_all(SectionsProjectsPublications, &1,
          placeholders: placeholders,
          on_conflict: {:replace_all_except, [:inserted_at]},
          conflict_target: [:section_id, :project_id]
        )
      )

      # cleanup any unused project publication mappings
      section_project_ids =
        section_resources
        |> Enum.reduce(%{}, fn sr, acc ->
          Map.put_new(acc, sr.project_id, true)
        end)
        |> Enum.map(fn {project_id, _} -> project_id end)

      from(spp in SectionsProjectsPublications,
        where: spp.section_id == ^section_id and spp.project_id not in ^section_project_ids
      )
      |> Repo.delete_all()

      # finally, create all non-hierarchical section resources for all projects used in the section
      publication_ids =
        section_project_ids
        |> Enum.map(fn project_id ->
          project_publications[project_id]
          |> then(fn %{id: publication_id} -> publication_id end)
        end)

      processed_resource_ids =
        processed_section_resources_by_id
        |> Enum.map(fn {_id, %{resource_id: resource_id}} -> resource_id end)

      create_nonstructural_section_resources(section_id, publication_ids,
        skip_resource_ids: processed_resource_ids
      )

      section_resources
    end)
  end

  @doc """
  Gracefully applies the specified publication update to a given section by leaving the existing
  curriculum and section modifications in-tact while applying the structural changes that
  occurred between the old and new publication.

  This implementation makes the assumption that a resource_id is unique within a curriculum.
  That is, a resource can only allowed to be added once in a single location within a curriculum.
  This makes it simpler to apply changes to the existing curriculum but if necessary, this implementation
  could be extended to not just apply the changes to the first node found that contains the changed resource,
  but any/all nodes in the hierarchy which reference the changed resource.
  """
  def apply_publication_update(
        %Section{id: section_id} = section,
        publication_id
      ) do
    Broadcaster.broadcast_update_progress(section.id, publication_id, 0)

    new_publication = Publishing.get_publication!(publication_id)
    project_id = new_publication.project_id
    current_publication = get_current_publication(section_id, project_id)
    current_hierarchy = DeliveryResolver.full_hierarchy(section.slug)

    # generate a diff between the old and new publication
    result =
      case Publishing.diff_publications(current_publication, new_publication) do
        {{:minor, _version}, _diff} ->
          # changes are minor, all we need to do is update the spp record and
          # rebuild the section curriculum based on the current hierarchy
          update_section_project_publication(section, project_id, publication_id)

          project_publications = get_pinned_project_publications(section_id)
          rebuild_section_curriculum(section, current_hierarchy, project_publications)

          {:ok}

        {{:major, _version}, diff} ->
          Repo.transaction(fn ->
            # changes are major, update the spp record and use the diff to take a "best guess"
            # strategy for applying structural updates to an existing section's curriculum.
            # new items will in a container be appended to the container's children
            update_section_project_publication(section, project_id, publication_id)

            published_resources_by_resource_id = published_resources_map(new_publication.id)

            %PublishedResource{revision: root_revision} =
              published_resources_by_resource_id[new_publication.root_resource_id]

            new_hierarchy =
              Hierarchy.create_hierarchy(root_revision, published_resources_by_resource_id)

            processed_resource_ids = %{}

            {updated_hierarchy, _} =
              new_hierarchy
              |> Hierarchy.flatten_hierarchy()
              |> Enum.reduce(
                {current_hierarchy, processed_resource_ids},
                fn node, {hierarchy, processed_resource_ids} ->
                  maybe_process_added_or_changed_node(
                    {hierarchy, processed_resource_ids},
                    node,
                    diff,
                    new_hierarchy
                  )
                end
              )

            # rebuild the section curriculum based on the updated hierarchy
            project_publications = get_pinned_project_publications(section_id)
            rebuild_section_curriculum(section, updated_hierarchy, project_publications)
          end)
      end

    Broadcaster.broadcast_update_progress(section.id, publication_id, :complete)

    result
  end

  @doc """
  Returns a map of resource_id to published resource
  """
  def published_resources_map(publication_ids) when is_list(publication_ids) do
    Publishing.get_published_resources_by_publication(publication_ids,
      preload: [:resource, :revision, :publication]
    )
    |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.resource_id, r) end)
  end

  def published_resources_map(publication_id) do
    published_resources_map([publication_id])
  end

  @doc """
  Returns the map of project_id to publication of all the section's pinned project publications
  """
  def get_pinned_project_publications(section_id) do
    from(spp in SectionsProjectsPublications,
      as: :spp,
      where: spp.section_id == ^section_id,
      join: publication in Publication,
      on: publication.id == spp.publication_id,
      preload: [publication: :project],
      select: spp
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn spp, acc ->
      Map.put(acc, spp.project_id, spp.publication)
    end)
  end

  defp maybe_process_added_or_changed_node(
         {hierarchy, processed_resource_ids},
         %HierarchyNode{resource_id: resource_id} = node,
         diff,
         new_hierarchy
       ) do
    container = ResourceType.get_id_by_type("container")

    if Map.has_key?(processed_resource_ids, resource_id) do
      # already processed, skip and continue
      {hierarchy, processed_resource_ids}
    else
      # get change type from diff and process accordingly
      case diff[resource_id] do
        {:added, _} ->
          # find the current parent of the node, using the assumed to be unique resource_id (as mentioned above)
          current_parent = hierarchy_parent_node(hierarchy, new_hierarchy, resource_id)

          # handle the case where the parent doesnt exist in the hierarchy, for example
          # if the container was removed in remix
          case current_parent do
            nil ->
              {hierarchy, processed_resource_ids}

            parent ->
              parent = %HierarchyNode{parent | children: parent.children ++ [node]}

              # update the hierarchy
              hierarchy = Hierarchy.find_and_update_node(hierarchy, parent)

              # we now consider all descendants to be processed, so that we dont
              # process them again we add them to the filter
              processed_resource_ids = add_descendant_resource_ids(node, processed_resource_ids)

              {hierarchy, processed_resource_ids}
          end

        {:changed, %{revision: %Revision{resource_type_id: ^container}}} ->
          # container has changed, check to see if any children were deleted
          current_parent = hierarchy_node(hierarchy, resource_id)

          # handle the case where the parent doesnt exist in the hierarchy, for example
          # if the container was removed in remix
          case current_parent do
            nil ->
              {hierarchy, processed_resource_ids}

            parent ->
              Enum.reduce(
                parent.children,
                {hierarchy, processed_resource_ids},
                fn child, {hierarchy, processed_resource_ids} ->
                  # fetch the latest parent on every call, as it may have changed
                  parent = hierarchy_node(hierarchy, resource_id)

                  maybe_process_deleted_node(
                    {hierarchy, processed_resource_ids},
                    child,
                    parent,
                    diff
                  )
                end
              )
          end

        _ ->
          # page wasn't added or deleted, so it is non-structural and is covered by spp update
          {hierarchy, Map.put(processed_resource_ids, node.resource_id, true)}
      end
    end
  end

  defp maybe_process_deleted_node(
         {hierarchy, processed_resource_ids},
         %HierarchyNode{resource_id: resource_id} = node,
         %HierarchyNode{} = parent,
         diff
       ) do
    case diff[resource_id] do
      {:deleted, _} ->
        # remove child from from parent's children
        parent = %HierarchyNode{
          parent
          | children:
              Enum.filter(parent.children, fn c ->
                c.resource_id != resource_id
              end)
        }

        # update the hierarchy
        hierarchy = Hierarchy.find_and_update_node(hierarchy, parent)

        # we now consider all descendants to be processed, so that we dont process them again
        processed_resource_ids = add_descendant_resource_ids(node, processed_resource_ids)

        {hierarchy, processed_resource_ids}

      _ ->
        # not deleted, skip
        {hierarchy, processed_resource_ids}
    end
  end

  defp add_descendant_resource_ids(node, processed_resource_ids) do
    Hierarchy.flatten_hierarchy(node)
    |> Enum.reduce(processed_resource_ids, fn n, acc ->
      Map.put(acc, n.resource_id, true)
    end)
  end

  # finds the node in the hierarchy with the given resource id
  defp hierarchy_node(hierarchy, resource_id) do
    Hierarchy.find_in_hierarchy(
      hierarchy,
      fn %HierarchyNode{
           resource_id: node_resource_id
         } ->
        node_resource_id == resource_id
      end
    )
  end

  # finds the parent node of a resource id by looking up the parent resource in the
  # new hierarchy, then using that parent resource_id to get the node from the current hierarchy
  defp hierarchy_parent_node(current_hierarchy, new_hierarchy, resource_id) do
    new_hierarchy_parent = parent_node(new_hierarchy, resource_id)

    case new_hierarchy_parent do
      nil ->
        nil

      %{resource_id: new_hierarchy_parent_resource_id} ->
        hierarchy_node(current_hierarchy, new_hierarchy_parent_resource_id)
    end
  end

  # finds the parent node of the given resource id
  defp parent_node(hierarchy, resource_id) do
    container = ResourceType.get_id_by_type("container")

    Hierarchy.find_in_hierarchy(hierarchy, fn %HierarchyNode{revision: revision} ->
      # only search containers, skip pages and other resource types
      if revision.resource_type_id == container do
        resource_id in Enum.map(revision.children, & &1)
      else
        false
      end
    end)
  end

  # Takes a hierarchy node and a accumulator list of section resources and returns the
  # updated collapsed list of section resources
  defp collapse_section_hierarchy(
         %HierarchyNode{
           numbering: numbering,
           children: children,
           resource_id: resource_id,
           project_id: project_id,
           revision: revision,
           section_resource: section_resource
         },
         section_id,
         section_resources \\ []
       ) do
    {section_resources, children_sr_ids} =
      Enum.reduce(children, {section_resources, []}, fn child, {section_resources, sr_ids} ->
        {child_section_resources, child_section_resource} =
          collapse_section_hierarchy(child, section_id, section_resources)

        {child_section_resources, [child_section_resource.id | sr_ids]}
      end)

    section_resource =
      case section_resource do
        nil ->
          # section resource record doesnt exist, create one on the fly.
          # this is necessary because we need the record id for the parent's children
          SectionResource.changeset(%SectionResource{}, %{
            numbering_index: numbering.index,
            numbering_level: numbering.level,
            slug: Oli.Utils.Slug.generate(:section_resources, revision.title),
            resource_id: resource_id,
            project_id: project_id,
            section_id: section_id,
            children: Enum.reverse(children_sr_ids)
          })
          |> Oli.Repo.insert!(
            # if there is a conflict on the unique section_id resource_id constraint,
            # we assume it is because a resource has been moved or removed/readded in
            # a remix operation, so we simply replace the existing section_resource record
            on_conflict: :replace_all,
            conflict_target: [:section_id, :resource_id]
          )

        %SectionResource{} ->
          %SectionResource{section_resource | children: Enum.reverse(children_sr_ids)}
      end

    {[section_resource | section_resources], section_resource}
  end

  # creates all non-structural section resources for the given publication ids skipping
  # any that belong to the resource ids in skip_resource_ids
  defp create_nonstructural_section_resources(section_id, publication_ids,
         skip_resource_ids: skip_resource_ids
       ) do
    published_resources_by_resource_id = published_resources_map(publication_ids)

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    published_resources_by_resource_id
    |> Enum.filter(fn {resource_id, %{revision: rev}} ->
      resource_id not in skip_resource_ids && !is_structural?(rev)
    end)
    |> Enum.map(fn {_id, %PublishedResource{revision: revision, publication: pub}} ->
      [
        slug: Oli.Utils.Slug.generate(:section_resources, revision.title),
        resource_id: revision.resource_id,
        project_id: pub.project_id,
        section_id: section_id,
        inserted_at: now,
        updated_at: now
      ]
    end)
    |> then(&Repo.insert_all(SectionResource, &1))
  end

  defp is_structural?(%Revision{resource_type_id: resource_type_id}) do
    container = ResourceType.get_id_by_type("container")
    page = ResourceType.get_id_by_type("page")

    resource_type_id == container or resource_type_id == page
  end

  @doc """
  Parses a ISO 8601 formatted local timestamps to DateTimes if they are not empty or nil.

  Returns a tuple containing the start and end datetimes in UTC: {utc_start_date, utc_end_date}
  """
  def parse_and_convert_start_end_dates_to_utc(start_date, end_date, from_timezone) do
    section_timezone = Timex.Timezone.get(from_timezone)
    utc_timezone = Timex.Timezone.get(:utc, Timex.now())

    utc_start_date =
      case start_date do
        start_date when start_date == nil or start_date == "" or not is_binary(start_date) ->
          start_date

        start_date ->
          start_date
          |> Timex.parse!("{ISO:Extended}")
          |> Timex.to_datetime(section_timezone)
          |> Timex.Timezone.convert(utc_timezone)
      end

    utc_end_date =
      case end_date do
        end_date when end_date == nil or end_date == "" or not is_binary(end_date) ->
          end_date

        end_date ->
          end_date
          |> Timex.parse!("{ISO:Extended}")
          |> Timex.to_datetime(section_timezone)
          |> Timex.Timezone.convert(utc_timezone)
      end

    {utc_start_date, utc_end_date}
  end

  @doc """
  Converts a section's start_date and end_date to the gievn timezone's local datetimes
  """
  def localize_section_start_end_datetimes(
         %Section{start_date: start_date, end_date: end_date, timezone: timezone} = section
       ) do
    timezone = Timex.Timezone.get(timezone, Timex.now())

    start_date =
      case start_date do
        start_date when start_date == nil or start_date == "" -> start_date
        start_date -> Timex.Timezone.convert(start_date, timezone)
      end

    end_date =
      case end_date do
        end_date when end_date == nil or end_date == "" -> end_date
        end_date -> Timex.Timezone.convert(end_date, timezone)
      end

    section
    |> Map.put(:start_date, start_date)
    |> Map.put(:end_date, end_date)
  end

end
