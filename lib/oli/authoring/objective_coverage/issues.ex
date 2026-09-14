defmodule Oli.Authoring.ObjectiveCoverage.Issues do
  @moduledoc """
  Derives coverage issue flags from an `ObjectiveCoverage` snapshot.

  The module is deliberately pure: callers provide the request-scoped snapshot
  and project thresholds, and no additional authoring data is loaded.
  """

  @default_formative_threshold 3
  @default_summative_threshold 3

  alias Oli.Authoring.ObjectiveCoverage

  @type thresholds :: %{
          required(:formative) => non_neg_integer(),
          required(:summative) => non_neg_integer()
        }

  @type issue :: %{
          formative_issue: boolean(),
          summative_issue: boolean(),
          any_issue: boolean(),
          direct_formative_issue: boolean(),
          direct_summative_issue: boolean()
        }

  @doc "Returns the recommended formative and summative thresholds."
  @spec default_thresholds() :: thresholds()
  def default_thresholds do
    %{formative: @default_formative_threshold, summative: @default_summative_threshold}
  end

  @doc """
  Classifies a single objective's coverage counts against project thresholds.

  `coverage.formative_activity_count`/`summative_activity_count` come from
  `ObjectiveCoverage.coverage_by_objective/5`, which already sums activities
  across an objective and all of its descendants. So `direct_formative_issue`/
  `direct_summative_issue` reflect this objective's own reported counts, not
  activities attached to this objective exclusive of its children — an
  objective with zero activities of its own can still read as healthy here
  if a descendant's activities cover the threshold.
  """
  @spec classify(map(), thresholds()) :: issue()
  def classify(coverage, thresholds \\ default_thresholds()) do
    direct_formative_issue = coverage.formative_activity_count < thresholds.formative
    direct_summative_issue = coverage.summative_activity_count < thresholds.summative

    # formative_issue/summative_issue/any_issue get OR'd with descendants by
    # propagate_to_parents/4; direct_formative_issue/direct_summative_issue stay
    # untouched so a parent keeps its own reason.
    %{
      formative_issue: direct_formative_issue,
      summative_issue: direct_summative_issue,
      any_issue: direct_formative_issue or direct_summative_issue,
      direct_formative_issue: direct_formative_issue,
      direct_summative_issue: direct_summative_issue
    }
  end

  @doc """
  Classifies every objective in a snapshot and propagates child issues to every
  visible parent. Direct flags remain available so child-level UI can explain
  its own formative and summative shortfalls (see `classify/2` for what
  "direct" actually reflects on a non-leaf objective).

  Requires `model.coverage_by_objective`, `model.objectives_by_id`, and
  `model.parents_by_child` to reference a consistent set of objective ids —
  the same guarantee `ObjectiveCoverage.build/2` already provides. An
  objective present in `objectives_by_id`/`parents_by_child` but missing from
  `coverage_by_objective` raises `KeyError` rather than being treated as
  having zero coverage.
  """
  @spec classify_all(ObjectiveCoverage.t(), thresholds()) :: %{pos_integer() => issue()}
  def classify_all(model, thresholds \\ default_thresholds()) do
    direct_issues =
      Map.new(model.coverage_by_objective, fn {objective_id, coverage} ->
        {objective_id, classify(coverage, thresholds)}
      end)

    queue =
      model.objectives_by_id
      |> Map.keys()
      |> Enum.reduce(:queue.new(), fn objective_id, queue ->
        issue = Map.fetch!(direct_issues, objective_id)

        if issue.any_issue, do: :queue.in(objective_id, queue), else: queue
      end)

    propagate_to_parents(queue, model.parents_by_child, direct_issues)
  end

  @doc """
  Returns the ids of top-level objectives that currently have a coverage
  issue (`any_issue`, per `classify_all/2` — an objective flags here if it
  or any of its descendants has a shortfall).

  Scoped to top-level objectives because that is the granularity the
  Coverage Issues toolbar control filters and counts against; sub-objective
  detail remains available through `classify_all/2` directly.

  Inherits `classify_all/2`'s precondition: every id in
  `model.top_level_objective_ids` must also be present in
  `model.coverage_by_objective`/`model.objectives_by_id`, or this raises
  `KeyError`.
  """
  @spec flagged_top_level_ids(ObjectiveCoverage.t(), thresholds()) ::
          MapSet.t(pos_integer())
  def flagged_top_level_ids(model, thresholds \\ default_thresholds()) do
    model
    |> classify_all(thresholds)
    |> then(&flagged_top_level_ids_from_issues(model, &1))
  end

  @doc "Returns flagged top-level IDs from an existing classification result."
  @spec flagged_top_level_ids_from_issues(
          ObjectiveCoverage.t(),
          %{pos_integer() => issue()}
        ) :: MapSet.t(pos_integer())
  def flagged_top_level_ids_from_issues(model, issues) do
    model.top_level_objective_ids
    |> Enum.filter(fn objective_id -> Map.fetch!(issues, objective_id).any_issue end)
    |> MapSet.new()
  end

  @spec propagate_to_parents(
          :queue.queue(pos_integer()),
          %{pos_integer() => [pos_integer()]},
          %{pos_integer() => issue()}
        ) :: %{pos_integer() => issue()}
  defp propagate_to_parents(queue, parents_by_child, issues) do
    case :queue.out(queue) do
      {:empty, _queue} ->
        issues

      {{:value, objective_id}, queue} ->
        issue = Map.fetch!(issues, objective_id)

        {queue, issues} =
          Enum.reduce(
            Map.get(parents_by_child, objective_id, []),
            {queue, issues},
            fn parent_id, {queue, issues} ->
              parent_issue = Map.fetch!(issues, parent_id)
              updated_parent_issue = merge_descendant_issue(parent_issue, issue)

              if updated_parent_issue == parent_issue do
                {queue, issues}
              else
                {:queue.in(parent_id, queue), Map.put(issues, parent_id, updated_parent_issue)}
              end
            end
          )

        propagate_to_parents(queue, parents_by_child, issues)
    end
  end

  defp merge_descendant_issue(parent_issue, descendant_issue) do
    formative_issue = parent_issue.formative_issue or descendant_issue.formative_issue
    summative_issue = parent_issue.summative_issue or descendant_issue.summative_issue

    %{
      parent_issue
      | formative_issue: formative_issue,
        summative_issue: summative_issue,
        any_issue: formative_issue or summative_issue
    }
  end
end
