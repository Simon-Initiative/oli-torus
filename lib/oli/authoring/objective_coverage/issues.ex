defmodule Oli.Authoring.ObjectiveCoverage.Issues do
  @moduledoc """
  Derives coverage issue flags from an `ObjectiveCoverage` snapshot.

  The module is deliberately pure: callers provide the request-scoped snapshot
  and project thresholds, and no additional authoring data is loaded.
  """

  @default_formative_threshold 3
  @default_summative_threshold 3

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
  @spec classify_all(map(), thresholds()) :: %{pos_integer() => issue()}
  def classify_all(model, thresholds \\ default_thresholds()) do
    direct_issues =
      Map.new(model.coverage_by_objective, fn {objective_id, coverage} ->
        {objective_id, classify(coverage, thresholds)}
      end)

    model.objectives_by_id
    |> Map.keys()
    |> Enum.reduce(direct_issues, fn objective_id, issues ->
      propagate_to_parents(objective_id, model.parents_by_child, issues, MapSet.new())
    end)
  end

  @spec propagate_to_parents(
          pos_integer(),
          %{pos_integer() => [pos_integer()]},
          %{pos_integer() => issue()},
          MapSet.t(pos_integer())
        ) :: %{pos_integer() => issue()}
  defp propagate_to_parents(objective_id, parents_by_child, issues, visited) do
    if MapSet.member?(visited, objective_id) do
      issues
    else
      issue = Map.fetch!(issues, objective_id)
      visited = MapSet.put(visited, objective_id)

      Enum.reduce(Map.get(parents_by_child, objective_id, []), issues, fn parent_id, issues ->
        updated_issues =
          Map.update!(issues, parent_id, fn parent_issue ->
            formative_issue = parent_issue.formative_issue or issue.formative_issue
            summative_issue = parent_issue.summative_issue or issue.summative_issue

            %{
              parent_issue
              | formative_issue: formative_issue,
                summative_issue: summative_issue,
                any_issue: formative_issue or summative_issue
            }
          end)

        propagate_to_parents(parent_id, parents_by_child, updated_issues, visited)
      end)
    end
  end
end
