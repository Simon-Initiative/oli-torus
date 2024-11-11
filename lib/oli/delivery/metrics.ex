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

  alias Oli.Delivery.Sections.{
    ContainedPage,
    Enrollment,
    EnrollmentContextRole,
    Section,
    SectionResource
  }

  alias Oli.Accounts.User
  alias Lti_1p3.Tool.ContextRoles

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
          rs.publication_id == -1 and rs.project_id == -1 and rs.resource_type_id == ^page_type_id,
      group_by: rs.resource_id,
      select: {
        rs.resource_id,
        fragment(
          "CAST(SUM(?) as float) / CAST(SUM(?) as float)",
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
          rs.publication_id == -1 and rs.project_id == -1 and
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
          dynamic([_s, e, ra], e.user_id == ra.user_id)

        _ ->
          pages_for_container =
            from(cp in ContainedPage,
              where: cp.section_id == ^section.id and cp.container_id == ^container_id,
              select: cp.page_id
            )
            |> Repo.all()

          dynamic([_s, e, ra], e.user_id == ra.user_id and ra.resource_id in ^pages_for_container)
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
        on: e.user_id == ra.user_id,
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
    unique_objective_and_subobjective_ids =
      Enum.flat_map(learning_objectives, fn rev -> [rev.resource_id | rev.children] end)
      |> Enum.uniq()

    raw_proficiency_per_learning_objective =
      raw_proficiency_for_student_per_learning_objective(
        section,
        student_id,
        unique_objective_and_subobjective_ids
      )

    Enum.into(learning_objectives, %{}, fn rev ->
      aggregated_proficiency =
        if rev.children == [] do
          [
            Map.get(
              raw_proficiency_per_learning_objective,
              rev.resource_id,
              nil
            )
          ]
        else
          Enum.map(rev.children, fn subobjective_id ->
            Map.get(raw_proficiency_per_learning_objective, subobjective_id)
          end)
        end
        |> Enum.reject(&is_nil/1)
        |> aggregate_raw_proficiency()

      {rev.resource_id, aggregated_proficiency}
    end)
  end

  defp aggregate_raw_proficiency([]), do: proficiency_range(nil, 0)

  defp aggregate_raw_proficiency(raw_values) do
    {first_correct, first_count, _correct, _total} =
      Enum.reduce(raw_values, {0, 0, 0, 0}, fn {first_correct, first_count, correct, count},
                                               acc ->
        {first_correct + elem(acc, 0), first_count + elem(acc, 1), correct + elem(acc, 2),
         count + elem(acc, 3)}
      end)

    proficiency_value =
      if first_count == 0 do
        0
      else
        (1.0 * first_correct + 0.2 * (first_count - first_correct)) /
          first_count
      end

    proficiency_range(proficiency_value, first_count)
  end

  def raw_proficiency_per_learning_objective(%Section{id: section_id}) do
    objective_type_id = Oli.Resources.ResourceType.id_for_objective()

    query =
      from(summary in Oli.Analytics.Summary.ResourceSummary,
        where:
          summary.section_id == ^section_id and
            summary.project_id == -1 and
            summary.publication_id == -1 and
            summary.user_id == -1 and
            summary.resource_type_id == ^objective_type_id,
        select: {
          summary.resource_id,
          summary.num_first_attempts_correct,
          summary.num_first_attempts,
          summary.num_correct,
          summary.num_attempts
        }
      )

    Repo.all(query)
    |> Enum.reduce(%{}, fn {objective_id, num_first_attempts_correct, num_first_attempts,
                            num_correct, num_total},
                           acc ->
      Map.put(
        acc,
        objective_id,
        {num_first_attempts_correct, num_first_attempts, num_correct, num_total}
      )
    end)
  end

  def raw_proficiency_for_student_per_learning_objective(
        section,
        studend_id,
        objective_ids \\ nil
      )

  def raw_proficiency_for_student_per_learning_objective(
        %Section{analytics_version: _both, id: section_id},
        student_id,
        objective_ids
      ) do
    objective_type_id = Oli.Resources.ResourceType.id_for_objective()

    filter_by_objective_id =
      case objective_ids do
        nil ->
          true

        _ ->
          dynamic([summary], summary.resource_id in ^objective_ids)
      end

    query =
      from(summary in Oli.Analytics.Summary.ResourceSummary,
        where:
          summary.section_id == ^section_id and
            summary.project_id == -1 and
            summary.publication_id == -1 and
            summary.user_id == ^student_id and
            summary.resource_type_id == ^objective_type_id,
        where: ^filter_by_objective_id,
        select: {
          summary.resource_id,
          summary.num_first_attempts_correct,
          summary.num_first_attempts,
          summary.num_correct,
          summary.num_attempts
        }
      )

    Repo.all(query)
    |> Enum.reduce(%{}, fn {objective_id, num_first_attempts_correct, num_first_attempts,
                            num_correct, num_total},
                           acc ->
      Map.put(
        acc,
        objective_id,
        {num_first_attempts_correct, num_first_attempts, num_correct, num_total}
      )
    end)
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
        %Section{id: section_id, analytics_version: _both},
        contained_pages
      ) do
    page_type_id = Oli.Resources.ResourceType.id_for_page()

    query =
      from(summary in Oli.Analytics.Summary.ResourceSummary,
        where:
          summary.section_id == ^section_id and
            summary.project_id == -1 and
            summary.publication_id == -1 and
            summary.user_id == -1 and
            summary.resource_type_id == ^page_type_id,
        select: {
          summary.resource_id,
          summary.num_first_attempts_correct,
          summary.num_first_attempts,
          summary.num_correct,
          summary.num_attempts
        }
      )

    Repo.all(query)
    |> bucket_into_container_totals(contained_pages)
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
        %Section{analytics_version: _both, id: section_id} = section,
        container_id
      ) do
    filter_by_container =
      case container_id do
        nil ->
          true

        _ ->
          pages_for_container =
            from(cp in ContainedPage,
              where: cp.section_id == ^section.id and cp.container_id == ^container_id,
              select: cp.page_id
            )
            |> Repo.all()

          dynamic([sn], sn.resource_id in ^pages_for_container)
      end

    page_type_id = Oli.Resources.ResourceType.id_for_page()

    query =
      from(summary in Oli.Analytics.Summary.ResourceSummary,
        where:
          summary.section_id == ^section_id and
            summary.project_id == -1 and
            summary.publication_id == -1 and
            summary.user_id != -1 and
            summary.resource_type_id == ^page_type_id,
        where: ^filter_by_container,
        group_by: summary.user_id,
        select:
          {summary.user_id,
           fragment(
             """
             (
               (1 * NULLIF(CAST(SUM(?) as float), 0.0001)) +
               (0.2 * (NULLIF(CAST(SUM(?) as float), 0.0001) - NULLIF(CAST(SUM(?) as float), 0.0001)))
             ) /
             NULLIF(CAST(SUM(?) as float), 0.0001)
             """,
             summary.num_first_attempts_correct,
             summary.num_first_attempts,
             summary.num_first_attempts_correct,
             summary.num_first_attempts
           ), sum(summary.num_first_attempts)}
      )

    Repo.all(query)
    |> Enum.into(%{}, fn {student_id, proficiency, num_first_attempts} ->
      {student_id, proficiency_range(proficiency, num_first_attempts)}
    end)
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
        %Section{id: section_id, analytics_version: _both},
        student_id,
        contained_pages
      ) do
    page_type_id = Oli.Resources.ResourceType.id_for_page()

    query =
      from(summary in Oli.Analytics.Summary.ResourceSummary,
        where:
          summary.section_id == ^section_id and
            summary.project_id == -1 and
            summary.publication_id == -1 and
            summary.user_id == ^student_id and
            summary.resource_type_id == ^page_type_id,
        select: {
          summary.resource_id,
          summary.num_first_attempts_correct,
          summary.num_first_attempts,
          summary.num_correct,
          summary.num_attempts
        }
      )

    Repo.all(query)
    |> bucket_into_container_totals(contained_pages)
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
        %Section{id: section_id, analytics_version: _both},
        student_id
      ) do
    page_type_id = Oli.Resources.ResourceType.id_for_page()

    query =
      from(summary in Oli.Analytics.Summary.ResourceSummary,
        where:
          summary.section_id == ^section_id and
            summary.project_id == -1 and
            summary.publication_id == -1 and
            summary.user_id == ^student_id and
            summary.resource_type_id == ^page_type_id,
        select: {
          summary.resource_id,
          fragment(
            """
            (
              (1 * NULLIF(CAST(? as float), 0.0001)) +
              (0.2 * (NULLIF(CAST(? as float), 0.0001) - NULLIF(CAST(? as float), 0.0001)))
            ) /
            NULLIF(CAST(? as float), 0.0001)
            """,
            summary.num_first_attempts_correct,
            summary.num_first_attempts,
            summary.num_first_attempts_correct,
            summary.num_first_attempts
          ),
          summary.num_first_attempts
        }
      )

    Repo.all(query)
    |> Enum.into(%{}, fn {resource_id, proficiency, num_first_attempts} ->
      {resource_id, proficiency_range(proficiency, num_first_attempts)}
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
        %Section{id: section_id, analytics_version: _both},
        page_id
      ) do
    page_type_id = Oli.Resources.ResourceType.id_for_page()

    query =
      from(summary in Oli.Analytics.Summary.ResourceSummary,
        where:
          summary.section_id == ^section_id and
            summary.project_id == -1 and
            summary.publication_id == -1 and
            summary.user_id != -1 and
            summary.resource_id == ^page_id and
            summary.resource_type_id == ^page_type_id,
        select:
          {summary.user_id,
           fragment(
             """
             (
               (1 * NULLIF(CAST(? as float), 0.0001)) +
               (0.2 * (NULLIF(CAST(? as float), 0.0001) - NULLIF(CAST(? as float), 0.0001)))
             ) /
             NULLIF(CAST(? as float), 0.0001)
             """,
             summary.num_first_attempts_correct,
             summary.num_first_attempts,
             summary.num_first_attempts_correct,
             summary.num_first_attempts
           ), summary.num_first_attempts}
      )

    Repo.all(query)
    |> Enum.into(%{}, fn {student_id, proficiency, num_first_attempts} ->
      {student_id, proficiency_range(proficiency, num_first_attempts)}
    end)
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
  def proficiency_per_page(%Section{id: section_id, analytics_version: _both}, page_ids) do
    page_type_id = Oli.Resources.ResourceType.id_for_page()

    query =
      from(summary in Oli.Analytics.Summary.ResourceSummary,
        where:
          summary.section_id == ^section_id and
            summary.project_id == -1 and
            summary.publication_id == -1 and
            summary.user_id == -1 and
            summary.resource_id in ^page_ids and
            summary.resource_type_id == ^page_type_id,
        select:
          {summary.resource_id,
           fragment(
             """
             (
               (1 * NULLIF(CAST(? as float), 0.0001)) +
               (0.2 * (NULLIF(CAST(? as float), 0.0001) - NULLIF(CAST(? as float), 0.0001)))
             ) /
             NULLIF(CAST(? as float), 0.0001)
             """,
             summary.num_first_attempts_correct,
             summary.num_first_attempts,
             summary.num_first_attempts_correct,
             summary.num_first_attempts
           ), summary.num_first_attempts}
      )

    Repo.all(query)
    |> Enum.into(%{}, fn {page_id, proficiency, num_first_attempts} ->
      {page_id, proficiency_range(proficiency, num_first_attempts)}
    end)
  end

  def proficiency_range(_, num_first_attempts) when num_first_attempts < 3, do: "Not enough data"
  def proficiency_range(nil, _num_first_attempts), do: "Not enough data"
  def proficiency_range(proficiency, _num_first_attempts) when proficiency <= 0.4, do: "Low"
  def proficiency_range(proficiency, _num_first_attempts) when proficiency <= 0.8, do: "Medium"
  def proficiency_range(_proficiency, _num_first_attempts), do: "High"

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
  evaluation of the first attempt for given activity.  This method should update exactly one record, the resource
  access for the page that this activity attempt ultimately pertains to (through its parent resource attempt).

  Can return one of:
  {:ok, :updated} -> Progress calculated and set
  {:ok, :noop} -> Noting needed to be done, since the attempt number was greater than 1
  {:error, :unexpected_update_count} -> 0 or more than 1 record would have been updated, rolled back
  {:error, e} -> An other error occurred, rolled back
  """
  def update_page_progress(activity_attempt_guid) when is_binary(activity_attempt_guid) do
    if Core.is_scoreable_first_attempt?(activity_attempt_guid) do
      do_update(activity_attempt_guid)
    else
      {:ok, :noop}
    end
  end

  def update_page_progress(%ActivityAttempt{
        scoreable: true,
        attempt_number: 1,
        attempt_guid: attempt_guid
      }) do
    do_update(attempt_guid)
  end

  def update_page_progress(_) do
    {:ok, :noop}
  end

  defp do_update(activity_attempt_guid) do
    Oli.Repo.transaction(fn ->
      sql = """
        UPDATE
          resource_accesses
        SET
          progress = GREATEST((SELECT
              COUNT(aa2.id) filter (WHERE aa2.lifecycle_state = 'evaluated' OR aa2.lifecycle_state = 'submitted')::float / COUNT(aa2.id)::float
            FROM activity_attempts as aa
            JOIN resource_attempts as ra ON ra.id = aa.resource_attempt_id
            JOIN activity_attempts as aa2 ON ra.id = aa2.resource_attempt_id
            WHERE aa.attempt_guid = $1 AND aa2.scoreable = true AND aa2.attempt_number = 1), resource_accesses.progress),
          updated_at = NOW()
        WHERE
          id =
            (SELECT
              resource_attempts.resource_access_id
            FROM resource_attempts
            JOIN activity_attempts ON resource_attempts.id = activity_attempts.resource_attempt_id
            WHERE activity_attempts.attempt_guid = $2
            LIMIT 1);
      """

      case Ecto.Adapters.SQL.query(Oli.Repo, sql, [activity_attempt_guid, activity_attempt_guid]) do
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

  # Given a list of ContainedPage records, return a map of
  # page ids to a list of container ids (their ancestor containers)
  # that contain that page
  #
  # For instance, given the following ContainedPage records:
  #
  #  %ContainedPage{container_id: 1, page_id: 10}
  #  %ContainedPage{container_id: 1, page_id: 11}
  #  %ContainedPage{container_id: 2, page_id: 10}
  #
  # This function will return:
  # %{10 => [1, 2], 11 => [1]}
  defp page_to_parent_containers_map(contained_pages) do
    Enum.reduce(contained_pages, %{}, fn %ContainedPage{
                                           container_id: container_id,
                                           page_id: page_id
                                         },
                                         inverted_cp_index ->
      case Map.get(inverted_cp_index, page_id) do
        nil -> Map.put(inverted_cp_index, page_id, [container_id])
        container_ids -> Map.put(inverted_cp_index, page_id, [container_id | container_ids])
      end
    end)
  end

  # Given a list of ContainedPage records, return a map of container ids to a tuple of
  # correct and total values, initialized to {0.0, 0.0, 0.0, 0.0}
  defp init_container_totals(contained_pages) do
    Enum.reduce(contained_pages, %{}, fn %ContainedPage{container_id: container_id}, map ->
      Map.put(map, container_id, {0.0, 0.0, 0.0, 0.0})
    end)
  end

  # Given a list of {page_id, first_attempt_correct, first_attempt_total, total_correct, total} tuples, and a list of
  # ContainedPage records, return a map of container ids to a tuple of correct and total values,
  # where the container totals are the sum of the page totals for all pages contained in that container.
  defp bucket_into_container_totals(page_totals, contained_pages) do
    inverted_cp_index = page_to_parent_containers_map(contained_pages)
    container_totals = init_container_totals(contained_pages)

    Enum.reduce(page_totals, container_totals, fn {page_id, first_correct, first_total, correct,
                                                   total},
                                                  map ->
      container_ids = Map.get(inverted_cp_index, page_id)

      case container_ids do
        nil ->
          map

        _ ->
          Enum.reduce(container_ids, map, fn container_id, map ->
            update_in(map, [container_id], fn {current_first_correct, current_first_total,
                                               current_correct, current_total} ->
              {current_first_correct + first_correct, current_first_total + first_total,
               current_correct + correct, current_total + total}
            end)
          end)
      end
    end)
    |> Enum.into(%{}, fn {container_id, {first_correct, first_total, _correct, total}} ->
      proficiency =
        case total do
          total when total in [+0.0, -0.0] ->
            nil

          _ ->
            (1 * first_correct + 0.2 * (first_total - first_correct)) / first_total
        end

      {container_id, proficiency_range(proficiency, total)}
    end)
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
end
