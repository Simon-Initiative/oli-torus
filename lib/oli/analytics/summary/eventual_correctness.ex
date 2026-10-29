defmodule Oli.Analytics.Summary.EventualCorrectness do
  @moduledoc """
  Derives eventual correctness from historical per-learner summaries.

  A learner's positive correct-submission count represents one success regardless
  of subsequent submissions. Each section enrollment is a separate learning
  opportunity, consistent with first-attempt counts across sections.
  """

  import Ecto.Query

  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Delivery.Sections.{Section, SectionsProjectsPublications}
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Resources.{ResourceType, Revision}
  alias Oli.Resources.ObjectiveIds

  require ObjectiveIds

  @doc """
  Returns attempted and successful learner counts per resource and part.

  With no section filter, counts are combined over sections using the project.
  Explicit section IDs are intersected with the project's sections, including
  sections using the project through a publication association. Section-only
  callers may pass a nil project ID after authorizing access to those sections.
  Submission counters are read without modification, so historical data needs
  no migration or replay of the analytics pipeline.

  Page and objective rollups combine learner-question-part opportunities, not
  learners with any success in the parent resource. Historical evaluated
  attempts supply page membership and the objective tags used at the time.

  `:resource_ids` limits the requested activity, page, or objective IDs;
  `:part_id` optionally narrows activity parts. Historical membership is
  deduplicated before joining learner summaries. Missing evidence in any
  contributing section or opportunity produces nil counts.

  Internal ranking callers may supply a resource-ID query instead of a list,
  keeping candidate filters within SQL rather than materializing all IDs.
  """
  def counts_query(project_id, section_ids, resource_type_id \\ nil, opts \\ []) do
    resource_type_id = resource_type_id || ResourceType.id_for_activity()
    activity_type_id = ResourceType.id_for_activity()
    page_type_id = ResourceType.id_for_page()
    objective_type_id = ResourceType.id_for_objective()
    scope = section_scope(project_id, section_ids)
    students = student_summaries_query(scope)

    opportunities =
      case resource_type_id do
        ^activity_type_id ->
          students
          |> filter_resources(Keyword.get(opts, :resource_ids))
          |> filter_part(Keyword.get(opts, :part_id))
          |> select([s], %{
            resource_id: s.resource_id,
            resource_type_id: s.resource_type_id,
            part_id: s.part_id,
            section_id: s.section_id,
            num_correct: s.num_correct,
            num_attempts: s.num_attempts
          })

        ^page_type_id ->
          scope
          |> page_membership(Keyword.get(opts, :resource_ids))
          |> join_student_summaries(students, page_type_id)

        ^objective_type_id ->
          scope
          |> objective_membership(Keyword.get(opts, :resource_ids))
          |> join_student_summaries(students, objective_type_id)
      end

    query =
      from(s in subquery(opportunities),
        group_by: [s.resource_id, s.resource_type_id, s.part_id, s.section_id],
        select: %{
          resource_id: s.resource_id,
          resource_type_id: s.resource_type_id,
          part_id: s.part_id,
          section_id: s.section_id,
          num_attempted:
            fragment("CASE WHEN count(?) = count(*) THEN count(*) END", s.num_attempts),
          num_correct:
            fragment(
              "CASE WHEN count(?) = count(*) THEN count(*) FILTER (WHERE ? > 0) END",
              s.num_attempts,
              s.num_correct
            )
        }
      )

    query = include_missing_sections(query, scope, resource_type_id, opts)

    case section_ids do
      [] ->
        from(s in subquery(query),
          group_by: [s.resource_id, s.resource_type_id, s.part_id],
          select: %{
            resource_id: s.resource_id,
            resource_type_id: s.resource_type_id,
            part_id: s.part_id,
            section_id: -1,
            num_attempted:
              fragment(
                "CASE WHEN count(?) = count(*) THEN sum(?)::bigint END",
                s.num_attempted,
                s.num_attempted
              ),
            num_correct:
              fragment(
                "CASE WHEN count(?) = count(*) THEN sum(?)::bigint END",
                s.num_attempted,
                s.num_correct
              )
          }
        )

      _ ->
        query
    end
  end

  # Section-wide counters identify attempted parts whose learner summaries or
  # historical membership are entirely missing. Keep them as NULL instead of
  # silently dropping that section from a project-wide denominator.
  defp include_missing_sections(counts, scope, resource_type_id, opts) do
    from(s in ResourceSummary,
      left_join: ec in subquery(counts),
      on:
        ec.section_id == s.section_id and ec.resource_id == s.resource_id and
          ec.resource_type_id == s.resource_type_id and
          fragment("? IS NOT DISTINCT FROM ?", ec.part_id, s.part_id),
      where: s.project_id == -1 and s.user_id == -1 and s.section_id != -1 and s.num_attempts > 0,
      where: s.resource_type_id == ^resource_type_id,
      where: ^scope,
      distinct: [s.section_id, s.resource_id, s.resource_type_id, s.part_id],
      select: %{
        resource_id: s.resource_id,
        resource_type_id: s.resource_type_id,
        part_id: s.part_id,
        section_id: s.section_id,
        num_attempted: ec.num_attempted,
        num_correct: ec.num_correct
      }
    )
    |> filter_resources(Keyword.get(opts, :resource_ids))
    |> filter_part(Keyword.get(opts, :part_id))
  end

  @doc """
  Combines successful/attempted learner counts into a rate.

  Missing evidence in any contributing part makes the whole rate unavailable.
  A measured zero requires a positive attempted-learner count.
  """
  def rate(counts) do
    Enum.reduce_while(counts, {0, 0}, fn
      {correct, attempted}, {correct_total, attempted_total}
      when is_integer(correct) and is_integer(attempted) and attempted > 0 ->
        {:cont, {correct_total + correct, attempted_total + attempted}}

      _, _ ->
        {:halt, nil}
    end)
    |> case do
      {correct, attempted} when attempted > 0 -> correct / attempted
      _ -> nil
    end
  end

  @doc """
  Returns a summary-row section filter constrained to the supplied project.

  An empty section list includes all sections using the project. Explicit IDs
  narrow that set. A nil project ID supports section-only callers that have
  already authorized access to the supplied sections.
  """
  def section_scope(project_id, []) do
    project_sections =
      from(section in Section,
        left_join: sp in SectionsProjectsPublications,
        on: sp.section_id == section.id,
        where: section.base_project_id == ^project_id or sp.project_id == ^project_id,
        select: section.id
      )

    dynamic([s], s.section_id in subquery(project_sections))
  end

  def section_scope(nil, ids), do: dynamic([s], s.section_id in ^ids)

  def section_scope(project_id, ids) do
    project_scope = section_scope(project_id, [])
    dynamic([s], ^project_scope and s.section_id in ^ids)
  end

  defp student_summaries_query(scope) do
    activity_type_id = ResourceType.id_for_activity()

    from(s in ResourceSummary,
      where: s.project_id == -1 and s.user_id != -1 and s.num_attempts > 0,
      where: s.resource_type_id == ^activity_type_id,
      where: ^scope
    )
  end

  defp filter_resources(query, nil), do: query

  defp filter_resources(query, %Ecto.Query{} = ids),
    do: where(query, [s], s.resource_id in subquery(ids))

  defp filter_resources(query, ids), do: where(query, [s], s.resource_id in ^ids)
  defp filter_part(query, nil), do: query
  defp filter_part(query, part_id), do: where(query, [s], s.part_id == ^part_id)

  # Retry history is reduced to compact membership before learner summaries are
  # joined. Page queries do not need revision data; objective queries retain the
  # historical revision until its tags have been expanded and deduplicated.
  defp historical_activity_attempts(scope) do
    from(access in ResourceAccess,
      join: ra in ResourceAttempt,
      on: ra.resource_access_id == access.id,
      join: aa in ActivityAttempt,
      on: aa.resource_attempt_id == ra.id,
      where: ^scope
    )
  end

  defp historical_attempts(scope) do
    from([_access, _ra, aa] in historical_activity_attempts(scope),
      join: pa in PartAttempt,
      on: pa.activity_attempt_id == aa.id,
      where: pa.lifecycle_state == :evaluated
    )
  end

  defp page_membership(scope, resource_ids) do
    scope
    |> historical_attempts()
    |> filter_resources(resource_ids)
    |> distinct(true)
    |> select([access, _ra, aa, pa], %{
      resource_id: access.resource_id,
      section_id: access.section_id,
      user_id: access.user_id,
      activity_id: aa.resource_id,
      activity_part_id: pa.part_id
    })
  end

  defp objective_membership(scope, resource_ids) do
    activity_attempts =
      scope
      |> historical_activity_attempts()
      |> restrict_objective_revisions(scope, resource_ids)
      |> select([access, _ra, aa], %{
        section_id: access.section_id,
        user_id: access.user_id,
        activity_id: aa.resource_id,
        revision_id: aa.revision_id,
        activity_attempt_id: aa.id
      })
      # Keep the filtered activity set ahead of the retry join in PostgreSQL's
      # plan. Without this boundary the planner can materialize every retry
      # before applying the objective-revision semi-join.
      |> offset(0)

    attempts =
      from(aa in subquery(activity_attempts),
        join: pa in PartAttempt,
        on: pa.activity_attempt_id == aa.activity_attempt_id,
        where: pa.lifecycle_state == :evaluated,
        distinct: true,
        select: %{
          section_id: aa.section_id,
          user_id: aa.user_id,
          activity_id: aa.activity_id,
          revision_id: aa.revision_id,
          activity_part_id: pa.part_id
        }
      )

    membership =
      from(attempt in subquery(attempts),
        join: revision in Revision,
        on: revision.id == attempt.revision_id,
        join:
          objective in fragment(
            "jsonb_array_elements_text(CASE WHEN jsonb_typeof(?) = 'array' THEN ? WHEN jsonb_typeof(? -> ?) = 'array' THEN ? -> ? ELSE '[]'::jsonb END)",
            revision.objectives,
            revision.objectives,
            revision.objectives,
            attempt.activity_part_id,
            revision.objectives,
            attempt.activity_part_id
          ),
        on: true,
        distinct: true,
        select: %{
          resource_id: type(ObjectiveIds.safe_id(objective.value), :integer),
          section_id: attempt.section_id,
          user_id: attempt.user_id,
          activity_id: attempt.activity_id,
          activity_part_id: attempt.activity_part_id
        }
      )

    from(m in subquery(membership)) |> filter_resources(resource_ids)
  end

  defp restrict_objective_revisions(query, _scope, nil), do: query

  defp restrict_objective_revisions(query, scope, resource_ids) do
    # Narrow activity revisions before reading their retry history. Only this
    # section/project's observed revisions are expanded, and part-specific tags
    # are still checked by objective_membership after retries are deduplicated.
    observed_revisions =
      scope
      |> historical_activity_attempts()
      |> select([_access, _ra, aa], aa.revision_id)
      |> distinct(true)

    matching =
      from(revision in Revision,
        where: revision.id in subquery(observed_revisions),
        join:
          tags in fragment(
            "jsonb_each(CASE WHEN jsonb_typeof(?) = 'array' THEN jsonb_build_object('_', ?) WHEN jsonb_typeof(?) = 'object' THEN ? ELSE '{}'::jsonb END)",
            revision.objectives,
            revision.objectives,
            revision.objectives,
            revision.objectives
          ),
        on: true,
        join:
          objective in fragment(
            "jsonb_array_elements_text(CASE WHEN jsonb_typeof(?) = 'array' THEN ? ELSE '[]'::jsonb END)",
            tags.value,
            tags.value
          ),
        on: true,
        select: %{
          resource_id: type(ObjectiveIds.safe_id(objective.value), :integer),
          revision_id: revision.id
        }
      )

    # Filter the objective IDs inside the derived membership, before selecting
    # revision IDs for the activity-attempt semi-join.
    filtered = from(row in subquery(matching)) |> filter_resources(resource_ids)
    revision_ids = from(row in subquery(filtered), select: row.revision_id, distinct: true)

    where(query, [_access, _ra, aa], aa.revision_id in subquery(revision_ids))
  end

  defp join_student_summaries(membership, students, resource_type_id) do
    from(m in subquery(membership),
      left_join: s in subquery(students),
      on:
        s.section_id == m.section_id and s.user_id == m.user_id and
          s.resource_id == m.activity_id and s.part_id == m.activity_part_id,
      select: %{
        resource_id: m.resource_id,
        resource_type_id: type(^resource_type_id, :integer),
        part_id: "unknown",
        section_id: m.section_id,
        num_correct: s.num_correct,
        num_attempts: s.num_attempts
      }
    )
  end
end
