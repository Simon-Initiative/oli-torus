defmodule Oli.Experiments.XAPI.Attributions do
  @moduledoc """
  Builds experiment attribution payloads for xAPI host statement extensions.
  """

  alias Oli.Experiments.{
    AssignmentDecision,
    AssignConditionRequest,
    ExposureReceipt,
    OutcomeReceipt,
    RecordExposureRequest,
    RecordOutcomeRequest,
    RecordRewardRequest,
    RewardReceipt,
    Scope
  }

  alias Oli.Experiments.Schemas.Assignment
  alias Oli.Experiments.Schemas.ExperimentDefinition, as: ExperimentDefinitionSchema

  @extension_base "http://oli.cmu.edu/extensions/"
  @experiment_attributions_key "#{@extension_base}experiment_attributions"

  def experiment_attributions_extension(attributions) when is_list(attributions) do
    %{@experiment_attributions_key => Enum.map(attributions, &normalize_attribution/1)}
  end

  def attach_attributions(statement, attributions)
      when is_map(statement) and is_list(attributions) do
    normalized = Enum.map(attributions, &normalize_attribution/1)

    if normalized == [] do
      statement
    else
      update_in(statement, ["context", "extensions"], fn
        nil -> %{@experiment_attributions_key => normalized}
        extensions -> Map.put(extensions, @experiment_attributions_key, normalized)
      end)
    end
  end

  def attributions_for_page_view(
        %ExposureReceipt{} = receipt,
        %RecordExposureRequest{} = request,
        opts
      ) do
    [exposure_attribution(receipt, request, opts)]
  end

  def attributions_for_part_attempt(
        %OutcomeReceipt{} = outcome_receipt,
        %RecordOutcomeRequest{} = outcome_request,
        opts
      ) do
    [outcome_attribution(outcome_receipt, outcome_request, opts)]
  end

  def attributions_for_part_attempt(
        %RewardReceipt{} = reward_receipt,
        %RecordRewardRequest{} = reward_request,
        opts
      ) do
    [reward_attribution(reward_receipt, reward_request, opts)]
  end

  def attributions_for_activity_attempt(attributions) when is_list(attributions) do
    Enum.map(attributions, &Map.put(normalize_attribution(&1), "role", "rollup"))
  end

  def attributions_for_page_attempt(attributions) when is_list(attributions) do
    Enum.map(attributions, &Map.put(normalize_attribution(&1), "role", "rollup"))
  end

  def attributions_for_media_event(attributions) when is_list(attributions) do
    Enum.map(attributions, &Map.put(normalize_attribution(&1), "role", "media_interaction"))
  end

  def assignment_attribution(
        %AssignmentDecision{} = decision,
        %AssignConditionRequest{} = request,
        opts
      ) do
    assignment = Keyword.get(opts, :assignment)

    %{
      role: "assignment",
      experiment_id: decision.experiment_id,
      decision_point_id: decision.decision_point_id,
      condition_id: decision.condition_id,
      condition_code: decision.condition_code,
      assignment_id: decision.assignment_id,
      assignment_key: assignment_value(assignment, :assignment_key),
      alternatives_resource_id: request.alternatives_resource_id,
      alternatives_revision_id: request.alternatives_revision_id,
      decision_point_key: request.decision_point_key,
      assigned_by_policy: assignment_value(assignment, :assigned_by_policy),
      algorithm: assignment_value(assignment, :assigned_by_policy),
      policy_version: assignment_value(assignment, :policy_version),
      idempotency_key:
        assignment_value(assignment, :assignment_key) ||
          "assignment:#{decision.assignment_id}",
      reused: decision.reused?
    }
    |> attribution_with_scope(request.scope)
    |> reject_nil_values()
    |> normalize_attribution()
  end

  def exposure_attribution(%ExposureReceipt{} = receipt, %RecordExposureRequest{} = request, opts) do
    assignment = Keyword.fetch!(opts, :assignment)

    assignment_attrs(assignment)
    |> Map.merge(%{
      role: "exposure",
      exposure_id: receipt.id,
      content_revision_id: request.content_revision_id,
      idempotency_key: receipt.idempotency_key,
      recorded_at: format_timestamp(receipt.recorded_at)
    })
    |> attribution_with_scope(request.scope)
    |> reject_nil_values()
    |> normalize_attribution()
  end

  def outcome_attribution(%OutcomeReceipt{} = receipt, %RecordOutcomeRequest{} = request, opts) do
    assignment = Keyword.fetch!(opts, :assignment)

    assignment_attrs(assignment)
    |> Map.merge(%{
      role: "outcome",
      outcome_id: receipt.id,
      activity_attempt_id: request.activity_attempt_id,
      resource_attempt_id: request.resource_attempt_id,
      activity_resource_id: request.activity_resource_id,
      score: decimal_to_number(request.score),
      out_of: decimal_to_number(request.out_of),
      idempotency_key: receipt.idempotency_key,
      recorded_at: format_timestamp(receipt.recorded_at)
    })
    |> attribution_with_scope(request.scope)
    |> reject_nil_values()
    |> normalize_attribution()
  end

  def reward_attribution(%RewardReceipt{} = receipt, %RecordRewardRequest{} = request, opts) do
    assignment = Keyword.fetch!(opts, :assignment)

    assignment_attrs(assignment)
    |> Map.merge(%{
      role: "reward",
      reward_id: receipt.id,
      outcome_id: receipt.outcome_id,
      outcome_idempotency_key: receipt.outcome_idempotency_key || request.outcome_idempotency_key,
      reward_value: decimal_to_number(request.reward_value),
      reward_source: request.reward_source,
      idempotency_key: receipt.idempotency_key,
      recorded_at: format_timestamp(receipt.recorded_at)
    })
    |> attribution_with_scope(request.scope)
    |> reject_nil_values()
    |> normalize_attribution()
  end

  def policy_update_evidence(%{} = update, %{} = reward, opts) do
    assignment = Keyword.fetch!(opts, :assignment)
    experiment = Keyword.fetch!(opts, :experiment)
    condition = Keyword.fetch!(opts, :condition)
    policy_state = Keyword.fetch!(opts, :policy_state)
    scope = policy_scope(assignment, experiment)

    assignment_attrs(assignment)
    |> Map.merge(%{
      role: "policy_update",
      experiment_id: map_value(reward, :experiment_id),
      decision_point_id: map_value(reward, :decision_point_id),
      condition_id: map_value(reward, :condition_id),
      condition_code: condition.condition_code,
      policy_update_id: map_value(update, :id),
      policy_state_id: map_value(update, :policy_state_id),
      reward_id: map_value(reward, :id),
      reward_value: decimal_to_number(map_value(reward, :reward_value)),
      algorithm: policy_state.algorithm,
      algorithm_version: map_value(update, :algorithm_version),
      policy_update_reason: map_value(update, :update_reason),
      previous_policy_state_hash: state_hash(map_value(update, :previous_state)),
      next_policy_state_hash: state_hash(map_value(update, :next_state)),
      idempotency_key:
        map_value(update, :idempotency_key) ||
          "policy_update:#{map_value(update, :id)}:reward:#{map_value(reward, :id)}",
      recorded_at: format_timestamp(map_value(update, :inserted_at))
    })
    |> attribution_with_scope(scope)
    |> reject_nil_values()
    |> normalize_attribution()
  end

  defp assignment_attrs(%Assignment{} = assignment) do
    %{
      assignment_id: assignment.id,
      assignment_key: assignment.assignment_key,
      experiment_id: assignment.experiment_id,
      decision_point_id: assignment.decision_point_id,
      condition_id: assignment.condition_id,
      section_id: assignment.section_id,
      enrollment_id: assignment.enrollment_id,
      user_id: assignment.user_id,
      assigned_by_policy: assignment.assigned_by_policy,
      algorithm: assignment.assigned_by_policy,
      policy_version: assignment.policy_version
    }
  end

  defp attribution_with_scope(attrs, %Scope{} = scope) do
    Map.merge(attrs, %{
      institution_id: scope.institution_id,
      project_id: scope.project_id,
      publication_id: scope.publication_id,
      section_id: scope.section_id,
      user_id: scope.user_id,
      enrollment_id: scope.enrollment_id
    })
  end

  defp attribution_with_scope(attrs, _scope), do: attrs

  defp policy_scope(%Assignment{} = assignment, %ExperimentDefinitionSchema{} = experiment) do
    %Scope{
      project_id: experiment.project_id,
      section_id: assignment.section_id,
      user_id: assignment.user_id,
      enrollment_id: assignment.enrollment_id
    }
  end

  defp assignment_value(%Assignment{} = assignment, key), do: Map.get(assignment, key)
  defp assignment_value(_assignment, _key), do: nil

  defp map_value(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp decimal_to_number(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp decimal_to_number(value), do: value

  defp normalize_extension_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_extension_value(%Decimal{} = value), do: Decimal.to_float(value)
  defp normalize_extension_value(value), do: value

  defp normalize_attribution(attribution) when is_map(attribution) do
    attribution
    |> Enum.map(fn {key, value} -> {to_string(key), normalize_extension_value(value)} end)
    |> Map.new()
    |> reject_nil_values()
  end

  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp hash_key(nil), do: nil

  defp hash_key(value) do
    :crypto.hash(:sha256, to_string(value))
    |> Base.encode16(case: :lower)
  end

  defp state_hash(state) do
    state
    |> Jason.encode!()
    |> hash_key()
  end

  defp format_timestamp(%DateTime{} = timestamp), do: DateTime.to_iso8601(timestamp)
  defp format_timestamp(timestamp), do: timestamp
end
