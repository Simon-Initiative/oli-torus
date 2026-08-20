defmodule Oli.Delivery.Experiments.AttemptAttributions do
  @moduledoc """
  Builds experiment attribution payloads for evaluated attempt xAPI host statements.
  """

  import Ecto.Query, warn: false
  require Logger

  alias Oli.Analytics.Summary.AttemptGroup

  alias Oli.Experiments.{
    OutcomeReceipt,
    RecordOutcomeRequest,
    RecordRewardRequest,
    RewardReceipt,
    Scope
  }

  alias Oli.Experiments.Schemas.{Assignment, Condition, ExperimentDefinition, Intervention}
  alias Oli.Experiments.XAPI.Attributions
  alias Oli.Repo
  alias Oli.Resources.PageContent

  def for_attempt_group(%AttemptGroup{} = attempt_group) do
    resolve_attempt_group(attempt_group)
  rescue
    error ->
      Logger.warning("Attempt experiment attribution enrichment failed",
        error_type: inspect(error.__struct__)
      )

      empty_attributions()
  end

  def for_attempt_group(_attempt_group), do: empty_attributions()

  defp resolve_attempt_group(%AttemptGroup{} = attempt_group) do
    host_part_attempts =
      attempt_group.part_attempts
      |> Enum.group_by(& &1.activity_attempt.id)
      |> Map.new(fn {activity_attempt_id, part_attempts} ->
        {activity_attempt_id, Enum.min_by(part_attempts, & &1.id)}
      end)

    selected_activities = selected_activity_placements(attempt_group.resource_attempt)

    if map_size(host_part_attempts) == 0 or selected_activities == [] do
      empty_attributions()
    else
      assignments = selected_assignments(attempt_group, selected_activities)

      case assignments do
        [] ->
          empty_attributions()

        _ ->
          assignments_by_activity_attempt =
            assignments_by_activity_attempt(assignments, host_part_attempts)

          part_attempts =
            part_attempt_attributions(
              host_part_attempts,
              assignments_by_activity_attempt,
              attempt_group
            )

          %{
            part_attempts: part_attempts,
            activity_attempts:
              activity_attempt_rollups(attempt_group.part_attempts, part_attempts),
            page_attempt: page_attempt_rollups(part_attempts)
          }
      end
    end
  end

  defp empty_attributions, do: %{part_attempts: %{}, activity_attempts: %{}, page_attempt: []}

  defp activity_attempt_rollups(part_attempts, part_attempt_attributions) do
    part_attempts
    |> Enum.group_by(& &1.activity_attempt.attempt_guid)
    |> Map.new(fn {activity_attempt_guid, part_attempts} ->
      attributions =
        part_attempts
        |> Enum.flat_map(fn part_attempt ->
          Map.get(part_attempt_attributions, part_attempt.attempt_guid, [])
        end)
        |> Attributions.attributions_for_activity_attempt()

      {activity_attempt_guid, attributions}
    end)
    |> Enum.reject(fn {_activity_attempt_guid, attributions} -> attributions == [] end)
    |> Map.new()
  end

  defp page_attempt_rollups(part_attempt_attributions) do
    part_attempt_attributions
    |> Map.values()
    |> List.flatten()
    |> Attributions.attributions_for_page_attempt()
  end

  defp part_attempt_attributions(
         host_part_attempts,
         assignments_by_activity_attempt,
         attempt_group
       ) do
    Enum.reduce(host_part_attempts, %{}, fn {activity_attempt_id, part_attempt}, acc ->
      activity_attempt = part_attempt.activity_attempt

      attributions =
        assignments_by_activity_attempt
        |> Map.get(activity_attempt_id, [])
        |> Enum.flat_map(&attributions_for_assignment(attempt_group, activity_attempt, &1))

      if attributions == [] do
        acc
      else
        Map.put(acc, part_attempt.attempt_guid, attributions)
      end
    end)
  end

  defp assignments_by_activity_attempt(assignments, host_part_attempts) do
    attempt_ids_by_resource =
      Enum.group_by(
        host_part_attempts,
        fn {_id, part_attempt} -> part_attempt.activity_attempt.resource_id end,
        fn {activity_attempt_id, _part_attempt} -> activity_attempt_id end
      )

    Enum.reduce(assignments, %{}, fn assignment_match, index ->
      attempt_ids_by_resource
      |> Map.get(assignment_match.activity_resource_id, [])
      |> Enum.reduce(index, fn activity_attempt_id, index ->
        Map.update(index, activity_attempt_id, [assignment_match], &[assignment_match | &1])
      end)
    end)
  end

  defp selected_assignments(%AttemptGroup{} = attempt_group, selected_activities) do
    page_resource_id = attempt_group.resource_attempt.resource_id

    selected_filter =
      selected_activities
      |> Enum.uniq_by(&{&1.alternatives_resource_id, &1.placement_id, &1.option_id})
      |> Enum.reduce(dynamic(false), fn selected, filter ->
        dynamic(
          [experiment: experiment, condition: condition, intervention: intervention],
          ^filter or
            (experiment.alternatives_resource_id == ^selected.alternatives_resource_id and
               intervention.content_element_id == ^selected.placement_id and
               (condition.option_id == ^selected.option_id or
                  condition.condition_code == ^selected.option_id))
        )
      end)

    selected_index =
      Enum.group_by(selected_activities, fn selected ->
        {selected.alternatives_resource_id, selected.placement_id, selected.option_id}
      end)

    from(assignment in Assignment,
      as: :assignment,
      join: experiment in ExperimentDefinition,
      as: :experiment,
      on: experiment.id == assignment.experiment_id,
      join: condition in Condition,
      as: :condition,
      on:
        condition.id == assignment.condition_id and
          condition.experiment_id == experiment.id,
      join: intervention in Intervention,
      as: :intervention,
      on:
        intervention.experiment_id == experiment.id and
          intervention.page_resource_id == ^page_resource_id and
          ((assignment.assignment_scope == :intervention and
              assignment.intervention_id == intervention.id) or
             (assignment.assignment_scope == :section_enrollment and
                is_nil(assignment.intervention_id))),
      join: enrollment in Oli.Delivery.Sections.Enrollment,
      on:
        enrollment.id == assignment.enrollment_id and
          enrollment.section_id == assignment.section_id and
          enrollment.user_id == assignment.user_id,
      where:
        experiment.project_id == ^attempt_group.context.project_id and
          assignment.section_id == ^attempt_group.context.section_id and
          assignment.user_id == ^attempt_group.context.user_id,
      where: ^selected_filter,
      select: %{
        assignment:
          map(assignment, [
            :id,
            :experiment_id,
            :intervention_id,
            :condition_id,
            :section_id,
            :enrollment_id,
            :user_id,
            :assigned_by_policy,
            :policy_version,
            :assignment_key,
            :assignment_scope,
            :runtime_event_state
          ]),
        experiment: map(experiment, [:id, :uuid, :alternatives_resource_id]),
        condition: map(condition, [:id, :condition_code, :option_id]),
        intervention: map(intervention, [:id, :page_resource_id, :content_element_id])
      },
      distinct: [assignment.id, intervention.id]
    )
    |> Repo.all()
    |> Enum.map(&hydrate_assignment_match/1)
    |> Enum.flat_map(&match_selected_activities(&1, selected_index))
  end

  defp attributions_for_assignment(
         %AttemptGroup{} = attempt_group,
         activity_attempt,
         %{assignment: %Assignment{} = assignment, intervention: %Intervention{} = intervention}
       ) do
    rewards = get_in(assignment.runtime_event_state || %{}, ["rewards"]) || %{}

    case {assignment.assigned_by_policy,
          Map.get(rewards, reward_key(activity_attempt.id, assignment.id))} do
      {"thompson_sampling", nil} ->
        []

      {algorithm, reward_event} ->
        scope = scope(attempt_group, assignment)
        outcome_key = outcome_key(activity_attempt.id, assignment.id)

        outcome_request = %RecordOutcomeRequest{
          key: outcome_key,
          scope: scope,
          assignment_id: assignment.id,
          activity_attempt_id: activity_attempt.id,
          resource_attempt_id: activity_attempt.resource_attempt_id,
          activity_resource_id: activity_attempt.resource_id,
          score: activity_attempt.score,
          out_of: activity_attempt.out_of,
          observed_at: activity_attempt.date_evaluated,
          metadata: %{
            "attempt_number" => activity_attempt.attempt_number,
            "source" => reward_source(reward_event)
          }
        }

        outcome_receipt = %OutcomeReceipt{
          key: outcome_key,
          assignment_id: assignment.id,
          recorded_at: activity_attempt.date_evaluated,
          reused?: true
        }

        outcome_attributions =
          outcome_receipt
          |> Attributions.attributions_for_part_attempt(outcome_request,
            assignment: assignment
          )
          |> Enum.map(&with_actual_intervention(&1, intervention))

        case {algorithm, reward_event} do
          {"thompson_sampling", reward_event} ->
            outcome_attributions ++
              reward_attributions(
                reward_event,
                outcome_key,
                scope,
                assignment,
                intervention,
                activity_attempt
              )

          {"weighted_random", _reward_event} ->
            outcome_attributions

          {_unsupported_algorithm, _reward_event} ->
            []
        end
    end
  end

  defp reward_attributions(
         reward_event,
         outcome_key,
         scope,
         assignment,
         intervention,
         activity_attempt
       ) do
    reward_request = %RecordRewardRequest{
      key: Map.get(reward_event, "key"),
      scope: scope,
      assignment_id: assignment.id,
      outcome_key: Map.get(reward_event, "outcome_key") || outcome_key,
      reward_value: Map.get(reward_event, "reward_value"),
      reward_source: Map.get(reward_event, "reward_source"),
      metadata: %{"attempt_number" => activity_attempt.attempt_number}
    }

    reward_receipt = %RewardReceipt{
      key: Map.get(reward_event, "key"),
      assignment_id: assignment.id,
      outcome_key: Map.get(reward_event, "outcome_key") || outcome_key,
      recorded_at: Map.get(reward_event, "recorded_at"),
      reused?: true
    }

    reward_receipt
    |> Attributions.attributions_for_part_attempt(reward_request, assignment: assignment)
    |> Enum.map(&with_actual_intervention(&1, intervention))
  end

  defp reward_source(%{} = reward_event), do: Map.get(reward_event, "reward_source")
  defp reward_source(_reward_event), do: nil

  defp with_actual_intervention(attribution, %Intervention{} = intervention) do
    attribution
    |> Map.put("intervention_id", intervention.id)
    |> Map.put(
      "intervention_key",
      "#{intervention.page_resource_id}:#{intervention.content_element_id}"
    )
  end

  defp match_selected_activities(assignment_match, selected_index) do
    base_key = {
      assignment_match.experiment.alternatives_resource_id,
      assignment_match.intervention.content_element_id
    }

    selected =
      Map.get(
        selected_index,
        {elem(base_key, 0), elem(base_key, 1), assignment_match.condition.option_id},
        Map.get(
          selected_index,
          {elem(base_key, 0), elem(base_key, 1), assignment_match.condition.condition_code},
          []
        )
      )

    Enum.map(selected, fn selected ->
      Map.put(assignment_match, :activity_resource_id, selected.activity_resource_id)
    end)
  end

  defp hydrate_assignment_match(match) do
    experiment = struct(ExperimentDefinition, match.experiment)
    condition = struct(Condition, match.condition)

    assignment =
      Assignment
      |> struct(match.assignment)
      |> Map.put(:experiment, experiment)
      |> Map.put(:condition, condition)

    %{
      assignment: assignment,
      experiment: experiment,
      condition: condition,
      intervention: struct(Intervention, match.intervention)
    }
  end

  defp selected_activity_placements(%{content: %{"model" => _model} = content}) do
    content
    |> PageContent.alternatives_placements()
    |> Enum.flat_map(&selected_activities/1)
  end

  defp selected_activity_placements(_resource_attempt), do: []

  defp selected_activities(%{
         "id" => placement_id,
         "alternatives_id" => alternatives_resource_id,
         "children" => [%{"value" => option_id} = selected_branch]
       })
       when is_binary(placement_id) and is_integer(alternatives_resource_id) and
              is_binary(option_id) do
    selected_branch
    |> Map.get("children", [])
    |> activity_resource_ids([])
    |> Enum.reverse()
    |> Enum.map(fn activity_resource_id ->
      %{
        placement_id: placement_id,
        alternatives_resource_id: alternatives_resource_id,
        option_id: option_id,
        activity_resource_id: activity_resource_id
      }
    end)
  end

  defp selected_activities(_placement), do: []

  defp activity_resource_ids(elements, acc) when is_list(elements) do
    Enum.reduce(elements, acc, &activity_resource_ids/2)
  end

  defp activity_resource_ids(%{"type" => "activity-reference", "activity_id" => id}, acc)
       when is_integer(id),
       do: [id | acc]

  defp activity_resource_ids(%{"children" => children}, acc) when is_list(children),
    do: activity_resource_ids(children, acc)

  defp activity_resource_ids(_element, acc), do: acc

  defp scope(%AttemptGroup{} = attempt_group, %Assignment{} = assignment) do
    %Scope{
      project_id: attempt_group.context.project_id,
      publication_id: attempt_group.context.publication_id,
      section_id: attempt_group.context.section_id,
      user_id: attempt_group.context.user_id,
      enrollment_id: assignment.enrollment_id
    }
  end

  defp outcome_key(activity_attempt_id, assignment_id),
    do: "outcome:activity_attempt:#{activity_attempt_id}:assignment:#{assignment_id}"

  defp reward_key(activity_attempt_id, assignment_id),
    do: "reward:activity_attempt:#{activity_attempt_id}:assignment:#{assignment_id}"
end
