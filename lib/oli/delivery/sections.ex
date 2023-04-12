defmodule Oli.Delivery.Sections do
  @moduledoc """
  The Sections context.
  """
  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections.EnrollmentContextRole
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.ContainedPage
  alias Oli.Delivery.Sections.Enrollment
  alias Lti_1p3.Tool.ContextRole
  alias Lti_1p3.DataProviders.EctoProvider
  alias Oli.Lti.Tool.{Deployment, Registration}
  alias Oli.Lti.LtiParams
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Publishing
  alias Oli.Publishing.Publications.Publication
  alias Oli.Delivery.Paywall.Payment
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Resources.Numbering
  alias Oli.Authoring.Course.{Project, ProjectAttributes}
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Delivery.Snapshots.Snapshot
  alias Oli.Resources.ResourceType
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Revision
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.Publications.{PublicationDiff}
  alias Oli.Accounts.User
  alias Lti_1p3.Tool.ContextRoles
  alias Lti_1p3.Tool.PlatformRoles
  alias Oli.Delivery.Updates.Broadcaster
  alias Oli.Delivery.Sections.EnrollmentBrowseOptions
  alias Oli.Utils.Slug
  alias OliWeb.Common.FormatDateTime
  alias Oli.Delivery.PreviousNextIndex
  alias Oli.Delivery
  alias Ecto.Multi
  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Attempts.Core.ResourceAccess

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
      |> join(:left, [e, _], p in Payment, on: p.enrollment_id == e.id)
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
        :payment_date -> order_by(query, [_, _, p], {^direction, p.application_date})
        :payment_id -> order_by(query, [_, _, p], {^direction, p.id})
        _ -> order_by(query, [_, u, _], {^direction, field(u, ^field)})
      end

    Repo.all(query)
  end

  @doc """
  Determines the user roles (student / instructor) in a given section
  """
  def get_user_roles(%User{id: user_id}, section_slug) do
    from(
      e in Enrollment,
      join: s in Section,
      on: e.section_id == s.id,
      where: e.user_id == ^user_id and s.slug == ^section_slug and s.status == :active,
      preload: :context_roles
    )
    |> Repo.one()
    |> reduce_to_roles(%{is_instructor?: false, is_student?: false})
  end

  defp reduce_to_roles(nil, roles), do: roles

  defp reduce_to_roles(%Enrollment{} = enrollment, roles) do
    Enum.reduce(enrollment.context_roles, roles, fn context_role, acum ->
      case context_role do
        %Lti_1p3.DataProviders.EctoProvider.ContextRole{id: 3} ->
          Map.put(acum, :is_instructor?, true)

        %Lti_1p3.DataProviders.EctoProvider.ContextRole{id: 4} ->
          Map.put(acum, :is_student?, true)

        _ ->
          acum
      end
    end)
  end

  @doc """
  Determines if a user is an instructor in a given section.
  """
  def is_instructor?(%User{id: id} = user, section_slug) do
    is_enrolled?(id, section_slug) && has_instructor_role?(user, section_slug)
  end

  def is_instructor?(_, _) do
    false
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
      user,
      [
        PlatformRoles.get_role(:institution_instructor)
      ],
      :any
    )
  end

  @doc """
  Can a user create independent, enrollable sections through OLI's LMS?
  """
  def is_independent_instructor?(%User{} = user) do
    user.can_create_sections
  end

  def is_independent_instructor?(_), do: false

  @doc """
  Determines if a user is an administrator in a given section.
  """
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

  def is_admin?(_, _) do
    false
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
        where: e.user_id == ^user_id and s.slug == ^section_slug and s.status == :active
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
        where: s.slug == ^section_slug and s.status == :active,
        preload: [:user, :context_roles],
        select: e
      )

    Repo.all(query)
  end

  @doc """
  Returns the count of enrollments for a given section.
  By default it returns the students count, but we can get more roles by providing
  a list of lt1_1p3_context_roles ids as a second argument
  """
  def count_enrollments(section_slug, role_ids \\ [4]) do
    query =
      from(
        e in Enrollment,
        join: s in Section,
        on: e.section_id == s.id,
        join: e_cr in EnrollmentContextRole,
        on: e.id == e_cr.enrollment_id,
        join: cr in Lti_1p3.DataProviders.EctoProvider.ContextRole,
        on: e_cr.context_role_id == cr.id,
        where: s.slug == ^section_slug and s.status == :active and cr.id in ^role_ids,
        select: count(e)
      )

    Repo.one(query)
  end

  @doc """
  Returns true if there is student data associated to the given section.
  """
  def has_student_data?(section_slug) do
    query =
      from(
        snapshot in Snapshot,
        join: s in assoc(snapshot, :section),
        where: s.slug == ^section_slug,
        select: snapshot
      )

    Repo.aggregate(query, :count, :id) > 0
  end

  def get_enrollment(section_slug, user_id) do
    query =
      from(
        e in Enrollment,
        join: s in Section,
        on: e.section_id == s.id,
        where: e.user_id == ^user_id and s.slug == ^section_slug and s.status == :active,
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
        where: e.user_id == ^user_id and s.open_and_free == true and s.status == :active,
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
        where: s.open_and_free == true and s.status == :active,
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
      left_join: blueprint in assoc(s, :blueprint),
      where: s.slug == ^slug,
      preload: [
        brand: b,
        lti_1p3_deployment: {d, institution: {i, default_brand: default_brand}},
        blueprint: blueprint
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
    client_id = LtiParams.peek_client_id(lti_params)

    Repo.all(
      from(s in Section,
        join: d in Deployment,
        on: s.lti_1p3_deployment_id == d.id,
        join: r in Registration,
        on: d.registration_id == r.id,
        where:
          s.context_id == ^context_id and s.status == :active and r.issuer == ^issuer and
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
      where: spp.publication_id == ^publication.id and s.status == :active
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
    from(s in Section, where: s.base_project_id == ^project.id and s.status == :active)
    |> Repo.all()
  end

  @doc """
  Gets all sections that use a particular project when their 'end_date' attribute is not nil and is later than the current date.

  ## Examples
      iex> get_active_sections_by_project(project_id)
      [%Section{}, ...]

      iex> get_active_sections_by_project(invalid_project_id)
      []
  """
  def get_active_sections_by_project(project_id) do
    today = DateTime.utc_now()

    Repo.all(
      from(
        section in Section,
        join: spp in SectionsProjectsPublications,
        on: spp.section_id == section.id,
        where:
          spp.project_id == ^project_id and
            (not is_nil(section.end_date) and section.end_date >= ^today),
        select: section,
        preload: [section_project_publications: [:publication]]
      )
    )
  end

  @doc """
  Gets all sections and products that will be affected by forcing the publication update.

  ## Examples
      iex> get_push_force_affected_sections(project_id, previous_publication_id)
      %{product_count: 1, section_count: 1}
  """
  def get_push_force_affected_sections(project_id, previous_publication_id) do
    today = DateTime.utc_now()

    Repo.one(
      from(
        section in Section,
        join: spp in SectionsProjectsPublications,
        on: section.id == spp.section_id,
        where:
          spp.project_id == ^project_id and section.status == :active and
            spp.publication_id == ^previous_publication_id and
            (is_nil(section.end_date) or section.end_date >= ^today),
        select: %{
          product_count: fragment("count(case when ? = 'blueprint' then 1 end)", section.type),
          section_count: fragment("count(case when ? = 'enrollable' then 1 end)", section.type)
        }
      )
    )
  end

  @doc """
  For a section resource record, map its children SR records to resource ids,
  of course preserving the order of the children list.

  ## Examples
      iex> map_section_resource_children_to_resource_ids(root_resource)
      [1, 2, 3, 4]
  """
  def map_section_resource_children_to_resource_ids(root_section_resource) do
    srs =
      from(s in SectionResource,
        where: s.id in ^root_section_resource.children
      )
      |> Repo.all()
      |> Enum.reduce(%{}, fn sr, map -> Map.put(map, sr.id, sr.resource_id) end)

    Enum.map(root_section_resource.children, fn sr_id -> Map.get(srs, sr_id) end)
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
  Deletes a section.
  ## Examples
      iex> delete_section(section)
      {:ok, %Section{}}
      iex> delete_section(section)
      {:error, %Ecto.Changeset{}}
  """
  def delete_section(%Section{} = section) do
    Repo.delete(section)
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

  # Creates a 'hierarchy definition' strictly from a a project and the recursive
  # definition of containers starting with the root revision container.  This hierarchy
  # definition is a map of resource ids to a list of the child resource ids, effectively
  # the definition of the hierarchy.
  defp create_hierarchy_definition_from_project(
         published_resources_by_resource_id,
         revision,
         definition
       ) do
    child_revisions =
      Enum.map(revision.children, fn id -> published_resources_by_resource_id[id].revision end)

    Enum.reduce(
      child_revisions,
      Map.put(
        definition,
        revision.resource_id,
        Enum.map(child_revisions, fn r -> r.resource_id end)
      ),
      fn revision, definition ->
        create_hierarchy_definition_from_project(
          published_resources_by_resource_id,
          revision,
          definition
        )
      end
    )
  end

  # For a given section id and the list of resource ids that exist in its hiearchy,
  # determine and return the list of page resource ids that are not reachable from that
  # hierarchy and linked pages.
  defp determine_unreachable_pages(publication_ids, hierarchy_ids) do

    # Start with all pages
    unreachable = Oli.Publishing.all_page_resource_ids(publication_ids)
    |> MapSet.new()

    # create a map of page resource ids to a list of target resource ids that they link to. We
    # do this both for resource-to-page links and for page to activity links (aka activity-references).
    # We do this because we want to treat these links the same way when we traverse the graph, and
    # we want to be able to handle cases where a page from the hierarhcy embeds an activity which
    # links to a page outside the hierarchy.
    all_links = MapSet.union(get_all_page_links(publication_ids), get_activity_references(publication_ids))
    |> MapSet.to_list()

    link_map = Enum.reduce(all_links, %{}, fn {source, target}, map ->
      case Map.get(map, source) do
        nil -> Map.put(map, source, [target])
        targets -> Map.put(map, source, [target | targets])
      end
    end)

    # Now traverse the pages in the hiearchy, and follow (recursively) the links that
    # they have to other pages.
    {unreachable, _ } = traverse_links(link_map, hierarchy_ids, unreachable, MapSet.new())

    MapSet.to_list(unreachable)

  end

  # Traverse the graph structure of the links to determine which pages are reachable
  # from the pages in the hierarchy, removing them from the candidate set of unreachable pages.
  # This also tracks seen pages to avoid infinite recursion, in cases where pages create a
  # a circular link structure.
  def traverse_links(link_map, hiearchy_ids, unreachable, seen) do

    unreachable = MapSet.difference(unreachable, MapSet.new(hiearchy_ids))
    seen = MapSet.union(seen, MapSet.new(hiearchy_ids))

    Enum.reduce(hiearchy_ids, {unreachable, seen}, fn id, {unreachable, seen} ->
      case Map.get(link_map, id) do
        nil -> {unreachable, seen}
        targets ->
          not_already_seen = MapSet.new(targets)
          |> MapSet.difference(seen)
          |> MapSet.to_list()

          traverse_links(link_map, not_already_seen, unreachable, seen)
      end
    end)
  end

  # Returns a mapset of two element tuples of the form {source_resource_id, target_resource_id}
  # representing all of the links between pages in the section
  defp get_all_page_links(publication_ids) do

    joined_publication_ids = Enum.join(publication_ids, ",")

    item_types =
      ["page_link", "a"]
      |> Enum.map(&~s|@.type == "#{&1}"|)
      |> Enum.join(" || ")

    sql = """
    select
      rev.resource_id,
      jsonb_path_query(content, '$.** ? (#{item_types})')
    from published_resources as mapping
    join revisions as rev
    on mapping.revision_id = rev.id
    where mapping.publication_id IN (#{joined_publication_ids})
    """

    {:ok, %{rows: results}} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

    slug_lookup = Oli.Publishing.distinct_slugs(publication_ids)
    |> Enum.reduce(%{}, fn {id, slug}, acc -> Map.put(acc, slug, id) end)

    Enum.reduce(results, MapSet.new(), fn [source_id, content], links ->
      case content["type"] do
        "a" -> case content["href"] do
          "/course/link/" <> slug -> MapSet.put(links, {source_id, Map.get(slug_lookup, slug)})
          _ -> links
        end
        "page_link" -> MapSet.put(links, {source_id, content["idref"]})
      end
    end)

  end

  # Returns a mapset of two element tuples of the form {source_resource_id, target_resource_id}
  # representing the links of pages to activities
  defp get_activity_references(publication_ids) do
    joined_publication_ids = Enum.join(publication_ids, ",")

    sql = """
    select
      rev.resource_id,
      jsonb_path_query(content, '$.** ? (@.type == "activity-reference")')
    from published_resources as mapping
    join revisions as rev
    on mapping.revision_id = rev.id
    where mapping.publication_id IN (#{joined_publication_ids})
    """
    {:ok, %{rows: results}} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

    Enum.reduce(results, MapSet.new(), fn [source_id, content], links ->
      MapSet.put(links, {source_id, content["activity_id"]})
    end)

  end



  @doc """
  Create all section resources from the given section and publication and optional hierarchy definition.
  The hierarchy definition is a map of resource ids to the list of directly contained children (referenced
  by resource ids) for that parent.  The hierarchy definition must contain an entry for every container that will appear
  in the course section resources.  An example of the hierarchy definition with the root (1) and three
  top-level units (resource ids 2, 3, 4):

  ```
  %{
    1 => [2, 3, 4],
    2 => [5, 6, 7],
    3 => [8, 9],
    4 => [10]
  }
  ```

  If the hierarchy definition argument is omitted, a default hierarchy definition will be generated from
  the project's root revision and its children, recursively.

  Returns the root section resource record.

  ## Examples
      iex> create_section_resources(section, publication, hierarchy_definition)
      {:ok, %SectionResource{}}
  """
  def create_section_resources(
        %Section{} = section,
        %Publication{
          id: publication_id,
          root_resource_id: root_resource_id,
          project_id: project_id
        } = publication,
        hierarchy_definition \\ nil
      ) do
    Repo.transaction(fn ->
      published_resources_by_resource_id = published_resources_map(publication.id)

      %PublishedResource{revision: root_revision} =
        published_resources_by_resource_id[root_resource_id]

      # If a custom hierarchy_definition was supplied, use it, otherwise
      # use the hierarchy defined by the project
      hierarchy_definition =
        case hierarchy_definition do
          nil ->
            create_hierarchy_definition_from_project(
              published_resources_by_resource_id,
              root_revision,
              %{}
            )

          other ->
            other
        end

      numbering_tracker = Numbering.init_numbering_tracker()
      level = 0
      processed_ids = []

      {root_section_resource_id, _numbering_tracker, processed_ids} =
        create_section_resource(
          section,
          publication,
          published_resources_by_resource_id,
          processed_ids,
          root_revision,
          level,
          numbering_tracker,
          hierarchy_definition
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
         numbering_tracker,
         hierarchy_definition
       ) do
    {numbering_index, numbering_tracker} =
      Numbering.next_index(numbering_tracker, level, revision)

    children = Map.get(hierarchy_definition, revision.resource_id, [])

    {children, numbering_tracker, processed_ids} =
      Enum.reduce(
        children,
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
              numbering_tracker,
              hierarchy_definition
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
        slug: Slug.generate(:section_resources, revision.title),
        resource_id: revision.resource_id,
        project_id: publication.project_id,
        section_id: section.id
      })

    {section_resource_id, numbering_tracker, processed_ids}
  end

  def get_project_by_section_resource(section_id, resource_id) do
    Repo.one(
      from s in SectionResource,
        join: p in Project,
        on: s.project_id == p.id,
        where: s.section_id == ^section_id and s.resource_id == ^resource_id,
        select: p
    )
  end

  def get_section_resource(section_id, resource_id) do
    Repo.one(
      from s in SectionResource,
        where: s.section_id == ^section_id and s.resource_id == ^resource_id,
        select: s
    )
  end

  def get_section_resources(section_id) do
    from(sr in SectionResource,
      where: sr.section_id == ^section_id
    )
    |> Repo.all()
  end

  @doc """
  Returns information about the projects that have been remixed in a section.

  ## Examples

      iex> get_remixed_projects(1, 1)
      [%{id: 2, description: "description of project 2", title: "Project 2", ...}]

      iex> get_remixed_projects(1, 2)
      []
  """

  def get_remixed_projects(section_id, current_project_id) do
    Repo.all(
      from(
        project in Project,
        join: spp in SectionsProjectsPublications,
        on: spp.project_id == project.id,
        join: pub in Publication,
        on: pub.id == spp.publication_id,
        where:
          spp.section_id == ^section_id and
            spp.project_id != ^current_project_id,
        select: %{
          id: project.id,
          title: project.title,
          description: project.description,
          publication: pub
        }
      )
    )
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
  Rebuilds a section by upserting any new or existing section resources and removing any
  deleted section resources. Also updates the project publication mappings based on the
  given project_publications map.

  If a finalized hierarchy node is given, then the section will be rebuilt from it. Otherwise, it
  will be rebuilt from a list of section resources.

  project_publications is a map of the project id to the pinned publication for the section.
  %{1 => %Publication{project_id: 1, ...}, ...}
  """
  def rebuild_section_curriculum(
        %Section{id: section_id} = section,
        %HierarchyNode{} = hierarchy,
        project_publications
      ) do
    if Hierarchy.finalized?(hierarchy) do
      Multi.new()
      |> Multi.run(:rebuild_section_resources, fn _repo, _ ->
        # ensure there are no duplicate resources so as to not violate the
        # section_resource [section_id, resource_id] database constraint
        hierarchy =
          Hierarchy.purge_duplicate_resources(hierarchy)
          |> Hierarchy.finalize()

        # generate a new set of section resources based on the hierarchy
        {section_resources, _} = collapse_section_hierarchy(hierarchy, section_id)

        rebuild_section_resources(section, section_resources, project_publications)
      end)
      |> Multi.run(
        :maybe_update_exploration_pages,
        fn _repo, _ ->
          # updates contains_explorations field in sections
          Delivery.maybe_update_section_contains_explorations(section)
        end
      )
      |> Repo.transaction()
    else
      throw(
        "Cannot rebuild section curriculum with a hierarchy that has unfinalized changes. See Oli.Delivery.Hierarchy.finalize/1 for details."
      )
    end
  end

  def rebuild_section_resources(
        %Section{id: section_id} = section,
        section_resources,
        project_publications
      )
      when is_list(section_resources) do
    Repo.transaction(fn ->
      previous_section_resource_ids =
        get_section_resources(section_id)
        |> Enum.map(fn sr -> sr.id end)

      # Upsert all hierarchical section resources. Some of these records may have
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

      # Cleanup any deleted or non-hierarchical section resources
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

      # Upsert section project publications ensure section project publication mappings are up to date
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

      # Cleanup any unused project publication mappings
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

      # Finally, create all non-hierarchical section resources for all projects used in the section
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

      # Rebuild section previous next index
      PreviousNextIndex.rebuild(section)

      {:ok, _} = rebuild_contained_pages(section, section_resources)

      section_resources
    end)
  end

  @doc """
  Rebuilds the "contained pages" relations for a course section.  A "contained page" for a
  container is the full set of pages found immeidately within that container or in any of
  its sub-containers.  For every container in a course section, one row will exist in this
  "contained pages" table for each contained page.  This allows a straightforward join through
  this relation from a container to then all of its contained pages - to power calculations like
  aggregating progress complete across all pages within a container.
  """
  def rebuild_contained_pages(%Section{id: section_id} = section) do
    section_resources =
      from(sr in SectionResource, where: sr.section_id == ^section_id)
      |> Repo.all()

    rebuild_contained_pages(section, section_resources)
  end

  def rebuild_contained_pages(%Section{slug: slug, id: section_id} = section, section_resources) do
    # First start be deleting all existing contained pages for this section.
    from(cp in ContainedPage, where: cp.section_id == ^section_id)
    |> Repo.delete_all()

    # We will need the set of resource ids for all containers in the hierarchy.
    container_type_id = Oli.Resources.ResourceType.get_id_by_type("container")

    container_ids =
      DeliveryResolver.revisions_of_type(slug, container_type_id)
      |> Enum.map(fn rev -> rev.resource_id end)
      |> MapSet.new()

    # From the section resources, locate the root section resource, and also create a lookup map
    # from section_resource id to each section resource.
    root = Enum.find(section_resources, fn sr -> sr.id == section.root_section_resource_id end)
    map = Enum.reduce(section_resources, %{}, fn sr, map -> Map.put(map, sr.id, sr) end)

    # Now recursively traverse the containers within the course section hierarchy, starting with the root
    # to build a map of page resource_ids to lists of the ancestor container resource_ids.  The resultant
    # map will look like:
    #
    # %{
    #   234 => [32, 25, nil],
    #   135 => [33, 25, nil],
    #   299 => [25, nil],
    #   408 => [nil]
    # }
    #
    # The `nil` entries above represent their presence in the root container, and each preceding resource id
    # references a parent container (like Unit, module, etc).  All container references besides the root are
    # true resource_id references, and not ids of the section resoource.
    #
    page_map = rebuild_contained_pages_helper(root, {[nil], %{}, map, container_ids})

    # Now convert the page_map to a list of maps for bulk insert
    insertions =
      Enum.reduce(page_map, [], fn {page_id, ancestors}, all ->
        Enum.map(ancestors, fn id ->
          %{section_id: section_id, container_id: id, page_id: page_id}
        end) ++ all
      end)

    insertion_count = Repo.insert_all(ContainedPage, insertions)

    # Finally, update the contained_page_count of the container section resource
    # records.  We calculate this and cache it on the section resource to simplify
    # the queries that calculate progress
    {:ok, _} = set_contained_page_counts(section_id)

    {:ok, insertion_count}
  end

  # Recursive helper to traverse the hierarchy of the section resources and create the page to ancestor
  # container map.
  defp rebuild_contained_pages_helper(sr, {ancestors, page_map, all, container_ids}) do
    case Enum.map(sr.children, fn sr_id ->
           sr = Map.get(all, sr_id)

           case MapSet.member?(container_ids, sr.resource_id) do
             true ->
               rebuild_contained_pages_helper(
                 sr,
                 {[sr.resource_id | ancestors], page_map, all, container_ids}
               )
               |> Map.merge(page_map)

             false ->
               Map.put(page_map, sr.resource_id, ancestors)
           end
         end) do
      [] -> %{}
      other -> Enum.reduce(other, fn m, a -> Map.merge(m, a) end)
    end
  end

  defp set_contained_page_counts(section_id) do
    sql = """
    UPDATE section_resources
    SET
      contained_page_count = subquery.count,
      updated_at = NOW()
    FROM (
        SELECT COUNT(*) as count, container_id
        FROM contained_pages
        WHERE section_id = $1
        GROUP BY container_id
    ) AS subquery
    WHERE section_resources.resource_id = subquery.container_id and section_resources.section_id = $2
    """

    Ecto.Adapters.SQL.query(Repo, sql, [section_id, section_id])
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
    project = Oli.Repo.get(Oli.Authoring.Course.Project, project_id)
    current_publication = get_current_publication(section_id, project_id)
    current_hierarchy = DeliveryResolver.full_hierarchy(section.slug)

    # fetch diff from cache if one is available. If not, compute one on the fly
    diff = Publishing.get_publication_diff(current_publication, new_publication)

    result =
      case diff do
        %PublicationDiff{classification: :minor} ->
          perform_update(:minor, section, project_id, new_publication, current_hierarchy)

        %PublicationDiff{classification: :major} ->
          cond do
            # Case 1: The course section is based on this project, but is not a product and is not seeded from a product
            section.base_project_id == project_id and section.type == :enrollable and
                is_nil(section.blueprint_id) ->
              perform_update(
                :major,
                section,
                project_id,
                current_publication,
                new_publication
              )

            # Case 2: The course section is based on this project and was seeded from a product
            section.base_project_id == project_id and !is_nil(section.blueprint_id) ->
              perform_update(:minor, section, project_id, new_publication, current_hierarchy)

            # Case 3: The course section is a product based on this project
            section.base_project_id == project_id and section.type == :blueprint ->
              perform_update(:minor, section, project_id, new_publication, current_hierarchy)

            # Case 4: The course section is not based on this project (but it remixes some materials from project)
            true ->
              perform_update(:minor, section, project_id, new_publication, current_hierarchy)
          end
      end

    # For a section based on this project, update the has_experiments in the section to match that
    # setting in the project.
    if section.base_project_id == project_id and
         project.has_experiments != section.has_experiments do
      Oli.Delivery.Sections.update_section(section, %{has_experiments: project.has_experiments})
    end

    Broadcaster.broadcast_update_progress(section.id, new_publication.id, :complete)

    result
  end

  # for minor update, all we need to do is update the spp record and
  # rebuild the section curriculum based on the current hierarchy
  defp perform_update(:minor, section, project_id, new_publication, current_hierarchy) do
    Repo.transaction(fn ->
      # Update the section project publication to the new publication
      update_section_project_publication(section, project_id, new_publication.id)

      project_publications = get_pinned_project_publications(section.id)
      rebuild_section_curriculum(section, current_hierarchy, project_publications)

      {:ok}
    end)
  end

  # for major update, update the spp record and use the diff and the AIRRO approach
  defp perform_update(:major, section, project_id, prev_publication, new_publication) do
    Repo.transaction(fn ->
      container = ResourceType.get_id_by_type("container")
      prev_published_resources_map = published_resources_map(prev_publication.id)
      new_published_resources_map = published_resources_map(new_publication.id)

      # Update the section project publication to the new publication
      update_section_project_publication(section, project_id, new_publication.id)

      # Bulk create new placeholder section resource records for new published resources.
      # The children of these records may need the id of other section resource records
      # created here, so children will be set to nil initially and set in the next step.
      #
      # This is more efficient than DFS traversing the hierarchy and creating these records
      # one at a time in order to ensure that child record ids are available for the parent
      # children.
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      placeholders = %{timestamp: now}

      new_published_resources_map
      |> Enum.filter(fn {resource_id, _pr} ->
        !Map.has_key?(prev_published_resources_map, resource_id)
      end)
      |> Enum.map(fn {resource_id, pr} ->
        %{
          resource_id: resource_id,
          project_id: project_id,
          section_id: section.id,
          # we set children to nil here so that we know it needs to be set in the next step
          children: nil,
          slug: Oli.Utils.Slug.generate("section_resources", pr.revision.title),
          inserted_at: {:placeholder, :timestamp},
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

      # get all section resources including freshly minted ones
      section_resources = get_section_resources(section.id)

      # build mappings from section_resource_id to resource_id and the inverse
      {sr_id_to_resource_id, resource_id_to_sr_id} =
        section_resources
        |> Enum.reduce({%{}, %{}}, fn %SectionResource{id: id, resource_id: resource_id},
                                      {sr_id_to_resource_id, resource_id_to_sr_id} ->
          {Map.put(sr_id_to_resource_id, id, resource_id),
           Map.put(resource_id_to_sr_id, resource_id, id)}
        end)

      # For all container section resources in the course project whose children attribute differs
      # from the new publication’s container children, execute the three way merge algorithm
      merged_section_resources =
        section_resources
        |> Enum.map(fn section_resource ->
          %SectionResource{
            resource_id: resource_id,
            children: current_children
          } = section_resource

          prev_published_resource = prev_published_resources_map[resource_id]

          is_container? =
            case prev_published_resource do
              %{revision: %{resource_type_id: ^container}} ->
                true

              _ ->
                false
            end

          if is_container? or is_nil(current_children) do
            new_published_resource = new_published_resources_map[resource_id]
            new_children = new_published_resource.revision.children

            case current_children do
              nil ->
                # this section resource was just created so it can assume the newly published value
                %SectionResource{
                  section_resource
                  | children: Enum.map(new_children, &resource_id_to_sr_id[&1])
                }

              current_children ->
                # ensure we are comparing resource_ids to resource_ids (and not section_resource_ids)
                # by translating the current section_resource children ids to resource_ids
                current_children_resource_ids =
                  Enum.map(current_children, &sr_id_to_resource_id[&1])

                # check if the children resource_ids have diverged from the new value
                if current_children_resource_ids != new_children do
                  # There is a merge conflict between the current section resource and the new published resource.
                  # Use the AIRRO three way merge algorithm to resolve
                  base = prev_published_resource.revision.children
                  source = new_published_resource.revision.children
                  target = current_children_resource_ids

                  case Oli.Publishing.Updating.Merge.merge(base, source, target) do
                    {:ok, merged} ->
                      %SectionResource{
                        section_resource
                        | children: Enum.map(merged, &resource_id_to_sr_id[&1])
                      }

                    {:no_change} ->
                      section_resource
                  end
                else
                  section_resource
                end
            end
          else
            section_resource
          end
        end)

      # Upsert all merged section resource records. Some of these records may have just been created
      # and some may not have been changed, but that's okay we will just update them again
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      placeholders = %{timestamp: now}

      merged_section_resources
      |> Enum.map(fn section_resource ->
        %{
          SectionResource.to_map(section_resource)
          | updated_at: {:placeholder, :timestamp}
        }
      end)
      |> then(
        &Repo.insert_all(SectionResource, &1,
          placeholders: placeholders,
          on_conflict: {:replace_all_except, [:inserted_at]},
          conflict_target: [:section_id, :resource_id]
        )
      )

      # Finally, we must fetch and renumber the final hierarchy in order to generate the proper numberings
      {new_hierarchy, _numberings} =
        DeliveryResolver.full_hierarchy(section.slug)
        |> Numbering.renumber_hierarchy()

      # Rebuild the section curriculum using the new hierarchy, adding any new non-hierarchical
      # resources and cleaning up any deleted ones
      pinned_project_publications = get_pinned_project_publications(section.id)
      rebuild_section_curriculum(section, new_hierarchy, pinned_project_publications)
      Delivery.maybe_update_section_contains_explorations(section)

      {:ok}
    end)
  end

  @doc """
  Returns a map of resource_id to published resource
  """
  def published_resources_map(
        publication_ids,
        opts \\ [preload: [:resource, :revision, :publication]]
      )

  def published_resources_map(publication_ids, opts) when is_list(publication_ids) do
    Publishing.get_published_resources_by_publication(publication_ids, opts)
    |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.resource_id, r) end)
  end

  def published_resources_map(publication_id, opts) do
    published_resources_map([publication_id], opts)
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

  @doc """
  For a given section and resource, determine which project this
  resource originally belongs to.
  """
  def determine_which_project_id(section_id, resource_id) do
    Repo.one(
      from(
        sr in SectionResource,
        where: sr.section_id == ^section_id and sr.resource_id == ^resource_id,
        select: sr.project_id
      )
    )
  end

  # Takes a hierarchy node and a accumulator list of section resources and returns the
  # updated collapsed list of section resources
  defp collapse_section_hierarchy(
         %HierarchyNode{
           finalized: true,
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
            slug: Slug.generate(:section_resources, revision.title),
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
          # section resource record already exists, so we reuse it and update the fields which may have changed
          %SectionResource{
            section_resource
            | children: Enum.reverse(children_sr_ids),
              numbering_index: numbering.index,
              numbering_level: numbering.level
          }
      end

    {[section_resource | section_resources], section_resource}
  end

  # creates all non-structural section resources for the given publication ids skipping
  # any that belong to the resource ids in skip_resource_ids
  defp create_nonstructural_section_resources(section_id, publication_ids,
         skip_resource_ids: skip_resource_ids
       ) do
    published_resources_by_resource_id =
      published_resources_map(publication_ids, preload: [:revision, :publication])

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    unreachable_page_resource_ids = determine_unreachable_pages(publication_ids, skip_resource_ids)
    skip_set = MapSet.new(skip_resource_ids ++ unreachable_page_resource_ids)

    published_resources_by_resource_id
    |> Enum.filter(fn {resource_id, %{revision: rev}} ->
      !MapSet.member?(skip_set, resource_id) && !is_structural?(rev)
    end)
    |> generate_slugs_until_uniq()
    |> Enum.map(fn {slug, %PublishedResource{revision: revision, publication: pub}} ->
      [
        slug: slug,
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

    resource_type_id == container
  end

  # Function that generates a set of unique slugs that don't collide with any of the existing ones from the
  # section_resources table. It aims to minimize the number of queries to the database for ensuring that the slugs
  # generated are unique.
  defp generate_slugs_until_uniq(published_resources) do
    # generate initial slugs for new section resources
    published_resources_by_slug =
      Enum.reduce(published_resources, %{}, fn {_, pr}, acc ->
        title = pr.revision.title

        # if a previous published resource has the same revision then generate a new initial slug different from the default
        slug_attempt = if Map.has_key?(acc, Slug.slugify(title)), do: 1, else: 0
        initial_slug = Slug.generate_nth(title, slug_attempt)

        Map.put(acc, initial_slug, pr)
      end)

    # until all slugs are unique or up to 10 attempts
    {prs_by_non_uniq_slug, prs_by_uniq_slug} =
      Enum.reduce_while(1..10, {published_resources_by_slug, %{}}, fn attempt,
                                                                      {prs_by_non_uniq_slug,
                                                                       prs_by_uniq_slug} ->
        # get all slugs that already exist in the system and can't be used for new section resources
        existing_slugs =
          prs_by_non_uniq_slug
          |> Map.keys()
          |> get_existing_slugs()

        # if all slugs are unique then finish the loop, otherwise generate new slugs for the non unique ones
        if Enum.empty?(existing_slugs) do
          {:halt, {%{}, Map.merge(prs_by_non_uniq_slug, prs_by_uniq_slug)}}
        else
          # separate the slug candidates that succeeded and are unique from the ones that are not unique yet
          {new_prs_by_non_uniq_slug, new_uniq_to_merge} =
            Map.split(prs_by_non_uniq_slug, existing_slugs)

          new_prs_by_non_uniq_slug = regenerate_slugs(new_prs_by_non_uniq_slug, attempt)
          new_prs_by_uniq_slug = Map.merge(prs_by_uniq_slug, new_uniq_to_merge)

          {:cont, {new_prs_by_non_uniq_slug, new_prs_by_uniq_slug}}
        end
      end)

    unless Enum.empty?(prs_by_non_uniq_slug) do
      throw(
        "Cannot rebuild section curriculum. After several attempts it was not possible to generate unique slugs for new nonstructural section resources. See Oli.Delivery.Sections.create_nonstructural_section_resources/3 for details."
      )
    end

    prs_by_uniq_slug
  end

  @doc """
  Filters a given list of slugs, returning only the ones that already exist in the section_resources table.
  """
  def get_existing_slugs(slugs) do
    Repo.all(
      from(
        sr in SectionResource,
        where: sr.slug in ^slugs,
        select: sr.slug,
        distinct: true
      )
    )
  end

  # Generates a new set of slug candidates
  defp regenerate_slugs(prs_by_slug, attempt) do
    Enum.reduce(prs_by_slug, %{}, fn {_slug,
                                      %PublishedResource{revision: revision} = published_resource},
                                     acc ->
      new_slug = Slug.generate_nth(revision.title, attempt)

      Map.put(acc, new_slug, published_resource)
    end)
  end

  @doc """
  Returns the base_project attributes for the given section
  """
  def get_section_attributes(section) do
    project =
      Ecto.assoc(section, :base_project)
      |> Repo.one()

    case project do
      nil -> %ProjectAttributes{}
      %Project{:attributes => nil} -> %ProjectAttributes{}
      %Project{:attributes => attributes} -> attributes
    end
  end

  @doc """
  Converts a section's start_date and end_date to the given timezone's local datetimes
  """
  def localize_section_start_end_datetimes(
        %Section{start_date: start_date, end_date: end_date} = section,
        context
      ) do
    start_date = FormatDateTime.convert_datetime(start_date, context)
    end_date = FormatDateTime.convert_datetime(end_date, context)

    section
    |> Map.put(:start_date, start_date)
    |> Map.put(:end_date, end_date)
  end

  @doc """
  Returns {:available, section} if the section is available fo enrollment.

  Otherwise returns {:unavailable, reason} where reasons is one of:
  :registration_closed, :before_start_date, :after_end_date
  """
  def available?(section) do
    now = Timex.now()

    cond do
      section.registration_open != true ->
        {:unavailable, :registration_closed}

      not is_nil(section.start_date) and Timex.before?(now, section.start_date) ->
        {:unavailable, :before_start_date}

      not is_nil(section.end_date) and Timex.after?(now, section.end_date) ->
        {:unavailable, :after_end_date}

      true ->
        {:available, section}
    end
  end

  defp build_helper(id, previous_next_index) do
    node = Map.get(previous_next_index, id)

    Map.put(
      node,
      "children",
      Enum.map(node["children"], fn id ->
        build_helper(id, previous_next_index)
      end)
    )
  end

  def build_hierarchy_from_top_level(resource_ids, previous_next_index) do
    Enum.map(resource_ids, fn resource_id -> build_helper(resource_id, previous_next_index) end)
  end

  def build_hierarchy(section) do
    {:ok, _, previous_next_index} =
      PreviousNextIndex.retrieve(section, section.root_section_resource.resource_id)

    # Retrieve the top level resource ids, and convert them to strings
    resource_ids =
      Oli.Delivery.Sections.map_section_resource_children_to_resource_ids(
        section.root_section_resource
      )
      |> Enum.map(fn integer_id -> Integer.to_string(integer_id) end)

    %{
      id: "hierarchy_built_with_previous_next_index",
      # Recursively build the map based hierarchy from the structure defined by previous_next_index
      children: build_hierarchy_from_top_level(resource_ids, previous_next_index)
    }
  end

  defp get_related_resources([], _, _), do: []

  defp get_related_resources(resource_ids, section_id, user_id) do
    SectionResource
    |> join(:inner, [sr], spp in SectionsProjectsPublications,
      on: spp.section_id == sr.section_id and spp.project_id == sr.project_id
    )
    |> join(:inner, [sr, spp], pr in PublishedResource,
      on: pr.publication_id == spp.publication_id and pr.resource_id == sr.resource_id
    )
    |> join(:inner, [sr, _, pr], rev in Revision, on: rev.id == pr.revision_id)
    |> join(:left, [sr, _, _, rev], ra in ResourceAccess,
      on:
        ra.section_id == ^section_id and ra.resource_id == sr.resource_id and
          ra.user_id == ^user_id
    )
    |> join(:left, [sr, _, _, rev, ra], ra2 in ResourceAccess,
      on:
        ra2.section_id == ra.section_id and ra2.resource_id == ra.resource_id and
          ra2.user_id == ra.user_id and ra2.id > ra.id
    )
    |> where(
      [sr, _, _, rev, _ra, ra2],
      sr.section_id == ^section_id and
        rev.resource_type_id == ^ResourceType.get_id_by_type("page") and
        sr.resource_id in ^resource_ids
    )
    |> select([sr, _, _, rev, ra], %{
      id: sr.resource_id,
      title: rev.title,
      progress: ra.progress,
      slug: rev.slug,
      graded: rev.graded,
      purpose: rev.purpose
    })
    |> Repo.all()
  end

  defp append_related_resources(graded_pages, user_id) do

    case graded_pages do
      [] -> []
      _ ->

      section_id = graded_pages |> List.first() |> Map.get(:section_id)

      related_resources =
        graded_pages
        |> Enum.reduce([], fn page, related_pages -> page.relates_to ++ related_pages end)
        |> get_related_resources(section_id, user_id)

      Enum.map(graded_pages, fn page ->
        Map.get_and_update(page, :relates_to, fn relates_to ->
          {relates_to,
           Enum.map(relates_to, fn resource_id ->
             Enum.find(related_resources, &(&1.id == resource_id))
           end)
           |> Enum.filter(&(&1 != nil))}
        end)
        |> elem(1)
        |> Map.delete(:children)
      end)
    end


  end

  @doc """
  Returns a tuple with the units and modules from a section.
  In case there are no units or modules, it returns a zero count and the pages
  of the curriculum.
  {container_count, containers} or {0, pages}
  """
  def get_units_and_modules_containers(section_slug) do
    query =
      from [sr, s, _spp, _pr, rev] in DeliveryResolver.section_resource_revisions(section_slug),
        where:
          s.slug == ^section_slug and sr.numbering_level in [1, 2] and rev.resource_type_id == 2,
        select: %{
          id: rev.resource_id,
          title: rev.title,
          numbering_level: sr.numbering_level,
          numbering_index: sr.numbering_index
        }

    case Repo.all(query) do
      [] -> {0, get_pages(section_slug)}
      containers -> {length(containers), containers}
    end
  end

  defp get_pages(section_slug) do
    query =
      from [sr, s, _spp, _pr, rev] in DeliveryResolver.section_resource_revisions(section_slug),
        where: s.slug == ^section_slug and rev.resource_type_id == 1,
        select: %{
          id: rev.resource_id,
          title: rev.title,
          numbering_index: sr.numbering_index
        }

    Repo.all(query)
  end

  def get_graded_pages(section_slug, user_id) do
    {graded_pages_with_date, other_resources} =
      SectionResource
      |> join(:inner, [sr], s in Section, on: sr.section_id == s.id)
      |> join(:inner, [sr, s], spp in SectionsProjectsPublications,
        on: spp.section_id == s.id and spp.project_id == sr.project_id
      )
      |> join(:inner, [sr, _, spp], pr in PublishedResource,
        on: pr.publication_id == spp.publication_id and pr.resource_id == sr.resource_id
      )
      |> join(:inner, [sr, _, _, pr], rev in Revision, on: rev.id == pr.revision_id)
      |> join(:left, [sr], gc in GatingCondition,
        on:
          gc.section_id == sr.section_id and gc.resource_id == sr.resource_id and
            is_nil(gc.user_id)
      )
      |> join(:left, [sr], gc2 in GatingCondition,
        on:
          gc2.section_id == sr.section_id and gc2.resource_id == sr.resource_id and
            gc2.user_id == ^user_id
      )
      |> where(
        [sr, s, _, _, _, gc, gc2],
        s.slug == ^section_slug and (is_nil(gc) or gc.type == :schedule) and
          (is_nil(gc2) or gc2.type == :schedule)
      )
      |> select([sr, s, _, _, rev, gc, gc2], %{
        id: sr.id,
        title: rev.title,
        slug: rev.slug,
        end_date:
          fragment(
            "cast(coalesce(coalesce(cast(? as text), cast(? as text)), cast(? as text)) as date) as end_date",
            gc2.data["end_datetime"],
            gc.data["end_datetime"],
            sr.end_date
          ),
        scheduled_type: sr.scheduling_type,
        gate_type:
          fragment(
            "coalesce(coalesce(cast(? as text), cast(? as text)), NULL) as hard_gate_type",
            gc2.type,
            gc.type
          ),
        graded: rev.graded,
        resource_type_id: rev.resource_type_id,
        numbering_level: sr.numbering_level,
        children: sr.children,
        section_id: s.id,
        relates_to: rev.relates_to
      })
      |> order_by([{:asc_nulls_last, fragment("end_date")}])
      |> Repo.all()
      |> Enum.uniq_by(& &1.id)
      |> Enum.split_with(fn page ->
        page.end_date != nil and page.graded == true and
          page.resource_type_id == ResourceType.get_id_by_type("page")
      end)

    (graded_pages_with_date ++ get_graded_pages_without_date(other_resources))
    |> append_related_resources(user_id)
  end

  defp get_graded_pages_without_date(resources) do
    {root_container, graded_pages} = get_root_container_and_graded_pages(resources)

    graded_page_map = Enum.reduce(graded_pages, %{}, fn p, m -> Map.put(m, p.id, p) end)

    {pages, remaining} =
      get_flatten_hierarchy(root_container.children, resources)
      |> Enum.reduce({[], graded_page_map}, fn id, {acc, remaining} ->
        case Map.get(remaining, id) do
          nil -> {acc, remaining}
          page -> {[page | acc], Map.delete(remaining, id)}
        end
      end)

    Enum.reverse(pages) ++ Map.values(remaining)
  end

  defp get_root_container_and_graded_pages(resources) do
    Enum.reduce(resources, {nil, []}, fn resource, {root_container, graded_pages} = acc ->
      cond do
        resource.numbering_level == 0 ->
          {resource, graded_pages}

        resource.resource_type_id == ResourceType.get_id_by_type("page") and
            resource.graded == true ->
          {root_container, [resource | graded_pages]}

        true ->
          acc
      end
    end)
  end

  defp get_flatten_hierarchy(nil, _), do: []
  defp get_flatten_hierarchy([], _), do: []

  defp get_flatten_hierarchy([head_id | rest], resources) do
    [
      head_id
      | get_flatten_hierarchy(
          Enum.find(resources, %{}, &(&1.id == head_id))[:children],
          resources
        )
    ] ++
      get_flatten_hierarchy(rest, resources)
  end

  def get_parent_project_survey(section_slug) do
    Section
    |> join(:inner, [s], spp in SectionsProjectsPublications, on: spp.section_id == s.id)
    |> join(:inner, [_, spp], pr in PublishedResource, on: pr.publication_id == spp.publication_id)
    |> join(:inner, [_, _, pr], rev in Revision, on: pr.revision_id == rev.id)
    |> join(:inner, [s], proj in Project, on: proj.id == s.base_project_id)
    |> where(
      [s, spp, _, pr, proj],
      s.slug == ^section_slug and
        spp.project_id == s.base_project_id and
        spp.section_id == s.id and
        pr.resource_id == proj.required_survey_resource_id
    )
    |> select([_, _, _, rev], rev)
    |> Repo.one()
  end

  defp update_project_required_survey_resource_id(section_id, resource_id) do
    Section
    |> where([s], s.id == ^section_id)
    |> Repo.one()
    |> Section.changeset(%{required_survey_resource_id: resource_id})
    |> Repo.update()
  end

  def create_required_survey(section) do
    case section.required_survey_resource_id do
      nil -> do_create_required_survey(section)
      _ -> {:error, "The section already has a survey"}
    end
  end

  defp do_create_required_survey(section) do
    case get_parent_project_survey(section.slug) do
      nil ->
        {:error, "The parent project doesn't have a survey"}

      survey ->
        update_project_required_survey_resource_id(section.id, survey.resource_id)
    end
  end

  def delete_required_survey(section) do
    case section.required_survey_resource_id do
      nil ->
        {:error, "The section doesn't have a survey"}

      _ ->
        update_project_required_survey_resource_id(section.id, nil)
    end
  end
end
