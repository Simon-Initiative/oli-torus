defmodule Oli.Delivery.Sections do
  @moduledoc """
  The Sections context.
  """
  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections.EnrollmentContextRole
  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.{ContainedObjective, ContainedPage, Enrollment, Section}
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
  alias Oli.Delivery.Attempts.Core.{ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Paywall
  alias Oli.Branding.CustomLabels
  alias OliWeb.Delivery.RebuildFullHierarchyWorker

  require Logger

  def enrolled_students(section_slug) do
    section = get_section_by_slug(section_slug)

    from(e in Enrollment,
      join: s in assoc(e, :section),
      join: ecr in assoc(e, :context_roles),
      join: u in assoc(e, :user),
      left_join: p in Payment,
      on: p.enrollment_id == e.id and not is_nil(p.application_date),
      where: s.slug == ^section_slug,
      select: {u, ecr.id, e, p},
      preload: [user: :platform_roles],
      distinct: u.id
    )
    |> Repo.all()
    |> Enum.map(fn {user, context_role_id, enrollment, payment} ->
      Map.merge(user, %{
        enrollment_status: enrollment.status,
        user_role_id: context_role_id,
        payment_status:
          Paywall.summarize_access(
            enrollment.user,
            section,
            context_role_id,
            enrollment,
            payment
          ).reason,
        payment_date: if(!is_nil(payment), do: payment.application_date, else: nil)
      })
    end)
  end

  def browse_enrollments_query(
        %Section{id: section_id},
        %Paging{limit: limit, offset: offset},
        %Sorting{field: field, direction: direction},
        %EnrollmentBrowseOptions{} = options
      ) do
    instructor_role_id = ContextRoles.get_role(:context_instructor).id

    filter_by_role =
      case options do
        %EnrollmentBrowseOptions{is_instructor: true, is_student: true} ->
          true

        %EnrollmentBrowseOptions{is_student: true} ->
          dynamic(
            [u, e],
            fragment(
              "(NOT EXISTS (SELECT 1 FROM enrollments_context_roles r WHERE r.enrollment_id = ? AND r.context_role_id = ?))",
              e.id,
              ^instructor_role_id
            )
          )

        %EnrollmentBrowseOptions{is_instructor: true} ->
          dynamic(
            [u, e],
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
          [s, _],
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
      User
      |> join(:left, [u], e in Enrollment, on: u.id == e.user_id)
      |> join(:left, [_, e], p in Payment, on: p.enrollment_id == e.id)
      |> where(^filter_by_text)
      |> where(^filter_by_role)
      |> where([u, e], e.section_id == ^section_id)
      |> limit(^limit)
      |> offset(^offset)
      |> group_by([u, e, p], [e.id, u.id, p.id])
      |> select([u, _], u)
      |> select_merge([_, e, p], %{
        total_count: fragment("count(*) OVER()"),
        enrollment_date: e.inserted_at,
        payment_date: p.application_date,
        payment_id: p.id
      })

    case field do
      :enrollment_date ->
        order_by(query, [_, e, _], {^direction, e.inserted_at})

      :payment_date ->
        order_by(query, [_, _, p], {^direction, p.application_date})

      :payment_id ->
        order_by(query, [_, _, p], {^direction, p.id})

      :name ->
        order_by(query, [u, _, _], [{^direction, u.family_name}, {^direction, u.given_name}])

      _ ->
        order_by(query, [u, _, _], {^direction, field(u, ^field)})
    end
  end

  def browse_enrollments(
        %Section{id: _section_id} = section,
        %Paging{limit: _limit, offset: _offset} = paging,
        %Sorting{field: _field, direction: _direction} = sorting,
        %EnrollmentBrowseOptions{} = options
      ) do
    browse_enrollments_query(
      section,
      paging,
      sorting,
      options
    )
    |> Repo.all()
  end

  def browse_enrollments_with_context_roles(
        %Section{id: _section_id} = section,
        %Paging{limit: _limit, offset: _offset} = paging,
        %Sorting{field: _field, direction: _direction} = sorting,
        %EnrollmentBrowseOptions{} = options
      ) do
    browse_enrollments_query(
      section,
      paging,
      sorting,
      options
    )
    |> where([u, e], e.status != :suspended)
    |> join(:left, [_, e, p], ecr in EnrollmentContextRole, on: ecr.enrollment_id == e.id)
    |> group_by([_, _, _, ecr], [ecr.context_role_id])
    |> preload([u], :platform_roles)
    |> select_merge([u, e, p, ecr], %{
      context_role_id: ecr.context_role_id,
      payment: p,
      enrollment: e
    })
    |> Repo.all()
  end

  @doc """
  Determines the user roles (student / instructor) in a given section
  """
  def get_user_roles(%User{id: user_id}, section_slug) do
    from(
      e in Enrollment,
      join: s in Section,
      on: e.section_id == s.id,
      where:
        e.user_id == ^user_id and s.slug == ^section_slug and s.status == :active and
          e.status == :enrolled,
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
    Get the user's role in a given section.
  """

  def get_user_role_from_enrollment(enrollment) do
    enrollment
    |> Repo.preload(:context_roles)
    |> Map.get(:context_roles)
    |> List.first()
    |> Map.get(:id)
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
  Enrolls a user or users in a course section
  ## Examples
      iex> enroll(user_id, section_id, [%ContextRole{}])
      {:ok, %Enrollment{}} # Inserted or updated with success

      iex> enroll(user_id, section_id, :open_and_free)
      {:error, changeset} # Something went wrong
  """
  @spec enroll(list(number()), number(), [%ContextRole{}]) :: {:ok, list(%Enrollment{})}
  def enroll(user_ids, section_id, context_roles) when is_list(user_ids) do
    Repo.transaction(fn ->
      context_roles = EctoProvider.Marshaler.to(context_roles)
      date = DateTime.utc_now() |> DateTime.truncate(:second)

      # Insert all the enrollments at the same time
      enrollments =
        Enum.map(
          user_ids,
          &%{
            user_id: &1,
            section_id: section_id,
            inserted_at: date,
            updated_at: date,
            status: :enrolled,
            state: %{}
          }
        )

      {_cont, enrollments} =
        Repo.insert_all(Enrollment, enrollments,
          returning: [:id],
          conflict_target: [:user_id, :section_id],
          on_conflict: {:replace, [:user_id]}
        )

      # Insert the enrollment context roles at the same time based on the previously created enrollments
      enrollment_context_roles =
        Enum.reduce(context_roles, [], fn role, enrollment_context_roles ->
          Enum.map(enrollments, &%{enrollment_id: &1.id, context_role_id: role.id}) ++
            enrollment_context_roles
        end)

      Repo.insert_all(EnrollmentContextRole, enrollment_context_roles, on_conflict: :nothing)

      {:ok, enrollments}
    end)
  end

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
  Unenrolls a user from a section by removing the provided context roles. If no context roles are provided, no change is made. If all context roles are removed from the user, the enrollment is marked as suspended.

  To unenroll a student, use unenroll_learner/2
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
          enrollment
          |> Enrollment.changeset(%{status: :suspended})
          |> Repo.update()
        else
          enrollment
          |> Enrollment.changeset(%{section_id: section_id})
          |> Ecto.Changeset.put_assoc(:context_roles, other_context_roles)
          |> Repo.update()
        end
    end
  end

  @doc """
  Unenrolls a student from a section by removing the :context_learner role. If this is their only context_role, the enrollment is marked as suspended.
  """
  def unenroll_learner(user_id, section_id) do
    unenroll(user_id, section_id, [ContextRoles.get_role(:context_learner)])
  end

  @doc """
  Re-enrolls a student in a section by marking the enrollment as enrolled again.
  """
  def re_enroll_learner(user_id, section_id) do
    case Repo.get_by(Enrollment, user_id: user_id, section_id: section_id, status: :suspended) do
      nil ->
        # Enrollment not found
        {:error, :not_found}

      enrollment ->
        enrollment
        |> Enrollment.changeset(%{status: :enrolled})
        |> Repo.update()
    end
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
        where:
          e.user_id == ^user_id and s.slug == ^section_slug and s.status == :active and
            e.status == :enrolled
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
        where: s.slug == ^section_slug and s.status == :active and e.status == :enrolled,
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
        where:
          s.slug == ^section_slug and cr.id in ^role_ids and
            e.status == :enrolled,
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
        where:
          e.user_id == ^user_id and s.slug == ^section_slug and s.status == :active and
            e.status == :enrolled,
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
        where:
          e.user_id == ^user_id and s.open_and_free == true and s.status == :active and
            e.status == :enrolled,
        preload: [:base_project],
        select: s
      )

    Repo.all(query)
  end

  @doc """
  Returns a listing of all enrolled sections for a given user.
  """
  def list_user_enrolled_sections(%{id: user_id} = _user) do
    query =
      from(
        s in Section,
        join: e in Enrollment,
        on: e.section_id == s.id,
        where: e.user_id == ^user_id and s.status == :active and e.status == :enrolled,
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
        Logger.warning("More than one active section was returned for context_id #{context_id}")

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
  Creates multiple section resources.
  ## Examples
      iex> bulk_create_section_resource([%{slug: slug_value_1, ...}, %{slug: slug_value_2, ...}])
      {2, [%SectionResource{}, %SectionResource{}]}
  """
  def bulk_create_section_resource(_section_resource_rows, _opts \\ [])

  def bulk_create_section_resource([], _opts), do: {0, []}

  def bulk_create_section_resource(section_resource_rows, opts) do
    section_resource_rows
    |> Enum.chunk_every(calculate_chunk_size(section_resource_rows))
    |> Enum.reduce({0, []}, fn chunk, {total, acc} ->
      {new_total, new_acc} =
        Repo.insert_all(SectionResource, chunk, returning: opts[:returning] || true)

      {total + new_total, acc ++ new_acc}
    end)
  end

  defp calculate_chunk_size(section_resource_rows) do
    # We want to split the list of section resources into chunks
    # to avoid hitting the max number of bind variables in a query.
    max_bind_variables = 65535

    fields_count =
      section_resource_rows
      |> List.first()
      |> Map.keys()
      |> length()

    div(max_bind_variables, fields_count)
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
  Updates multiple section resources.
  ## Examples
      iex> bulk_update_section_resource(section, %{field: new_value})
      {2, [%SectionResource{}, %SectionResource{}]}
  """
  def bulk_update_section_resource(_section_resource_rows, _opts \\ [])

  def bulk_update_section_resource([], _), do: {0, []}

  def bulk_update_section_resource(section_resource_rows, opts) do
    Repo.insert_all(SectionResource, section_resource_rows,
      returning: opts[:returning] || true,
      on_conflict: {:replace, [:children]},
      conflict_target: [:id]
    )
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

  @doc """
  Returns the set of all students with :context_learner role in the given section.
  """
  def fetch_students(section_slug) do
    list_enrollments(section_slug)
    |> Enum.filter(fn e ->
      ContextRoles.contains_role?(e.context_roles, ContextRoles.get_role(:context_learner))
    end)
    |> Enum.map(fn e -> e.user end)
  end

  @doc """
  Returns the set of all instructors with :context_instructor role in the given section.
  """
  def fetch_instructors(section_slug) do
    list_enrollments(section_slug)
    |> Enum.filter(fn e ->
      ContextRoles.contains_role?(e.context_roles, ContextRoles.get_role(:context_instructor))
    end)
    |> Enum.map(fn e -> e.user end)
  end

  @doc """
  Returns the names of all instructors with :context_instructor role for the given section ids.

  %{
    section_id_1: [inst_1, inst_2],
    ...
    section_id_n: [inst_3]
  }
  """

  def instructors_per_section(section_ids) do
    instructor_context_role_id = ContextRoles.get_role(:context_instructor).id

    query =
      from(
        e in Enrollment,
        join: s in Section,
        on: e.section_id == s.id,
        join: ecr in EnrollmentContextRole,
        on: e.id == ecr.enrollment_id,
        where:
          s.id in ^section_ids and e.status == :enrolled and
            ecr.context_role_id == ^instructor_context_role_id,
        preload: [:user],
        select: {s.id, e}
      )

    Repo.all(query)
    |> Enum.group_by(fn {section_id, _} -> section_id end, fn {_, enrollment} ->
      OliWeb.Components.Delivery.Utils.user_name(enrollment.user)
    end)
  end

  @doc """
  Returns all scored pages for the given section.
  """
  def fetch_scored_pages(section_slug), do: fetch_all_pages(section_slug, true)

  @doc """
  Returns all unscored pages for the given section.
  """
  def fetch_unscored_pages(section_slug), do: fetch_all_pages(section_slug, false)

  @doc """
  Returns all pages for the given section.
  """
  def fetch_all_pages(section_slug, graded \\ nil) do
    maybe_filter_by_graded =
      case graded do
        nil -> true
        graded -> dynamic([_, _, _, _, rev], rev.graded == ^graded)
      end

    SectionResource
    |> join(:inner, [sr], s in Section, on: sr.section_id == s.id)
    |> join(:inner, [sr, s], spp in SectionsProjectsPublications,
      on: spp.section_id == s.id and spp.project_id == sr.project_id
    )
    |> join(:inner, [sr, _, spp], pr in PublishedResource,
      on: pr.publication_id == spp.publication_id and pr.resource_id == sr.resource_id
    )
    |> join(:inner, [sr, _, _, pr], rev in Revision, on: rev.id == pr.revision_id)
    |> where(
      [sr, s, _, _, rev],
      s.slug == ^section_slug and
        rev.deleted == false and
        rev.resource_type_id == ^ResourceType.get_id_by_type("page")
    )
    |> where(^maybe_filter_by_graded)
    |> order_by([_, _, _, _, rev], asc: rev.resource_id)
    |> select([_, _, _, _, rev], rev)
    |> Repo.all()
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

  # For a given section id and the list of resource ids that exist in its hierarchy,
  # determine and return the list of page resource ids that are not reachable from that
  # hierarchy, taking into account links from pages to other pages and the 'relates_to'
  # relationship between pages.
  defp determine_unreachable_pages(publication_ids, hierarchy_ids) do
    # Start with all pages
    unreachable =
      Oli.Publishing.all_page_resource_ids(publication_ids)
      |> MapSet.new()

    # create a map of page resource ids to a list of target resource ids that they link to. We
    # do this both for resource-to-page links and for page to activity links (aka activity-references).
    # We do this because we want to treat these links the same way when we traverse the graph, and
    # we want to be able to handle cases where a page from the hierarchy embeds an activity which
    # links to a page outside the hierarchy.
    all_links =
      [
        get_all_page_links(publication_ids),
        get_activity_references(publication_ids),
        get_relates_to(publication_ids)
      ]
      |> Enum.reduce(MapSet.new(), fn links, acc -> MapSet.union(links, acc) end)
      |> MapSet.to_list()

    link_map =
      Enum.reduce(all_links, %{}, fn {source, target}, map ->
        case Map.get(map, source) do
          nil -> Map.put(map, source, [target])
          targets -> Map.put(map, source, [target | targets])
        end
      end)

    # Now traverse the pages in the hierarchy, and follow (recursively) the links that
    # they have to other pages.
    {unreachable, _} = traverse_links(link_map, hierarchy_ids, unreachable, MapSet.new())

    MapSet.to_list(unreachable)
  end

  # Traverse the graph structure of the links to determine which pages are reachable
  # from the pages in the hierarchy, removing them from the candidate set of unreachable pages
  # This also tracks seen pages to avoid infinite recursion, in cases where pages create a
  # a circular link structure.
  def traverse_links(link_map, hierarchy_ids, unreachable, seen) do
    unreachable = MapSet.difference(unreachable, MapSet.new(hierarchy_ids))
    seen = MapSet.union(seen, MapSet.new(hierarchy_ids))

    Enum.reduce(hierarchy_ids, {unreachable, seen}, fn id, {unreachable, seen} ->
      case Map.get(link_map, id) do
        nil ->
          {unreachable, seen}

        targets ->
          not_already_seen =
            MapSet.new(targets)
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

    slug_lookup =
      Oli.Publishing.distinct_slugs(publication_ids)
      |> Enum.reduce(%{}, fn {id, slug}, acc -> Map.put(acc, slug, id) end)

    Enum.reduce(results, MapSet.new(), fn [source_id, content], links ->
      case content["type"] do
        "a" ->
          case content["href"] do
            "/course/link/" <> slug -> MapSet.put(links, {source_id, Map.get(slug_lookup, slug)})
            _ -> links
          end

        "page_link" ->
          MapSet.put(links, {source_id, content["idref"]})
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

  # Returns a mapset of two element tuples of the form {source_resource_id, target_resource_id}
  # representing the relates_to relationship between pages.
  defp get_relates_to(publication_ids) do
    joined_publication_ids = Enum.join(publication_ids, ",")
    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")

    sql = """
    select
      rev.resource_id, rev.relates_to
    from published_resources as mapping
    join revisions as rev
    on mapping.revision_id = rev.id
    where rev.resource_type_id = #{page_type_id} and array_length(rev.relates_to, 1) > 0 and mapping.publication_id IN (#{joined_publication_ids})
    """

    {:ok, %{rows: results}} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

    Enum.reduce(results, MapSet.new(), fn [source_id, relates_to], links ->
      # The relates_to field is an array of resource ids, to be future proof
      # to how relates_to is used, we will follow these 'links' in both directions
      Enum.reduce(relates_to, links, fn target_id, links ->
        MapSet.put(links, {source_id, target_id}) |> MapSet.put({target_id, source_id})
      end)
    end)
  end

  @doc """
  Builds a map of all page links in a given section. Returns a map of resource ids to a list of
  resource ids of the pages that they are linked from. Typically this will be a single
  resource id, but in cases where a page is linked from multiple pages it can be more than one.

  ## Examples
      iex> build_resource_link_map(publication_ids)
      %{1 => [], 2 => [], 3 => [1, 2], 4 => [4]}
  """
  def build_resource_link_map(publication_ids) do
    # Returns a MapSet of two element tuples of the form {source_resource_id, target_resource_id}
    # representing all of the links between resources
    all_page_links =
      [
        get_all_page_links(publication_ids),
        get_activity_references(publication_ids),
        get_relates_to(publication_ids),
        get_hierarchical_parent_links(publication_ids)
      ]
      |> Enum.reduce(MapSet.new(), fn links, acc -> MapSet.union(links, acc) end)

    # For each page, find the set of pages that link to it and add those links to the map
    all_resource_ids(publication_ids)
    |> Enum.reduce(%{}, fn id, acc ->
      Enum.reduce(all_page_links, acc, fn {source, target}, acc ->
        if target == id do
          Map.update(acc, id, [source], fn links ->
            [source | links]
          end)
        else
          acc
        end
      end)
    end)
  end

  @doc """
  Returns the resource_to_container map for the given section,
  that maps all resources ids to their parent container id.
  If the section does not have a precomputed resource_to_container_map, one will be generated.

  ## Examples
      iex> get_resource_to_container_map(section)
      %{
        "21" => 39,
        "22" => 40,
        "23" => 42,
        "24" => 42,
        "25" => 42,
        "26" => 42,
        "27" => 42,
        "28" => 43,
      }
  """

  def get_resource_to_container_map(section) do
    case section do
      %Section{resource_to_container_map: nil} ->
        Logger.warning(
          "Section #{section.slug} has no precomputed resource_to_container_map. One will be generated now."
        )

        {:ok, section} = update_resource_to_container_map(section)
        section.resource_to_container_map

      %Section{resource_to_container_map: resource_to_container_map} ->
        resource_to_container_map
    end
  end

  @doc """
  Builds a section's resource_to_container_map and updates the section with it.
  """
  def update_resource_to_container_map(section) do
    update_section(section, %{
      resource_to_container_map: build_resource_to_container_map(section)
    })
  end

  defp build_resource_to_container_map(section) do
    publication_ids = section_publication_ids(section.slug)
    resource_link_map = build_resource_link_map(publication_ids)

    all_pages = fetch_all_pages(section.slug)

    all_containers =
      DeliveryResolver.revisions_of_type(
        section.slug,
        Oli.Resources.ResourceType.get_id_by_type("container")
      )

    container_ids = Enum.map(all_containers, fn c -> c.resource_id end)

    # get all explorations in the section and group them by their container title
    all_pages
    |> Enum.reduce(%{}, fn page, acc ->
      {container_id, _seen} =
        find_parent_container(
          page.resource_id,
          resource_link_map,
          MapSet.new(container_ids),
          MapSet.new()
        )

      Map.put(acc, Integer.to_string(page.resource_id), container_id)
    end)
  end

  defp section_publication_ids(section_slug) do
    from(s in Section,
      where: s.slug == ^section_slug,
      join: spp in SectionsProjectsPublications,
      on: s.id == spp.section_id,
      select: spp.publication_id
    )
    |> Repo.all()
  end

  defp all_resource_ids(publication_ids) do
    from(pr in PublishedResource,
      join: rev in Revision,
      on: pr.revision_id == rev.id,
      where: pr.publication_id in ^publication_ids,
      select: rev.resource_id,
      distinct: true
    )
    |> Repo.all()
  end

  defp find_parent_container(
         resource_id,
         resource_link_map,
         container_ids,
         seen
       ) do
    if MapSet.member?(seen, resource_id) do
      # we've already seen this page, so we've reached a cycle in the recursion and it is not linked
      # from any page in the hierarchy
      {nil, seen}
    else
      if MapSet.member?(container_ids, resource_id) do
        # found the first hierarchical container for this page, so return it
        {resource_id, seen}
      else
        case Map.get(resource_link_map, resource_id) do
          nil ->
            # resource_link_map has no links for this resource, so we've reached the end of the
            # recursion and it is not linked from any page in the hierarchy
            {nil, seen}

          link_ids ->
            link_ids
            |> Enum.reduce({nil, seen}, fn id, acc ->
              case acc do
                {nil, seen} ->
                  find_parent_container(
                    id,
                    resource_link_map,
                    container_ids,
                    MapSet.put(seen, resource_id)
                  )

                _ ->
                  acc
              end
            end)
        end
      end
    end
  end

  @doc """
  Returns a map of all explorations in the section, grouped by their container. Each exploration
  returned as a tuple of the exploration and its status.

  ## Examples
      iex> get_explorations_by_containers(section)
      %{
        default: [
          {exploration, :not_started},
          {exploration, :started},
          ...
        ],
        "Unit 1: Acids and Bases" => [
          {exploration, :not_started},
          {exploration, :started},
          ...
        ]
      }
  """
  def get_explorations_by_containers(section, user) do
    resource_to_container_map = get_resource_to_container_map(section)

    # get all explorations in the section and group them by their container title
    DeliveryResolver.get_by_purpose(section.slug, :application)
    |> Enum.reduce(%{}, fn exploration, acc ->
      container_id =
        Map.get(resource_to_container_map, Integer.to_string(exploration.resource_id), :default)

      # group by container resource_id
      Map.update(acc, container_id, [exploration], fn explorations ->
        [exploration | explorations]
      end)
    end)
    |> label_and_sort_explorations_by_hierarchy(section.slug)
    |> attach_statuses_for_user(section.slug, user)
  end

  defp attach_statuses_for_user(explorations_map, _section_slug, nil),
    do:
      explorations_map
      |> Enum.map(fn {container_id, explorations} ->
        {container_id, Enum.map(explorations, fn exploration -> {exploration, :not_started} end)}
      end)

  defp attach_statuses_for_user(explorations_map, section_slug, user) do
    started_explorations = fetch_started_explorations(section_slug, user.id)

    explorations_map
    |> Enum.map(fn {container_id, explorations} ->
      {container_id,
       Enum.map(explorations, fn exploration ->
         {exploration, Map.get(started_explorations, exploration.resource_id, :not_started)}
       end)}
    end)
  end

  defp fetch_started_explorations(section_slug, user_id) do
    page_id = Oli.Resources.ResourceType.get_id_by_type("page")

    from([sr: sr, rev: rev] in DeliveryResolver.section_resource_revisions(section_slug),
      join: ra in ResourceAccess,
      on: ra.resource_id == rev.resource_id,
      join: resource_attempt in ResourceAttempt,
      on: resource_attempt.resource_access_id == ra.id,
      join: user in assoc(ra, :user),
      where:
        rev.purpose == :application and rev.deleted == false and
          rev.resource_type_id == ^page_id and user.id == ^user_id,
      order_by: [asc: rev.resource_id],
      group_by: [rev.id, resource_attempt.id],
      select: rev.resource_id
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn id, acc -> Map.put(acc, id, :started) end)
  end

  defp label_and_sort_explorations_by_hierarchy(explorations_map, section_slug) do
    fetch_ordered_containers(section_slug)
    |> Enum.reduce(
      case explorations_map[:default] do
        nil -> []
        default -> [{:default, default}]
      end,
      fn {resource_id, title}, acc ->
        if explorations_map[resource_id] do
          [{title, explorations_map[resource_id]} | acc]
        else
          acc
        end
      end
    )
    |> Enum.reverse()
  end

  @doc """
  Returns a map of all containers numbering index and title for the given section,
  ordered in the way they appear in the course, considering the customizations that
  could be configured to containers (ex, naming SubModules to Sections)

  ## Examples
      iex> get_ordered_containers(section_slug)
      %{
        4 => "Section 1: Curriculum",
        39 => "Module 1: Setup",
        40 => "Module 2: Phoenix project",
        41 => "Unit 1: Getting Started",
        42 => "Module 3: Types",
        43 => "Module 4: Enum",
        44 => "Unit 2: Basics",
        45 => "Module 5: OTP",
        46 => "Module 6: GenServers",
        47 => "Unit 3: Advanced",
        48 => "Unit 4: Final"
      }
  """

  def fetch_ordered_containers(section_slug) do
    container_type_id = Oli.Resources.ResourceType.get_id_by_type("container")

    SectionResource
    |> join(:inner, [sr], s in Section, on: sr.section_id == s.id)
    |> join(:inner, [sr, s], spp in SectionsProjectsPublications,
      on: spp.section_id == s.id and spp.project_id == sr.project_id
    )
    |> join(:inner, [sr, _, spp], pr in PublishedResource,
      on: pr.publication_id == spp.publication_id and pr.resource_id == sr.resource_id
    )
    |> join(:inner, [sr, _, _, pr], rev in Revision, on: rev.id == pr.revision_id)
    |> join(:inner, [sr, _, spp, _, _], p in Project, on: p.id == spp.project_id)
    |> where(
      [sr, s, _, _, rev, _],
      s.slug == ^section_slug and rev.resource_type_id == ^container_type_id
    )
    |> select([sr, s, _, _, rev, p], %{
      id: rev.resource_id,
      title: rev.title,
      numbering_level: sr.numbering_level,
      numbering_index: sr.numbering_index,
      children: rev.children,
      customizations: p.customizations
    })
    |> order_by([
      {:asc_nulls_last, fragment("numbering_level")},
      {:asc_nulls_last, fragment("numbering_index")}
    ])
    |> Repo.all()
    |> Enum.map(fn c ->
      {
        c.id,
        ~s{#{get_container_label(c.numbering_level, c.customizations || Map.from_struct(CustomLabels.default()))} #{c.numbering_index}: #{c.title}}
      }
    end)
  end

  defp get_hierarchical_parent_links(publication_ids) do
    container_type_id = Oli.Resources.ResourceType.get_id_by_type("container")

    from(pr in PublishedResource,
      join: rev in Revision,
      on: pr.revision_id == rev.id,
      where: rev.resource_type_id == ^container_type_id and pr.publication_id in ^publication_ids,
      select: %{id: rev.resource_id, children: rev.children},
      distinct: true
    )
    |> Repo.all()
    |> Enum.reduce(MapSet.new(), fn %{id: resource_id, children: children}, links ->
      Enum.reduce(children, links, fn child_id, links ->
        # MapSet.put(links, {child_id, resource_id})
        MapSet.put(links, {resource_id, child_id})
      end)
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

      # Generate all the section resource slugs at the same time
      titles =
        published_resources_by_resource_id
        |> Map.values()
        |> Enum.map(fn %PublishedResource{revision: revision} ->
          revision.title
        end)

      section_resource_slugs =
        Enum.zip(
          titles,
          Slug.generate(
            :section_resources,
            titles
          )
        )
        |> Enum.into(%{})

      # Transverse the hierarchy and create a list containing the SectionResource maps to be inserted
      {section_resources, _, _} =
        build_section_resource_insertion(%{
          section: section,
          publication: publication,
          published_resources_by_resource_id: published_resources_by_resource_id,
          processed_ids: processed_ids,
          revision: root_revision,
          level: level,
          numbering_tracker: numbering_tracker,
          hierarchy_definition: hierarchy_definition,
          date: DateTime.utc_now() |> DateTime.truncate(:second),
          slugs: section_resource_slugs
        })

      # Insert all the section resources without their children
      {_count, section_resources} =
        Repo.insert_all(SectionResource, section_resources,
          returning: [:id, :resource_id, :inserted_at, :updated_at]
        )

      processed_ids = Enum.map(section_resources, & &1.resource_id)

      # Rebuild the section resources (with the id they have in the database) and add their children
      section_resources_by_resource_id =
        Enum.reduce(section_resources, %{}, fn sr, map ->
          Map.put(map, sr.resource_id, sr)
        end)

      section_resources =
        Enum.reduce(section_resources, [], fn sr, section_resources ->
          children = hierarchy_definition[sr.resource_id]

          if !is_nil(children) and length(children) > 0 do
            sr =
              Map.put(
                sr,
                :children,
                Enum.map(hierarchy_definition[sr.resource_id] || [], fn child_resource_id ->
                  section_resources_by_resource_id[child_resource_id].id
                end)
              )
              |> Map.take([:id, :children, :inserted_at, :updated_at])

            [sr | section_resources]
          else
            section_resources
          end
        end)

      # Update children for the section resources that were just created in the database
      # (only when it's necessary to do so)
      Repo.insert_all(SectionResource, section_resources,
        returning: [:id, :resource_id, :children],
        on_conflict: {:replace, [:children]},
        conflict_target: [:id]
      )

      survey_id =
        Project
        |> where([p], p.id == ^section.base_project_id)
        |> select([p], p.required_survey_resource_id)
        |> Repo.one()

      # create any remaining section resources which are not in the hierarchy
      create_nonstructural_section_resources(section.id, [publication_id],
        skip_resource_ids: processed_ids,
        required_survey_resource_id: survey_id
      )

      root_section_resource_id = section_resources_by_resource_id[root_resource_id].id

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

  # The following function receives a hierarchy and recursively builds a list with the
  # SectionResource maps that will be inserted in the database.
  defp build_section_resource_insertion(%{
         section: section,
         publication: publication,
         published_resources_by_resource_id: published_resources_by_resource_id,
         processed_ids: processed_ids,
         revision: revision,
         level: level,
         numbering_tracker: numbering_tracker,
         hierarchy_definition: hierarchy_definition,
         date: date,
         slugs: slugs
       }) do
    {numbering_index, numbering_tracker} =
      Numbering.next_index(numbering_tracker, level, revision)

    children = Map.get(hierarchy_definition, revision.resource_id, [])

    # Transform each child of the revision into a section resource
    {children, numbering_tracker, slugs} =
      Enum.reduce(
        children,
        {[], numbering_tracker, slugs},
        fn resource_id, {processed_children, numbering_tracker, slugs} ->
          %PublishedResource{revision: child} = published_resources_by_resource_id[resource_id]

          {section_resources, numbering_tracker, slugs} =
            build_section_resource_insertion(%{
              section: section,
              publication: publication,
              published_resources_by_resource_id: published_resources_by_resource_id,
              processed_ids: processed_ids,
              revision: child,
              level: level + 1,
              numbering_tracker: numbering_tracker,
              hierarchy_definition: hierarchy_definition,
              date: date,
              slugs: slugs
            })

          {section_resources ++ processed_children, numbering_tracker, slugs}
        end
      )

    slug = Map.get(slugs, revision.title)

    # If the slug is a list it's because other resources in the hierarchy have the same title, so
    # we need to remove that slug from the list so it doesn't get used again
    {slug, slugs} =
      if is_list(slug) do
        slug = List.first(slug)

        slugs =
          Map.update(slugs, revision.title, [], fn slug_list ->
            Enum.filter(slug_list, &(&1 != slug))
          end)

        {slug, slugs}
      else
        {slug, slugs}
      end

    # Return the section resource for the revision along with all the section resources
    # for the revision's children
    section_resources = [
      # The below is necessary because Repo.insert_all/3 receives a map, not a struct
      # The below is necessary because Repo.insert_all/3 doesn't autogenerate values
      %SectionResource{
        numbering_index: numbering_index,
        numbering_level: level,
        slug: slug,
        collab_space_config: revision.collab_space_config,
        max_attempts: revision.max_attempts,
        resource_id: revision.resource_id,
        project_id: publication.project_id,
        scoring_strategy_id: revision.scoring_strategy_id,
        section_id: section.id
      }
      |> SectionResource.to_map()
      |> Map.delete(:id)
      |> Map.merge(%{
        inserted_at: date,
        updated_at: date
      })
      | children
    ]

    {section_resources, numbering_tracker, slugs}
  end

  def get_project_by_section_resource(section_id, resource_id) do
    Repo.one(
      from(s in SectionResource,
        join: p in Project,
        on: s.project_id == p.id,
        where: s.section_id == ^section_id and s.resource_id == ^resource_id,
        select: p
      )
    )
  end

  def get_section_resource(section_id, resource_id) do
    Repo.one(
      from(s in SectionResource,
        where: s.section_id == ^section_id and s.resource_id == ^resource_id,
        preload: [:scoring_strategy],
        select: s
      )
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
      on: true,
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

  def get_current_publications(section_id) do
    from(spp in SectionsProjectsPublications,
      join: pub in Publication,
      on: spp.publication_id == pub.id,
      where: spp.section_id == ^section_id,
      select: pub
    )
    |> Repo.all()
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
          Delivery.maybe_update_section_contains_deliberate_practice(section)
        end
      )
      |> Multi.run(
        :update_resource_to_container_map,
        fn _repo, _ ->
          update_resource_to_container_map(section)
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
          on_conflict:
            {:replace_all_except,
             [
               :inserted_at,
               :scoring_strategy_id,
               :scheduling_type,
               :manually_scheduled,
               :start_date,
               :end_date,
               :collab_space_config,
               :explanation_strategy,
               :max_attempts,
               :retake_mode,
               :password,
               :late_submit,
               :late_start,
               :time_limit,
               :grace_period,
               :review_submission,
               :feedback_mode,
               :feedback_scheduled_date
             ]},
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

      survey_id =
        Project
        |> where([p], p.id == ^section.base_project_id)
        |> select([p], p.required_survey_resource_id)
        |> Repo.one()

      create_nonstructural_section_resources(section_id, publication_ids,
        skip_resource_ids: processed_resource_ids,
        required_survey_resource_id: survey_id
      )

      # Rebuild section previous next index
      PreviousNextIndex.rebuild(section)

      {:ok, _} = rebuild_contained_pages(section, section_resources)
      {:ok, _} = rebuild_contained_objectives(section)
      {:ok, _} = rebuild_full_hierarchy(section)

      section_resources
    end)
  end

  def get_contained_pages(%Section{id: section_id}) do
    from(cp in ContainedPage,
      where: cp.section_id == ^section_id
    )
    |> Repo.all()
  end

  @doc """
  Rebuilds the full_hierachy field for a course section,
  needed as "cache" data for student's content view (OliWeb.Delivery.Student.ContentLive).
  The full hierarchy represents the main structure in which a course curriculum is organized
  to be delivered (see Oli.Delivery.Hierarchy)

  If `async` is set to true, the rebuild will be performed asynchronously relying on an Oban worker.
  """

  def rebuild_full_hierarchy(section, async \\ false)

  def rebuild_full_hierarchy(%Section{slug: slug} = section, false) do
    update_section(section, %{
      full_hierarchy: DeliveryResolver.full_hierarchy(slug)
    })
  end

  def rebuild_full_hierarchy(%Section{slug: slug} = _section, true) do
    RebuildFullHierarchyWorker.new(%{section_slug: slug})
    |> Oban.insert()
  end

  @doc """
  Rebuilds the "contained pages" relations for a course section.  A "contained page" for a
  container is the full set of pages found immeidately within that container or in any of
  its sub-containers.  For every container in a course section, one row will exist in this
  "contained pages" table for each contained page.  This allows a straightforward join through
  this relation from a container to then all of its contained pages - to power calculations like
  aggregating progress complete across all pages within a container.
  """
  def rebuild_contained_pages(%{id: section_id} = section) do
    section_resources =
      from(sr in SectionResource, where: sr.section_id == ^section_id)
      |> select([sr], %{id: sr.id, resource_id: sr.resource_id, children: sr.children})
      |> Repo.all()

    rebuild_contained_pages(section, section_resources)
  end

  def rebuild_contained_pages(
        %{slug: slug, id: section_id, root_section_resource_id: root_section_resource_id},
        section_resources
      ) do
    # First start be deleting all existing contained pages for this section.
    from(cp in ContainedPage, where: cp.section_id == ^section_id)
    |> Repo.delete_all()

    # We will need the set of resource ids for all containers in the hierarchy.
    container_type_id = Oli.Resources.ResourceType.get_id_by_type("container")

    container_ids =
      from([rev: rev] in Oli.Publishing.DeliveryResolver.section_resource_revisions(slug),
        where: rev.resource_type_id == ^container_type_id and rev.deleted == false,
        select: rev.resource_id
      )
      |> Repo.all()
      |> MapSet.new()

    # From the section resources, locate the root section resource, and also create a lookup map
    # from section_resource id to each section resource.
    root = Enum.find(section_resources, fn sr -> sr.id == root_section_resource_id end)
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
    case sr do
      nil ->
        %{}

      _ ->
        case Enum.map(sr.children, fn sr_id ->
               sr = Map.get(all, sr_id)

               case sr do
                 nil ->
                   nil

                 _ ->
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
               end
             end)
             |> Enum.filter(fn m -> !is_nil(m) end) do
          [] -> %{}
          other -> Enum.reduce(other, fn m, a -> Map.merge(m, a) end)
        end
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
  Rebuilds the "contained objectives" relations for a course section. A "contained objective" for a
  container is the full set of objectives found within the activities (within the pages) included in the container or in any of
  its sub-containers.  For every container in a course section, one row will exist in this
  "contained objectives" table for each contained objective. This allows a straightforward join through
  this relation from a container to then all of its contained objectives.
  It does not take into account the objectives attached to the pages within a container.

  There will be always at least one entry per objective with the container_id being nil, which represents the inclusion of the objective in the root container.
  """

  def rebuild_contained_objectives(section) do
    timestamps = %{
      inserted_at: {:placeholder, :now},
      updated_at: {:placeholder, :now}
    }

    placeholders = %{
      now: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    Multi.new()
    |> Multi.delete_all(
      :delete_all_objectives,
      from(ContainedObjective, where: [section_id: ^section.id])
    )
    |> Multi.run(:contained_objectives, &build_contained_objectives(&1, &2, section.slug))
    |> Multi.insert_all(
      :inserted_contained_objectives,
      ContainedObjective,
      &objectives_with_timestamps(&1, timestamps),
      placeholders: placeholders
    )
    |> Repo.transaction()
    |> case do
      {:ok, res} ->
        {:ok, res}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  def build_contained_objectives(repo, _changes, section_slug) do
    page_type_id = ResourceType.get_id_by_type("page")
    activity_type_id = ResourceType.get_id_by_type("activity")

    section_resource_pages =
      from(
        [sr: sr, rev: rev, s: s] in DeliveryResolver.section_resource_revisions(section_slug),
        where: not rev.deleted and rev.resource_type_id == ^page_type_id
      )

    section_resource_activities =
      from(
        [sr: sr, rev: rev, s: s] in DeliveryResolver.section_resource_revisions(section_slug),
        where: not rev.deleted and rev.resource_type_id == ^activity_type_id,
        select: rev
      )

    activity_references =
      from(
        rev in Revision,
        join: content_elem in fragment("jsonb_array_elements(?->'model')", rev.content),
        on: true,
        select: %{
          revision_id: rev.id,
          activity_id: fragment("(?->>'activity_id')::integer", content_elem)
        },
        where: fragment("?->>'type'", content_elem) == "activity-reference"
      )

    activity_objectives =
      from(
        rev in Revision,
        join: obj in fragment("jsonb_each_text(?)", rev.objectives),
        on: true,
        select: %{
          objective_revision_id: rev.id,
          objective_resource_id:
            fragment("jsonb_array_elements_text(?::jsonb)::integer", obj.value)
        },
        where: rev.deleted == false and rev.resource_type_id == ^activity_type_id
      )

    contained_objectives =
      from(
        [sr: sr, rev: rev, s: s] in section_resource_pages,
        join: cp in ContainedPage,
        on: cp.page_id == rev.resource_id and cp.section_id == s.id,
        join: ar in subquery(activity_references),
        on: ar.revision_id == rev.id,
        join: act in subquery(section_resource_activities),
        on: act.resource_id == ar.activity_id,
        join: ao in subquery(activity_objectives),
        on: ao.objective_revision_id == act.id,
        group_by: [cp.section_id, cp.container_id, ao.objective_resource_id],
        select: %{
          section_id: cp.section_id,
          container_id: cp.container_id,
          objective_id: ao.objective_resource_id
        }
      )
      |> repo.all()

    {:ok, contained_objectives}
  end

  defp objectives_with_timestamps(%{contained_objectives: contained_objectives}, timestamps) do
    Enum.map(contained_objectives, &Map.merge(&1, timestamps))
  end

  @doc """
  Returns the contained objectives for a given section and container.
  If the container id is nil, then it returns the contained objectives for the root container (all objectives of the section).
  """
  def get_section_contained_objectives(section_id, nil) do
    Repo.all(
      from(co in ContainedObjective,
        where: co.section_id == ^section_id and is_nil(co.container_id),
        select: co.objective_id
      )
    )
  end

  def get_section_contained_objectives(section_id, container_id) do
    Repo.all(
      from(co in ContainedObjective,
        where: [section_id: ^section_id, container_id: ^container_id],
        select: co.objective_id
      )
    )
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
              if section.blueprint.apply_major_updates do
                perform_update(:major, section, project_id, current_publication, new_publication)
              else
                perform_update(:minor, section, project_id, new_publication, current_hierarchy)
              end

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
          scoring_strategy_id: pr.revision.scoring_strategy_id,
          slug: Oli.Utils.Slug.generate("section_resources", pr.revision.title),
          inserted_at: {:placeholder, :timestamp},
          updated_at: {:placeholder, :timestamp}
        }
      end)
      |> then(
        &Repo.insert_all(SectionResource, &1,
          placeholders: placeholders,
          on_conflict:
            {:replace_all_except,
             [
               :inserted_at,
               :scoring_strategy_id,
               :scheduling_type,
               :manually_scheduled,
               :start_date,
               :end_date,
               :collab_space_config,
               :explanation_strategy,
               :max_attempts,
               :retake_mode,
               :password,
               :late_submit,
               :late_start,
               :time_limit,
               :grace_period,
               :review_submission,
               :feedback_mode,
               :feedback_scheduled_date
             ]},
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
          on_conflict:
            {:replace_all_except,
             [
               :inserted_at,
               :scoring_strategy_id,
               :scheduling_type,
               :manually_scheduled,
               :start_date,
               :end_date,
               :collab_space_config,
               :explanation_strategy,
               :max_attempts,
               :retake_mode,
               :password,
               :late_submit,
               :late_start,
               :time_limit,
               :grace_period,
               :review_submission,
               :feedback_mode,
               :feedback_scheduled_date
             ]},
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
      Delivery.maybe_update_section_contains_deliberate_practice(section)

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
            children: Enum.reverse(children_sr_ids),
            collab_space_config: revision.collab_space_config,
            max_attempts: revision.max_attempts || 0,
            scoring_strategy_id: revision.scoring_strategy_id,
            retake_mode: revision.retake_mode
          })
          |> Oli.Repo.insert!(
            # if there is a conflict on the unique section_id resource_id constraint,
            # we assume it is because a resource has been moved or removed/readded in
            # a remix operation, so we simply replace the existing section_resource record
            on_conflict:
              {:replace_all_except,
               [
                 :inserted_at,
                 :scoring_strategy_id,
                 :scheduling_type,
                 :manually_scheduled,
                 :start_date,
                 :end_date,
                 :collab_space_config,
                 :explanation_strategy,
                 :max_attempts,
                 :retake_mode,
                 :password,
                 :late_submit,
                 :late_start,
                 :time_limit,
                 :grace_period,
                 :review_submission,
                 :feedback_mode,
                 :feedback_scheduled_date
               ]},
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
         skip_resource_ids: skip_resource_ids,
         required_survey_resource_id: required_survey_resource_id
       ) do
    published_resources_by_resource_id =
      published_resources_map(publication_ids, preload: [:revision, :publication])

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # determine which pages are unreachable from the hierarchy, taking into account
    # the optional survey resource
    unreachable_page_resource_ids =
      case required_survey_resource_id do
        nil -> determine_unreachable_pages(publication_ids, skip_resource_ids)
        id -> determine_unreachable_pages(publication_ids, [id | skip_resource_ids])
      end

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
        updated_at: now,
        collab_space_config: revision.collab_space_config,
        max_attempts:
          if is_nil(revision.max_attempts) do
            0
          else
            revision.max_attempts
          end,
        scoring_strategy_id: revision.scoring_strategy_id,
        retake_mode: revision.retake_mode
      ]
    end)
    |> then(&Repo.insert_all(SectionResource, &1))
  end

  def is_structural?(%Revision{resource_type_id: resource_type_id}) do
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

    previous_next_index =
      previous_next_index
      |> Enum.map(fn {k, v} ->
        label =
          if Map.get(v, "type") === "container" do
            get_container_label(
              String.to_integer(Map.get(v, "level")),
              section.customizations || Map.from_struct(CustomLabels.default())
            )
          else
            ""
          end

        {k, Map.put(v, "label", label)}
      end)
      |> Map.new()

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
      [] ->
        []

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
      from([sr, s, _spp, _pr, rev] in DeliveryResolver.section_resource_revisions(section_slug),
        where:
          s.slug == ^section_slug and sr.numbering_level in [1, 2] and rev.resource_type_id == 2,
        select: %{
          id: rev.resource_id,
          title: rev.title,
          numbering_level: sr.numbering_level,
          numbering_index: sr.numbering_index
        }
      )

    case Repo.all(query) do
      [] -> {0, get_pages(section_slug)}
      containers -> {length(containers), containers}
    end
  end

  @doc """
  Returns the resources scheduled dates for a given student.
  Hard sceduled dates for a specific student take precedence over "global" hard scheduled dates.
  Global hard scheduled dates take precedence over soft scheduled dates.
  """
  def get_resources_scheduled_dates_for_student(section_slug, student_id) do
    get_soft_scheduled_dates(section_slug)
    |> Map.merge(get_hard_scheduled_dates(section_slug))
    |> Map.merge(get_hard_scheduled_dates_for_student(section_slug, student_id))
  end

  def get_soft_scheduled_dates(section_slug) do
    query =
      from([sr, _s, _spp, _pr, _rev] in DeliveryResolver.section_resource_revisions(section_slug),
        select: {
          sr.resource_id,
          %{end_date: sr.end_date, scheduled_type: sr.scheduling_type}
        }
      )

    Repo.all(query)
    |> Enum.into(%{})
  end

  def get_hard_scheduled_dates(section_slug) do
    query =
      from([_sr, s, _spp, _pr, _rev] in DeliveryResolver.section_resource_revisions(section_slug),
        join: gc in GatingCondition,
        on: gc.section_id == s.id,
        where: gc.type == :schedule and is_nil(gc.user_id),
        select: {
          gc.resource_id,
          %{
            end_date:
              fragment(
                "CASE WHEN ? = 'null' THEN NULL ELSE cast(cast(? as text) as date) END",
                gc.data["end_datetime"],
                gc.data["end_datetime"]
              ),
            scheduled_type: gc.type
          }
        }
      )

    Repo.all(query)
    |> Enum.into(%{})
  end

  def get_hard_scheduled_dates_for_student(section_slug, student_id) do
    query =
      from([_sr, s, _spp, _pr, _rev] in DeliveryResolver.section_resource_revisions(section_slug),
        join: gc in GatingCondition,
        on: gc.section_id == s.id,
        where: gc.type == :schedule and gc.user_id == ^student_id,
        select: {
          gc.resource_id,
          %{
            end_date:
              fragment(
                "CASE WHEN ? = 'null' THEN NULL ELSE cast(cast(? as text) as date) END",
                gc.data["end_datetime"],
                gc.data["end_datetime"]
              ),
            scheduled_type: gc.type
          }
        }
      )

    Repo.all(query)
    |> Enum.into(%{})
  end

  defp get_pages(section_slug) do
    query =
      from([sr, s, _spp, _pr, rev] in DeliveryResolver.section_resource_revisions(section_slug),
        where: s.slug == ^section_slug and rev.resource_type_id == 1,
        select: %{
          id: rev.resource_id,
          title: rev.title,
          numbering_index: sr.numbering_index
        }
      )

    Repo.all(query)
  end

  def get_student_pages(section_slug, user_id) do
    SectionResource
    |> join(:inner, [sr], s in Section, on: sr.section_id == s.id)
    |> join(:inner, [sr, s], spp in SectionsProjectsPublications,
      on: spp.section_id == s.id and spp.project_id == sr.project_id
    )
    |> join(:inner, [sr, _, spp], pr in PublishedResource,
      on: pr.publication_id == spp.publication_id and pr.resource_id == sr.resource_id
    )
    |> join(:inner, [sr, _, _, pr], rev in Revision, on: rev.id == pr.revision_id)
    |> join(:left, [sr], ds in Oli.Delivery.Settings.StudentException,
      on:
        ds.section_id == sr.section_id and ds.resource_id == sr.resource_id and
          ds.user_id == ^user_id
    )
    |> where([sr, s, _, _, _, ds], s.slug == ^section_slug)
    |> select([sr, s, _, _, rev, ds], %{
      id: sr.id,
      title: rev.title,
      slug: rev.slug,
      end_date:
        fragment(
          "coalesce(?, ?)",
          ds.end_date,
          sr.end_date
        ),
      scheduled_type: sr.scheduling_type,
      graded: rev.graded,
      resource_type_id: rev.resource_type_id,
      resource_id: rev.resource_id,
      numbering_level: sr.numbering_level,
      numbering_index: sr.numbering_index,
      scheduling_type: sr.scheduling_type,
      children: sr.children,
      section_id: s.id,
      relates_to: rev.relates_to
    })
    |> order_by([
      {:asc_nulls_last, fragment("end_date")},
      {:asc_nulls_last, fragment("numbering_level")},
      {:asc_nulls_last, fragment("numbering_index")}
    ])
  end

  @doc """
    Returns the latest page revision visited by a user in a section.
  """
  def get_latest_visited_page(section_slug, user_id) do
    from([rev: rev, s: s] in DeliveryResolver.section_resource_revisions(section_slug),
      join: e in Enrollment,
      on: e.section_id == s.id and rev.resource_id == e.most_recently_visited_resource_id,
      where: e.user_id == ^user_id and s.slug == ^section_slug,
      select: rev
    )
    |> Repo.one()
  end

  @doc """
    Returns the revision_ids of the pages visited by a user in a section.
    Instead of returning a list of revision_ids, it returns a map of revision_id to true,
    to make it more efficient to check if a page was visited (O(1) instead of O(n)).

    %{
      7185 => true,
      7349 => true
    }
  """
  def get_visited_pages(section_id, user_id) do
    page_resource_type_id = Oli.Resources.ResourceType.get_id_by_type("page")

    from(ra in ResourceAccess,
      join: r_att in ResourceAttempt,
      on: r_att.resource_access_id == ra.id,
      join: rev in Revision,
      on: r_att.revision_id == rev.id,
      where:
        rev.resource_type_id == ^page_resource_type_id and ra.section_id == ^section_id and
          ra.user_id == ^user_id,
      select: {rev.id, true}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Returns all the resource_ids of a section grouped by resource type.

  %{
    "activity" => [4630, 6927, 593],
    "container" => [7742, 7743, 7744, 7745],
    "objective" => [4260, 4249, 4308, 4309, 4277, 4254, 4316],
    "page" => [7400, 7568, 7436, 7714, 7165, 7433, 7181, 7451, 7592, 7449, 7587,
    7638, 7286, 7564, 7244, 7172, 7404, 7424],
    "tag" => [3986, 4035, 4102, 3959, 4205, 3975, 4235, 4134, 4087, 4075, 4165,
    4036, 4052, 3973, 4023, 4030]
  }
  """

  def get_resource_ids_group_by_resource_type(section_slug) do
    from([_sr, _s, _spp, _pr, rev] in DeliveryResolver.section_resource_revisions(section_slug),
      join: rt in ResourceType,
      on: rt.id == rev.resource_type_id,
      select: {rt.type, rev.resource_id}
    )
    |> Repo.all()
    |> Enum.group_by(fn {resource_type, _resource_id} -> resource_type end, fn {_, resource_id} ->
      resource_id
    end)
  end

  @doc """
    Returns the activities that a student need to complete next.
  """
  def get_next_activities_for_student(section_slug, user_id, session_context) do
    student_pages_query = get_student_pages(section_slug, user_id)

    query =
      from(sp in subquery(student_pages_query),
        where:
          not is_nil(sp.end_date) and
            sp.end_date >= ^DateTime.utc_now() and
            sp.resource_type_id == ^ResourceType.get_id_by_type("page"),
        limit: 2
      )

    query
    |> Repo.all()
    |> Enum.map(
      &Map.merge(
        &1,
        %{
          end_date:
            if is_nil(&1.end_date) do
              nil
            else
              OliWeb.Common.FormatDateTime.date(&1.end_date, session_context)
            end,
          progress:
            Oli.Delivery.Metrics.progress_for_page(
              &1.section_id,
              user_id,
              &1.resource_id
            ) * 100,
          completion_percentage:
            Oli.Delivery.Metrics.completion_for(
              &1.section_id,
              &1.resource_id
            )
        }
      )
    )
  end

  defp to_datetime(nd) do
    DateTime.from_naive!(nd, "Etc/UTC")
  end

  @doc """
    Returns the graded pages and their due dates for a given student.
  """
  def get_graded_pages(section_slug, user_id) do
    student_pages_query = get_student_pages(section_slug, user_id)

    {graded_pages_with_date, other_resources} =
      Repo.all(from(sp in subquery(student_pages_query)))
      |> Enum.uniq_by(& &1.id)
      |> Enum.split_with(fn page ->
        page.end_date != nil and page.graded == true and
          page.resource_type_id == ResourceType.get_id_by_type("page")
      end)

    (graded_pages_with_date ++ get_graded_pages_without_date(other_resources))
    |> append_related_resources(user_id)
    |> Enum.map(fn sr ->
      Map.put(
        sr,
        :end_date,
        if is_nil(sr.end_date) do
          nil
        else
          to_datetime(sr.end_date)
        end
      )
    end)
  end

  defp get_graded_pages_without_date([]), do: []

  defp get_graded_pages_without_date(resources) do
    {root_container, graded_pages} = get_root_container_and_graded_pages(resources)

    graded_page_map = Enum.reduce(graded_pages, %{}, fn p, m -> Map.put(m, p.id, p) end)

    {reachable_graded_pages, unreachable_graded_pages} =
      get_flatten_hierarchy(
        (root_container || %{})[:children],
        resources
      )
      |> Enum.reduce({[], graded_page_map}, fn id, {acc, remaining} ->
        case Map.get(remaining, id) do
          nil -> {acc, remaining}
          page -> {[page | acc], Map.delete(remaining, id)}
        end
      end)

    Enum.reverse(reachable_graded_pages) ++
      (Map.values(unreachable_graded_pages)
       |> Enum.sort_by(&{&1.numbering_level, &1.numbering_index}))
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

  @doc """
  Returns all objectives and subobjectives for a given section, with associated proficiency
  results generally available in the form:
  %{
    objective: "Parent Objective Title"
    objective_resource_id: 231,
    student_proficiency_obj: "High"
    subobjective: "Subobjective Title",
    subobjective_resource_id: 388,
    student_proficiency_subobj: "Low"
  }

  For objectives that are subobjectives, the objective is shown as the `subobjective` like the
  above example, with the aggregated proficiency for its parent shown.  For objectives that are
  top level objectives, they appear with their proficiency for only those activities that
  directly attached to them.
  """
  def get_objectives_and_subobjectives(%Section{slug: section_slug} = section, student_id \\ nil) do
    calc = fn count, total ->
      case total do
        0 -> nil
        _ -> count / total
      end
    end

    proficiency_per_learning_objective =
      case student_id do
        nil ->
          Metrics.raw_proficiency_per_learning_objective(section)

        student_id ->
          Metrics.raw_proficiency_for_student_per_learning_objective(section, student_id)
      end

    # get the minimal fields for all objectives from the database
    objective_id = Oli.Resources.ResourceType.get_id_by_type("objective")

    objectives =
      from([rev: rev, s: s] in DeliveryResolver.section_resource_revisions(section_slug))
      |> join_contained_objectives(section.v25_migration)
      |> where([rev: rev, s: s], rev.deleted == false and rev.resource_type_id == ^objective_id)
      |> group_by([rev: rev], [rev.title, rev.resource_id, rev.children])
      |> select([rev: rev, co: co], %{
        title: rev.title,
        resource_id: rev.resource_id,
        children: rev.children,
        container_ids: fragment("array_agg(DISTINCT ?)", co.container_id)
      })
      |> Repo.all()

    lookup_map =
      Enum.reduce(objectives, %{}, fn obj, acc ->
        Map.put(acc, obj.resource_id, obj)
      end)

    # identify top level objectives (those that don't have a parent)
    parent_map =
      Enum.reduce(objectives, %{}, fn obj, acc ->
        Enum.reduce(obj.children, acc, fn child, acc ->
          Map.put(acc, child, obj.resource_id)
        end)
      end)

    top_level_objectives =
      Enum.filter(objectives, fn obj ->
        !Map.has_key?(parent_map, obj.resource_id)
      end)

    # Now calculate the aggregate proficiency for each top level objective
    top_level_aggregation =
      Enum.reduce(top_level_objectives, %{}, fn obj, map ->
        aggregation =
          Enum.reduce(obj.children, {0, 0}, fn child, {correct, total} ->
            {child_correct, child_total} =
              Map.get(proficiency_per_learning_objective, child, {0, 0})

            {correct + child_correct, total + child_total}
          end)

        Map.put(map, obj.resource_id, aggregation)
      end)

    # Now make a pass over top level objectives, and for each one, pull in its subobjectives.
    # We have to take this approach to account for the fact that a sub objective can have
    # multiple parents.
    Enum.reduce(objectives, [], fn objective, all ->
      case Map.has_key?(parent_map, objective.resource_id) do
        # this is a top-level objective
        false ->
          {correct, total} =
            Map.get(proficiency_per_learning_objective, objective.resource_id, {0, 0})

          objective =
            Map.merge(objective, %{
              objective: objective.title,
              objective_resource_id: objective.resource_id,
              student_proficiency_obj: calc.(correct, total) |> Metrics.proficiency_range(),
              subobjective: "",
              subobjective_resource_id: nil,
              student_proficiency_subobj: ""
            })

          {parent_correct, parent_total} =
            Map.get(top_level_aggregation, objective.resource_id, {0, 0})

          sub_objectives =
            Enum.map(objective.children, fn child ->
              sub_objective = Map.get(lookup_map, child)

              {correct, total} =
                Map.get(proficiency_per_learning_objective, sub_objective.resource_id, {0, 0})

              Map.merge(sub_objective, %{
                objective: objective.title,
                objective_resource_id: objective.resource_id,
                student_proficiency_obj:
                  calc.(parent_correct, parent_total) |> Metrics.proficiency_range(),
                subobjective: sub_objective.title,
                subobjective_resource_id: sub_objective.resource_id,
                student_proficiency_subobj: calc.(correct, total) |> Metrics.proficiency_range()
              })
            end)

          [objective | sub_objectives] ++ all

        # this is a subobjective, we do nothing as it will be handled in the context of its parent(s)
        _ ->
          all
      end
    end)
  end

  _docp = """
    Join to take into account sections that have already created the contained objectives.
    This will filter out any objective directly attached to a page, and will only consider objectives attached to activities.
  """

  defp join_contained_objectives(query, :done),
    do:
      join(query, :inner, [rev: rev], co in ContainedObjective,
        as: :co,
        on: co.objective_id == rev.resource_id
      )

  _docp = """
    Join to take into account sections that have no contained objectives yet.
    This will still return objectives attached to pages but not to activities, just to be consistent with how it used to work until we migrate all sections.
  """

  defp join_contained_objectives(query, _),
    do:
      join(query, :left, [rev: rev], co in ContainedObjective,
        as: :co,
        on: co.objective_id == rev.resource_id
      )

  @doc """
  Maps each resource with its parent container label, being the label (if any) like
  <Container Label> <Numbering Index>: <Container Title>

  For example:

  %{1: "Unit 1: Basics", 15: nil, 45: "Module 3: Enumerables"}
  """
  def map_resources_with_container_labels(section_slug, resource_ids) do
    resource_type_id = Oli.Resources.ResourceType.get_id_by_type("container")

    containers =
      from([sr, s, spp, _pr, rev] in DeliveryResolver.section_resource_revisions(section_slug),
        join: p in Project,
        on: p.id == spp.project_id,
        where: s.slug == ^section_slug and rev.resource_type_id == ^resource_type_id,
        select: %{
          id: rev.resource_id,
          title: rev.title,
          numbering_level: sr.numbering_level,
          numbering_index: sr.numbering_index,
          children: rev.children,
          customizations: p.customizations
        }
      )
      |> Repo.all()

    Enum.map(resource_ids, fn page_id ->
      {page_id,
       case Enum.find(containers, fn container ->
              page_id in container.children
            end) do
         nil ->
           nil

         %{numbering_level: 0} ->
           nil

         c ->
           ~s{#{get_container_label(c.numbering_level, c.customizations || Map.from_struct(CustomLabels.default()))} #{c.numbering_index}: #{c.title}}
       end}
    end)
    |> Enum.into(%{})
  end

  defp get_container_label(
         numbering_level,
         customizations
       ) do
    case numbering_level do
      1 -> Map.get(customizations, :unit)
      2 -> Map.get(customizations, :module)
      _ -> Map.get(customizations, :section)
    end
  end

  def get_units_and_modules_from_a_section(section_slug) do
    all =
      Repo.all(
        from(
          [sr: sr, rev: rev, s: s] in DeliveryResolver.section_resource_revisions(section_slug),
          join: cp in ContainedPage,
          on: cp.container_id == rev.resource_id,
          where: rev.deleted == false and s.slug == ^section_slug and rev.resource_type_id == 2,
          group_by: [cp.container_id, rev.title, sr.numbering_level, rev.children],
          order_by: [asc: rev.title],
          select: %{
            container_id: cp.container_id,
            title: rev.title,
            level: sr.numbering_level,
            children: rev.children
          }
        )
      )

    # This is map used to get the name of a module's parent unit title
    # so that we can display a module as "Unit Title / Module Title"
    # instead of just "Module Title"

    parent_title_map =
      Enum.reduce(all, %{}, fn %{children: children} = elem, map ->
        Enum.reduce(children, map, fn child, map -> Map.put(map, child, elem.title) end)
      end)

    Enum.map(all, fn %{children: children} = elem ->
      children_from_children =
        all
        |> Enum.filter(fn %{container_id: container_id} -> container_id in children end)
        |> Enum.flat_map(fn child_map ->
          child_map[:children]
        end)

      elem = %{elem | children: children ++ children_from_children}

      if elem.level == 2 do
        # Determine the parent unit title, in a robust way that works even if the
        # somehow the module is not contained in a unit
        parent_title = Map.get(parent_title_map, elem.container_id, "Unknown")

        Map.put(
          elem,
          :title,
          "#{parent_title} / #{elem.title}"
        )
      else
        elem
      end
    end)
    |> Enum.sort_by(& &1.title)
  end

  defp do_get_survey(section_slug) do
    Section
    |> join(:inner, [s], spp in SectionsProjectsPublications, on: spp.section_id == s.id)
    |> join(:inner, [_, spp], pr in PublishedResource,
      on: pr.publication_id == spp.publication_id
    )
    |> join(:inner, [_, _, pr], rev in Revision, on: pr.revision_id == rev.id)
    |> join(:inner, [s], proj in Project, on: proj.id == s.base_project_id)
    |> where(
      [s, spp, _, pr, proj],
      s.slug == ^section_slug and
        spp.project_id == s.base_project_id and
        spp.section_id == s.id and
        (pr.resource_id == s.required_survey_resource_id or
           pr.resource_id == proj.required_survey_resource_id)
    )
    |> select([_, _, _, rev], rev)
  end

  def get_base_project_survey(section_slug) do
    do_get_survey(section_slug)
    |> where([s, spp, _, pr, proj], pr.resource_id == proj.required_survey_resource_id)
    |> limit(1)
    |> Repo.one()
  end

  def get_survey(section_slug) do
    do_get_survey(section_slug)
    |> where([s, spp, _, pr, proj], pr.resource_id == s.required_survey_resource_id)
    |> limit(1)
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
    case get_base_project_survey(section.slug) do
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

  @spec has_visited_section(map, map) :: boolean
  def has_visited_section(section, user) do
    required_survey_filter =
      if section.required_survey_resource_id,
        do: dynamic([ra], ra.resource_id != ^section.required_survey_resource_id),
        else: true

    has_resource_accesses =
      ResourceAccess
      |> where(
        [ra],
        ra.user_id == ^user.id and ra.section_id == ^section.id
      )
      |> where(^required_survey_filter)
      |> select([ra], ra.id)
      |> Repo.all()
      |> length()
      |> Kernel.>(0)

    case has_resource_accesses do
      # If the user already has a resource access, they have already visited the section
      true ->
        true

      # If the user doesn't, check if the visited flag in the enrollment state is true
      false ->
        visited_section_key = Oli.Delivery.ExtrinsicState.Key.has_visited_once()

        state =
          case Oli.Delivery.ExtrinsicState.read_section(user.id, section.slug) do
            {:ok, state} -> state
            _ -> %{}
          end

        !is_nil(state[visited_section_key])
    end
  end

  @spec mark_section_visited_for_student(map, map) :: {:ok, map}
  def mark_section_visited_for_student(section, user) do
    visited_section_key = Oli.Delivery.ExtrinsicState.Key.has_visited_once()

    Oli.Delivery.ExtrinsicState.upsert_section(
      user.id,
      section.slug,
      Map.put(%{}, visited_section_key, true)
    )
  end

  @doc """
  Get all the revisions that have numbering_index for a given section.
  ## Examples
      iex> get_revision_indexes("test_section")
      [%{numbering_index: 1, slug: "revision_x"}, %{numbering_index: 2, slug: "revision_y"}]
  """
  def get_revision_indexes(section_slug) do
    from([sr, s, _spp, _pr, rev] in DeliveryResolver.section_resource_revisions(section_slug),
      where:
        s.slug == ^section_slug and rev.resource_type_id == 1 and not is_nil(sr.numbering_index),
      select: %{
        slug: rev.slug,
        numbering_index: sr.numbering_index
      },
      order_by: [asc: sr.numbering_index]
    )
    |> Repo.all()
  end

  @doc """
  Get the revision for a section given the revision numbering_index
  ## Examples
      iex> get_revision_by_index(3)
      %{slug: "revision_x", numbering_index: 3}
      iex> get_revision_by_index(12)
      nil
  """
  def get_revision_by_index(section_slug, numbering_index) when is_number(numbering_index) do
    from([sr, s, _spp, _pr, rev] in DeliveryResolver.section_resource_revisions(section_slug),
      where:
        s.slug == ^section_slug and rev.resource_type_id == 1 and
          sr.numbering_index == ^numbering_index,
      select: %{
        slug: rev.slug,
        numbering_index: sr.numbering_index,
        resource_type_id: rev.resource_type_id
      },
      limit: 1
    )
    |> Repo.one()
  end

  def get_revision_by_index(_, _), do: nil

  @doc """
  Get all students for a given section with their enrollment date.
  """

  def get_students_for_section_with_enrollment_date(section_id) do
    student_context_role_id = ContextRoles.get_role(:context_learner).id

    Repo.all(
      from(enrollment in Enrollment,
        join: enrollment_context_role in EnrollmentContextRole,
        on: enrollment_context_role.enrollment_id == enrollment.id,
        join: user in User,
        on: enrollment.user_id == user.id,
        where:
          enrollment.section_id == ^section_id and
            enrollment_context_role.context_role_id == ^student_context_role_id,
        select: {user, enrollment}
      )
    )
    |> Enum.map(fn {user, enrollment} ->
      Map.put(user, :enrollment_date, enrollment.inserted_at)
    end)
    |> Enum.sort_by(fn user -> user.name end)
  end

  @doc """
    Get all instructors for a given section.
  """
  def get_instructors_for_section(section_id) do
    instructor_context_role_id = ContextRoles.get_role(:context_instructor).id

    Repo.all(
      from(enrollment in Enrollment,
        join: enrollment_context_role in EnrollmentContextRole,
        on: enrollment_context_role.enrollment_id == enrollment.id,
        join: user in User,
        on: enrollment.user_id == user.id,
        where:
          enrollment.section_id == ^section_id and
            enrollment_context_role.context_role_id == ^instructor_context_role_id,
        select: user
      )
    )
  end

  @doc """
    Get all sections filtered by the clauses passed as the first argument.
    The second argument is a list of fields to be selected from the Section table.
    If the second argument is not passed, all fields will be selected.
  """
  def get_sections_by(clauses, select_fields \\ nil) do
    Section
    |> from(where: ^clauses)
    |> maybe_select_section_fields(select_fields)
    |> Repo.all()
  end

  defp maybe_select_section_fields(query, nil), do: query

  defp maybe_select_section_fields(query, select_fields),
    do: select(query, [s], struct(s, ^select_fields))
end
