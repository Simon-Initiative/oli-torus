defmodule Oli.Delivery.Attempts.Core do
  import Ecto.Query, warn: false

  require Logger

  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.PublishedResource
  alias Oli.Resources.Revision
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Accounts.User

  alias Oli.Delivery.Attempts.Core.{
    PartAttempt,
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt,
    LMSGradeUpdate,
    GradeUpdateBrowseOptions
  }

  def get_user_from_attempt(%ResourceAttempt{resource_access_id: resource_access_id}) do
    query =
      from(access in ResourceAccess,
        join: user in User,
        on: access.user_id == user.id,
        select: user,
        where: access.id == ^resource_access_id
      )

    Repo.one(query)
  end

  def get_user_from_attempt_guid(attempt_guid) do
    query =
      from(access in ResourceAccess,
        join: attempt in ResourceAttempt,
        on: access.id == attempt.resource_access_id,
        join: user in User,
        on: access.user_id == user.id,
        select: user,
        where: attempt.attempt_guid == ^attempt_guid
      )

    Repo.one(query)
  end

  @doc """
  For a given user, section, and resource id, determine whether any resource attempts are
  present.
  """
  def has_any_attempts?(%User{id: user_id}, %Section{id: section_id}, resource_id) do
    query =
      from(access in ResourceAccess,
        join: attempt in ResourceAttempt,
        on: access.id == attempt.resource_access_id,
        select: count(attempt.id),
        where:
          access.user_id == ^user_id and access.section_id == ^section_id and
            access.resource_id == ^resource_id
      )

    Repo.one(query) > 0
  end

  def browse_lms_grade_updates(
        %Paging{limit: limit, offset: offset},
        %Sorting{field: field, direction: direction},
        %GradeUpdateBrowseOptions{section_id: section_id} = options
      ) do
    by_section = dynamic([_, ra, _], ra.section_id == ^section_id)

    filter_by_user =
      if is_nil(options.user_id) do
        true
      else
        dynamic([_, _, u], u.id == ^options.user_id)
      end

    filter_by_text =
      if options.text_search == "" or is_nil(options.text_search) do
        true
      else
        text_search = String.trim(options.text_search)

        dynamic(
          [g, _, u],
          ilike(g.details, ^"%#{text_search}%") or
            ilike(g.result, ^"%#{text_search}%") or
            ilike(u.email, ^"%#{text_search}%")
        )
      end

    query =
      LMSGradeUpdate
      |> join(:left, [g], ra in ResourceAccess, on: g.resource_access_id == ra.id)
      |> join(:left, [_, ra], u in Oli.Accounts.User, on: ra.user_id == u.id)
      |> where(^by_section)
      |> where(^filter_by_text)
      |> where(^filter_by_user)
      |> limit(^limit)
      |> offset(^offset)
      |> select_merge([_, _, u], %{
        user_email: u.email,
        total_count: fragment("count(*) OVER()")
      })

    query =
      case field do
        :user_email -> order_by(query, [_, _, u], {^direction, u.email})
        _ -> order_by(query, [p, _], {^direction, field(p, ^field)})
      end

    Repo.all(query)
  end

  @doc """
  Select the model to use to power all aspects of an activity.  If an activity utilizes
  transformations, the transformed model will be stored on the activity attempt in the
  `transformed_model` attribute.  Otherwise, that field will be `nil` indicating that the
  original model from the revision of the activity should be used.  Allowing the
  `transformed_model` to be nil is a significant storage and performance optimization,
  particularly when the size and number of activities within a page becomes large.

  This variant of this function allows the activity attempt and the revision to be passed
  as separate arguments to support workflows where the revision is not expected to be
  preloaded in the activity attempt. In situations where that revision is expected to be
  preloaded, `select_model/1` can be used instead.

  In both variants, a robustness feature exists that will inline retrieve the revision,
  if needed and not specified.  This is clearly to prevent functional problems, but it can
  lead to performance issues if done across a collection.  A warning is logged in this
  case.
  """
  def select_model(%ActivityAttempt{transformed_model: nil, revision_id: revision_id}, nil) do
    perform_inline_fetch(revision_id)
  end

  def select_model(%ActivityAttempt{transformed_model: nil}, %Oli.Resources.Revision{
        content: content
      }) do
    content
  end

  def select_model(%ActivityAttempt{transformed_model: transformed_model}, _) do
    transformed_model
  end

  def select_model(%ActivityAttempt{
        transformed_model: nil,
        revision: nil,
        revision_id: revision_id
      }) do
    perform_inline_fetch(revision_id)
  end

  def select_model(%ActivityAttempt{
        transformed_model: nil,
        revision: %Oli.Resources.Revision{
          content: content
        }
      }) do
    content
  end

  def select_model(%ActivityAttempt{
        transformed_model: transformed_model
      }) do
    transformed_model
  end

  defp perform_inline_fetch(revision_id) do
    Logger.warning(
      "Inline fetch of revision for model selection. This can lead to performance problems if done as part of an iteration of a collection."
    )

    case Oli.Repo.get(Oli.Resources.Revision, revision_id) do
      nil ->
        Logger.error("Inline fetch could not locate revision")
        nil

      %Oli.Resources.Revision{content: content} ->
        content
    end
  end

  @moduledoc """
  Core attempt related functions.
  """

  @doc """
  Creates or updates an access record for a given resource, section id and user. When
  created the access count is set to 1, otherwise on updates the
  access count is incremented.
  ## Examples
      iex> track_access(resource_id, section_id, user_id)
      {:ok, %ResourceAccess{}}
      iex> track_access(resource_id, section_id, user_id)
      {:error, %Ecto.Changeset{}}
  """
  def track_access(resource_id, section_id, user_id) do
    now = DateTime.utc_now()

    Oli.Repo.insert!(
      %ResourceAccess{
        access_count: 1,
        user_id: user_id,
        section_id: section_id,
        resource_id: resource_id
      },
      on_conflict: [inc: [access_count: 1], set: [updated_at: now]],
      conflict_target: [:resource_id, :user_id, :section_id]
    )
  end

  @doc """
  For a given resource attempt id, this returns a list of the id and resource_id
  for all activity attempt records that pertain to this resource attempt id.
  """
  def get_attempt_resource_id_pair(resource_attempt_id) do
    Repo.all(
      from(r in ActivityAttempt,
        where: r.resource_attempt_id == ^resource_attempt_id,
        select: map(r, [:id, :resource_id])
      )
    )
  end

  @doc """
  For a given resource attempt id, this returns a list of three element tuples containing
  the activity resource id, the activity attempt guid, and the id of the type of the
  registered activity.
  """
  def get_thin_activity_context(resource_attempt_id) do
    Repo.all(
      from(a in ActivityAttempt,
        join: r in Revision,
        on: a.revision_id == r.id,
        where: a.resource_attempt_id == ^resource_attempt_id,
        order_by: a.attempt_number,
        select: {a.resource_id, a.attempt_guid, r.activity_type_id}
      )
    )
  end

  @doc """
  Retrieves all graded resource access for a given context

  `[%ResourceAccess{}, ...]`
  """
  def get_graded_resource_access_for_context(section_id) do
    graded_resource_access_for_context(section_id)
    |> Repo.all()
  end

  def get_graded_resource_access_for_context(section_id, user_ids) do
    graded_resource_access_for_context(section_id)
    |> where([_, _, _, a], a.user_id in ^user_ids)
    |> Repo.all()
  end

  # base query, intended to be composable for the above two uses
  defp graded_resource_access_for_context(section_id) do
    SectionsProjectsPublications
    |> join(:left, [spp], pr in PublishedResource, on: pr.publication_id == spp.publication_id)
    |> join(:left, [_, pr], r in Revision, on: r.id == pr.revision_id)
    |> join(:left, [spp, _, r], a in ResourceAccess,
      on: r.resource_id == a.resource_id and a.section_id == spp.section_id
    )
    |> where([spp, _, r, a], not is_nil(a) and spp.section_id == ^section_id and r.graded == true)
    |> select([_, _, _, a], a)
  end

  @doc """
    Retrieves all graded resource access where the last lms grade sync failed
    for a given section.

    `[
      %{
        id: 21390,
        resource_id: 1234,
        user_id: 558,
        user_name: "Some user name",
        page_title: "Some page title"
      },
      ...
    ]`
  """
  def get_failed_grade_sync_resource_accesses_for_section(section_slug) do
    Repo.all(
      from(
        resource_access in ResourceAccess,
        join: section in assoc(resource_access, :section),
        join: user in assoc(resource_access, :user),
        join: section_project_publication in assoc(section, :section_project_publications),
        join: published_resource in PublishedResource,
        on: section_project_publication.publication_id == published_resource.publication_id,
        join: revision in Revision,
        on:
          revision.id == published_resource.revision_id and
            revision.resource_id == resource_access.resource_id,
        where:
          section.slug == ^section_slug and
            section.status == :active and
            revision.deleted == false and
            revision.graded == true and
            (not is_nil(resource_access.last_grade_update_id) and
               (is_nil(resource_access.last_successful_grade_update_id) or
                  resource_access.last_grade_update_id !=
                    resource_access.last_successful_grade_update_id)),
        select: %{
          id: resource_access.id,
          resource_id: resource_access.resource_id,
          user_id: user.id,
          user_name: user.name,
          page_title: revision.title
        },
        group_by: [
          resource_access.id,
          resource_access.resource_id,
          user.id,
          user.name,
          revision.title
        ]
      )
    )
  end

  @doc """
  Retrieves a preloaded resource access from its id.
  """
  def get_resource_access(resource_access_id) do
    Repo.one(
      from(a in ResourceAccess,
        where: a.id == ^resource_access_id,
        select: a,
        preload: [:section, :user]
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
        join: spp in SectionsProjectsPublications,
        on: s.id == spp.section_id,
        join: pr in PublishedResource,
        on: pr.publication_id == spp.publication_id,
        join: r in Revision,
        on: pr.revision_id == r.id,
        where:
          s.slug == ^section_slug and r.graded == true and
            a.resource_id == ^resource_id,
        select: a,
        distinct: a
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
        join: spp in SectionsProjectsPublications,
        on: s.id == spp.section_id,
        join: pr in PublishedResource,
        on: pr.publication_id == spp.publication_id,
        join: r in Revision,
        on: pr.revision_id == r.id,
        where: s.slug == ^section_slug and a.user_id == ^user_id,
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
          a.user_id == ^user_id and s.slug == ^section_slug and
            a.resource_id == ^resource_id,
        select: a
      )
    )
  end

  def get_resource_accesses(section_slug, user_id) do
    Repo.all(
      from(a in ResourceAccess,
        left_join: ra in ResourceAttempt,
        on: a.id == ra.resource_access_id,
        join: s in Section,
        on: a.section_id == s.id,
        where: a.user_id == ^user_id and s.slug == ^section_slug,
        group_by: a.id,
        select: a,
        select_merge: %{
          resource_attempts_count: count(ra.id)
        }
      )
    )
  end

  def get_resource_access_from_guid(resource_attempt_guid) do
    Repo.one(
      from(a in ResourceAccess,
        left_join: ra in ResourceAttempt,
        on: a.id == ra.resource_access_id,
        where: ra.attempt_guid == ^resource_attempt_guid,
        select: a
      )
    )
  end

  def has_any_active_attempts?(resource_attempts) do
    Enum.any?(resource_attempts, fn r -> r.lifecycle_state == :active end)
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

  def get_latest_activity_attempt(resource_attempt_id, resource_id) do
    Repo.one(
      from(aa in ActivityAttempt,
        left_join: aa2 in ActivityAttempt,
        on:
          aa2.resource_id == ^resource_id and aa.resource_attempt_id == aa2.resource_attempt_id and
            aa.id < aa2.id,
        where:
          aa.resource_id == ^resource_id and aa.resource_attempt_id == ^resource_attempt_id and
            is_nil(aa2),
        select: aa
      )
    )
    |> Repo.preload(revision: [:activity_type])
  end

  def get_latest_activity_attempt(section_id, user_id, resource_id) do
    Repo.one(
      from(aa in ActivityAttempt,
        left_join: aa2 in ActivityAttempt,
        on:
          aa.resource_id == aa2.resource_id and
            aa.id < aa2.id,
        join: ra in ResourceAttempt,
        on: ra.id == aa.resource_attempt_id,
        join: rac in ResourceAccess,
        on: rac.id == ra.resource_access_id,
        where:
          aa.resource_id == ^resource_id and not is_nil(aa.date_evaluated) and
            is_nil(aa2) and rac.user_id == ^user_id and rac.section_id == ^section_id,
        select: aa
      )
    )
    |> Repo.preload(revision: [:activity_type])
  end

  @doc """
  Retrieves the latest activity attempt for a given page attempt guid, activity resource id,
  and user id. If no attempts exist, returns nil.
  """
  def get_latest_activity_attempt_from_page_attempt(
        page_attempt_guid,
        activity_resource_id,
        user_id
      ) do
    from(activity_attempt in ActivityAttempt,
      join: resource_attempt in ResourceAttempt,
      on: activity_attempt.resource_attempt_id == resource_attempt.id,
      join: resource_access in ResourceAccess,
      on: resource_attempt.resource_access_id == resource_access.id,
      where:
        resource_attempt.attempt_guid == ^page_attempt_guid and
          activity_attempt.resource_id == ^activity_resource_id and
          resource_access.user_id == ^user_id,
      order_by: [desc: activity_attempt.attempt_number],
      select: activity_attempt,
      preload: [:part_attempts, :revision],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Retrieves the latest resource attempt for a given section slug, user id, and activity resource id.
  """
  def get_latest_user_resource_attempt_for_activity(
        section_slug,
        user_id,
        activity_resource_id
      ) do
    from(activity_attempt in ActivityAttempt,
      join: resource_attempt in ResourceAttempt,
      on: activity_attempt.resource_attempt_id == resource_attempt.id,
      join: resource_access in ResourceAccess,
      on: resource_attempt.resource_access_id == resource_access.id,
      join: s in Section,
      on: resource_access.section_id == s.id,
      where:
        s.slug == ^section_slug and
          activity_attempt.resource_id == ^activity_resource_id and
          resource_access.user_id == ^user_id,
      order_by: [desc: resource_attempt.attempt_number],
      select: resource_attempt,
      limit: 1
    )
    |> Repo.one()
  end

  def get_latest_activity_attempts(resource_attempt_id) do
    Repo.all(
      from(aa in ActivityAttempt,
        left_join: aa2 in ActivityAttempt,
        on:
          aa.resource_attempt_id == aa2.resource_attempt_id and aa.resource_id == aa2.resource_id and
            aa.id < aa2.id,
        left_join: rev in assoc(aa, :revision),
        where: aa.resource_attempt_id == ^resource_attempt_id and is_nil(aa2),
        select: aa,
        preload: [revision: rev]
      )
    )
  end

  def get_latest_non_active_activity_attempts(resource_attempt_id) do
    query =
      from(
        aa in ActivityAttempt,
        where:
          (aa.lifecycle_state == :evaluated or aa.lifecycle_state == :submitted) and
            aa.resource_attempt_id == ^resource_attempt_id,
        group_by: aa.resource_id,
        select: max(aa.id)
      )

    Repo.all(
      from(aa in ActivityAttempt,
        where: aa.id in subquery(query),
        select: aa
      )
    )
  end

  @doc """
  Retrieves the latest resource attempt for a given resource id,
  context id and user id.  If no attempts exist, returns nil.
  """
  def get_latest_resource_attempt(resource_id, section_slug, user_id) do
    Repo.one(
      ResourceAttempt
      |> join(:left, [ra1], a in ResourceAccess, on: a.id == ra1.resource_access_id)
      |> join(:left, [_, a], s in Section, on: a.section_id == s.id)
      |> join(:left, [ra1, a, _], ra2 in ResourceAttempt,
        on:
          a.id == ra2.resource_access_id and ra1.id < ra2.id and
            ra1.resource_access_id == ra2.resource_access_id
      )
      |> join(:left, [ra1, _, _, _], r in Revision, on: ra1.revision_id == r.id)
      |> where(
        [ra1, a, s, ra2, _],
        a.user_id == ^user_id and s.slug == ^section_slug and s.status == :active and
          a.resource_id == ^resource_id and
          is_nil(ra2)
      )
      |> preload(:revision)
    )
  end

  @doc """
  Retrieves the resource access record and all (if any) attempts related to it
  in a two element tuple of the form:

  `{%ResourceAccess, [%ResourceAttempt{}]}`

  The empty list `[]` will be present if there are no resource attempts.
  """
  def get_resource_attempt_history(resource_id, section_slug, user_id) do
    access = get_resource_access(resource_id, section_slug, user_id)

    case access do
      nil ->
        nil

      %{id: id} ->
        attempts =
          Repo.all(
            from(ra in ResourceAttempt,
              where: ra.resource_access_id == ^id,
              order_by: ra.attempt_number,
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

  def is_scoreable_first_attempt?(activity_attempt_guid) do
    {attempt_number, scoreable} =
      Repo.one(
        from(a in ActivityAttempt,
          where: a.attempt_guid == ^activity_attempt_guid,
          select: {a.attempt_number, a.scoreable}
        )
      )

    case {attempt_number, scoreable} do
      {1, true} -> true
      _ -> false
    end
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
          preload: [:part_attempts, :revision]
        )
      )

    {:ok, results}
  end

  @doc """
  Returns a list of activity attempts for a given section and activity resource ids.
  """
  @spec get_activity_attempts_by(integer(), [integer()]) :: [map()]
  def get_activity_attempts_by(section_id, activity_resource_ids) do
    from(activity_attempt in ActivityAttempt,
      left_join: resource_attempt in assoc(activity_attempt, :resource_attempt),
      left_join: resource_access in assoc(resource_attempt, :resource_access),
      left_join: user in assoc(resource_access, :user),
      left_join: activity_revision in assoc(activity_attempt, :revision),
      left_join: resource_revision in assoc(resource_attempt, :revision),
      where:
        resource_access.section_id == ^section_id and
          activity_revision.resource_id in ^activity_resource_ids,
      select: activity_attempt,
      select_merge: %{
        activity_type_id: activity_revision.activity_type_id,
        activity_title: activity_revision.title,
        page_title: resource_revision.title,
        page_id: resource_revision.resource_id,
        resource_attempt_number: resource_attempt.attempt_number,
        graded: resource_revision.graded,
        user: user,
        revision: activity_revision,
        resource_attempt_guid: resource_attempt.attempt_guid,
        resource_access_id: resource_access.id
      }
    )
    |> Repo.all()
  end

  @doc """
  Fetches the activities for a given assessment and section attempted by a list of students

  ## Parameters
    * `assessment_resource_id` - the resource id of the assessment
    * `section_id` - the section id
    * `student_ids` - the list of student ids
    * `filter_by_survey` - an optional boolean flag to filter by survey activities

  iex> get_activities(1, 2, [3, 4], false)
  [
    %{
      id: 1,
      resource_id: 1,
      title: "Activity 1"
    },
    %{
      id: 2,
      resource_id: 2,
      title: "Activity 2"
    }
  ]
  """
  @spec get_evaluated_activities_for(integer(), integer(), [integer()], boolean()) :: [map()]
  def get_evaluated_activities_for(
        assessment_resource_id,
        section_id,
        student_ids,
        filter_by_survey \\ false
      ) do
    filter_by_survey? =
      if filter_by_survey do
        dynamic([aa, _], not is_nil(aa.survey_id))
      else
        dynamic([aa, _], is_nil(aa.survey_id))
      end

    from(aa in ActivityAttempt,
      join: res_attempt in ResourceAttempt,
      on: aa.resource_attempt_id == res_attempt.id,
      where: aa.lifecycle_state == :evaluated,
      join: res_access in ResourceAccess,
      on: res_attempt.resource_access_id == res_access.id,
      where:
        res_access.section_id == ^section_id and
          res_access.resource_id == ^assessment_resource_id and
          res_access.user_id in ^student_ids,
      where: ^filter_by_survey?,
      join: rev in Revision,
      on: aa.revision_id == rev.id,
      group_by: [rev.resource_id, rev.id],
      select: map(rev, [:id, :resource_id, :title])
    )
    |> Repo.all()
  end

  def get_all_activity_attempts(resource_attempt_id) do
    Repo.all(
      from(activity_attempt in ActivityAttempt,
        where: activity_attempt.resource_attempt_id == ^resource_attempt_id
      )
    )
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
    do:
      Repo.get_by(ActivityAttempt, clauses)
      |> Repo.preload([:part_attempts, revision: [:activity_type]])

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
  Gets a resource attempt by its id, preloading the resource revision
  in the same query.
  ## Examples
      iex> get_resource_attempt_and_revision(1337)
      %ResourceAttempt{}
      iex> get_resource_attempt_and_revision(160605904)
      nil
  """
  def get_resource_attempt_and_revision(resource_attempt_id) do
    Repo.one(
      ResourceAttempt
      |> where([ra1], ra1.id == ^resource_attempt_id)
      |> preload(:revision)
    )
  end

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
  Gets all part attempts for a given activity attempts.
  """

  def get_part_attempts_by_activity_attempts(activity_attempts) do
    Repo.all(
      from(pa in PartAttempt,
        where: pa.activity_attempt_id in ^activity_attempts,
        select: pa
      )
    )
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
  Creates an LMS grade update record.
  ## Examples
      iex> create_lms_grade_update(%{field: value})
      {:ok, %LMSGradeUpdate{}}
      iex> create_lms_grade_update(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_lms_grade_update(attrs \\ %{}) do
    %LMSGradeUpdate{}
    |> LMSGradeUpdate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an LMS grade update.
  ## Examples
      iex> update_lms_grade_update(grade_update, %{field: new_value})
      {:ok, %LMSGradeUpdate{}}
      iex> update_lms_grade_update(grade_update, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_lms_grade_update(grade_update, attrs) do
    LMSGradeUpdate.changeset(grade_update, attrs)
    |> Repo.update()
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
      iex> update_resource_access(resource_access, %{field: new_value})
      {:ok, %ResourceAccess{}}
      iex> update_resource_access(resource_access, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource_access(resource_access, attrs) do
    ResourceAccess.changeset(resource_access, attrs)
    |> Repo.update()
  end

  @doc """
  Updates all resource accesses for a given section and user.
  """

  def update_resource_accesses_by_section_and_user(
        current_section_id,
        current_user_id,
        target_section_id,
        target_user_id
      ) do
    from(
      ra in ResourceAccess,
      where: ra.section_id == ^current_section_id and ra.user_id == ^current_user_id
    )
    |> Repo.update_all(set: [section_id: target_section_id, user_id: target_user_id])
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
  Gets all activity attempts for a given resource attempts.
  """

  def get_activity_attempts_by_resource_attempts(resource_attempts) do
    Repo.all(
      from(aa in ActivityAttempt,
        where: aa.resource_attempt_id in ^resource_attempts,
        select: aa
      )
    )
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

  @doc """
  Gets all resource attempts for a given resource accesses.
  """

  def get_resource_attempts_by_resource_accesses(resource_accesses) do
    Repo.all(
      from(ra in ResourceAttempt,
        where: ra.resource_access_id in ^resource_accesses,
        select: ra
      )
    )
  end

  @doc """
    Deletes part attempts, activity attempts, resource attempts, and resource accesses for a given section and user.
    Deleting resource accesses will cascade to deleting resource attempts, which will cascade to deleting activity
  """

  def delete_resource_accesses_by_section_and_user(target_section_id, target_user_id) do
    Repo.delete_all(
      from(res_acc in ResourceAccess,
        where: res_acc.section_id == ^target_section_id and res_acc.user_id == ^target_user_id
      )
    )
  end

  @doc """
  Counts the number of attempts made by a list of students for a given activity in a given section.
  """
  @spec count_student_attempts(integer(), %Section{}, [integer()]) :: integer() | nil
  def count_student_attempts(activity_resource_id, section_id, student_ids) do
    from(ra in ResourceAttempt,
      join: access in ResourceAccess,
      on: access.id == ra.resource_access_id,
      where:
        ra.lifecycle_state == :evaluated and access.section_id == ^section_id and
          access.resource_id == ^activity_resource_id and access.user_id in ^student_ids,
      select: count(ra.id)
    )
    |> Repo.one()
  end

  @doc """
  Preloads `activity_attempts` and their associated `part_attempts` for a given resource attempt or list of attempts.

  This allows fetching detailed attempt data only when needed, avoiding unnecessary preloading in other queries.
  """
  def preload_activity_part_attempts(resource_attempts) do
    Repo.preload(resource_attempts,
      activity_attempts: [:part_attempts]
    )
  end
end
