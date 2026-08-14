defmodule Oli.Experiments.RuntimeEvidence do
  @moduledoc """
  Records experiment exposure, outcome, and reward evidence for delivery assignments.
  """

  alias Oli.Experiments.{ExperimentError, ExposureReceipt, OutcomeReceipt, RewardReceipt}
  alias Oli.Experiments.{ScopeValidator, Telemetry}
  alias Oli.Experiments.Schemas.Assignment
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Resources.Revision

  @doc false
  def record_exposure(request, deps) do
    with {:ok, scope} <- ScopeValidator.validate_delivery_participation_scope(request.scope) do
      request = %{request | scope: scope}

      Repo.transaction(fn ->
        {assignment, alternatives_resource_id} =
          deps.scoped_with_experiment.(request.assignment_id, scope)

        case validate_exposure_revision(alternatives_resource_id, request) do
          :ok -> {assignment, Map.put(runtime_event(request), "reused", false)}
          {:error, %ExperimentError{} = error} -> Repo.rollback(error)
        end
      end)
      |> deps.normalize.()
      |> case do
        {:ok, {assignment, event}} ->
          receipt = exposure_receipt(assignment, event)

          :telemetry.execute([:oli, :experiments, :exposure, :recorded], %{count: 1}, %{
            experiment_id: assignment.experiment_id
          })

          Telemetry.emit(:exposure_recorded, {receipt, request}, assignment: assignment)
          {:ok, receipt}

        {:error, %ExperimentError{}} = error ->
          error
      end
    end
  end

  @doc false
  def record_outcome(request, deps) do
    with {:ok, scope} <- ScopeValidator.validate_delivery_participation_scope(request.scope) do
      request = %{request | scope: scope}

      Repo.transaction(fn ->
        assignment = deps.scoped_assignment.(request.assignment_id, scope, lock: false)
        {assignment, Map.put(runtime_event(request), "reused", false)}
      end)
      |> deps.normalize.()
      |> case do
        {:ok, {assignment, event}} ->
          receipt = outcome_receipt(assignment, event)
          Telemetry.emit(:outcome_recorded, {receipt, request}, assignment: assignment)
          {:ok, receipt}

        {:error, %ExperimentError{}} = error ->
          error
      end
    end
  end

  @doc false
  def record_reward(request, deps) do
    with {:ok, scope} <- ScopeValidator.validate_delivery_participation_scope(request.scope) do
      request = %{request | scope: scope}

      Repo.transaction(fn ->
        assignment = deps.scoped_assignment.(request.assignment_id, scope, lock: true)
        reward_events = Map.get(assignment.runtime_event_state || %{}, "rewards", %{})

        case Map.get(reward_events, request.key) do
          nil ->
            event = reward_event(request, assignment)
            update_assignment_event_state!(assignment, "rewards", request.key, event)

            case deps.record_policy_reward.(assignment, request, event) do
              :ok -> {assignment, Map.put(event, "reused", false), nil}
              {:ok, emit} -> {assignment, Map.put(event, "reused", false), emit}
              {:error, error} -> Repo.rollback(error)
            end

          event ->
            {assignment, Map.put(event, "reused", true), nil}
        end
      end)
      |> deps.normalize.()
      |> case do
        {:ok, {assignment, event, policy_update_emit}} ->
          receipt = reward_receipt(assignment, event)

          if receipt.reused? == false do
            :telemetry.execute([:oli, :experiments, :reward, :recorded], %{count: 1}, %{
              experiment_id: assignment.experiment_id,
              condition_id: assignment.condition_id,
              reward_class: reward_class(request.reward_value)
            })
          end

          Telemetry.emit(:reward_recorded, {receipt, request}, assignment: assignment)
          deps.emit_policy_update.(policy_update_emit)
          {:ok, receipt}

        {:error, %ExperimentError{}} = error ->
          error
      end
    end
  end

  defp validate_exposure_revision(alternatives_resource_id, request) do
    case DeliveryResolver.from_resource_id(request.scope.section_slug, alternatives_resource_id) do
      %Revision{id: revision_id} when revision_id == request.content_revision_id ->
        :ok

      %Revision{id: revision_id} ->
        invalid_condition(
          "exposure revision does not match the alternatives revision deployed to section",
          %{
            alternatives_resource_id: alternatives_resource_id,
            content_revision_id: request.content_revision_id,
            resolved_revision_id: revision_id
          }
        )

      nil ->
        invalid_condition("exposure alternatives resource is not deployed to section", %{
          alternatives_resource_id: alternatives_resource_id,
          section_id: request.scope.section_id
        })
    end
  end

  defp update_assignment_event_state!(assignment, event_group, key, event) do
    state = assignment.runtime_event_state || %{}
    updated = Map.put(state, event_group, Map.put(Map.get(state, event_group, %{}), key, event))
    assignment |> Assignment.changeset(%{runtime_event_state: updated}) |> Repo.update!()
  end

  defp runtime_event(%Oli.Experiments.RecordExposureRequest{} = request) do
    %{
      "assignment_id" => request.assignment_id,
      "key" => request.key,
      "content_revision_id" => request.content_revision_id,
      "publication_id" => request.scope && request.scope.publication_id,
      "recorded_at" => request.exposed_at || now()
    }
  end

  defp runtime_event(%Oli.Experiments.RecordOutcomeRequest{} = request) do
    %{
      "assignment_id" => request.assignment_id,
      "key" => request.key,
      "activity_attempt_id" => request.activity_attempt_id,
      "resource_attempt_id" => request.resource_attempt_id,
      "activity_resource_id" => request.activity_resource_id,
      "score" => request.score,
      "out_of" => request.out_of,
      "recorded_at" => request.observed_at || now()
    }
  end

  defp reward_event(request, assignment) do
    %{
      "assignment_id" => request.assignment_id,
      "experiment_id" => assignment.experiment_id,
      "condition_id" => assignment.condition_id,
      "outcome_key" => request.outcome_key,
      "key" => request.key,
      "reward_value" => request.reward_value,
      "reward_source" => request.reward_source,
      "recorded_at" => now()
    }
  end

  defp exposure_receipt(assignment, event),
    do: %ExposureReceipt{
      key: event["key"],
      assignment_id: assignment.id,
      recorded_at: event["recorded_at"],
      reused?: Map.get(event, "reused", false)
    }

  defp outcome_receipt(assignment, event),
    do: %OutcomeReceipt{
      key: event["key"],
      assignment_id: assignment.id,
      recorded_at: event["recorded_at"],
      reused?: Map.get(event, "reused", false)
    }

  defp reward_receipt(assignment, event),
    do: %RewardReceipt{
      key: event["key"],
      assignment_id: assignment.id,
      outcome_key: event["outcome_key"],
      recorded_at: event["recorded_at"],
      reused?: Map.get(event, "reused", false)
    }

  defp reward_class(value) when value in [1, 1.0], do: :success
  defp reward_class(value) when value in [0, 0.0], do: :failure
  defp reward_class(_value), do: :unknown
  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp invalid_condition(message, details),
    do: {:error, %ExperimentError{type: :invalid_condition, message: message, details: details}}
end
