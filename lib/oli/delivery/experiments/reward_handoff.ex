defmodule Oli.Delivery.Experiments.RewardHandoff do
  @moduledoc """
  Converts finalized scored-page assessment attempts into experiment rewards.

  Reward inputs are derived exclusively from persisted resource-attempt scores and
  assessment bindings. Activity attempts and learner responses are not inspected.
  """

  import Ecto.Query, warn: false

  alias Oli.Delivery.Attempts.Core.{ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Sections.Section

  alias Oli.Repo

  alias Oli.Experiments.Policies.ThompsonSampling

  alias Oli.Experiments.Schemas.{
    AcceptedReward,
    AssessmentBinding,
    Assignment,
    Condition,
    DecisionPoint,
    DecisionPointCondition,
    ExperimentDefinition,
    ExperimentSection,
    Intervention,
    PolicyState
  }

  @doc """
  Processes a finalized scored-page attempt using persisted assessment bindings.

  The first attempt in canonical `(attempt_number, id)` order governs eligibility.
  Pending attempts block later attempts, and accepted rewards are claimed and applied
  to the decision-point posterior in one transaction.
  """
  @spec record_evaluated_resource_attempt(integer()) :: :ok | {:error, term()}
  def record_evaluated_resource_attempt(resource_attempt_id)
      when is_integer(resource_attempt_id) do
    case load_resource_attempt_context(resource_attempt_id) do
      nil ->
        emit_skipped(:resource_attempt_not_found, %{resource_attempt_id: resource_attempt_id})
        :ok

      context ->
        process_resource_attempt_context(context)
    end
  end

  def record_evaluated_resource_attempt(_resource_attempt_id),
    do: {:error, :invalid_resource_attempt}

  @doc "Returns whether an evaluated resource attempt has an active Thompson assessment binding."
  @spec relevant_resource_attempt?(integer(), integer()) :: boolean()
  def relevant_resource_attempt?(resource_attempt_id, section_id)
      when is_integer(resource_attempt_id) and is_integer(section_id) do
    from(resource_attempt in ResourceAttempt,
      join: resource_access in ResourceAccess,
      on:
        resource_access.id == resource_attempt.resource_access_id and
          resource_access.section_id == ^section_id,
      join: section in Section,
      on: section.id == resource_access.section_id,
      join: binding in AssessmentBinding,
      on: binding.assessment_page_resource_id == resource_access.resource_id,
      join: intervention in Intervention,
      on: intervention.id == binding.intervention_id,
      join: decision_point in DecisionPoint,
      on:
        decision_point.id == intervention.decision_point_id and
          decision_point.algorithm == :thompson_sampling,
      join: experiment in ExperimentDefinition,
      on:
        experiment.id == decision_point.experiment_id and experiment.state == :active and
          experiment.project_id == section.base_project_id,
      join: experiment_section in ExperimentSection,
      on:
        experiment_section.experiment_id == experiment.id and
          experiment_section.section_id == resource_access.section_id,
      where: resource_attempt.id == ^resource_attempt_id
    )
    |> Repo.exists?()
  end

  def relevant_resource_attempt?(_resource_attempt_id, _section_id), do: false

  defp load_resource_attempt_context(resource_attempt_id) do
    from(resource_attempt in ResourceAttempt,
      join: resource_access in ResourceAccess,
      on: resource_access.id == resource_attempt.resource_access_id,
      join: section in Section,
      on: section.id == resource_access.section_id,
      join: enrollment in Oli.Delivery.Sections.Enrollment,
      on: enrollment.section_id == section.id and enrollment.user_id == resource_access.user_id,
      where: resource_attempt.id == ^resource_attempt_id,
      select: %{
        resource_attempt: resource_attempt,
        resource_access: resource_access,
        section_id: section.id,
        project_id: section.base_project_id,
        enrollment_id: enrollment.id,
        user_id: resource_access.user_id
      }
    )
    |> Repo.one()
  end

  defp process_resource_attempt_context(context) do
    case assessment_bindings(context) do
      [] ->
        :ok

      bindings ->
        eligibility = eligible_resource_attempt(context)

        Enum.reduce_while(bindings, :ok, fn binding_context, :ok ->
          binding = binding_context.binding

          case eligibility do
            {:eligible, resource_attempt, normalized_score} ->
              case accept_assessment_reward(
                     context,
                     binding_context,
                     resource_attempt,
                     normalized_score
                   ) do
                {:ok, disposition} ->
                  emit_disposition(disposition, binding.id, resource_attempt.id)
                  {:cont, :ok}

                {:error, reason} ->
                  {:halt, {:error, reason}}
              end

            {:skip, reason} ->
              emit_skipped(reason, %{
                resource_attempt_id: context.resource_attempt.id,
                assessment_binding_id: binding.id
              })

              {:cont, :ok}
          end
        end)
    end
  end

  defp assessment_bindings(context) do
    from(binding in AssessmentBinding,
      join: intervention in Intervention,
      on: intervention.id == binding.intervention_id,
      join: decision_point in DecisionPoint,
      on: decision_point.id == intervention.decision_point_id,
      join: experiment in ExperimentDefinition,
      on: experiment.id == decision_point.experiment_id,
      join: experiment_section in ExperimentSection,
      on:
        experiment_section.experiment_id == experiment.id and
          experiment_section.section_id == ^context.section_id,
      where:
        binding.assessment_page_resource_id == ^context.resource_access.resource_id and
          experiment.project_id == ^context.project_id and experiment.state == :active and
          decision_point.algorithm == :thompson_sampling,
      select: %{
        binding: %{binding | intervention: intervention},
        experiment_id: experiment.id,
        decision_point_id: decision_point.id
      }
    )
    |> Repo.all()
  end

  defp eligible_resource_attempt(context) do
    first_attempt =
      from(resource_attempt in ResourceAttempt,
        where: resource_attempt.resource_access_id == ^context.resource_access.id,
        order_by: [asc: resource_attempt.attempt_number, asc: resource_attempt.id],
        limit: 1
      )
      |> Repo.one()

    case first_attempt do
      nil ->
        {:skip, :attempt_not_found}

      %ResourceAttempt{id: id} when id != context.resource_attempt.id ->
        {:skip, :not_first_attempt}

      %ResourceAttempt{lifecycle_state: state} when state in [:active, :submitted] ->
        {:skip, :pending_attempt}

      %ResourceAttempt{lifecycle_state: :evaluated, score: score, out_of: out_of} = attempt
      when is_number(score) and is_number(out_of) and out_of > 0 ->
        normalized_score =
          Decimal.div(Decimal.from_float(score * 1.0), Decimal.from_float(out_of * 1.0))

        case Decimal.compare(normalized_score, 0) in [:eq, :gt] and
               Decimal.compare(normalized_score, 1) in [:eq, :lt] do
          true -> {:eligible, attempt, normalized_score}
          false -> {:skip, :invalid_normalized_score}
        end

      %ResourceAttempt{lifecycle_state: :evaluated} ->
        {:skip, :invalid_score}

      %ResourceAttempt{lifecycle_state: state} ->
        {:skip, {:invalid_lifecycle_state, state}}
    end
  end

  defp accept_assessment_reward(context, binding_context, resource_attempt, normalized_score) do
    binding = binding_context.binding

    case Repo.get_by(AcceptedReward,
           assessment_binding_id: binding.id,
           enrollment_id: context.enrollment_id
         ) do
      %AcceptedReward{} = reward ->
        {:ok, {:duplicate, reward}}

      nil ->
        Repo.transaction(fn ->
          assignment =
            Repo.one(
              from(assignment in Assignment,
                where:
                  assignment.intervention_id == ^binding.intervention_id and
                    assignment.enrollment_id == ^context.enrollment_id and
                    assignment.experiment_id == ^binding_context.experiment_id and
                    assignment.decision_point_id == ^binding_context.decision_point_id and
                    assignment.section_id == ^context.section_id and
                    assignment.user_id == ^context.user_id
              )
            )

          case assignment do
            nil ->
              {:skipped, :missing_assignment}

            assignment ->
              accept_locked_reward(
                binding,
                assignment,
                binding_context.experiment_id,
                binding_context.decision_point_id,
                context.enrollment_id,
                resource_attempt,
                normalized_score
              )
          end
        end)
    end
  end

  defp accept_locked_reward(
         binding,
         assignment,
         experiment_id,
         decision_point_id,
         enrollment_id,
         resource_attempt,
         normalized_score
       ) do
    policy_state =
      Repo.one!(
        from(policy_state in PolicyState,
          where:
            policy_state.experiment_id == ^experiment_id and
              policy_state.decision_point_id == ^decision_point_id and
              policy_state.algorithm == :thompson_sampling,
          lock: "FOR UPDATE"
        )
      )

    existing =
      Repo.get_by(AcceptedReward,
        assessment_binding_id: binding.id,
        enrollment_id: enrollment_id
      )

    case existing do
      %AcceptedReward{} = reward ->
        {:duplicate, reward}

      nil ->
        condition =
          Repo.one!(
            from(condition in Condition,
              join: mapping in DecisionPointCondition,
              on:
                mapping.condition_id == condition.id and
                  mapping.decision_point_id == ^decision_point_id,
              where:
                condition.id == ^assignment.condition_id and
                  condition.experiment_id == ^experiment_id
            )
          )

        reward =
          if Decimal.compare(normalized_score, binding.reward_threshold) in [:eq, :gt],
            do: 1,
            else: 0

        {:ok, update} =
          ThompsonSampling.record_reward(%{}, policy_state.state, %{
            condition_code: condition.condition_code,
            reward_value: reward
          })

        accepted_reward =
          %AcceptedReward{}
          |> AcceptedReward.changeset(%{
            assessment_binding_id: binding.id,
            assignment_id: assignment.id,
            enrollment_id: enrollment_id,
            resource_attempt_id: resource_attempt.id,
            reward: reward,
            normalized_score: normalized_score
          })
          |> Repo.insert!()

        policy_state
        |> PolicyState.changeset(%{
          state: update.next_state,
          algorithm_version: update.algorithm_version,
          reward_success_count:
            policy_state.reward_success_count + if(reward == 1, do: 1, else: 0),
          reward_failure_count:
            policy_state.reward_failure_count + if(reward == 0, do: 1, else: 0)
        })
        |> Repo.update!()

        {:accepted, accepted_reward}
    end
  end

  defp emit_skipped(reason, metadata) do
    :telemetry.execute(
      [:oli, :experiments, :delivery_reward, :skipped],
      %{count: 1},
      Map.put(metadata, :reason, reason)
    )
  end

  defp emit_disposition({:skipped, reason}, binding_id, resource_attempt_id) do
    emit_skipped(reason, %{
      assessment_binding_id: binding_id,
      resource_attempt_id: resource_attempt_id
    })
  end

  defp emit_disposition({disposition, %AcceptedReward{}}, binding_id, resource_attempt_id)
       when disposition in [:accepted, :duplicate] do
    :telemetry.execute(
      [:oli, :experiments, :delivery_reward, disposition],
      %{count: 1},
      %{assessment_binding_id: binding_id, resource_attempt_id: resource_attempt_id}
    )
  end
end
