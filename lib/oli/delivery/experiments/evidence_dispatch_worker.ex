defmodule Oli.Delivery.Experiments.EvidenceDispatchWorker do
  @moduledoc """
  Dispatches durable assessment-reward evidence after the reward transaction commits.

  The Oban row is inserted by the reward transaction, so rollback removes the handoff.
  Retries only re-emit idempotently keyed evidence and never mutate policy state.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 10,
    unique: [fields: [:args, :worker], keys: [:accepted_reward_id], period: :infinity]

  import Ecto.Query, warn: false

  alias Oli.Analytics.XAPI.{Events.Attempt.PageAttemptEvaluated, Events.Context, StatementBundle}
  alias Oli.Delivery.Attempts.Core.{ResourceAccess, ResourceAttempt}

  alias Oli.Experiments.Schemas.{
    AcceptedReward,
    AssessmentBinding,
    Assignment,
    Condition,
    Intervention
  }

  alias Oli.Experiments.XAPI.Attributions
  alias Oli.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"accepted_reward_id" => reward_id} = args}) do
    started_at = System.monotonic_time()

    result =
      with {:ok, evidence} <- load_evidence(reward_id),
           :ok <- dispatch(evidence, args) do
        :ok
      end

    emit_dispatch_telemetry(result, started_at)
    result
  end

  @doc "Persists the evidence handoff in the caller's current database transaction."
  @spec enqueue(map()) :: :ok | {:error, term()}
  def enqueue(%{accepted_reward_id: reward_id} = attrs) when is_integer(reward_id) do
    attrs
    |> stringify_args()
    |> new()
    |> Oban.insert()
    |> case do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_evidence(reward_id) do
    query =
      from(reward in AcceptedReward,
        join: assignment in Assignment,
        on: assignment.id == reward.assignment_id,
        join: condition in Condition,
        on: condition.id == assignment.condition_id,
        join: binding in AssessmentBinding,
        on: binding.id == reward.assessment_binding_id,
        join: intervention in Intervention,
        on: intervention.id == binding.intervention_id,
        join: attempt in ResourceAttempt,
        on: attempt.id == reward.resource_attempt_id,
        join: access in ResourceAccess,
        on: access.id == attempt.resource_access_id,
        where: reward.id == ^reward_id,
        select: %{
          reward: reward,
          assignment: assignment,
          condition_code: condition.condition_code,
          binding: binding,
          intervention: intervention,
          attempt: attempt,
          page_resource_id: access.resource_id
        }
      )

    case Repo.one(query) do
      nil -> {:error, :reward_evidence_not_found}
      evidence -> {:ok, evidence}
    end
  end

  defp dispatch(evidence, args) do
    attribution = %{
      role: "reward",
      attribution_type: "reward",
      key: "assessment_reward:#{evidence.reward.id}",
      experiment_id: evidence.assignment.experiment_id,
      condition_id: evidence.assignment.condition_id,
      condition_code: evidence.condition_code,
      assignment_id: evidence.assignment.id,
      assignment_key: evidence.assignment.assignment_key,
      intervention_id: evidence.intervention.id,
      intervention_key:
        "#{evidence.intervention.page_resource_id}:#{evidence.intervention.content_element_id}",
      assessment_binding_id: evidence.binding.id,
      assessment_page_resource_id: evidence.binding.assessment_page_resource_id,
      resource_attempt_id: evidence.attempt.id,
      disposition: args["disposition"],
      reward_threshold: decimal_number(evidence.binding.reward_threshold),
      normalized_score: decimal_number(evidence.reward.normalized_score),
      reward_value: evidence.reward.reward,
      reward_source: "assessment_page:normalized_score",
      page_revision_id: args["page_revision_id"],
      project_id: args["project_id"],
      section_id: evidence.assignment.section_id,
      previous_policy_context: args["previous_policy_context"],
      next_policy_context: args["next_policy_context"]
    }

    context = %Context{
      user_id: evidence.assignment.user_id,
      host_name: Oli.Analytics.XAPI.host_name(),
      section_id: evidence.assignment.section_id,
      project_id: args["project_id"],
      publication_id: args["publication_id"]
    }

    statement =
      context
      |> PageAttemptEvaluated.new(
        Map.put(evidence.attempt, :resource_id, evidence.page_resource_id)
      )
      |> Attributions.attach_attributions([attribution])

    %StatementBundle{
      body: Oli.Analytics.Common.to_jsonlines([statement]),
      bundle_id: "experiment-assessment-reward-#{evidence.reward.id}",
      partition_id: evidence.assignment.section_id,
      category: :attempt_evaluated,
      partition: :section
    }
    |> Oli.Analytics.XAPI.emit()
  end

  defp emit_dispatch_telemetry(result, started_at) do
    duration =
      started_at
      |> then(&(System.monotonic_time() - &1))
      |> System.convert_time_unit(:native, :millisecond)

    status = if result == :ok, do: :ok, else: :error

    :telemetry.execute(
      [:oli, :experiments, :delivery_reward, :evidence_dispatch, :completed],
      %{count: 1, duration_ms: duration},
      %{status: status}
    )
  end

  defp stringify_args(attrs), do: Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  defp decimal_number(%Decimal{} = value), do: Decimal.to_float(value)
  defp decimal_number(value), do: value
end
