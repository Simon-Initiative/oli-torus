defmodule Oli.Delivery.Experiments.AttemptAttributions do
  @moduledoc """
  Builds experiment attribution payloads for evaluated attempt xAPI host statements.
  """

  import Ecto.Query, warn: false

  alias Oli.Analytics.Summary.AttemptGroup

  alias Oli.Experiments.{
    OutcomeReceipt,
    RecordOutcomeRequest,
    RecordRewardRequest,
    RewardReceipt,
    Scope
  }

  alias Oli.Experiments.Schemas.{Assignment, ExperimentDefinition}
  alias Oli.Experiments.XAPI.Attributions
  alias Oli.Delivery.Sections.Section
  alias Oli.Repo

  def for_attempt_group(%AttemptGroup{} = attempt_group) do
    host_part_attempts =
      attempt_group.part_attempts
      |> Enum.group_by(& &1.activity_attempt.id)
      |> Map.new(fn {activity_attempt_id, part_attempts} ->
        {activity_attempt_id, Enum.min_by(part_attempts, & &1.id)}
      end)

    if map_size(host_part_attempts) == 0 or
         not experiment_section?(attempt_group.context.section_id) do
      empty_attributions()
    else
      activity_attempt_ids = Map.keys(host_part_attempts)
      assignments = reward_assignments(attempt_group, activity_attempt_ids)
      part_attempts = part_attempt_attributions(host_part_attempts, assignments, attempt_group)

      %{
        part_attempts: part_attempts,
        activity_attempts: activity_attempt_rollups(attempt_group.part_attempts, part_attempts),
        page_attempt: page_attempt_rollups(part_attempts)
      }
    end
  end

  def for_attempt_group(_attempt_group), do: empty_attributions()

  defp empty_attributions, do: %{part_attempts: %{}, activity_attempts: %{}, page_attempt: []}

  defp experiment_section?(nil), do: false

  defp experiment_section?(section_id) do
    Repo.one(
      from(section in Section,
        where: section.id == ^section_id,
        select: section.has_experiments
      )
    ) == true
  end

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

  defp part_attempt_attributions(host_part_attempts, assignments, attempt_group) do
    Enum.reduce(host_part_attempts, %{}, fn {_activity_attempt_id, part_attempt}, acc ->
      activity_attempt = part_attempt.activity_attempt

      attributions =
        assignments
        |> Enum.flat_map(&attributions_for_assignment(attempt_group, activity_attempt, &1))

      if attributions == [] do
        acc
      else
        Map.put(acc, part_attempt.attempt_guid, attributions)
      end
    end)
  end

  defp reward_assignments(%AttemptGroup{} = attempt_group, activity_attempt_ids) do
    if activity_attempt_ids == [] do
      []
    else
      from(assignment in Assignment,
        join: experiment in ExperimentDefinition,
        on: experiment.id == assignment.experiment_id,
        where:
          experiment.project_id == ^attempt_group.context.project_id and
            assignment.section_id == ^attempt_group.context.section_id and
            assignment.user_id == ^attempt_group.context.user_id and
            fragment("? \\? 'rewards'", assignment.runtime_event_state),
        preload: [experiment: experiment]
      )
      |> Repo.all()
      |> Enum.filter(&has_reward_for_any_activity?(&1, activity_attempt_ids))
    end
  end

  defp has_reward_for_any_activity?(%Assignment{} = assignment, activity_attempt_ids) do
    rewards = get_in(assignment.runtime_event_state || %{}, ["rewards"]) || %{}

    Enum.any?(activity_attempt_ids, fn activity_attempt_id ->
      Map.has_key?(rewards, reward_key(activity_attempt_id, assignment.id))
    end)
  end

  defp attributions_for_assignment(
         %AttemptGroup{} = attempt_group,
         activity_attempt,
         %Assignment{} = assignment
       ) do
    rewards = get_in(assignment.runtime_event_state || %{}, ["rewards"]) || %{}

    case Map.get(rewards, reward_key(activity_attempt.id, assignment.id)) do
      nil ->
        []

      reward_event ->
        scope = scope(attempt_group, assignment)
        outcome_key = outcome_key(activity_attempt.id, assignment.id)

        outcome_request = %RecordOutcomeRequest{
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
            "source" => Map.get(reward_event, "reward_source")
          },
          idempotency_key: outcome_key
        }

        outcome_receipt = %OutcomeReceipt{
          id: Map.get(reward_event, "outcome_id") || receipt_id("outcome", outcome_key),
          assignment_id: assignment.id,
          idempotency_key: outcome_key,
          recorded_at: activity_attempt.date_evaluated,
          reused?: true
        }

        reward_request = %RecordRewardRequest{
          scope: scope,
          assignment_id: assignment.id,
          outcome_id: Map.get(reward_event, "outcome_id"),
          outcome_idempotency_key: Map.get(reward_event, "outcome_idempotency_key"),
          reward_value: Map.get(reward_event, "reward_value"),
          reward_source: Map.get(reward_event, "reward_source"),
          metadata: %{"attempt_number" => activity_attempt.attempt_number},
          idempotency_key: Map.get(reward_event, "idempotency_key")
        }

        reward_receipt = %RewardReceipt{
          id: Map.get(reward_event, "id"),
          assignment_id: assignment.id,
          outcome_id: Map.get(reward_event, "outcome_id"),
          outcome_idempotency_key: Map.get(reward_event, "outcome_idempotency_key"),
          idempotency_key: Map.get(reward_event, "idempotency_key"),
          recorded_at: Map.get(reward_event, "recorded_at"),
          reused?: true
        }

        Attributions.attributions_for_part_attempt(outcome_receipt, outcome_request,
          assignment: assignment
        ) ++
          Attributions.attributions_for_part_attempt(reward_receipt, reward_request,
            assignment: assignment
          )
    end
  end

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

  # Reconstructs the deterministic receipt ID that Oli.Experiments returns for
  # a logical outcome or reward. This is not a PostgreSQL primary key; it lets
  # evaluated attempt xAPI rebuild the same attribution payload from
  # runtime_event_state during later rollups.
  defp receipt_id(prefix, idempotency_key) do
    <<int::unsigned-integer-size(64), _rest::binary>> =
      :crypto.hash(:sha256, "#{prefix}:#{idempotency_key}")

    int
  end
end
