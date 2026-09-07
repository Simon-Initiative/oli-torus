defmodule Oli.Delivery.Sections.LinkedActivities do
  @moduledoc """
  Resolves the activity set and delivery context for instructor Learning Objective insights.

  `get_activities_for_objective/2` is the entry point used by the instructor dashboard.
  The remaining functions are the composable steps it is built from, exposed so each can
  be tested on its own.

  Relationship discovery is depot-backed. The module does not inspect activity revision
  objective JSON during an instructor request; that relationship is maintained by section
  post-processing.
  """

  import Ecto.Query

  alias Oli.Activities
  alias Oli.Analytics.Summary
  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Resources.Revision

  @type page_context :: %{
          page_resource_id: integer(),
          page_revision: map()
        }

  @type linked_context :: %{
          objective_ids: [integer()],
          activity_ids: [integer()],
          activity_page_contexts: %{optional(integer()) => [page_context()]},
          canonical_page_context: %{optional(integer()) => page_context()}
        }

  @doc """
  Resolves the selected objective and all of its effective descendants.

  The input is intentionally a list of objective-like maps or structs so hierarchy traversal
  and cycle handling can be tested without a database.
  """
  @spec objective_family_ids([map()], integer()) :: [integer()]
  def objective_family_ids(objectives, selected_objective_id) do
    objectives_by_id = Map.new(objectives, &{&1.resource_id, &1})

    do_objective_family_ids(objectives_by_id, selected_objective_id, MapSet.new(), [])
    |> elem(1)
    |> Enum.reverse()
  end

  defp do_objective_family_ids(objectives_by_id, objective_id, visited, result) do
    cond do
      MapSet.member?(visited, objective_id) ->
        {visited, result}

      not Map.has_key?(objectives_by_id, objective_id) ->
        {visited, result}

      true ->
        objective = Map.fetch!(objectives_by_id, objective_id)
        visited = MapSet.put(visited, objective_id)
        result = [objective_id | result]

        Enum.reduce(List.wrap(Map.get(objective, :children, [])), {visited, result}, fn child_id,
                                                                                        {visited,
                                                                                         result} ->
          do_objective_family_ids(objectives_by_id, child_id, visited, result)
        end)
    end
  end

  @doc "Returns stable, unique activity IDs related to the supplied objective resources."
  @spec unique_activity_ids([map()]) :: [integer()]
  def unique_activity_ids(objective_resources) do
    Enum.reduce(objective_resources, MapSet.new(), fn resource, ids ->
      Enum.reduce(List.wrap(Map.get(resource, :related_activities, [])), ids, &MapSet.put(&2, &1))
    end)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  @doc "Returns the unique activity IDs for a selected objective and its effective descendants."
  @spec activity_ids_for_objective([map()], [map()], integer()) :: [integer()]
  def activity_ids_for_objective(objectives, objective_resources, selected_objective_id) do
    objectives
    |> objective_family_ids(selected_objective_id)
    |> activity_ids_for_objective_family(objective_resources)
  end

  @doc "Returns the unique activity IDs for an already-resolved objective family."
  @spec activity_ids_for_objective_family([integer()], [map()]) :: [integer()]
  def activity_ids_for_objective_family(objective_ids, objective_resources) do
    objective_resources_by_id = Map.new(objective_resources, &{&1.resource_id, &1})

    objective_ids
    |> Enum.map(&Map.get(objective_resources_by_id, &1))
    |> Enum.reject(&is_nil/1)
    |> unique_activity_ids()
  end

  @doc """
  Builds an activity-to-page index from depot page resources and their already-derived revisions.

  Page revisions are supplied separately to keep the one batch revision lookup at the caller
  boundary and to make this function deterministic in unit tests.
  """
  @spec build_page_contexts([map()], [Revision.t() | map()]) :: %{
          optional(integer()) => [page_context()]
        }
  def build_page_contexts(page_resources, page_revisions) do
    revisions_by_id = Map.new(page_revisions, &{&1.id, &1})

    Enum.reduce(page_resources, %{}, fn page_resource, contexts ->
      case Map.get(revisions_by_id, page_resource.revision_id) do
        nil ->
          contexts

        page_revision ->
          context = %{
            page_resource_id: page_resource.resource_id,
            page_revision: page_revision
          }

          Enum.reduce(List.wrap(Map.get(page_revision, :activity_refs, [])), contexts, fn
            activity_id, contexts ->
              Map.update(contexts, activity_id, [context], &(&1 ++ [context]))
          end)
      end
    end)
  end

  @doc "Selects the first stable page context for every activity."
  @spec canonical_page_contexts(%{optional(integer()) => [page_context()]}) :: %{
          optional(integer()) => page_context()
        }
  def canonical_page_contexts(contexts) do
    Map.new(contexts, fn {activity_id, [context | _]} -> {activity_id, context} end)
  end

  @doc """
  Resolves the section-scoped objective family, unique activity IDs, and page contexts.
  """
  @spec resolve_context(integer(), integer()) :: {:ok, linked_context()} | {:error, atom()}
  def resolve_context(section_id, selected_objective_id) do
    objectives = SectionResourceDepot.objectives_with_effective_children(section_id)

    with true <- Enum.any?(objectives, &(&1.resource_id == selected_objective_id)),
         objective_ids <- objective_family_ids(objectives, selected_objective_id),
         objective_resources <-
           SectionResourceDepot.get_resources_by_ids(section_id, objective_ids),
         activity_ids <-
           activity_ids_for_objective_family(objective_ids, objective_resources) do
      page_resources =
        SectionResourceDepot.get_lessons(section_id)
        |> Enum.reject(& &1.hidden)

      revision_ids =
        Enum.map(page_resources, & &1.revision_id) |> Enum.reject(&is_nil/1) |> Enum.uniq()

      page_revisions =
        from(revision in Revision,
          where: revision.id in ^revision_ids,
          select: %{
            id: revision.id,
            resource_id: revision.resource_id,
            activity_refs: revision.activity_refs,
            graded: revision.graded
          }
        )
        |> Repo.all()

      activity_page_contexts = build_page_contexts(page_resources, page_revisions)

      {:ok,
       %{
         objective_ids: objective_ids,
         activity_ids: activity_ids,
         activity_page_contexts: activity_page_contexts,
         canonical_page_context: canonical_page_contexts(activity_page_contexts)
       }}
    else
      false -> {:error, :objective_not_found}
    end
  end

  @doc """
  Returns one row per unique activity linked to the objective and its effective descendants.

  Each row carries the published revision, the extracted question stem, and attempts and
  percent-correct aggregated across every eligible page the activity appears on.
  """
  def get_activities_for_objective(section, selected_objective_id) do
    with {:ok, context} <-
           resolve_context(section.id, selected_objective_id) do
      activity_ids = context.activity_ids
      metrics_by_id = activity_metrics(section.id, activity_ids, context.activity_page_contexts)
      lti_activity_type_ids = Activities.list_lti_activity_registrations() |> Enum.map(& &1.id)

      revisions_by_id =
        DeliveryResolver.from_resource_id(section.slug, activity_ids)
        |> Enum.reject(&is_nil/1)
        |> Map.new(&{&1.resource_id, &1})

      Enum.flat_map(activity_ids, fn activity_id ->
        case Map.get(revisions_by_id, activity_id) do
          nil ->
            []

          revision ->
            metrics =
              Map.get(metrics_by_id, revision.resource_id, %{attempts: 0, percent_correct: 0.0})

            page_contexts = Map.get(context.activity_page_contexts, activity_id, [])

            [
              normalize_activity_row(revision, metrics, page_contexts, lti_activity_type_ids)
              |> Map.put(
                :canonical_page_context,
                Map.get(context.canonical_page_context, activity_id)
              )
            ]
        end
      end)
    else
      {:error, :objective_not_found} -> []
    end
  end

  @doc "Normalizes a published activity revision and aggregate metrics for shared consumers."
  def normalize_activity_row(revision, metrics, page_contexts \\ []) do
    normalize_activity_row(
      revision,
      metrics,
      page_contexts,
      Activities.list_lti_activity_registrations() |> Enum.map(& &1.id)
    )
  end

  def normalize_activity_row(revision, metrics, page_contexts, lti_activity_type_ids) do
    question_stem = extract_question_stem(revision.content)
    attempts = Map.get(metrics, :attempts, Map.get(metrics, :total_attempts, 0))
    percent_correct = Map.get(metrics, :percent_correct, 0.0)

    %{
      resource_id: revision.resource_id,
      title: revision.title,
      content: revision.content,
      revision: revision,
      slug: revision.slug,
      question_stem: question_stem,
      attempts: attempts,
      percent_correct: percent_correct,
      total_attempts: attempts,
      avg_score: percent_correct / 100,
      page_contexts: page_contexts,
      has_lti_activity: revision.activity_type_id in lti_activity_type_ids
    }
  end

  @doc "Merges aggregate summary rows without averaging already-rounded percentages."
  def merge_summary_metrics(summaries) do
    totals =
      Enum.reduce(
        summaries,
        %{attempts: 0, correct: 0, first_attempts: 0, first_correct: 0},
        fn summary, totals ->
          %{
            attempts: totals.attempts + Map.get(summary, :num_attempts, 0),
            correct: totals.correct + Map.get(summary, :num_correct, 0),
            first_attempts: totals.first_attempts + Map.get(summary, :num_first_attempts, 0),
            first_correct: totals.first_correct + Map.get(summary, :num_first_attempts_correct, 0)
          }
        end
      )

    Map.merge(totals, %{
      avg_score: ratio(totals.correct, totals.attempts),
      first_attempt_pct: ratio(totals.first_correct, totals.first_attempts)
    })
  end

  def telemetry_metadata(operation, metadata) when operation in [:load, :summary_load] do
    allowed_keys = [
      :section_id,
      :objective_id,
      :objective_count,
      :activity_count,
      :page_group_count,
      :cache_outcome,
      :outcome
    ]

    Map.take(metadata, allowed_keys)
    |> Map.put(:operation, operation)
  end

  defp ratio(_numerator, 0), do: 0.0
  defp ratio(numerator, denominator), do: numerator / denominator

  # Single accumulator for attempt/correct counts, so every source of summary rows
  # aggregates the same way.
  defp add_counts(metrics_by_id, resource_id, attempts, correct) do
    Map.update(
      metrics_by_id,
      resource_id,
      %{attempts: attempts, correct: correct},
      &%{attempts: &1.attempts + attempts, correct: &1.correct + correct}
    )
  end

  defp activity_metrics(_section_id, [], _contexts), do: %{}

  defp activity_metrics(section_id, activity_ids, activity_page_contexts) do
    started_at = System.monotonic_time()

    page_groups = activity_page_groups(activity_ids, activity_page_contexts)

    metrics_by_id =
      page_groups
      |> Enum.reduce(%{}, fn {page_id, page_activity_ids}, metrics_by_id ->
        Summary.summarize_activities_for_page(section_id, page_id, page_activity_ids)
        |> Enum.reduce(metrics_by_id, fn %ResourceSummary{} = summary, acc ->
          add_counts(acc, summary.resource_id, summary.num_attempts, summary.num_correct)
        end)
      end)

    missing_ids = activity_ids -- Map.keys(metrics_by_id)

    metrics_by_id =
      if missing_ids == [] do
        metrics_by_id
      else
        summary_metrics =
          from(summary in ResourceSummary,
            where:
              summary.section_id == ^section_id and summary.project_id == -1 and
                summary.user_id == -1 and summary.resource_id in ^missing_ids
          )
          |> Repo.all()
          |> Enum.reduce(%{}, fn summary, acc ->
            add_counts(acc, summary.resource_id, summary.num_attempts, summary.num_correct)
          end)

        fallback_ids = missing_ids -- Map.keys(summary_metrics)

        Map.merge(summary_metrics, activity_attempt_fallback(section_id, fallback_ids))
        |> Map.merge(metrics_by_id)
      end

    metrics_by_id =
      Map.merge(Map.new(activity_ids, &{&1, %{attempts: 0, correct: 0}}), metrics_by_id)

    result =
      metrics_by_id
      |> Map.new(fn {resource_id, %{attempts: attempts, correct: correct}} ->
        {resource_id,
         %{
           attempts: attempts,
           percent_correct:
             if(attempts > 0, do: Float.round(correct / attempts * 100, 1), else: 0.0)
         }}
      end)

    :telemetry.execute(
      [:oli, :delivery, :linked_activities, :summary_load],
      %{duration: System.monotonic_time() - started_at},
      telemetry_metadata(:summary_load, %{
        section_id: section_id,
        activity_count: length(activity_ids),
        page_group_count: map_size(page_groups),
        outcome: :ok
      })
    )

    result
  end

  # Older test and migrated sections can have evaluated attempts before their summary rows
  # exist. Keep those rows visible while the summary pipeline catches up.
  defp activity_attempt_fallback(_section_id, []), do: %{}

  defp activity_attempt_fallback(section_id, activity_ids) do
    from(activity_attempt in ActivityAttempt,
      join: resource_attempt in ResourceAttempt,
      on: activity_attempt.resource_attempt_id == resource_attempt.id,
      join: resource_access in ResourceAccess,
      on: resource_attempt.resource_access_id == resource_access.id,
      where:
        resource_access.section_id == ^section_id and
          activity_attempt.resource_id in ^activity_ids and
          activity_attempt.lifecycle_state == :evaluated,
      select: %{
        resource_id: activity_attempt.resource_id,
        score: activity_attempt.score,
        out_of: activity_attempt.out_of
      }
    )
    |> Repo.all()
    |> Enum.group_by(& &1.resource_id)
    |> Map.new(fn {resource_id, attempts} ->
      correct = Enum.count(attempts, &(&1.score && &1.out_of && &1.score == &1.out_of))
      {resource_id, %{attempts: length(attempts), correct: correct}}
    end)
  end

  def activity_page_groups(activity_ids, activity_page_contexts) do
    Enum.reduce(activity_ids, %{}, fn activity_id, groups ->
      Enum.reduce(Map.get(activity_page_contexts, activity_id, []), groups, fn context, groups ->
        page_id = context.page_resource_id
        Map.update(groups, page_id, [activity_id], &[activity_id | &1])
      end)
    end)
    |> Map.new(fn {page_id, ids} ->
      {page_id,
       ids
       |> Enum.uniq()
       |> Enum.sort_by(&Enum.find_index(activity_ids, fn id -> id == &1 end))}
    end)
  end

  defp extract_question_stem(content) when is_map(content) do
    case Map.get(content, "stem") do
      %{"content" => stem_content} when is_list(stem_content) ->
        extract_text_from_content(stem_content)

      stem_text when is_binary(stem_text) ->
        stem_text

      _ ->
        case Map.get(content, "content") do
          content_list when is_list(content_list) ->
            extract_text_from_content(content_list)

          _ ->
            "No question stem available"
        end
    end
  rescue
    _ -> "No question stem available"
  end

  defp extract_question_stem(_), do: "No question stem available"

  defp extract_text_from_content(content) when is_list(content) do
    Enum.map_join(content, "", &extract_text_from_content/1)
  end

  defp extract_text_from_content(%{"text" => text}) when is_binary(text), do: text

  defp extract_text_from_content(%{"children" => children}),
    do: extract_text_from_content(List.wrap(children))

  defp extract_text_from_content(%{"content" => content}),
    do: extract_text_from_content(List.wrap(content))

  defp extract_text_from_content(_), do: ""
end
