defmodule Oli.Experiments.Telemetry do
  @moduledoc false

  alias Oli.Analytics.XAPI

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

  alias Oli.Experiments.Schemas.{
    Assignment,
    Exposure,
    Outcome,
    PolicyUpdate,
    Reward
  }

  alias Oli.Experiments.Schemas.ExperimentDefinition, as: ExperimentDefinitionSchema

  @category :experiment
  @extension_base "http://oli.cmu.edu/extensions/"
  @verb_base "http://oli.cmu.edu/extensions/verbs/"
  @activity_type "#{@extension_base}types/experiment_event"

  @event_display %{
    "experiment_assigned" => "assigned experiment condition",
    "experiment_assignment_reused" => "reused experiment condition",
    "experiment_exposed" => "recorded experiment exposure",
    "experiment_outcome_recorded" => "recorded experiment outcome",
    "experiment_reward_recorded" => "recorded experiment reward",
    "experiment_policy_updated" => "updated experiment policy"
  }

  def emit(event, payload, opts \\ [])

  def emit(
        :assignment_decided,
        {%AssignmentDecision{status: :assigned} = decision, %AssignConditionRequest{} = request},
        opts
      ) do
    event_type =
      if decision.reused?,
        do: "experiment_assignment_reused",
        else: "experiment_assigned"

    emit_statement(event_type, assignment_statement(decision, request, opts))
  end

  def emit(:assignment_decided, _payload, _opts), do: :ok

  def emit(
        :exposure_recorded,
        {%ExposureReceipt{reused?: false} = receipt, %RecordExposureRequest{} = request},
        opts
      ) do
    emit_statement("experiment_exposed", exposure_statement(receipt, request, opts))
  end

  def emit(
        :exposure_recorded,
        {%ExposureReceipt{} = receipt, %RecordExposureRequest{} = request},
        _opts
      ) do
    skip_duplicate("experiment_exposed", receipt.idempotency_key, request.scope)
  end

  def emit(
        :outcome_recorded,
        {%OutcomeReceipt{reused?: false} = receipt, %RecordOutcomeRequest{} = request},
        opts
      ) do
    emit_statement("experiment_outcome_recorded", outcome_statement(receipt, request, opts))
  end

  def emit(
        :outcome_recorded,
        {%OutcomeReceipt{} = receipt, %RecordOutcomeRequest{} = request},
        _opts
      ) do
    skip_duplicate("experiment_outcome_recorded", receipt.idempotency_key, request.scope)
  end

  def emit(
        :reward_recorded,
        {%RewardReceipt{reused?: false} = receipt, %RecordRewardRequest{} = request},
        opts
      ) do
    emit_statement("experiment_reward_recorded", reward_statement(receipt, request, opts))
  end

  def emit(
        :reward_recorded,
        {%RewardReceipt{} = receipt, %RecordRewardRequest{} = request},
        _opts
      ) do
    skip_duplicate("experiment_reward_recorded", receipt.idempotency_key, request.scope)
  end

  def emit(:policy_updated, {%PolicyUpdate{} = update, %Reward{} = reward}, opts) do
    emit_statement("experiment_policy_updated", policy_update_statement(update, reward, opts))
  end

  def emit(_event, _payload, _opts), do: :ok

  def assignment_statement(
        %AssignmentDecision{} = decision,
        %AssignConditionRequest{} = request,
        opts
      ) do
    assignment = Keyword.get(opts, :assignment)

    event_type =
      if decision.reused?,
        do: "experiment_assignment_reused",
        else: "experiment_assigned"

    attrs = %{
      event_type: event_type,
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
      policy_version: assignment_value(assignment, :policy_version),
      idempotency_key:
        assignment_value(assignment, :assignment_key) ||
          "assignment:#{decision.assignment_id}:#{event_type}",
      reused: decision.reused?
    }

    base_statement(event_type, request.scope, attrs, assignment_value(assignment, :assigned_at))
  end

  def exposure_statement(%ExposureReceipt{} = receipt, %RecordExposureRequest{} = request, opts) do
    assignment = Keyword.fetch!(opts, :assignment)
    exposure = Keyword.get(opts, :exposure)

    attrs =
      assignment_attrs(assignment)
      |> Map.merge(%{
        event_type: "experiment_exposed",
        exposure_id: receipt.id,
        content_revision_id: request.content_revision_id,
        idempotency_key: receipt.idempotency_key,
        publication_id: request.scope.publication_id
      })

    base_statement(
      "experiment_exposed",
      request.scope,
      attrs,
      receipt.recorded_at || schema_value(exposure, :exposed_at)
    )
  end

  def outcome_statement(%OutcomeReceipt{} = receipt, %RecordOutcomeRequest{} = request, opts) do
    assignment = Keyword.fetch!(opts, :assignment)
    outcome = Keyword.get(opts, :outcome)

    attrs =
      assignment_attrs(assignment)
      |> Map.merge(%{
        event_type: "experiment_outcome_recorded",
        outcome_id: receipt.id,
        activity_attempt_id: request.activity_attempt_id,
        resource_attempt_id: request.resource_attempt_id,
        activity_resource_id: request.activity_resource_id,
        score: decimal_to_number(request.score),
        out_of: decimal_to_number(request.out_of),
        idempotency_key: receipt.idempotency_key,
        publication_id: request.scope.publication_id
      })

    base_statement(
      "experiment_outcome_recorded",
      request.scope,
      attrs,
      receipt.recorded_at || schema_value(outcome, :observed_at)
    )
  end

  def reward_statement(%RewardReceipt{} = receipt, %RecordRewardRequest{} = request, opts) do
    assignment = Keyword.fetch!(opts, :assignment)
    reward = Keyword.get(opts, :reward)

    attrs =
      assignment_attrs(assignment)
      |> Map.merge(%{
        event_type: "experiment_reward_recorded",
        reward_id: receipt.id,
        outcome_id: receipt.outcome_id,
        reward_value: decimal_to_number(request.reward_value),
        reward_source: request.reward_source,
        idempotency_key: receipt.idempotency_key,
        publication_id: request.scope.publication_id
      })

    base_statement(
      "experiment_reward_recorded",
      request.scope,
      attrs,
      receipt.recorded_at || schema_value(reward, :inserted_at)
    )
  end

  def policy_update_statement(%PolicyUpdate{} = update, %Reward{} = reward, opts) do
    assignment = Keyword.fetch!(opts, :assignment)
    experiment = Keyword.fetch!(opts, :experiment)
    condition = Keyword.fetch!(opts, :condition)
    policy_state = Keyword.fetch!(opts, :policy_state)
    scope = policy_scope(assignment, experiment)

    attrs =
      assignment_attrs(assignment)
      |> Map.merge(%{
        event_type: "experiment_policy_updated",
        experiment_id: reward.experiment_id,
        decision_point_id: reward.decision_point_id,
        condition_id: reward.condition_id,
        condition_code: condition.condition_code,
        policy_update_id: update.id,
        policy_state_id: update.policy_state_id,
        reward_id: reward.id,
        reward_value: decimal_to_number(reward.reward_value),
        algorithm: policy_state.algorithm,
        algorithm_version: update.algorithm_version,
        update_reason: update.update_reason,
        previous_state_hash: state_hash(update.previous_state),
        next_state_hash: state_hash(update.next_state),
        idempotency_key: "policy_update:#{update.id}:reward:#{reward.id}"
      })

    base_statement("experiment_policy_updated", scope, attrs, update.inserted_at)
  end

  defp skip_duplicate(event_type, idempotency_key, %Scope{} = scope, extra \\ %{}) do
    metadata =
      %{
        event_type: event_type,
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

  defp emit_statement(event_type, statement) do
    start_time = System.monotonic_time()
    metadata = statement_metadata(event_type, statement)

    :telemetry.execute([:oli, :experiments, :xapi, :emit, :start], %{count: 1}, metadata)

    try do
      result = xapi_module().emit(@category, statement)
      duration = System.monotonic_time() - start_time

      :telemetry.execute(
        [:oli, :experiments, :xapi, :emit, :stop],
        %{count: 1, duration: duration},
        metadata
      )

      result
    rescue
      exception ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:oli, :experiments, :xapi, :emit, :exception],
          %{count: 1, duration: duration},
          Map.merge(metadata, %{kind: :error, reason: exception.__struct__})
        )

        {:error, exception}
    catch
      kind, reason ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:oli, :experiments, :xapi, :emit, :exception],
          %{count: 1, duration: duration},
          Map.merge(metadata, %{kind: kind, reason: reason})
        )

        {:error, reason}
    end
  end

  defp base_statement(event_type, scope, attrs, timestamp) do
    scope = scope || %Scope{}
    timestamp = timestamp || DateTime.utc_now()
    extensions = extensions(scope, attrs)
    host = host_name()

    %{
      "actor" => %{
        "objectType" => "Agent",
        "account" => %{
          "homePage" => host,
          "name" => to_string(scope.user_id || "system")
        }
      },
      "verb" => %{
        "id" => "#{@verb_base}#{event_type}",
        "display" => %{"en-US" => Map.fetch!(@event_display, event_type)}
      },
      "object" => %{
        "id" => object_id(host, attrs),
        "definition" => %{
          "type" => @activity_type,
          "name" => %{"en-US" => event_type}
        }
      },
      "timestamp" => format_timestamp(timestamp),
      "context" => %{
        "extensions" => extensions
      }
    }
    |> maybe_put_result(event_type, attrs)
  end

  defp maybe_put_result(statement, event_type, attrs)
       when event_type in ["experiment_outcome_recorded", "experiment_reward_recorded"] do
    result =
      %{}
      |> maybe_put("score", score_result(attrs))
      |> maybe_put("extensions", result_extensions(attrs))

    if map_size(result) == 0, do: statement, else: Map.put(statement, "result", result)
  end

  defp maybe_put_result(statement, _event_type, _attrs), do: statement

  defp score_result(%{score: score, out_of: out_of})
       when not is_nil(score) and not is_nil(out_of) do
    %{"raw" => score, "max" => out_of}
  end

  defp score_result(%{reward_value: reward_value}) when not is_nil(reward_value) do
    %{"raw" => reward_value, "min" => 0, "max" => 1}
  end

  defp score_result(_attrs), do: nil

  defp result_extensions(attrs) do
    attrs
    |> Map.take([:reward_source])
    |> extension_map()
    |> reject_nil_values()
    |> then(fn extensions -> if map_size(extensions) == 0, do: nil, else: extensions end)
  end

  defp extensions(scope, attrs) do
    scope_attrs =
      %{
        institution_id: scope.institution_id,
        project_id: scope.project_id,
        publication_id: scope.publication_id,
        section_id: scope.section_id,
        user_id: scope.user_id,
        enrollment_id: scope.enrollment_id
      }

    attrs
    |> Map.merge(scope_attrs, fn _key, left, right -> left || right end)
    |> extension_map()
    |> reject_nil_values()
  end

  defp extension_map(attrs) do
    Enum.reduce(attrs, %{}, fn {key, value}, acc ->
      Map.put(acc, "#{@extension_base}#{key}", normalize_extension_value(value))
    end)
  end

  defp statement_metadata(event_type, statement) do
    extensions = get_in(statement, ["context", "extensions"]) || %{}

    %{
      event_type: event_type,
      experiment_id: extensions["#{@extension_base}experiment_id"],
      decision_point_id: extensions["#{@extension_base}decision_point_id"],
      condition_id: extensions["#{@extension_base}condition_id"],
      condition_code: extensions["#{@extension_base}condition_code"],
      section_id: extensions["#{@extension_base}section_id"],
      publication_id: extensions["#{@extension_base}publication_id"],
      algorithm:
        extensions["#{@extension_base}algorithm"] ||
          extensions["#{@extension_base}assigned_by_policy"],
      algorithm_version:
        extensions["#{@extension_base}algorithm_version"] ||
          extensions["#{@extension_base}policy_version"],
      idempotency_key_hash: hash_key(extensions["#{@extension_base}idempotency_key"])
    }
    |> reject_nil_values()
  end

  defp object_id(host, attrs) do
    experiment_id = Map.get(attrs, :experiment_uuid) || Map.get(attrs, :experiment_id)
    decision_point_id = Map.get(attrs, :decision_point_id)
    event_type = Map.get(attrs, :event_type, "experiment_event")

    "#{host}/experiments/#{experiment_id}/decision-points/#{decision_point_id}/events/#{event_type}"
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
      policy_version: assignment.policy_version
    }
  end

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

  defp schema_value(%Exposure{} = schema, key), do: Map.get(schema, key)
  defp schema_value(%Outcome{} = schema, key), do: Map.get(schema, key)
  defp schema_value(%Reward{} = schema, key), do: Map.get(schema, key)
  defp schema_value(_schema, _key), do: nil

  defp decimal_to_number(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp decimal_to_number(value), do: value

  defp normalize_extension_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_extension_value(%Decimal{} = value), do: Decimal.to_float(value)
  defp normalize_extension_value(value), do: value

  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

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

  defp xapi_module do
    Application.get_env(:oli, :experiments_xapi_module, XAPI)
  end

  defp host_name, do: Oli.Utils.get_base_url()
end
