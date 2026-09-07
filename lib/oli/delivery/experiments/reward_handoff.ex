defmodule Oli.Delivery.Experiments.RewardHandoff do
  @moduledoc """
  Converts finalized scored-page assessment attempts into experiment rewards.

  Reward inputs are derived exclusively from persisted resource-attempt scores and
  assessment bindings. Activity attempts and learner responses are not inspected.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Oli.Delivery.Attempts.Core.{ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Sections.Section

  alias Oli.Repo

  alias Oli.Experiments.Policies.ThompsonSampling

  alias Oli.Experiments.Schemas.{
    AcceptedReward,
    AssessmentBinding,
    Assignment,
    Condition,
    ExperimentDefinition,
    ExperimentSection,
    Intervention,
    PolicyState
  }

  @doc """
  Processes a finalized scored-page attempt using persisted assessment bindings.

  The first attempt in canonical `(attempt_number, id)` order governs eligibility.
  Pending attempts block later attempts, and accepted rewards are claimed and applied
  to the experiment posterior in one transaction.
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

  @doc "Processes an evaluated attempt only when its section has an active Thompson experiment."
  @spec record_if_active_thompson(integer(), integer()) :: :ok | {:error, term()}
  def record_if_active_thompson(resource_attempt_id, section_id)
      when is_integer(resource_attempt_id) and is_integer(section_id) do
    try do
      case active_thompson_section?(section_id) do
        true ->
          case record_evaluated_resource_attempt(resource_attempt_id) do
            :ok ->
              :ok

            {:error, reason} = error ->
              report_failure(reason, resource_attempt_id, section_id)
              error
          end

        false ->
          :ok
      end
    rescue
      exception ->
        report_failure(exception, resource_attempt_id, section_id)
        reraise exception, __STACKTRACE__
    end
  end

  def record_if_active_thompson(_resource_attempt_id, _section_id),
    do: {:error, :invalid_resource_attempt}

  @doc "Returns whether a section participates in an active Thompson Sampling experiment."
  @spec active_thompson_section?(integer()) :: boolean()
  def active_thompson_section?(section_id) when is_integer(section_id) do
    from(experiment_section in ExperimentSection,
      join: experiment in ExperimentDefinition,
      on: experiment.id == experiment_section.experiment_id,
      join: section in Section,
      on: section.id == experiment_section.section_id,
      where:
        experiment_section.section_id == ^section_id and
          experiment.project_id == section.base_project_id and
          experiment.state == :active and experiment.algorithm == :thompson_sampling
    )
    |> Repo.exists?()
  end

  def active_thompson_section?(_section_id), do: false

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
      join: experiment in ExperimentDefinition,
      on: experiment.id == intervention.experiment_id,
      join: experiment_section in ExperimentSection,
      on:
        experiment_section.experiment_id == experiment.id and
          experiment_section.section_id == ^context.section_id,
      left_join: assignment in Assignment,
      on:
        assignment.intervention_id == binding.intervention_id and
          assignment.enrollment_id == ^context.enrollment_id and
          assignment.experiment_id == experiment.id and
          assignment.section_id == ^context.section_id and
          assignment.user_id == ^context.user_id,
      left_join: condition in Condition,
      on: condition.id == assignment.condition_id and condition.experiment_id == experiment.id,
      left_join: accepted_reward in AcceptedReward,
      on:
        accepted_reward.assessment_binding_id == binding.id and
          accepted_reward.enrollment_id == ^context.enrollment_id,
      where:
        binding.assessment_page_resource_id == ^context.resource_access.resource_id and
          experiment.project_id == ^context.project_id and experiment.state == :active and
          experiment.algorithm == :thompson_sampling,
      select: %{
        binding: %{binding | intervention: intervention},
        experiment_id: experiment.id,
        project_id: experiment.project_id,
        assignment: assignment,
        condition: condition,
        accepted_reward: accepted_reward
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

    case binding_context.accepted_reward do
      %AcceptedReward{} = reward ->
        {:ok, {:duplicate, reward}}

      nil ->
        Repo.transaction(fn ->
          case binding_context.assignment do
            nil ->
              {:skipped, :missing_assignment}

            assignment ->
              accept_locked_reward(
                binding,
                assignment,
                binding_context.condition,
                binding_context.experiment_id,
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
         condition,
         experiment_id,
         enrollment_id,
         resource_attempt,
         normalized_score
       ) do
    policy_state =
      Repo.one!(
        from(policy_state in PolicyState,
          where:
            policy_state.experiment_id == ^experiment_id and
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

  defp report_failure(reason, resource_attempt_id, section_id) do
    failure_reason = classify_failure(reason)

    :telemetry.execute(
      [:oli, :experiments, :delivery_reward, :failed],
      %{count: 1},
      %{reason: failure_reason}
    )

    Logger.error("Thompson reward processing failed",
      reward_processing_reason: failure_reason,
      resource_attempt_id: resource_attempt_id,
      section_id: section_id,
      failure: inspect(reason)
    )
  end

  defp classify_failure(%Ecto.NoResultsError{}), do: :missing_policy_state
  defp classify_failure(%MatchError{term: {:error, :invalid_reward_value}}), do: :invalid_reward
  defp classify_failure(%MatchError{term: {:error, _reason}}), do: :policy_update_error
  defp classify_failure(%MatchError{}), do: :unexpected_exception
  defp classify_failure(%Ecto.ConstraintError{}), do: :database_error

  defp classify_failure(%Postgrex.Error{postgres: %{code: :lock_not_available}}),
    do: :lock_timeout

  defp classify_failure(%Postgrex.Error{postgres: %{code: :query_canceled, message: message}})
       when is_binary(message) do
    case String.contains?(message, "lock timeout") do
      true -> :lock_timeout
      false -> :database_timeout
    end
  end

  defp classify_failure(%Postgrex.Error{postgres: %{code: :deadlock_detected}}), do: :deadlock
  defp classify_failure(%Postgrex.Error{}), do: :database_error
  defp classify_failure(%_{}), do: :unexpected_exception
  defp classify_failure(_reason), do: :unexpected_exception
end
