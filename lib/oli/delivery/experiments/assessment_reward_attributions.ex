defmodule Oli.Delivery.Experiments.AssessmentRewardAttributions do
  @moduledoc """
  Builds accepted assessment reward attributions for the authoritative page-attempt snapshot.
  """

  import Ecto.Query, warn: false

  alias Oli.Analytics.XAPI.Events.Context

  alias Oli.Experiments.Schemas.{
    AcceptedReward,
    AssessmentBinding,
    Assignment,
    Condition,
    ExperimentDefinition,
    Intervention
  }

  alias Oli.Experiments.{RecordRewardRequest, RewardReceipt, Scope}
  alias Oli.Experiments.XAPI.Attributions
  alias Oli.Repo

  @doc "Returns reward attributions accepted for the given resource attempt."
  @spec for_resource_attempt(integer(), Context.t()) :: [map()]
  def for_resource_attempt(resource_attempt_id, %Context{} = context)
      when is_integer(resource_attempt_id) do
    from(reward in AcceptedReward,
      join: assignment in Assignment,
      on: assignment.id == reward.assignment_id,
      join: condition in Condition,
      on: condition.id == assignment.condition_id,
      join: experiment in ExperimentDefinition,
      on: experiment.id == assignment.experiment_id,
      join: binding in AssessmentBinding,
      on: binding.id == reward.assessment_binding_id,
      join: intervention in Intervention,
      on: intervention.id == binding.intervention_id,
      where: reward.resource_attempt_id == ^resource_attempt_id,
      order_by: [asc: reward.id],
      select: %{
        reward: reward,
        assignment: assignment,
        condition_code: condition.condition_code,
        experiment_uuid: experiment.uuid,
        binding: binding,
        intervention: intervention
      }
    )
    |> Repo.all()
    |> Enum.map(&attribution(&1, context))
  end

  defp attribution(evidence, context) do
    assignment = %{
      evidence.assignment
      | condition: %Condition{condition_code: evidence.condition_code},
        experiment: %ExperimentDefinition{uuid: evidence.experiment_uuid}
    }

    request = %RecordRewardRequest{
      key: "assessment_reward:#{evidence.reward.id}",
      scope: %Scope{
        project_id: context.project_id,
        publication_id: context.publication_id,
        section_id: context.section_id,
        enrollment_id: context.enrollment_id,
        user_id: context.user_id
      },
      assignment_id: assignment.id,
      reward_value: evidence.reward.reward,
      reward_source: "assessment_page:normalized_score",
      metadata: %{}
    }

    receipt = %RewardReceipt{
      key: request.key,
      assignment_id: assignment.id,
      recorded_at: evidence.reward.inserted_at,
      reused?: true
    }

    receipt
    |> Attributions.reward_attribution(request, assignment: assignment)
    |> Map.merge(%{
      "role" => "rollup",
      "assessment_binding_id" => evidence.binding.id,
      "assessment_page_resource_id" => evidence.binding.assessment_page_resource_id,
      "intervention_id" => evidence.intervention.id,
      "intervention_key" =>
        "#{evidence.intervention.page_resource_id}:#{evidence.intervention.content_element_id}",
      "resource_attempt_id" => resource_attempt_id(evidence.reward),
      "reward_threshold" => decimal_number(evidence.binding.reward_threshold),
      "normalized_score" => decimal_number(evidence.reward.normalized_score),
      "disposition" => "accepted"
    })
  end

  defp resource_attempt_id(reward), do: reward.resource_attempt_id
  defp decimal_number(%Decimal{} = value), do: Decimal.to_float(value)
  defp decimal_number(value), do: value
end
