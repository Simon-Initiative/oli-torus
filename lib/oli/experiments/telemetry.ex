defmodule Oli.Experiments.Telemetry do
  @moduledoc false

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

  alias Oli.Experiments.XAPI.Attributions

  def emit(event, payload, opts \\ [])

  def emit(
        :assignment_decided,
        {%AssignmentDecision{status: :assigned} = decision, %AssignConditionRequest{} = request},
        opts
      ) do
    emit_operational(
      :assignment_decided,
      Attributions.assignment_attribution(decision, request, opts)
    )
  end

  def emit(:assignment_decided, _payload, _opts), do: :ok

  def emit(
        :exposure_recorded,
        {%ExposureReceipt{reused?: false} = receipt, %RecordExposureRequest{} = request},
        opts
      ) do
    emit_operational(
      :exposure_recorded,
      Attributions.exposure_attribution(receipt, request, opts)
    )
  end

  def emit(
        :exposure_recorded,
        {%ExposureReceipt{} = receipt, %RecordExposureRequest{} = request},
        _opts
      ) do
    skip_duplicate("exposure", receipt.idempotency_key, request.scope)
  end

  def emit(
        :outcome_recorded,
        {%OutcomeReceipt{reused?: false} = receipt, %RecordOutcomeRequest{} = request},
        opts
      ) do
    emit_operational(:outcome_recorded, Attributions.outcome_attribution(receipt, request, opts))
  end

  def emit(
        :outcome_recorded,
        {%OutcomeReceipt{} = receipt, %RecordOutcomeRequest{} = request},
        _opts
      ) do
    skip_duplicate("outcome", receipt.idempotency_key, request.scope)
  end

  def emit(
        :reward_recorded,
        {%RewardReceipt{reused?: false} = receipt, %RecordRewardRequest{} = request},
        opts
      ) do
    emit_operational(:reward_recorded, Attributions.reward_attribution(receipt, request, opts))
  end

  def emit(
        :reward_recorded,
        {%RewardReceipt{} = receipt, %RecordRewardRequest{} = request},
        _opts
      ) do
    skip_duplicate("reward", receipt.idempotency_key, request.scope)
  end

  def emit(:policy_updated, {%{} = update, %{} = reward}, opts) do
    emit_operational(:policy_updated, Attributions.policy_update_evidence(update, reward, opts))
  end

  def emit(_event, _payload, _opts), do: :ok

  defp skip_duplicate(event_type, idempotency_key, %Scope{} = scope, extra \\ %{}) do
    metadata =
      %{
        attribution_role: event_type,
        idempotency_key_hash: hash_key(idempotency_key),
        section_id: scope.section_id,
        publication_id: scope.publication_id
      }
      |> Map.merge(extra)
      |> reject_nil_values()

    :telemetry.execute(
      [:oli, :experiments, :xapi, :emit, :skipped_duplicate],
      %{count: 1},
      metadata
    )

    :ok
  end

  defp emit_operational(event, attribution) do
    metadata =
      attribution
      |> Map.take([
        "role",
        "experiment_id",
        "decision_point_id",
        "condition_id",
        "condition_code",
        "section_id",
        "publication_id",
        "algorithm",
        "algorithm_version",
        "policy_version"
      ])
      |> Map.put("idempotency_key_hash", hash_key(attribution["idempotency_key"]))
      |> reject_nil_values()

    :telemetry.execute([:oli, :experiments, :telemetry, event], %{count: 1}, metadata)

    :ok
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
end
