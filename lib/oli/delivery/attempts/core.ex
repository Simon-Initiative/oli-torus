defmodule Oli.Delivery.Attempts.Core do
  import Ecto.Query, warn: false

  alias Oli.Repo

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.PublishedResource
  alias Oli.Resources.Revision

  alias Oli.Delivery.Attempts.Core.{
    PartAttempt,
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt
  }

  @doc """
  Creates or updates an access record for a given resource, section context id and user. When
  created the access count is set to 1, otherwise on updates the
  access count is incremented.
  ## Examples
      iex> track_access(resource_id, section_slug, user_id)
      {:ok, %ResourceAccess{}}
      iex> track_access(resource_id, section_slug, user_id)
      {:error, %Ecto.Changeset{}}
  """
  def track_access(resource_id, section_slug, user_id) do
    section = Sections.get_section_by(slug: section_slug)

    Oli.Repo.insert!(
      %ResourceAccess{
        access_count: 1,
        user_id: user_id,
        section_id: section.id,
        resource_id: resource_id
      },
      on_conflict: [inc: [access_count: 1]],
      conflict_target: [:resource_id, :user_id, :section_id]
    )
  end

  @doc """
  Retrieves all graded resource access for a given context

  `[%ResourceAccess{}, ...]`
  """
  def get_graded_resource_access_for_context(section_slug) do
    Repo.all(
      from(a in ResourceAccess,
        join: s in Section,
        on: a.section_id == s.id,
        join: p in PublishedResource,
        on: s.publication_id == p.publication_id,
        join: r in Revision,
        on: p.revision_id == r.id,
        where: s.slug == ^section_slug and s.status != :deleted and r.graded == true,
        select: a
      )
    )
  end

  @doc """
  Retrieves all graded resource access for a given context

  `[%ResourceAccess{}, ...]`
  """
  def get_resource_access_for_page(section_slug, resource_id) do
    Repo.all(
      from(a in ResourceAccess,
        join: s in Section,
        on: a.section_id == s.id,
        join: p in PublishedResource,
        on: s.publication_id == p.publication_id,
        join: r in Revision,
        on: p.revision_id == r.id,
        where:
          s.slug == ^section_slug and s.status != :deleted and r.graded == true and
            r.resource_id == ^resource_id,
        select: a
      )
    )
  end

  @doc """
  Retrieves all resource accesses for a given context and user

  `[%ResourceAccess{}, ...]`
  """
  def get_user_resource_accesses_for_context(section_slug, user_id) do
    Repo.all(
      from(a in ResourceAccess,
        join: s in Section,
        on: a.section_id == s.id,
        join: p in PublishedResource,
        on: s.publication_id == p.publication_id,
        join: r in Revision,
        on: p.revision_id == r.id,
        where: s.slug == ^section_slug and s.status != :deleted and a.user_id == ^user_id,
        distinct: a.id,
        select: a
      )
    )
  end

  def get_resource_access(resource_id, section_slug, user_id) do
    Repo.one(
      from(a in ResourceAccess,
        join: s in Section,
        on: a.section_id == s.id,
        where:
          a.user_id == ^user_id and s.slug == ^section_slug and s.status != :deleted and
            a.resource_id == ^resource_id,
        select: a
      )
    )
  end

  def get_part_attempts_and_users_for_publication(publication_id) do
    student_role_id = Lti_1p3.Tool.ContextRoles.get_role(:context_learner).id

    Repo.all(
      from(section in Section,
        join: enrollment in Enrollment,
        on: enrollment.section_id == section.id,
        join: user in Oli.Accounts.User,
        on: enrollment.user_id == user.id,
        join: raccess in ResourceAccess,
        on: user.id == raccess.user_id,
        join: rattempt in ResourceAttempt,
        on: raccess.id == rattempt.resource_access_id,
        join: aattempt in ActivityAttempt,
        on: rattempt.id == aattempt.resource_attempt_id,
        join: pattempt in PartAttempt,
        on: aattempt.id == pattempt.activity_attempt_id,
        where: section.publication_id == ^publication_id,

        # only fetch records for users enrolled as students
        left_join: er in "enrollments_context_roles",
        on: enrollment.id == er.enrollment_id,
        left_join: context_role in Lti_1p3.DataProviders.EctoProvider.ContextRole,
        on: er.context_role_id == context_role.id and context_role.id == ^student_role_id,
        select: %{part_attempt: pattempt, user: user}
      )
    )
    # TODO: This should be done in the query, but can't get the syntax right
    |> Enum.map(
      &%{
        user: &1.user,
        part_attempt:
          Repo.preload(&1.part_attempt,
            activity_attempt: [:revision, revision: :activity_type, resource_attempt: :revision]
          )
      }
    )
  end

  def has_any_active_attempts?(resource_attempts) do
    Enum.any?(resource_attempts, fn r -> r.date_evaluated == nil end)
  end

  @doc """
  Gets a section by activity attempt guid.
  ## Examples
      iex> get_section_by_activity_attempt_guid("123")
      %Section{}
      iex> get_section_by_activity_attempt_guid("111")
      nil
  """
  def get_section_by_activity_attempt_guid(activity_attempt_guid) do
    Repo.one(
      from(activity_attempt in ActivityAttempt,
        join: resource_attempt in ResourceAttempt,
        on: resource_attempt.id == activity_attempt.resource_attempt_id,
        join: resource_access in ResourceAccess,
        on: resource_access.id == resource_attempt.resource_access_id,
        join: section in Section,
        on: section.id == resource_access.section_id,
        where: activity_attempt.attempt_guid == ^activity_attempt_guid,
        select: section
      )
    )
  end

  def get_latest_part_attempts(activity_attempt_guid) do
    Repo.all(
      from(aa in ActivityAttempt,
        join: pa1 in PartAttempt,
        on: aa.id == pa1.activity_attempt_id,
        left_join: pa2 in PartAttempt,
        on:
          aa.id == pa2.activity_attempt_id and pa1.part_id == pa2.part_id and pa1.id < pa2.id and
            pa1.activity_attempt_id == pa2.activity_attempt_id,
        where: aa.attempt_guid == ^activity_attempt_guid and is_nil(pa2),
        select: pa1
      )
    )
  end

  @doc """
  Retrieves the latest resource attempt for a given resource id,
  context id and user id.  If no attempts exist, returns nil.
  """
  def get_latest_resource_attempt(resource_id, section_slug, user_id) do
    Repo.one(
      from(a in ResourceAccess,
        join: s in Section,
        on: a.section_id == s.id,
        join: ra1 in ResourceAttempt,
        on: a.id == ra1.resource_access_id,
        left_join: ra2 in ResourceAttempt,
        on:
          a.id == ra2.resource_access_id and ra1.id < ra2.id and
            ra1.resource_access_id == ra2.resource_access_id,
        where:
          a.user_id == ^user_id and s.slug == ^section_slug and s.status != :deleted and
            a.resource_id == ^resource_id and
            is_nil(ra2),
        select: ra1
      )
    )
    |> Repo.preload([:revision])
  end

  @doc """
  Retrieves the resource access record and all (if any) attempts related to it
  in a two element tuple of the form:

  `{%ResourceAccess, [%ResourceAttempt{}]}`

  The empty list `[]` will be present if there are no resource attempts.
  """
  def get_resource_attempt_history(resource_id, section_slug, user_id) do
    access = get_resource_access(resource_id, section_slug, user_id)

    id = access.id

    attempts =
      Repo.all(
        from(ra in ResourceAttempt,
          where: ra.resource_access_id == ^id,
          select: ra,
          preload: [:revision]
        )
      )

    attempt_representation =
      case attempts do
        nil -> []
        records -> records
      end

    {access, attempt_representation}
  end

  @doc """
  Retrieves all graded resource attempts for a given resource access.

  `[%ResourceAccess{}, ...]`
  """
  def get_graded_attempts_from_access(resource_access_id) do
    Repo.all(
      from(a in ResourceAttempt,
        join: r in Revision,
        on: a.revision_id == r.id,
        where: a.resource_access_id == ^resource_access_id and r.graded == true,
        select: a
      )
    )
  end

  @doc """
  Gets a collection of activity attempt records that pertain to a collection of activity
  attempt guids. There is no guarantee that the ordering of the results of the activity attempts
  will match the ordering of the input guids.  Any attempt guids that cannot be found are simply omitted
  from the result.
  ## Examples
      iex> get_activity_attempts(["20595ef0-e5f1-474e-880d-f2c20f3a4459", "30b59817-e193-488f-94b1-597420b8670e"])
      {:ok, [%ActivityAttempt{}, %ActivityAttempt{}]
      iex> get_activity_attempts(["20595ef0-e5f1-474e-880d-f2c20f3a4459", "a-missing-one"])
      {:ok, [%ActivityAttempt{}]}
      iex> get_activity_attempts(["a-missing-one"])
      {:ok, []}
  """
  def get_activity_attempts(activity_attempt_guids) do
    results =
      Repo.all(
        from(activity_attempt in ActivityAttempt,
          where: activity_attempt.attempt_guid in ^activity_attempt_guids,
          preload: [:part_attempts]
        )
      )

    {:ok, results}
  end

  @doc """
  Gets an activity attempt by a clause.
  ## Examples
      iex> get_activity_attempt_by(attempt_guid: "123")
      %ActivityAttempt
      iex> get_activity_attempt_by(attempt_guid: "111")
      nil
  """
  def get_activity_attempt_by(clauses),
    do: Repo.get_by(ActivityAttempt, clauses) |> Repo.preload(revision: [:activity_type])

  @doc """
  Gets a part attempt by a clause.
  ## Examples
      iex> get_part_attempt_by(attempt_guid: "123")
      %PartAttempt{}
      iex> get_part_attempt_by(attempt_guid: "111")
      nil
  """
  def get_part_attempt_by(clauses), do: Repo.get_by(PartAttempt, clauses)

  @doc """
  Gets a resource attempt by a clause.
  ## Examples
      iex> get_resource_attempt_by(attempt_guid: "123")
      %ResourceAttempt{}
      iex> get_resource_attempt_by(attempt_guid: "111")
      nil
  """
  def get_resource_attempt_by(clauses),
    do: Repo.get_by(ResourceAttempt, clauses) |> Repo.preload([:activity_attempts, :revision])

  @doc """
  Creates a part attempt.
  ## Examples
      iex> create_part_attempt(%{field: value})
      {:ok, %PartAttempt{}}
      iex> create_part_attempt(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_part_attempt(attrs \\ %{}) do
    %PartAttempt{}
    |> PartAttempt.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a part attempt.
  ## Examples
      iex> update_part_attempt(part_attempt, %{field: new_value})
      {:ok, %PartAttempt{}}
      iex> update_part_attempt(part_attempt, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_part_attempt(part_attempt, attrs) do
    PartAttempt.changeset(part_attempt, attrs)
    |> Repo.update()
  end

  @doc """
  Creates a resource attempt.
  ## Examples
      iex> create_resource_attempt(%{field: value})
      {:ok, %ResourceAttempt{}}
      iex> create_resource_attempt(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_resource_attempt(attrs \\ %{}) do
    %ResourceAttempt{}
    |> ResourceAttempt.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an activity attempt.
  ## Examples
      iex> update_activity_attempt(revision, %{field: new_value})
      {:ok, %ActivityAttempt{}}
      iex> update_activity_attempt(revision, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_activity_attempt(activity_attempt, attrs) do
    ActivityAttempt.changeset(activity_attempt, attrs)
    |> Repo.update()
  end

  @doc """
  Updates an resource access.
  ## Examples
      iex> update_resource_access(revision, %{field: new_value})
      {:ok, %ResourceAccess{}}
      iex> update_resource_access(revision, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource_access(activity_attempt, attrs) do
    ResourceAccess.changeset(activity_attempt, attrs)
    |> Repo.update()
  end

  @doc """
  Creates an activity attempt.
  ## Examples
      iex> create_activity_attempt(%{field: value})
      {:ok, %ActivityAttempt{}}
      iex> create_activity_attempt(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_activity_attempt(attrs \\ %{}) do
    %ActivityAttempt{}
    |> ActivityAttempt.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a resource attempt.
  ## Examples
      iex> update_resource_attempt(revision, %{field: new_value})
      {:ok, %ResourceAttempt{}}
      iex> update_resource_attempt(revision, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource_attempt(resource_attempt, attrs) do
    ResourceAttempt.changeset(resource_attempt, attrs)
    |> Repo.update()
  end

  @doc """
  Gets a resource attempt by parameter.
  ## Examples
      iex> get_resource_attempt(attempt_guid: "123")
      %ResourceAttempt{}
      iex> get_resource_attempt(attempt_guid: "notfound")
      nil
  """
  def get_resource_attempt(clauses),
    do: Repo.get_by(ResourceAttempt, clauses)
end
