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

  @doc """
  Returns attempted and successful learner counts per resource and part.

  With no section filter, counts are combined over sections using the project.
  Submission counters are read without modification, so historical data needs
  no migration or replay of the analytics pipeline.

  Page and objective rollups combine learner-question-part opportunities, not
  learners with any success in the parent resource. Historical evaluated
  attempts supply page membership and the objective tags used at the time.
  """
  def counts_query(project_id, section_ids, resource_type_id \\ nil) do
    resource_type_id = resource_type_id || ResourceType.id_for_activity()
    activity_type_id = ResourceType.id_for_activity()
    page_type_id = ResourceType.id_for_page()
    objective_type_id = ResourceType.id_for_objective()
    students = student_summaries_query(project_id, section_ids)

    opportunities =
      case resource_type_id do
        ^activity_type_id ->
          students
          |> select([s], %{
            resource_id: s.resource_id,
            resource_type_id: s.resource_type_id,
            part_id: s.part_id,
            section_id: s.section_id,
            num_correct: s.num_correct
          })

        ^page_type_id ->
          students |> historical_opportunities() |> page_opportunities(page_type_id)

        ^objective_type_id ->
          students |> historical_opportunities() |> objective_opportunities(objective_type_id)
      end

    query =
      from(s in subquery(opportunities),
        group_by: [s.resource_id, s.resource_type_id, s.part_id],
        select: %{
          resource_id: s.resource_id,
          resource_type_id: s.resource_type_id,
          part_id: s.part_id,
          num_attempted: count(),
          num_correct: filter(count(), s.num_correct > 0)
        }
      )

    case section_ids do
      [] -> select_merge(query, %{section_id: -1})
      _ -> query |> group_by([s], s.section_id) |> select_merge([s], %{section_id: s.section_id})
    end
  end

  defp student_summaries_query(project_id, section_ids) do
    scope =
      case section_ids do
        [] ->
          project_sections =
            from(section in Section,
              left_join: sp in SectionsProjectsPublications,
              on: sp.section_id == section.id,
              where: section.base_project_id == ^project_id or sp.project_id == ^project_id,
              select: section.id
            )

          dynamic([s], s.section_id in subquery(project_sections))

        ids ->
          dynamic([s], s.section_id in ^ids)
      end

    activity_type_id = ResourceType.id_for_activity()

    from(s in ResourceSummary,
      where: s.project_id == -1 and s.user_id != -1 and s.num_attempts > 0,
      where: s.resource_type_id == ^activity_type_id,
      where: ^scope
    )
  end

  # Historical attempts supply membership only. Correctness still comes from
  # the learner's cumulative question-part summary, so later failures never
  # erase a success. DISTINCT removes retries and repeated activity attempts.
  defp historical_opportunities(students) do
    from(s in students,
      join: access in ResourceAccess,
      on: access.section_id == s.section_id and access.user_id == s.user_id,
      join: ra in ResourceAttempt,
      on: ra.resource_access_id == access.id,
      join: aa in ActivityAttempt,
      on: aa.resource_attempt_id == ra.id and aa.resource_id == s.resource_id,
      join: pa in PartAttempt,
      on: pa.activity_attempt_id == aa.id and pa.part_id == s.part_id,
      join: revision in Revision,
      on: revision.id == aa.revision_id,
      where: pa.lifecycle_state == :evaluated
    )
  end

  defp page_opportunities(query, page_type_id) do
    from([s, access] in query,
      distinct: true,
      select: %{
        resource_id: access.resource_id,
        resource_type_id: type(^page_type_id, :integer),
        part_id: "unknown",
        section_id: s.section_id,
        user_id: s.user_id,
        activity_id: s.resource_id,
        activity_part_id: s.part_id,
        num_correct: s.num_correct
      }
    )
  end

  defp objective_opportunities(query, objective_type_id) do
    from([s, _access, _ra, _aa, _pa, revision] in query,
      join:
        objective in fragment(
          "jsonb_array_elements_text(CASE WHEN jsonb_typeof(?) = 'array' THEN ? ELSE COALESCE(? -> ?, '[]'::jsonb) END)",
          revision.objectives,
          revision.objectives,
          revision.objectives,
          s.part_id
        ),
      on: true,
      distinct: true,
      select: %{
        resource_id: fragment("?::bigint", objective.value),
        resource_type_id: type(^objective_type_id, :integer),
        part_id: "unknown",
        section_id: s.section_id,
        user_id: s.user_id,
        activity_id: s.resource_id,
        activity_part_id: s.part_id,
        num_correct: s.num_correct
      }
    )
  end
end
