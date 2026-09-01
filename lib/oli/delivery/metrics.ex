defmodule Oli.Delivery.Metrics do
  import Ecto.Query, warn: false

  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Repo
  alias Oli.Analytics.DataTables.DataTable
  alias Oli.Delivery.Attempts.Core.{ResourceAccess, ActivityAttempt}
  alias Oli.Delivery.Attempts.Core
  alias Oli.Resources.Revision

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Proficiency
  alias Oli.Delivery.Proficiency.Naive

  alias Oli.Delivery.Sections.{
    ContainedPage,
    Enrollment,
    EnrollmentContextRole,
    Section,
    SectionResource
  }

  alias Oli.Accounts.User
  alias Lti_1p3.Roles.ContextRoles

  def progress_datatable_for(section_id, container_id) do
    learner_id = ContextRoles.get_role(:context_learner).id

    users =
      from(e in Enrollment,
        join: ecr in assoc(e, :context_roles),
        join: u in assoc(e, :user),
        where: e.section_id == ^section_id,
        where: ecr.id == ^learner_id,
        select: u,
        distinct: u
      )
      |> Repo.all()
      |> Enum.reduce(%{}, fn user, acc -> Map.put(acc, user.id, user) end)

    user_ids = Map.keys(users)

    progress_for(section_id, user_ids, container_id)
    |> Enum.reduce([], fn {user_id, progress}, acc ->
      [
        %{
          id: user_id,
          name: users[user_id].name,
          email: users[user_id].email,
          progress: progress
        }
        | acc
      ]
    end)
    |> DataTable.new()
    |> DataTable.headers([:id, :name, :email, :progress])
  end

  @doc """
  Calculate the progress for a specific student (or a list of students), in all pages of a specific
  container.

  Omitting the container_id (or specifying nil) calculates progress across the entire course
  section.

  This query leverages the `contained_pages` relation, which is always an up to date view of the
  structure of a course section. This allows this query to take into account structural changes as
  the result of course remix. The `contained_pages` relation is rebuilt after every remix.

  It returns a map:

    %{user_id_1 => user_1_progress, ... user_id_n => user_n_progress }

  If only a single user_id is provided, it returns a single number representing progress for that
  user. If a user does not have any progress, it returns 0.
  """
  @spec progress_for(
          section_id :: integer,
          user_ids :: integer | list(integer),
          container_id :: integer | nil
        ) :: map | number
  def progress_for(section_id, user_ids, container_id \\ nil)

  def progress_for(section_id, user_ids, container_id) when is_list(user_ids) do
    filter_by_container =
      case container_id do
        nil ->
          dynamic([cp, _], is_nil(cp.container_id))

        _ ->
          dynamic([cp, _], cp.container_id == ^container_id)
      end

    pages_count =
      from(cp in ContainedPage)
      |> where([cp], cp.section_id == ^section_id)
      |> where(^filter_by_container)
      |> select([cp], count(cp.id))
      |> Repo.one()
      |> max(1)

    query =
      ContainedPage
      |> join(:inner, [cp], ra in ResourceAccess,
        on:
          cp.page_id == ra.resource_id and cp.section_id == ra.section_id and
            ra.user_id in ^user_ids
      )
      |> where([cp, ra], cp.section_id == ^section_id)
      |> where(^filter_by_container)
      |> group_by([_cp, ra], ra.user_id)
      |> select([cp, ra], {ra.user_id, fragment("SUM(?)", ra.progress) / ^pages_count})

    Repo.all(query)
    |> Enum.into(%{})
  end

  def progress_for(section_id, user_id, container_id),
    do: progress_for(section_id, [user_id], container_id) |> Map.get(user_id, 0.0)

  @doc """
  Calculates the completed pages and the total pages of a course for a specific student (or a list of students).
  The last parameter gives flexibility for scoping the calculation to a specific container.

  Note that this metric is "acid" in the sense that will not count as `completed` pages whose progress < 1.0.
  This may sound obvios, but it is important to keep in mind that this metric is not the same as the progress metric
  of `progress_for/3` (where we may have a progress of 0.5 for a page, for example).

  Returns a map:
  %{user_id_1 => completed_pages_1,
    user_id_2 => completed_pages_2,
    ...
    user_id_n => completed_pages_n,
    total_pages => total_pages
  }
  """
  def raw_completed_pages_for(section_id, user_ids, container_id \\ nil)

  def raw_completed_pages_for(section_id, user_ids, container_id) when is_list(user_ids) do
    filter_by_container =
      case container_id do
        nil ->
          dynamic([cp, _], is_nil(cp.container_id))

        _ ->
          dynamic([cp, _], cp.container_id == ^container_id)
      end

    pages_count =
      from(cp in ContainedPage)
      |> where([cp], cp.section_id == ^section_id)
      |> where(^filter_by_container)
      |> select([cp], count(cp.id))
      |> Repo.one()

    query =
      ContainedPage
      |> join(:inner, [cp], ra in ResourceAccess,
        on:
          cp.page_id == ra.resource_id and cp.section_id == ra.section_id and
            ra.user_id in ^user_ids
      )
      |> where([cp, ra], cp.section_id == ^section_id and ra.progress == 1.0)
      |> where(^filter_by_container)
      |> group_by([_cp, ra], ra.user_id)
      |> select(
        [cp, ra],
        {ra.user_id, count()}
      )

    Repo.all(query)
    |> Enum.into(%{})
    |> Map.merge(%{total_pages: pages_count})
  end

  def raw_completed_pages_for(section_id, user_id, container_id),
    do: raw_completed_pages_for(section_id, [user_id], container_id)

  defp do_get_progress_for_page(section_id, user_ids, page_id) do
    filter_by_user =
      case is_list(user_ids) do
        true -> dynamic([ra], ra.user_id in ^user_ids)
        _ -> dynamic([ra], ra.user_id == ^user_ids)
      end

    from(ra in ResourceAccess,
      where: ra.resource_id == ^page_id and ra.section_id == ^section_id,
      where: ^filter_by_user,
      group_by: ra.user_id,
      select: {
        ra.user_id,
        fragment(
          "SUM(?)",
          ra.progress
        )
      }
    )
  end

  @doc """
  Calculate the progress for a given student or list of students in a page.
  """
  def progress_for_page(_section_id, [], _), do: %{}

  def progress_for_page(section_id, user_ids, page_id) when is_list(user_ids),
    do:
      do_get_progress_for_page(section_id, user_ids, page_id)
      |> Repo.all()
      |> Enum.into(%{})

  def progress_for_page(section_id, user_id, page_id) do
    case do_get_progress_for_page(section_id, user_id, page_id) |> Repo.one() do
      nil -> 0
      {_, progress} -> progress
    end
  end

  @doc """
  Calculate the progress for a given student for a list of pages.
  """

  def progress_for_pages(section_id, user_id, page_ids) do
    from(ra in ResourceAccess,
      where:
        ra.resource_id in ^page_ids and
          ra.section_id == ^section_id and
          ra.user_id == ^user_id,
      group_by: ra.resource_id,
      select: {
        ra.resource_id,
        fragment("COALESCE(SUM(?), 0)", ra.progress)
      }
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Calculate the percentage of students that have completed a container or page
  """
  def completion_for(section_id, container_id) do
    completions =
      User
      |> join(:inner, [u], e in Enrollment,
        on: u.id == e.user_id and e.section_id == ^section_id and e.status == :enrolled
      )
      |> join(:inner, [u, e], ecr in EnrollmentContextRole,
        on:
          ecr.enrollment_id == e.id and
            ecr.context_role_id == ^ContextRoles.get_role(:context_learner).id
      )
      |> join(:left, [u, e], ra in ResourceAccess,
        on:
          ra.user_id == u.id and ra.section_id == ^section_id and
            ra.resource_id == ^container_id
      )
      |> select([_, _, _, ra], %{
        progress: ra.progress
      })
      |> Repo.all()

    case length(completions) do
      0 -> 0.0
      length -> Enum.count(completions, &(&1.progress == 1)) / length * 100
    end
  end

  @doc """
  Calculate the progress for a specific student, in all pages of a
  collection of containers.
  """
  def progress_across(section_id, container_ids, user_id) do
    query =
      ContainedPage
      |> join(:left, [cp], ra in ResourceAccess,
        on:
          cp.page_id == ra.resource_id and cp.section_id == ra.section_id and
            ra.user_id == ^user_id
      )
      |> where([cp, ra], cp.section_id == ^section_id and cp.container_id in ^container_ids)
      |> group_by([cp, ra], cp.container_id)
      |> select([cp, ra], {
        cp.container_id,
        fragment(
          "SUM(?) / COUNT(*)",
          ra.progress
        )
      })

    Repo.all(query)
    |> Enum.into(%{})
  end

  @doc """
  Calculate the progress for all students, in all pages of a
  collection of containers.

  The last two parameters gives flexibility into excluding specific users
  from the calculation. This exists primarily to exclude instructors.
  `user_ids_to_ignore` can be an empty list, but `user_count` should always be the total
  number of enrolled students (excluding the count of those in the exlusion parameter).
  """
  def progress_across(section_id, container_ids, user_ids_to_ignore, user_count) do
    # If zero was passed in, we can allow the query to execute correctly and avoid a divide by zero by
    # simply changing it to 1
    user_count = max(user_count, 1)

    query =
      ContainedPage
      |> join(:left, [cp], ra in ResourceAccess,
        on: cp.page_id == ra.resource_id and cp.section_id == ra.section_id
      )
      |> join(:left, [cp, _], sr in SectionResource,
        on: cp.container_id == sr.resource_id and cp.section_id == sr.section_id
      )
      |> where(
        [cp, ra, _],
        cp.section_id == ^section_id and cp.container_id in ^container_ids and
          ra.user_id not in ^user_ids_to_ignore
      )
      |> group_by([cp, ra, sr], [cp.container_id, sr.contained_page_count])
      |> select([cp, ra, sr], {
        cp.container_id,
        fragment(
          "SUM(?) / (? * ?)",
          ra.progress,
          sr.contained_page_count,
          ^user_count
        )
      })

    Repo.all(query)
    |> Enum.into(%{})
  end

  @doc """
  Calculate the progress for a given list of students in a collection of pages.

  The last parameter gives flexibility for including specific users in the calculation.
  This exists primarily to exclude instructors.
  """
  def progress_across_for_pages(section_id, pages_ids, user_ids) when is_list(user_ids) do
    from(ra in ResourceAccess,
      where: ra.resource_id in ^pages_ids,
      where: ra.section_id == ^section_id,
      where: ra.user_id in ^user_ids,
      group_by: ra.resource_id,
      select: {ra.resource_id, fragment("SUM(?) / (?)", ra.progress, ^Enum.count(user_ids))}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  def progress_across_for_pages(section_id, pages_ids, student_id),
    do: progress_across_for_pages(section_id, pages_ids, [student_id])

  @doc """
  Calculate the average score for a specific student (or a list of students),
  in all pages of a specific container.

  Omitting the container_id (or specifying nil) calculates average score
  across the entire course section.

  This query leverages the `contained_pages` relation, which is always an
  up to date view of the structure of a course section. This allows this
  query to take into account structural changes as the result of course
  remix. The `contained_pages` relation is rebuilt after every remix.

  It returns a map:

    %{user_id_1 => user_1_avg_score,
      ...
      user_id_n => user_n_avg_score
    }
  """
  @spec avg_score_for(
          section_id :: integer,
          user_id :: integer | list(integer),
          container_id :: integer | nil
        ) :: map

  def avg_score_for(section_id, user_id, container_id \\ nil) do
    user_id_list = if is_list(user_id), do: user_id, else: [user_id]

    query =
      case container_id do
        nil ->
          ResourceAccess
          |> where(
            [ra],
            ra.section_id == ^section_id and ra.user_id in ^user_id_list and not is_nil(ra.score)
          )
          |> group_by([ra], ra.user_id)
          |> select(
            [ra],
            {ra.user_id, fragment("SUM(?)", ra.score) / fragment("SUM(?)", ra.out_of)}
          )

        container_id ->
          ContainedPage
          |> join(:inner, [cp], ra in ResourceAccess,
            on:
              cp.page_id == ra.resource_id and cp.section_id == ra.section_id and
                ra.user_id in ^user_id_list
          )
          |> where(
            [cp, ra],
            cp.section_id == ^section_id and not is_nil(ra.score) and
              cp.container_id == ^container_id
          )
          |> group_by([_cp, ra], ra.user_id)
          |> select(
            [cp, ra],
            {ra.user_id, fragment("SUM(?)", ra.score) / fragment("SUM(?)", ra.out_of)}
          )
      end

    Repo.all(query)
    |> Enum.into(%{})
  end

  @doc """
  Calculates the average score for all students in a collection of pages
  (only considering finished attempts).

  The last parameter gives flexibility for including specific users in the calculation.
  This exists primarily to exclude instructors.
  """
  def avg_score_across_for_pages(
        %Section{id: section_id, analytics_version: :v2} = _section,
        pages_ids,
        user_ids
      ) do
    page_type_id = Oli.Resources.ResourceType.id_for_page()

    from(rs in ResourceSummary,
      where:
        rs.section_id == ^section_id and rs.resource_id in ^pages_ids and rs.user_id in ^user_ids and
          rs.project_id == -1 and rs.resource_type_id == ^page_type_id,
      group_by: rs.resource_id,
      select: {
        rs.resource_id,
        fragment(
          "CAST(SUM(?) as float) / NULLIF(CAST(SUM(?) as float), 0.0)",
          rs.num_correct,
          rs.num_attempts
        )
      }
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  def avg_score_across_for_pages(%Section{id: section_id} = _section, pages_ids, user_ids) do
    from(ra in ResourceAccess,
      where:
        ra.resource_id in ^pages_ids and ra.section_id == ^section_id and
          ra.user_id in ^user_ids and not is_nil(ra.score),
      group_by: ra.resource_id,
      select: {
        ra.resource_id,
        fragment(
          "SUM(?) / SUM(?)",
          ra.score,
          ra.out_of
        )
      }
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Calculates the raw average score ('score' and 'out_of' separately) for a list of students in a collection of pages
  (only considering finished attempts).

  The last parameter gives flexibility for including specific users in the calculation.
  This exists primarily to exclude instructors.
  """

  def raw_avg_score_across_for_pages(%Section{id: section_id} = _section, pages_ids, user_ids) do
    from(ra in ResourceAccess,
      where:
        ra.resource_id in ^pages_ids and ra.section_id == ^section_id and
          ra.user_id in ^user_ids and not is_nil(ra.score),
      group_by: ra.resource_id,
      select: {
        ra.resource_id,
        %{
          score: sum(ra.score),
          out_of: fragment("SUM(?)", ra.out_of)
        }
      }
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Calculates the raw average score ('score' and 'out_of' separately) for a list of students in a collection of containers
  (only considering finished attempts for graded pages).

  The last parameter gives flexibility for including specific users in the calculation.
  This exists primarily to exclude instructors.

  It returns a map of %{container_id => %{score: score, out_of: out_of}}, for example

  %{
    17126 => %{score: 26.0, out_of: 29.0},
    17128 => %{score: 26.0, out_of: 29.0},
    17130 => %{score: 4.0, out_of: 19.0},
    17131 => %{score: 4.0, out_of: 19.0}
  }
  """

  def raw_avg_score_across_for_containers(
        %Section{id: section_id, analytics_version: :v2} = _section,
        container_ids,
        user_ids
      ) do
    page_type_id = Oli.Resources.ResourceType.get_id_by_type("page")

    from(rs in ResourceSummary,
      join: cp in ContainedPage,
      on: cp.page_id == rs.resource_id,
      join: rev in Revision,
      on: rs.resource_id == rev.resource_id,
      where:
        cp.container_id in ^container_ids and cp.section_id == ^section_id and
          rs.section_id == ^section_id and
          rs.user_id in ^user_ids and
          rs.project_id == -1 and
          rs.resource_type_id == ^page_type_id and
          rev.graded,
      group_by: cp.container_id,
      select: {
        cp.container_id,
        %{
          score: fragment("CAST(SUM(?) as float)", rs.num_correct),
          out_of: fragment("CAST(SUM(?) as float)", rs.num_attempts)
        }
      }
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  def raw_avg_score_across_for_containers(
        %Section{id: section_id} = _section,
        container_ids,
        user_ids
      ) do
    from(ra in ResourceAccess,
      join: cp in ContainedPage,
      on: cp.page_id == ra.resource_id,
      join: rev in Revision,
      on: ra.resource_id == rev.resource_id,
      where:
        cp.container_id in ^container_ids and cp.section_id == ^section_id and
          ra.section_id == ^section_id and
          ra.user_id in ^user_ids and not is_nil(ra.score),
      group_by: cp.container_id,
      select: {
        cp.container_id,
        %{
          score: sum(ra.score),
          out_of: fragment("SUM(?)", ra.out_of)
        }
      }
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Returns the number of attempts for a given list of pages.
  The last parameter gives flexibility for including specific users in the calculation.
  This exists primarily to exclude instructors.

  It only considers submitted attempts.

  It returns a map:

    %{page_id_1 => number_of_attempts_for_page_1,
      ...
      page_id_n => number_of_attempts_for_page_n
    }
  """
  def attempts_across_for_pages(
        %Section{id: section_id} = _section_id,
        pages_ids,
        user_ids,
        evaluated_only \\ true
      ) do
    query =
      case evaluated_only do
        true ->
          from(ra in ResourceAttempt,
            join: access in ResourceAccess,
            on: access.id == ra.resource_access_id,
            where:
              ra.lifecycle_state == :evaluated and access.section_id == ^section_id and
                access.resource_id in ^pages_ids and access.user_id in ^user_ids,
            group_by: access.resource_id,
            select: {
              access.resource_id,
              count(ra.id)
            }
          )

        _ ->
          from(ra in ResourceAttempt,
            join: access in ResourceAccess,
            on: access.id == ra.resource_access_id,
            where:
              access.section_id == ^section_id and
                access.resource_id in ^pages_ids and access.user_id in ^user_ids,
            group_by: access.resource_id,
            select: {
              access.resource_id,
              count(ra.id)
            }
          )
      end

    Repo.all(query)
    |> Enum.into(%{})
  end

  @doc """
  Calculates the students latest interaction across all pages of a given container (the max value).
  Omitting the container_id (or specifying nil) calculates students latest interaction
  across the entire course section.
  If an enrolled student has not yet interacted, it returns the :updated_at time stamp of his enrollment.

  It returns a map:

    %{student_id_1 => student_1_last_interaction,
      ...
      student_id_n => student_n_last_interaction
    }
  """
  @spec students_last_interaction_across(section :: map, container_id :: any) :: map
  def students_last_interaction_across(section, container_id \\ nil) do
    on =
      case container_id do
        nil ->
          dynamic([_s, e, ra], e.user_id == ra.user_id and e.section_id == ra.section_id)

        _ ->
          pages_for_container =
            from(cp in ContainedPage,
              where: cp.section_id == ^section.id and cp.container_id == ^container_id,
              select: cp.page_id
            )
            |> Repo.all()

          dynamic(
            [_s, e, ra],
            e.user_id == ra.user_id and e.section_id == ra.section_id and
              ra.resource_id in ^pages_for_container
          )
      end

    query =
      from(
        s in Section,
        join: e in Enrollment,
        on: e.section_id == s.id,
        left_join: ra in ResourceAccess,
        on: ^on,
        where: s.slug == ^section.slug and e.status == :enrolled,
        group_by: [e.user_id, e.updated_at],
        select: {
          e.user_id,
          fragment(
            "coalesce(MAX(?), ?)",
            ra.updated_at,
            e.updated_at
          )
        }
      )

    Repo.all(query)
    |> Enum.into(%{})
  end

  @doc """
  Calculates the students latest interaction for a given section page:
  the latest :updated_at time stamp across all ResourceAccess records for each student for a given page.
  If an enrolled student has not yet interacted in that page, it returns the :updated_at time stamp of his enrollment.

    It returns a map:

    %{student_id_1 => student_1_last_interaction,
      ...
      student_id_n => student_n_last_interaction
    }
  """
  @spec students_last_interaction_for_page(section_slug :: String.t(), page_id :: integer) :: map
  def students_last_interaction_for_page(section_slug, page_id) do
    query =
      from(
        s in Section,
        join: e in Enrollment,
        on: e.section_id == s.id,
        left_join: ra in ResourceAccess,
        on: e.user_id == ra.user_id and e.section_id == ra.section_id,
        where:
          s.slug == ^section_slug and (ra.resource_id == ^page_id or is_nil(ra.resource_id)) and
            e.status == :enrolled,
        group_by: [e.user_id, e.updated_at],
        select: {
          e.user_id,
          fragment(
            "coalesce(MAX(?), ?)",
            ra.updated_at,
            e.updated_at
          )
        }
      )

    Repo.all(query)
    |> Enum.into(%{})
  end

  @doc """
  Given a list of objective revisions it calculates the aggregated proficiency for each of those objectives
  for a given student in a given course.

  It returns a map:

  %{
    objective_1_resource_id: "Low",
    ...
    objective_n_resource_id: "Medium"
  }

  This implementation considers that an objective may have sub-objectives.
  In that case, the proficiency for the given objectives will result from the aggregated raw proficiency of its contained sub-objectives.

  Example:
    Given the following parent-child learning objectives relationship:
      - Objective 1:
        - Sub-objective A (1 correct out of 1 attempt - resource_id: 1)
        - Sub-objective B (0 correct out of 1 attempt - resource_id: 2)
        - Sub-objective C (1 correct out of 1 attempt - resource_id: 3)

      - Objective 2 (0 correct out of 1 attempt)

      - Objective 3 (1 correct out of 1 attempt)

    The student proficiency per objective will be:
      - Objective 1: 2 correct out of 3 => 0.66 => "Low" (this proficiency is the result of agregating its sub-objectives)
      - Objective 2: 0 correct out of 1 => 0.00 => "Medium"
      - Objective 3: 1 correct out of 1 => 1.00 => "High"

      %{1 => "Low", 2 => "Medium", 3 => "High"}
  """

  @spec proficiency_for_student_per_learning_objective(
          learning_objectives :: [%Revision{}],
          student_id :: integer,
          section :: %Oli.Delivery.Sections.Section{}
        ) :: map
  def proficiency_for_student_per_learning_objective(
        learning_objectives,
        student_id,
        section
      ) do
    objective_ids = Enum.map(learning_objectives, & &1.resource_id)

    case Proficiency.estimates_for_objectives(section, [student_id], objective_ids) do
      {:ok, estimates} ->
        Map.new(objective_ids, fn objective_id ->
          {objective_id, estimates |> get_in([objective_id, student_id]) |> estimate_label()}
        end)

      {:error, _reason} ->
        Map.new(objective_ids, &{&1, "Not enough data"})
    end
  end

  defp estimate_label(nil), do: "Not enough data"
  defp estimate_label(%{label: :low}), do: "Low"
  defp estimate_label(%{label: :medium}), do: "Medium"
  defp estimate_label(%{label: :high}), do: "High"
  defp estimate_label(_estimate), do: "Not enough data"

  @doc """
  Retrieves raw proficiency data for a specific section and set of learning objectives,
  optionally filtering by a list of objective IDs or a specific student ID.

  This is a naive-model compatibility API whose tuple is coupled to
  `ResourceSummary` first-attempt counters. Model-aware callers must use
  `Oli.Delivery.Proficiency`; this function will not acquire an LKT-AOA tuple
  variant.

  ## Options

    * `:objective_ids` - (optional) a list of objective IDs to filter the data by specific objectives.
    * `:student_id` - (optional) an ID of a student to filter data by a specific student.

  ## Examples

      iex> raw_proficiency_per_learning_objective(123, objective_ids: [1, 2, 3], student_id: 42)
      # Query result with raw proficiency data for section 123, filtered by objectives [1, 2, 3] and student ID 42

      iex> raw_proficiency_per_learning_objective(123)
      # Query result with raw proficiency data for all objectives in section 123
  """
  @spec raw_proficiency_per_learning_objective(section_id :: integer, opts :: Keyword.t()) :: %{
          integer => tuple
        }
  def raw_proficiency_per_learning_objective(section_id, opts \\ []) do
    Naive.raw_proficiency_per_learning_objective(section_id, opts)
  end

  @doc """
  Calculates the learning proficiency ("High", "Medium", "Low", "Not enough data")
  for every container of a given section

    It returns a map:

    %{container_id_1 => "High",
      ...
      container_id_n => "Low"
    }
  """
  def proficiency_per_container(
        %Section{} = section,
        contained_pages
      ) do
    scopes = contained_pages |> Enum.map(&{:container, &1.container_id}) |> Enum.uniq()
    membership = page_membership(contained_pages, scopes)
    learner_ids = scope_user_ids(section, scopes, page_membership: membership)

    estimates_for_scope_labels(section, learner_ids, scopes, page_membership: membership)
    |> Map.new(fn {{:container, container_id}, by_user} ->
      {container_id, by_user |> Map.values() |> Enum.frequencies() |> mode_label()}
    end)
  end

  @doc """
  Calculates the learning proficiency ("High", "Medium", "Low", "Not enough data")
  for every student across a given container.
  Omitting the container_id (or specifying nil) calculates students learning proficiency
  across the entire course section.

    It returns a map:

    %{student_id_1 => "High",
      ...
      student_id_n => "Low"
    }
  """
  def proficiency_per_student_across(section, container_id \\ nil)

  def proficiency_per_student_across(
        %Section{} = section,
        container_id
      ) do
    scope = if is_nil(container_id), do: :course, else: {:container, container_id}
    learner_ids = scope_user_ids(section, [scope])
    estimates_for_scope_labels(section, learner_ids, [scope]) |> Map.get(scope, %{})
  end

  @doc """
  Calculates the learning proficiency ("High", "Medium", "Low", "Not enough data")
  for every container of a given section for a given student

    It returns a map:

    %{container_id_1 => "High",
      ...
      container_id_n => "Low"
    }
  """
  def proficiency_for_student_per_container(
        %Section{} = section,
        student_id,
        contained_pages
      ) do
    scopes = contained_pages |> Enum.map(&{:container, &1.container_id}) |> Enum.uniq()

    estimates_for_scope_labels(section, [student_id], scopes,
      page_membership: page_membership(contained_pages, scopes)
    )
    |> Map.new(fn {{:container, container_id}, by_user} ->
      {container_id, Map.get(by_user, student_id, "Not enough data")}
    end)
  end

  @doc """
  Calculates the learning proficiency ("High", "Medium", "Low", "Not enough data")
  for every page of a given section for a given student

    It returns a map:

    %{page_id_1 => "High",
      ...
      page_id_n => "Low"
    }
  """
  def proficiency_for_student_per_page(
        %Section{} = section,
        student_id
      ) do
    {:ok, page_ids} = Proficiency.page_ids(section)
    scopes = Enum.map(page_ids, &{:page, &1})

    estimates_for_scope_labels(section, [student_id], scopes)
    |> Map.new(fn {{:page, page_id}, by_user} ->
      {page_id, Map.get(by_user, student_id, "Not enough data")}
    end)
  end

  @doc """
  Calculates the learning proficiency ("High", "Medium", "Low", "Not enough data")
  for each student of a given section for a specific page

    It returns a map:

    %{student_id_1 => "High",
      ...
      student_id_n => "Low"
    }
  """
  def proficiency_per_student_for_page(
        %Section{} = section,
        page_id
      ) do
    scope = {:page, page_id}
    learner_ids = scope_user_ids(section, [scope])
    estimates_for_scope_labels(section, learner_ids, [scope]) |> Map.get(scope, %{})
  end

  @doc """
  Calculates the learning proficiency ("High", "Medium", "Low", "Not enough data")
  for each page provided as a list

    It returns a map:

    %{page_id_1 => "High",
      ...
      page_id_n => "Low"
    }
  """
  def proficiency_per_page(%Section{} = section, page_ids) do
    scopes = Enum.map(page_ids, &{:page, &1})
    learner_ids = scope_user_ids(section, scopes)
    {:ok, labels} = Proficiency.labels_for_pages(section, page_ids, learner_ids)
    labels
  end

  defp estimates_for_scope_labels(section, learner_ids, scopes, opts \\ []) do
    case Proficiency.estimates_for_scopes(section, learner_ids, scopes, opts) do
      {:ok, estimates} ->
        Map.new(estimates, fn {scope, by_user} ->
          {scope,
           Map.new(by_user, fn {user_id, estimate} -> {user_id, estimate_label(estimate)} end)}
        end)

      {:error, _reason} ->
        %{}
    end
  end

  defp page_membership(contained_pages, scopes) do
    pages_by_container = Enum.group_by(contained_pages, & &1.container_id, & &1.page_id)

    Map.new(scopes, fn {:container, container_id} = scope ->
      {scope, MapSet.new(Map.get(pages_by_container, container_id, []))}
    end)
  end

  defp scope_user_ids(section, scopes, opts \\ []) do
    enrolled_ids = Sections.enrolled_student_ids(section.slug)
    {:ok, state_ids} = Proficiency.user_ids_for_scopes(section, scopes, opts)
    Enum.uniq(enrolled_ids ++ state_ids)
  end

  defp mode_label(distribution) when map_size(distribution) == 0, do: "Not enough data"

  defp mode_label(distribution) do
    distribution
    |> Enum.sort_by(fn {label, _count} -> label_rank(label) end)
    |> Enum.max_by(fn {_label, count} -> count end)
    |> elem(0)
  end

  defp label_rank("Low"), do: 0
  defp label_rank("Medium"), do: 1
  defp label_rank("High"), do: 2
  defp label_rank(_label), do: 3

  defdelegate proficiency_range(proficiency, num_first_attempts), to: Naive

  def progress_range(nil), do: "Not enough data"
  def progress_range(progress) when progress <= 0.5, do: "Low"
  def progress_range(progress) when progress <= 0.8, do: "Medium"
  def progress_range(_progress), do: "High"

  @doc """
  Updates page progress to be 100% complete.
  """
  def mark_progress_completed(resource_attempt_guid) when is_binary(resource_attempt_guid) do
    case Core.get_resource_access_from_guid(resource_attempt_guid) do
      nil -> {:error, :resource_access_not_found}
      ra -> mark_progress_completed(ra)
    end
  end

  def mark_progress_completed(resource_access_id) when is_integer(resource_access_id) do
    case Core.get_resource_access(resource_access_id) do
      nil -> {:error, :resource_access_not_found}
      ra -> mark_progress_completed(ra)
    end
  end

  def mark_progress_completed(%ResourceAccess{} = ra) do
    Core.update_resource_access(ra, %{progress: 1.0})
  end

  @doc """
  Resets page progress to be 0% complete.
  """
  def reset_progress(%ResourceAccess{} = ra) do
    Core.update_resource_access(ra, %{progress: 0.0})
  end

  @doc """
  For an activity attempt specified by an attempt guid, calculate and set in the corresponding resource access
  record, the percentage complete for the related page. This calculation only needs to be performed after the
  evaluation of a scoreable attempt for given activity.  This method should update exactly one record, the resource
  access for the page that this activity attempt ultimately pertains to (through its parent resource attempt).

  Can return one of:
  {:ok, :updated} -> Progress calculated and set
  {:ok, :noop} -> Nothing needed to be done, since the attempt was not scoreable
  {:error, :unexpected_update_count} -> 0 or more than 1 record would have been updated, rolled back
  {:error, e} -> An other error occurred, rolled back
  """
  def update_page_progress(activity_attempt_guid) when is_binary(activity_attempt_guid) do
    if scoreable_activity_attempt?(activity_attempt_guid) do
      do_update(activity_attempt_guid)
    else
      {:ok, :noop}
    end
  end

  def update_page_progress(%ActivityAttempt{
        scoreable: true,
        attempt_guid: attempt_guid
      }) do
    do_update(attempt_guid)
  end

  def update_page_progress(_) do
    {:ok, :noop}
  end

  defp scoreable_activity_attempt?(activity_attempt_guid) do
    Repo.exists?(
      from(aa in ActivityAttempt,
        where: aa.attempt_guid == ^activity_attempt_guid and aa.scoreable == true
      )
    )
  end

  defp do_update(activity_attempt_guid) do
    Oli.Repo.transaction(fn ->
      sql = """
        WITH target AS (
          SELECT
            ra.resource_access_id,
            ra.revision_id,
            aa.resource_attempt_id
          FROM activity_attempts AS aa
          JOIN resource_attempts AS ra ON ra.id = aa.resource_attempt_id
          WHERE aa.attempt_guid = $1
          LIMIT 1
        ),
        latest_attempts AS (
          SELECT DISTINCT ON (aa2.resource_id)
            aa2.id,
            aa2.lifecycle_state
          FROM activity_attempts AS aa2
          JOIN target ON target.resource_attempt_id = aa2.resource_attempt_id
          WHERE aa2.scoreable = true
          ORDER BY aa2.resource_id, aa2.attempt_number DESC, aa2.id DESC
        ),
        counts AS (
          SELECT
            COUNT(id) FILTER (WHERE lifecycle_state = 'evaluated' OR lifecycle_state = 'submitted')::float AS completed_count,
            COUNT(id)::float AS total_count
          FROM latest_attempts
        )
        UPDATE
          resource_accesses
        SET
          progress = LEAST(
            1.0,
            GREATEST(
              (
                SELECT
                  completed_count / (total_count * ((COALESCE(rev.full_progress_pct, 100) / 100.0)))
                FROM counts, target
                JOIN revisions AS rev ON rev.id = target.revision_id
              ),
              resource_accesses.progress
            )
          ),
          updated_at = NOW()
        WHERE
          id =
            (SELECT resource_access_id FROM target);
      """

      case Ecto.Adapters.SQL.query(Oli.Repo, sql, [activity_attempt_guid]) do
        {:ok, %{num_rows: 1}} ->
          :updated

        {:ok, %{num_rows: _}} ->
          Oli.Repo.rollback(:unexpected_update_count)

        {:error, e} ->
          Oli.Repo.rollback(e)
      end
    end)
  end

  @doc """
    Returns the last time a user accessed a section
  """

  def get_last_access_for_user_in_a_section(user_id, section_id) do
    query =
      from(u in User,
        join: enr in Enrollment,
        on: enr.user_id == u.id,
        join: ra in ResourceAccess,
        on: ra.user_id == enr.user_id,
        where: u.id == ^user_id and ra.section_id == ^section_id and enr.status == :enrolled,
        group_by: u.name,
        select: fragment("MAX(?)", ra.updated_at)
      )

    Repo.one(query)
  end

  def get_all_user_resource_attempt_counts(section, user_id) do
    from(
      a in ResourceAttempt,
      join: ra in ResourceAccess,
      on: a.resource_access_id == ra.id,
      join: rev in Revision,
      on: a.revision_id == rev.id,
      where: ra.section_id == ^section.id and ra.user_id == ^user_id and rev.graded,
      group_by: [ra.resource_id],
      select: {ra.resource_id, count(a.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  @doc """
  Retrieves proficiency data for a list of learning objectives, aggregated by objective_id and user_id.
  Returns a map where each key is an objective_id, and the value is another map where each key is a student_id and the value is the proficiency.

  ## Examples

      iex> proficiency_per_student_for_objective(1, [42, 43], student_id: 123)
      # Query result with raw proficiency data for objectives 42 and 43 in section 1
      # => %{42 => %{123 => "Low", 456 => "Medium", 789 => "Not enough data"}, 43 => %{123 => "High"}}
  """
  @spec proficiency_per_student_for_objective(
          section_id :: integer,
          objective_ids :: list(integer),
          opts :: Keyword.t()
        ) :: %{integer => %{integer => String.t()}}
  def proficiency_per_student_for_objective(section, objective_ids, opts \\ [])

  def proficiency_per_student_for_objective(section_id, objective_ids, opts)
      when is_integer(section_id) do
    section_id
    |> Sections.get_section!()
    |> proficiency_per_student_for_objective(objective_ids, opts)
  end

  def proficiency_per_student_for_objective(%Section{} = section, objective_ids, opts) do
    student_ids =
      case opts[:student_id] do
        nil ->
          {:ok, user_ids} = Proficiency.user_ids_for_objectives(section, objective_ids)
          user_ids

        student_id ->
          [student_id]
      end

    case Proficiency.estimates_for_objectives(section, student_ids, objective_ids) do
      {:ok, estimates} ->
        Map.new(estimates, fn {objective_id, by_user} ->
          {objective_id,
           Map.new(by_user, fn {user_id, estimate} -> {user_id, estimate_label(estimate)} end)}
        end)

      {:error, _reason} ->
        %{}
    end
  end

  @doc """
  Get proficiency data for a list of learning objectives (including sub-objectives) within a section.

  This function takes a list of SectionResource records and returns proficiency distribution
  data for each of them.

  ## Parameters
  - section_id: The section ID to get proficiency data from
  - section_slug: The section slug for filtering students
  - objective_section_resources: List of SectionResource structs for the objectives

  ## Returns
  List of objective data:
  [%{sub_objective_id: 123, title: "Sub-objective title", proficiency_distribution: %{...}}]
  """
  @spec objectives_proficiency(
          section_id :: integer,
          section_slug :: String.t(),
          objective_section_resources :: list(map())
        ) :: list(map())
  def objectives_proficiency(section_id, section_slug, objective_section_resources) do
    # Extract resource IDs from the SectionResource structs
    objective_ids = Enum.map(objective_section_resources, & &1.resource_id)

    # Get proficiency data for all objectives at once
    objectives_proficiency =
      proficiency_per_student_for_objective(section_id, objective_ids)

    student_ids =
      Sections.enrolled_student_ids(section_slug)

    # Process ALL objectives, not just those with proficiency data
    proficiency_dist_for_objectives =
      objective_ids
      |> Enum.reduce(%{}, fn obj_id, acc ->
        # Get proficiency data for this specific objective
        student_proficiency = Map.get(objectives_proficiency, obj_id, %{})

        # Filter proficiency data to only include enrolled students (exclude instructors)
        student_set = MapSet.new(student_ids)

        filtered_student_proficiency =
          student_proficiency
          |> Enum.filter(fn {user_id, _proficiency_level} ->
            MapSet.member?(student_set, user_id)
          end)
          |> Map.new()

        # Add "Not enough data" for students who don't have proficiency data
        complete_student_proficiency =
          student_ids
          |> Enum.reject(&Map.has_key?(filtered_student_proficiency, &1))
          |> Enum.reduce(filtered_student_proficiency, fn user_id, acc ->
            Map.put(acc, user_id, "Not enough data")
          end)

        proficiency_dist =
          Enum.frequencies_by(complete_student_proficiency, fn {_student_id, proficiency} ->
            proficiency
          end)

        Map.put(acc, obj_id, proficiency_dist)
      end)

    # Build result list using the SectionResource titles
    objective_section_resources
    |> Enum.map(fn section_resource ->
      %{
        sub_objective_id: section_resource.resource_id,
        title: section_resource.title,
        proficiency_distribution:
          Map.get(proficiency_dist_for_objectives, section_resource.resource_id, %{})
      }
    end)
  end

  @doc """
  Gets individual student proficiency data for a specific learning objective within a section.

  This function returns detailed proficiency data for each student, which shows how students are distributed
  across proficiency levels.

  ## Parameters
  - section_id: The section ID to filter students by
  - objective_id: The learning objective resource ID to get proficiency for

  ## Returns
  List of student proficiency data:
  [%{student_id: "123", proficiency: 0.85, proficiency_range: "High"}]
  """
  @spec student_proficiency_for_objective(section_id :: integer, objective_id :: integer) ::
          list(map())
  def student_proficiency_for_objective(section_id, objective_id) do
    section = Sections.get_section!(section_id)
    {:ok, student_ids} = Proficiency.user_ids_for_objectives(section, [objective_id])

    case Proficiency.estimates_for_objectives(section, student_ids, [objective_id]) do
      {:ok, estimates} ->
        estimates
        |> Map.get(objective_id, %{})
        |> Enum.map(fn {student_id, estimate} ->
          %{
            id: student_id,
            proficiency: estimate.score || 0.0,
            proficiency_range: estimate_label(estimate)
          }
        end)

      {:error, _reason} ->
        []
    end
  end

  @doc """
  Calculates how many activities a student has attempted out of the total related activities.

  Returns a map with student_id as key and attempt count as value.

  ## Parameters
  - section_id: The section ID
  - student_ids: List of student IDs to calculate for
  - related_activity_ids: List of activity resource IDs related to the objective

  ## Returns
  %{student_id => attempted_activities_count}
  """
  @spec student_activities_attempted_count(
          section_id :: integer,
          student_ids :: list(integer),
          related_activity_ids :: list(integer)
        ) :: map()
  def student_activities_attempted_count(_section_id, _student_ids, related_activity_ids)
      when related_activity_ids == [],
      do: %{}

  def student_activities_attempted_count(section_id, student_ids, related_activity_ids) do
    activity_type_id = Oli.Resources.ResourceType.id_for_activity()

    # Count distinct activities where the student has at least one attempt in any part
    # Note: ResourceSummary has multiple rows per activity (one per part_id),
    # so we filter by num_attempts > 0 and then count distinct resource_ids
    from(rs in ResourceSummary,
      where:
        rs.section_id == ^section_id and
          rs.user_id in ^student_ids and
          rs.resource_id in ^related_activity_ids and
          rs.project_id == -1 and
          rs.resource_type_id == ^activity_type_id and
          rs.num_attempts > 0,
      group_by: rs.user_id,
      select: {rs.user_id, fragment("COUNT(DISTINCT ?)", rs.resource_id)}
    )
    |> Repo.all()
    |> Map.new()
  end
end
