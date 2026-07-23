defmodule Oli.Delivery.Experiments.MediaAttributions do
  @moduledoc """
  Builds experiment attribution payloads for media xAPI host statements.
  """

  import Ecto.Query, warn: false

  alias Oli.Analytics.XAPI.Events.Context

  alias Oli.Experiments.{
    AssignmentDecision,
    AssignConditionRequest,
    Scope
  }

  alias Oli.Experiments.Schemas.{Assignment, Condition, DecisionPoint, ExperimentDefinition}
  alias Oli.Experiments.XAPI.Attributions
  alias Oli.Repo
  alias Oli.Resources.PageContent

  def for_media_event(%Context{} = context, page_content, content_element_id)
      when is_binary(content_element_id) do
    matching_branches = matching_alternatives_branches(page_content, content_element_id)

    case matching_branches do
      [] ->
        []

      _ ->
        context
        |> assignment_query()
        |> Repo.all()
        |> Enum.filter(&assignment_matches_branch?(&1, matching_branches))
        |> Enum.flat_map(&media_attribution(&1, context))
    end
  end

  def for_media_event(_context, _page_content, _content_element_id), do: []

  defp assignment_query(%Context{} = context) do
    from(assignment in Assignment,
      join: experiment in ExperimentDefinition,
      on: experiment.id == assignment.experiment_id,
      join: decision_point in DecisionPoint,
      on: decision_point.id == assignment.decision_point_id,
      join: condition in Condition,
      on: condition.id == assignment.condition_id,
      where:
        experiment.project_id == ^context.project_id and
          assignment.section_id == ^context.section_id and
          assignment.user_id == ^context.user_id,
      preload: [experiment: experiment],
      select: %{
        assignment: assignment,
        decision_point: decision_point,
        condition: condition
      },
      distinct: assignment.id
    )
  end

  defp media_attribution(
         %{
           assignment: %Assignment{} = assignment,
           decision_point: %DecisionPoint{} = decision_point,
           condition: %Condition{} = condition
         },
         %Context{} = context
       ) do
    decision = %AssignmentDecision{
      status: :assigned,
      experiment_id: assignment.experiment_id,
      decision_point_id: assignment.decision_point_id,
      condition_id: assignment.condition_id,
      condition_code: condition.condition_code,
      assignment_id: assignment.id,
      reused?: true
    }

    request = %AssignConditionRequest{
      scope: scope(context, assignment),
      alternatives_resource_id: decision_point.alternatives_resource_id,
      alternatives_revision_id: decision_point.alternatives_revision_id,
      decision_point_key: decision_point.decision_point_key,
      available_condition_codes: [condition.condition_code]
    }

    decision
    |> Attributions.assignment_attribution(request, assignment: assignment)
    |> List.wrap()
    |> Attributions.attributions_for_media_event()
  end

  defp matching_alternatives_branches(%{"model" => _model} = page_content, content_element_id) do
    page_content
    |> PageContent.flat_filter(&(Map.get(&1, "type") == "alternatives"))
    |> Enum.flat_map(fn alternatives ->
      alternatives
      |> Map.get("children", [])
      |> Enum.filter(&branch_contains_content_element?(&1, content_element_id))
      |> Enum.map(fn branch ->
        %{
          alternatives_resource_id: Map.get(alternatives, "alternatives_id"),
          option_id: Map.get(branch, "value")
        }
      end)
    end)
    |> Enum.reject(fn branch ->
      is_nil(branch.alternatives_resource_id) or is_nil(branch.option_id)
    end)
  end

  defp matching_alternatives_branches(_page_content, _content_element_id), do: []

  defp branch_contains_content_element?(%{"children" => children}, content_element_id) do
    %{"model" => children}
    |> PageContent.flat_filter(&content_element?(&1, content_element_id))
    |> Enum.any?()
  end

  defp branch_contains_content_element?(_branch, _content_element_id), do: false

  defp content_element?(%{} = element, content_element_id) do
    Enum.any?(["id", "guid", "content_element_id"], fn key ->
      Map.get(element, key) == content_element_id
    end)
  end

  defp content_element?(_element, _content_element_id), do: false

  defp assignment_matches_branch?(
         %{
           decision_point: %DecisionPoint{} = decision_point,
           condition: %Condition{} = condition
         },
         matching_branches
       ) do
    option_ids = [condition.option_id, condition.condition_code] |> Enum.reject(&is_nil/1)

    Enum.any?(matching_branches, fn branch ->
      branch.alternatives_resource_id == decision_point.alternatives_resource_id and
        branch.option_id in option_ids
    end)
  end

  defp scope(%Context{} = context, %Assignment{} = assignment) do
    %Scope{
      project_id: context.project_id,
      publication_id: context.publication_id,
      section_id: context.section_id,
      user_id: context.user_id,
      enrollment_id: assignment.enrollment_id
    }
  end
end
