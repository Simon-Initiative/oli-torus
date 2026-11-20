defmodule Oli.Analytics.Summary.EventualCorrectness do
  @moduledoc """
  Derives eventual correctness from historical per-learner summaries.

  A learner's positive correct-submission count represents one success regardless
  of subsequent submissions. Each section enrollment is a separate learning
  opportunity, consistent with first-attempt counts across sections.
  """

  import Ecto.Query

  alias Oli.Activities.AdaptiveParts
  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Delivery.Sections.{Section, SectionsProjectsPublications}
  alias Oli.Resources.ResourceType

  @doc """
  Returns attempted and successful learner counts for individual activity parts.

  Each learner counts once per section and part, regardless of retries. Missing
  correctness counters or section-wide evidence without learner summaries produce
  nil counts. No attempt history is read. Project scopes include sections using
  that project; explicit section selections narrow that set. A nil project ID is
  reserved for callers that have already authorized the supplied sections.

  `:resource_ids` accepts a list or resource-ID query; `:part_id` narrows the parts.
  Page and objective response accuracy is calculated from aggregate summaries by
  the caller, independently of eventual correctness.
  """
  def counts_query(project_id, section_ids, resource_type_id \\ nil, opts \\ []) do
    activity_type_id = ResourceType.id_for_activity()
    resource_type_id = resource_type_id || activity_type_id
    ^activity_type_id = resource_type_id

    part_counts_query(project_id, section_ids, opts)
    |> aggregate_sections(section_ids)
  end

  defp part_counts_query(project_id, section_ids, opts) do
    resource_type_id = ResourceType.id_for_activity()
    scope = section_scope(project_id, section_ids)

    opportunities =
      scope
      |> student_summaries_query()
      |> filter_resources(Keyword.get(opts, :resource_ids))
      |> filter_part(Keyword.get(opts, :part_id))

    query =
      from(s in subquery(opportunities),
        group_by: [s.resource_id, s.resource_type_id, s.part_id, s.section_id],
        select: %{
          resource_id: s.resource_id,
          resource_type_id: s.resource_type_id,
          part_id: s.part_id,
          section_id: s.section_id,
          num_attempted:
            fragment(
              "CASE WHEN count(?) = count(*) AND count(?) = count(*) THEN count(*) END",
              s.num_attempts,
              s.num_correct
            ),
          num_correct:
            fragment(
              "CASE WHEN count(?) = count(*) AND count(?) = count(*) THEN count(*) FILTER (WHERE ? > 0) END",
              s.num_attempts,
              s.num_correct,
              s.num_correct
            )
        }
      )

    include_missing_sections(query, scope, resource_type_id, opts)
  end

  defp aggregate_sections(query, section_ids) do
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

  # Section-wide counters identify attempted parts whose learner summaries
  # are entirely missing. Keep them as NULL instead of
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

  @doc """
  Returns scored part IDs from the activity definition already loaded for display.

  Adaptive screens use their response-summary parts, excluding state-only inputs.
  Ordinary activities use their authored parts. Empty definitions cannot establish
  whole-question correctness.
  """
  def required_part_ids(%{content: content}) when is_map(content) do
    case Map.has_key?(content, "partsLayout") do
      true ->
        definitions = AdaptiveParts.merged_parts_by_id(content)

        content
        |> AdaptiveParts.response_summary_part_ids()
        |> Enum.filter(&scored_part?(Map.get(definitions, &1)))

      false ->
        (get_in(content, ["authoring", "parts"]) || [])
        |> Enum.filter(&scored_part?/1)
        |> Enum.map(&Map.get(&1, "id"))
    end
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
  end

  def required_part_ids(_), do: []

  defp scored_part?(%{"outOf" => out_of}) when is_number(out_of), do: out_of > 0
  defp scored_part?(%{"gradingApproach" => "manual"}), do: true

  defp scored_part?(%{"responses" => [_ | _] = responses}) do
    Enum.any?(responses, fn response ->
      case Map.get(response, "score") do
        score when is_number(score) -> score > 0
        _ -> false
      end
    end)
  end

  defp scored_part?(_), do: true

  @doc """
  Returns whole-question learner counts using only resource summaries.

  `required_parts` maps activity IDs to their scored part IDs. A learner who has
  attempted any required part qualifies only after every required part has a
  positive correct counter, possibly on different submissions. An unattempted
  required part prevents success. Missing counters or missing per-learner evidence
  for an attempted section/part make the question unavailable. Each section
  enrollment is counted separately, matching individual-part opportunities.
  """
  def question_counts_query(project_id, section_ids, required_parts) do
    pairs =
      for {resource_id, ids} <- required_parts,
          part_id <- Enum.uniq(ids),
          do: {resource_id, part_id}

    {resource_ids, part_ids} = Enum.unzip(pairs)

    parts =
      from(
        p in fragment(
          "SELECT * FROM unnest(?::bigint[], ?::text[]) AS parts(resource_id, part_id)",
          ^resource_ids,
          ^part_ids
        ),
        select: %{
          resource_id: type(p.resource_id, :integer),
          part_id: type(p.part_id, :string),
          num_parts: fragment("count(*) OVER (PARTITION BY ?)", p.resource_id)
        }
      )

    students =
      section_scope(project_id, section_ids)
      |> student_summaries_query()
      |> filter_resources(Enum.uniq(resource_ids))

    learners =
      from(s in students,
        join: p in subquery(parts),
        on: p.resource_id == s.resource_id and p.part_id == s.part_id,
        group_by: [s.resource_id, s.section_id, s.user_id],
        select: %{
          resource_id: s.resource_id,
          section_id: s.section_id,
          num_correct:
            fragment(
              "CASE WHEN count(?) = count(*) THEN CASE WHEN count(*) FILTER (WHERE ? > 0) = max(?) THEN 1 ELSE 0 END END",
              s.num_correct,
              s.num_correct,
              p.num_parts
            )
        }
      )

    counts =
      from(l in subquery(learners),
        group_by: [l.resource_id, l.section_id],
        select: %{
          resource_id: l.resource_id,
          section_id: l.section_id,
          num_attempted:
            fragment("CASE WHEN count(?) = count(*) THEN count(*) END", l.num_correct),
          num_correct:
            fragment(
              "CASE WHEN count(?) = count(*) THEN sum(?)::bigint END",
              l.num_correct,
              l.num_correct
            )
        }
      )

    # Anchor completeness to attempted section-wide parts. An absent learner row
    # must not silently improve a rate by disappearing from its denominator.
    availability =
      from(
        ec in subquery(
          part_counts_query(project_id, section_ids, resource_ids: Enum.uniq(resource_ids))
        ),
        join: p in subquery(parts),
        on: ec.resource_id == p.resource_id and ec.part_id == p.part_id,
        group_by: [ec.resource_id, ec.section_id],
        select: %{
          resource_id: ec.resource_id,
          section_id: ec.section_id,
          complete: fragment("count(?) = count(*)", ec.num_attempted)
        }
      )

    from(a in subquery(availability),
      left_join: c in subquery(counts),
      on: c.resource_id == a.resource_id and c.section_id == a.section_id,
      select: %{
        resource_id: a.resource_id,
        resource_type_id: type(^ResourceType.id_for_activity(), :integer),
        part_id: type(^nil, :string),
        section_id: a.section_id,
        num_attempted: fragment("CASE WHEN ? THEN ? END", a.complete, c.num_attempted),
        num_correct: fragment("CASE WHEN ? THEN ? END", a.complete, c.num_correct)
      }
    )
    |> aggregate_sections(section_ids)
  end
end
