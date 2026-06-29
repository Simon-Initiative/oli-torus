defmodule Oli.Experiments do
  @moduledoc """
  Public context boundary for native A/B testing experiments.
  """

  import Ecto.Changeset
  import Ecto.Query

  alias Oli.Accounts.User
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.{Enrollment, Section}

  alias Oli.Experiments.{
    AssignmentDecision,
    ExperimentDefinition,
    ExperimentError,
    ExposureReceipt,
    OutcomeReceipt,
    RewardReceipt,
    Scope
  }

  alias Oli.Experiments.Schemas.{
    Assignment,
    Condition,
    DecisionPoint,
    Exposure,
    Outcome,
    PolicyState,
    PolicyUpdate,
    Reward
  }

  alias Oli.Experiments.Policies.{ThompsonSampling, WeightedRandom}

  alias Oli.Experiments.Schemas.ExperimentDefinition, as: ExperimentDefinitionSchema
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo

  @transition_targets %{
    activate_experiment: :active,
    pause_experiment: :paused,
    complete_experiment: :completed,
    archive_experiment: :archived
  }

  @allowed_transitions %{
    draft: [:active, :archived],
    active: [:paused, :completed, :archived],
    paused: [:active, :completed, :archived],
    completed: [:archived],
    archived: []
  }

  @doc """
  Creates a native experiment definition.
  """
  def create_experiment(%Oli.Experiments.CreateExperimentRequest{} = request) do
    with {:ok, scope} <- validate_scope(request.scope),
         attrs <- create_attrs(request, scope),
         {:ok, schema} <- insert_definition(attrs) do
      {:ok, to_definition(schema)}
    end
  end

  def create_experiment(_request), do: invalid_request("expected CreateExperimentRequest")

  @doc """
  Updates mutable fields on a draft experiment definition.
  """
  def update_experiment(experiment_id, %Oli.Experiments.UpdateExperimentRequest{} = request) do
    with {:ok, schema} <- get_scoped_definition(experiment_id, request.scope),
         :ok <- require_state(schema, [:draft]),
         {:ok, updated} <- update_definition(schema, update_attrs(request)) do
      {:ok, to_definition(updated)}
    end
  end

  def update_experiment(_experiment_id, _request),
    do: invalid_request("expected UpdateExperimentRequest")

  @doc """
  Activates a draft or paused experiment.
  """
  def activate_experiment(experiment_id, request),
    do: transition(experiment_id, request, :activate_experiment)

  @doc """
  Pauses an active experiment.
  """
  def pause_experiment(experiment_id, request),
    do: transition(experiment_id, request, :pause_experiment)

  @doc """
  Completes an active or paused experiment.
  """
  def complete_experiment(experiment_id, request),
    do: transition(experiment_id, request, :complete_experiment)

  @doc """
  Archives an experiment when the current lifecycle state allows it.
  """
  def archive_experiment(experiment_id, request),
    do: transition(experiment_id, request, :archive_experiment)

  @doc """
  Delivery assignment API placeholder. Runtime assignment writes are implemented in Phase 3.
  """
  def assign_condition(%Oli.Experiments.AssignConditionRequest{} = request) do
    metadata = assignment_metadata(request)
    start_time = System.monotonic_time()

    :telemetry.execute(
      [:oli, :experiments, :assignment, :start],
      %{system_time: System.system_time()},
      metadata
    )

    try do
      result = do_assign_condition(request)
      duration = System.monotonic_time() - start_time

      :telemetry.execute(
        [:oli, :experiments, :assignment, :stop],
        %{duration: duration},
        metadata
      )

      result
    rescue
      exception ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:oli, :experiments, :assignment, :exception],
          %{duration: duration},
          Map.merge(metadata, %{kind: :error, reason: exception.__struct__})
        )

        reraise exception, __STACKTRACE__
    end
  end

  def assign_condition(_request), do: invalid_request("expected AssignConditionRequest")

  @doc """
  Exposure recording API placeholder. Runtime evidence writes are implemented in Phase 3.
  """
  def record_exposure(%Oli.Experiments.RecordExposureRequest{} = request) do
    with {:ok, _scope} <- validate_scope(request.scope),
         {:ok, nil} <- find_exposure_receipt(request.idempotency_key, request.scope) do
      create_exposure(request)
    else
      {:ok, %ExposureReceipt{} = receipt} -> {:ok, receipt}
      {:error, %ExperimentError{}} = error -> error
    end
  end

  def record_exposure(_request), do: invalid_request("expected RecordExposureRequest")

  @doc """
  Outcome recording API placeholder. Runtime evidence writes are implemented in Phase 3.
  """
  def record_outcome(%Oli.Experiments.RecordOutcomeRequest{} = request) do
    with {:ok, _scope} <- validate_scope(request.scope),
         {:ok, nil} <- find_outcome_receipt(request.idempotency_key, request.scope) do
      create_outcome(request)
    else
      {:ok, %OutcomeReceipt{} = receipt} -> {:ok, receipt}
      {:error, %ExperimentError{}} = error -> error
    end
  end

  def record_outcome(_request), do: invalid_request("expected RecordOutcomeRequest")

  @doc """
  Reward recording API placeholder. Runtime evidence writes are implemented in Phase 3.
  """
  def record_reward(%Oli.Experiments.RecordRewardRequest{} = request) do
    with {:ok, _scope} <- validate_scope(request.scope),
         {:ok, nil} <- find_reward_receipt(request.idempotency_key, request.scope) do
      create_reward(request)
    else
      {:ok, %RewardReceipt{} = receipt} -> {:ok, receipt}
      {:error, %ExperimentError{}} = error -> error
    end
  end

  def record_reward(_request), do: invalid_request("expected RecordRewardRequest")

  @doc """
  Analytics read API placeholder. Aggregate reads are implemented in Phase 5.
  """
  def experiment_summary(%Oli.Experiments.AnalyticsQuery{} = query) do
    with {:ok, scope} <- validate_scope(query.scope),
         :ok <- ensure_analytics_experiment_scope(scope, query.experiment_id) do
      experiment_query = scoped_experiment_query(scope, query.experiment_id)

      {:ok,
       %{
         experiments: Repo.aggregate(experiment_query, :count, :id),
         assignments:
           Repo.aggregate(scoped_assignment_query(scope, query.experiment_id), :count, :id),
         exposures:
           Repo.aggregate(scoped_exposure_query(scope, query.experiment_id), :count, :id),
         rewards: Repo.aggregate(scoped_reward_query(scope, query.experiment_id), :count, :id)
       }}
    end
  end

  def experiment_summary(_query), do: invalid_request("expected AnalyticsQuery")

  def assignment_counts(%Oli.Experiments.AnalyticsQuery{} = query) do
    with {:ok, scope} <- validate_scope(query.scope),
         :ok <- ensure_analytics_experiment_scope(scope, query.experiment_id) do
      counts =
        scope
        |> scoped_assignment_query(query.experiment_id)
        |> join(:inner, [assignment, _experiment], condition in Condition,
          on: condition.id == assignment.condition_id
        )
        |> group_by([assignment, _experiment, condition], [
          assignment.experiment_id,
          assignment.decision_point_id,
          assignment.condition_id,
          condition.condition_code
        ])
        |> select([assignment, _experiment, condition], %{
          experiment_id: assignment.experiment_id,
          decision_point_id: assignment.decision_point_id,
          condition_id: assignment.condition_id,
          condition_code: condition.condition_code,
          count: count(assignment.id)
        })
        |> Repo.all()

      {:ok, counts}
    end
  end

  def assignment_counts(_query), do: invalid_request("expected AnalyticsQuery")

  def exposure_counts(%Oli.Experiments.AnalyticsQuery{} = query) do
    with {:ok, scope} <- validate_scope(query.scope),
         :ok <- ensure_analytics_experiment_scope(scope, query.experiment_id) do
      counts =
        scope
        |> scoped_exposure_query(query.experiment_id)
        |> join(:inner, [exposure, _experiment], condition in Condition,
          on: condition.id == exposure.condition_id
        )
        |> group_by([exposure, _experiment, condition], [
          exposure.experiment_id,
          exposure.decision_point_id,
          exposure.condition_id,
          condition.condition_code
        ])
        |> select([exposure, _experiment, condition], %{
          experiment_id: exposure.experiment_id,
          decision_point_id: exposure.decision_point_id,
          condition_id: exposure.condition_id,
          condition_code: condition.condition_code,
          count: count(exposure.id)
        })
        |> Repo.all()

      {:ok, counts}
    end
  end

  def exposure_counts(_query), do: invalid_request("expected AnalyticsQuery")

  def reward_counts(%Oli.Experiments.AnalyticsQuery{} = query) do
    with {:ok, scope} <- validate_scope(query.scope),
         :ok <- ensure_analytics_experiment_scope(scope, query.experiment_id) do
      counts =
        scope
        |> scoped_reward_query(query.experiment_id)
        |> join(:inner, [reward, _experiment], condition in Condition,
          on: condition.id == reward.condition_id
        )
        |> group_by([reward, _experiment, condition], [
          reward.experiment_id,
          reward.decision_point_id,
          reward.condition_id,
          condition.condition_code
        ])
        |> select([reward, _experiment, condition], %{
          experiment_id: reward.experiment_id,
          decision_point_id: reward.decision_point_id,
          condition_id: reward.condition_id,
          condition_code: condition.condition_code,
          count: count(reward.id)
        })
        |> Repo.all()

      {:ok, counts}
    end
  end

  def reward_counts(_query), do: invalid_request("expected AnalyticsQuery")

  def policy_state_snapshot(%Oli.Experiments.AnalyticsQuery{} = query) do
    with {:ok, scope} <- validate_scope(query.scope),
         :ok <- ensure_analytics_experiment_scope(scope, query.experiment_id) do
      snapshots =
        scope
        |> scoped_policy_state_query(query.experiment_id)
        |> select([policy_state, _experiment], %{
          experiment_id: policy_state.experiment_id,
          decision_point_id: policy_state.decision_point_id,
          algorithm: policy_state.algorithm,
          algorithm_version: policy_state.algorithm_version,
          state: policy_state.state,
          reward_success_count: policy_state.reward_success_count,
          reward_failure_count: policy_state.reward_failure_count,
          assignment_count: policy_state.assignment_count
        })
        |> Repo.all()

      {:ok, snapshots}
    end
  end

  def policy_state_snapshot(_query), do: invalid_request("expected AnalyticsQuery")

  defp transition(experiment_id, %Oli.Experiments.LifecycleRequest{} = request, action) do
    target_state = Map.fetch!(@transition_targets, action)

    with {:ok, schema} <- get_scoped_definition(experiment_id, request.scope),
         :ok <- validate_transition(schema.state, target_state),
         attrs <- transition_attrs(schema, target_state, request.transitioned_at),
         {:ok, updated} <- update_definition(schema, attrs) do
      {:ok, to_definition(updated)}
    end
  end

  defp transition(_experiment_id, _request, _action),
    do: invalid_request("expected LifecycleRequest")

  defp scoped_experiment_query(scope, experiment_id) do
    query =
      from(experiment in ExperimentDefinitionSchema,
        where:
          experiment.institution_id == ^scope.institution_id and
            experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_experiment_id(experiment_id)
    |> maybe_filter_experiment_publication(scope.publication_id)
    |> maybe_filter_experiment_section(scope.section_id)
  end

  defp ensure_analytics_experiment_scope(_scope, nil), do: :ok

  defp ensure_analytics_experiment_scope(scope, experiment_id) do
    case Repo.exists?(scoped_experiment_query(scope, experiment_id)) do
      true ->
        :ok

      false ->
        invalid_scope("experiment is outside analytics scope", %{experiment_id: experiment_id})
    end
  end

  defp scoped_assignment_query(scope, experiment_id) do
    query =
      from(assignment in Assignment,
        join: experiment in ExperimentDefinitionSchema,
        on: experiment.id == assignment.experiment_id,
        where:
          experiment.institution_id == ^scope.institution_id and
            experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_joined_experiment_id(experiment_id)
    |> maybe_filter_assignment_publication(scope.publication_id)
    |> maybe_filter_assignment_section(scope.section_id)
  end

  defp scoped_exposure_query(scope, experiment_id) do
    query =
      from(exposure in Exposure,
        join: experiment in ExperimentDefinitionSchema,
        on: experiment.id == exposure.experiment_id,
        where:
          experiment.institution_id == ^scope.institution_id and
            experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_joined_experiment_id(experiment_id)
    |> maybe_filter_exposure_publication(scope.publication_id)
    |> maybe_filter_exposure_section(scope.section_id)
  end

  defp scoped_reward_query(scope, experiment_id) do
    query =
      from(reward in Reward,
        join: experiment in ExperimentDefinitionSchema,
        on: experiment.id == reward.experiment_id,
        where:
          experiment.institution_id == ^scope.institution_id and
            experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_joined_experiment_id(experiment_id)
    |> maybe_filter_joined_experiment_publication(scope.publication_id)
    |> maybe_filter_reward_section(scope.section_id)
  end

  defp maybe_filter_experiment_id(query, nil), do: query

  defp maybe_filter_experiment_id(query, experiment_id) do
    where(query, [experiment], experiment.id == ^experiment_id)
  end

  defp maybe_filter_joined_experiment_id(query, nil), do: query

  defp maybe_filter_joined_experiment_id(query, experiment_id) do
    where(query, [_record, experiment], experiment.id == ^experiment_id)
  end

  defp maybe_filter_experiment_publication(query, nil), do: query

  defp maybe_filter_experiment_publication(query, publication_id) do
    where(
      query,
      [experiment],
      is_nil(experiment.publication_id) or experiment.publication_id == ^publication_id
    )
  end

  defp maybe_filter_joined_experiment_publication(query, nil), do: query

  defp maybe_filter_joined_experiment_publication(query, publication_id) do
    where(
      query,
      [_record, experiment],
      is_nil(experiment.publication_id) or experiment.publication_id == ^publication_id
    )
  end

  defp maybe_filter_experiment_section(query, nil), do: query

  defp maybe_filter_experiment_section(query, section_id) do
    where(
      query,
      [experiment],
      is_nil(experiment.section_id) or experiment.section_id == ^section_id
    )
  end

  defp maybe_filter_joined_experiment_section(query, nil), do: query

  defp maybe_filter_joined_experiment_section(query, section_id) do
    where(
      query,
      [_record, experiment],
      is_nil(experiment.section_id) or experiment.section_id == ^section_id
    )
  end

  defp maybe_filter_assignment_publication(query, nil), do: query

  defp maybe_filter_assignment_publication(query, publication_id) do
    where(query, [assignment, _experiment], assignment.publication_id == ^publication_id)
  end

  defp maybe_filter_assignment_section(query, nil), do: query

  defp maybe_filter_assignment_section(query, section_id) do
    where(query, [assignment, _experiment], assignment.section_id == ^section_id)
  end

  defp maybe_filter_exposure_publication(query, nil), do: query

  defp maybe_filter_exposure_publication(query, publication_id) do
    where(query, [exposure, _experiment], exposure.publication_id == ^publication_id)
  end

  defp maybe_filter_exposure_section(query, nil), do: query

  defp maybe_filter_exposure_section(query, section_id) do
    where(query, [exposure, _experiment], exposure.section_id == ^section_id)
  end

  defp maybe_filter_reward_section(query, nil), do: query

  defp maybe_filter_reward_section(query, section_id) do
    where(
      query,
      [reward, _experiment],
      fragment(
        "EXISTS (SELECT 1 FROM experiment_assignments ea WHERE ea.id = ? AND ea.section_id = ?)",
        reward.assignment_id,
        ^section_id
      )
    )
  end

  defp scoped_policy_state_query(scope, experiment_id) do
    query =
      from(policy_state in PolicyState,
        join: experiment in ExperimentDefinitionSchema,
        on: experiment.id == policy_state.experiment_id,
        where:
          experiment.institution_id == ^scope.institution_id and
            experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_joined_experiment_id(experiment_id)
    |> maybe_filter_joined_experiment_publication(scope.publication_id)
    |> maybe_filter_joined_experiment_section(scope.section_id)
  end

  defp do_assign_condition(request) do
    with {:ok, scope} <- validate_scope(request.scope),
         :ok <- require_delivery_scope(scope),
         {:ok, match} <- active_experiment_match(request, scope),
         {:ok, decision} <- assign_or_reuse(match, scope) do
      {:ok, decision}
    end
  end

  defp require_delivery_scope(scope) do
    missing =
      [:section_id, :user_id, :enrollment_id]
      |> Enum.filter(fn field -> is_nil(Map.fetch!(scope, field)) end)

    case missing do
      [] -> :ok
      fields -> invalid_scope("delivery assignment scope is incomplete", %{missing: fields})
    end
  end

  defp active_experiment_match(request, scope) do
    query =
      from experiment in ExperimentDefinitionSchema,
        join: decision_point in DecisionPoint,
        on: decision_point.experiment_id == experiment.id,
        where:
          experiment.state == :active and
            experiment.institution_id == ^scope.institution_id and
            experiment.project_id == ^scope.project_id and
            decision_point.alternatives_resource_id == ^request.alternatives_resource_id and
            decision_point.alternatives_revision_id == ^request.alternatives_revision_id and
            decision_point.decision_point_key == ^request.decision_point_key,
        where:
          is_nil(experiment.publication_id) or experiment.publication_id == ^scope.publication_id,
        where: is_nil(experiment.section_id) or experiment.section_id == ^scope.section_id,
        order_by: [asc: experiment.id],
        limit: 1,
        select: {experiment, decision_point}

    case Repo.one(query) do
      nil ->
        :telemetry.execute(
          [:oli, :experiments, :assignment, :fallback],
          %{count: 1},
          %{reason: :no_experiment}
        )

        {:ok, %{status: :no_experiment}}

      {experiment, decision_point} ->
        with {:ok, selection} <-
               select_condition(
                 experiment,
                 decision_point,
                 request.available_condition_codes,
                 scope
               ) do
          {:ok, Map.merge(selection, %{experiment: experiment, decision_point: decision_point})}
        end
    end
  end

  defp select_condition(_experiment, _decision_point, [], _scope),
    do: invalid_condition("no condition codes supplied")

  defp select_condition(experiment, decision_point, available_condition_codes, scope) do
    conditions =
      from(condition in Condition,
        where:
          condition.experiment_id == ^experiment.id and
            condition.decision_point_id == ^decision_point.id and
            condition.active == true and
            condition.condition_code in ^available_condition_codes,
        order_by: [asc: condition.position, asc: condition.id]
      )
      |> Repo.all()

    case conditions do
      [] ->
        :telemetry.execute(
          [:oli, :experiments, :assignment, :fallback],
          %{count: 1},
          %{
            reason: :invalid_condition,
            experiment_id: experiment.id,
            decision_point_id: decision_point.id
          }
        )

        invalid_condition("no active experiment condition matches the available condition codes")

      conditions ->
        policy_state = get_policy_state(experiment.id, decision_point.id, experiment.algorithm)

        policy_context = %{
          conditions: conditions,
          assignment_key: assignment_key(experiment.id, decision_point.id, scope.enrollment_id)
        }

        experiment.algorithm
        |> policy_module()
        |> apply(:assign, [
          experiment.policy_config,
          policy_state && policy_state.state,
          policy_context
        ])
        |> case do
          {:ok, policy_assignment} ->
            condition = Enum.find(conditions, &(&1.id == policy_assignment.condition_id))
            {:ok, %{condition: condition, policy_assignment: policy_assignment}}

          {:error, reason} ->
            invalid_condition("policy could not assign a condition", %{reason: reason})
        end
    end
  end

  defp assign_or_reuse(%{status: :no_experiment}, _scope),
    do: {:ok, %AssignmentDecision{status: :no_experiment}}

  defp assign_or_reuse(match, scope) do
    case find_assignment(match.experiment.id, match.decision_point.id, scope.enrollment_id) do
      %Assignment{} = assignment ->
        :telemetry.execute([:oli, :experiments, :assignment, :reuse], %{count: 1}, %{
          experiment_id: match.experiment.id,
          decision_point_id: match.decision_point.id
        })

        {:ok, to_assignment_decision(assignment, match.condition, true)}

      nil ->
        create_assignment(match, scope)
    end
  end

  defp find_assignment(experiment_id, decision_point_id, enrollment_id) do
    Repo.one(
      from assignment in Assignment,
        where:
          assignment.experiment_id == ^experiment_id and
            assignment.decision_point_id == ^decision_point_id and
            assignment.enrollment_id == ^enrollment_id
    )
  end

  defp create_assignment(match, scope) do
    attrs = %{
      experiment_id: match.experiment.id,
      decision_point_id: match.decision_point.id,
      condition_id: match.condition.id,
      institution_id: scope.institution_id,
      section_id: scope.section_id,
      enrollment_id: scope.enrollment_id,
      user_id: scope.user_id,
      publication_id: scope.publication_id,
      assigned_by_policy: Atom.to_string(match.experiment.algorithm),
      policy_version: match.policy_assignment.policy_version,
      assignment_key:
        assignment_key(match.experiment.id, match.decision_point.id, scope.enrollment_id),
      assigned_at: now()
    }

    %Assignment{}
    |> Assignment.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, assignment} ->
        increment_assignment_count(match.experiment, match.decision_point.id)
        {:ok, to_assignment_decision(assignment, match.condition, false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        if conflict?(changeset) do
          match.experiment.id
          |> find_assignment(match.decision_point.id, scope.enrollment_id)
          |> then(&{:ok, to_assignment_decision(&1, match.condition, true)})
        else
          normalize_result({:error, changeset})
        end
    end
  end

  defp assignment_key(experiment_id, decision_point_id, enrollment_id) do
    "#{experiment_id}:#{decision_point_id}:#{enrollment_id}"
  end

  defp increment_assignment_count(experiment, decision_point_id) do
    policy_state = get_or_create_policy_state(experiment, decision_point_id)

    policy_state
    |> PolicyState.changeset(%{assignment_count: policy_state.assignment_count + 1})
    |> Repo.update!()
  end

  defp find_exposure_receipt(idempotency_key, scope) do
    case Repo.get_by(Exposure, idempotency_key: idempotency_key) do
      nil ->
        {:ok, nil}

      exposure ->
        with {:ok, _assignment} <- get_scoped_assignment(exposure.assignment_id, scope) do
          {:ok, to_exposure_receipt(exposure, true)}
        end
    end
  end

  defp create_exposure(request) do
    with {:ok, assignment} <- get_scoped_assignment(request.assignment_id, request.scope),
         attrs <- %{
           assignment_id: assignment.id,
           experiment_id: assignment.experiment_id,
           decision_point_id: assignment.decision_point_id,
           condition_id: assignment.condition_id,
           section_id: assignment.section_id,
           enrollment_id: assignment.enrollment_id,
           user_id: assignment.user_id,
           publication_id: assignment.publication_id,
           content_revision_id: request.content_revision_id,
           exposed_at: request.exposed_at || now(),
           idempotency_key: request.idempotency_key
         },
         {:ok, exposure} <- insert_runtime_record(Exposure.changeset(%Exposure{}, attrs)) do
      :telemetry.execute([:oli, :experiments, :exposure, :recorded], %{count: 1}, %{
        experiment_id: assignment.experiment_id,
        decision_point_id: assignment.decision_point_id
      })

      {:ok, to_exposure_receipt(exposure, false)}
    end
  end

  defp find_outcome_receipt(idempotency_key, scope) do
    case Repo.get_by(Outcome, idempotency_key: idempotency_key) do
      nil ->
        {:ok, nil}

      outcome ->
        with {:ok, _assignment} <- get_scoped_assignment(outcome.assignment_id, scope) do
          {:ok, to_outcome_receipt(outcome, true)}
        end
    end
  end

  defp create_outcome(request) do
    with {:ok, assignment} <- get_scoped_assignment(request.assignment_id, request.scope),
         attrs <- %{
           assignment_id: assignment.id,
           activity_attempt_id: request.activity_attempt_id,
           resource_attempt_id: request.resource_attempt_id,
           activity_resource_id: request.activity_resource_id,
           score: request.score,
           out_of: request.out_of,
           metadata: request.metadata || %{},
           observed_at: request.observed_at || now(),
           idempotency_key: request.idempotency_key
         },
         {:ok, outcome} <- insert_runtime_record(Outcome.changeset(%Outcome{}, attrs)) do
      {:ok, to_outcome_receipt(outcome, false)}
    end
  end

  defp find_reward_receipt(idempotency_key, scope) do
    case Repo.get_by(Reward, idempotency_key: idempotency_key) do
      nil ->
        {:ok, nil}

      reward ->
        with {:ok, _assignment} <- get_scoped_assignment(reward.assignment_id, scope) do
          {:ok, to_reward_receipt(reward, true)}
        end
    end
  end

  defp create_reward(request) do
    with {:ok, assignment} <- get_scoped_assignment(request.assignment_id, request.scope),
         attrs <- %{
           assignment_id: assignment.id,
           outcome_id: request.outcome_id,
           experiment_id: assignment.experiment_id,
           decision_point_id: assignment.decision_point_id,
           condition_id: assignment.condition_id,
           reward_value: request.reward_value,
           reward_source: request.reward_source,
           idempotency_key: request.idempotency_key,
           metadata: request.metadata || %{}
         },
         {:ok, reward} <- insert_runtime_record(Reward.changeset(%Reward{}, attrs)),
         :ok <- record_policy_reward(assignment, reward) do
      :telemetry.execute([:oli, :experiments, :reward, :recorded], %{count: 1}, %{
        experiment_id: assignment.experiment_id,
        decision_point_id: assignment.decision_point_id
      })

      {:ok, to_reward_receipt(reward, false)}
    end
  end

  defp insert_runtime_record(changeset) do
    changeset
    |> Repo.insert()
    |> normalize_result()
  end

  defp record_policy_reward(assignment, reward) do
    experiment = Repo.get!(ExperimentDefinitionSchema, assignment.experiment_id)
    condition = Repo.get!(Condition, assignment.condition_id)
    policy_state = get_or_create_policy_state(experiment, assignment.decision_point_id)

    experiment.algorithm
    |> policy_module()
    |> apply(:record_reward, [
      experiment.policy_config,
      policy_state.state,
      %{condition_code: condition.condition_code, reward_value: reward.reward_value}
    ])
    |> case do
      {:ok, policy_update} ->
        persist_policy_update(policy_state, reward, condition, policy_update)

      {:error, reason} ->
        {:error,
         %ExperimentError{
           type: :persistence_error,
           message: "policy reward update failed",
           details: %{reason: reason}
         }}
    end
  end

  defp get_policy_state(experiment_id, decision_point_id, algorithm) do
    Repo.get_by(PolicyState,
      experiment_id: experiment_id,
      decision_point_id: decision_point_id,
      algorithm: algorithm
    )
  end

  defp get_or_create_policy_state(experiment, decision_point_id) do
    case get_policy_state(experiment.id, decision_point_id, experiment.algorithm) do
      nil ->
        %PolicyState{}
        |> PolicyState.changeset(%{
          experiment_id: experiment.id,
          decision_point_id: decision_point_id,
          algorithm: experiment.algorithm,
          algorithm_version: Atom.to_string(experiment.algorithm),
          state: %{},
          prior_config: %{},
          reward_success_count: 0,
          reward_failure_count: 0,
          assignment_count: 0
        })
        |> Repo.insert!()

      policy_state ->
        policy_state
    end
  end

  defp persist_policy_update(policy_state, reward, condition, policy_update) do
    Repo.transaction(fn ->
      updated_policy_state =
        policy_state
        |> PolicyState.changeset(%{
          algorithm_version: policy_update.algorithm_version,
          state: policy_update.next_state,
          reward_success_count:
            policy_state.reward_success_count +
              Map.get(policy_update.counters, :reward_success_count, 0),
          reward_failure_count:
            policy_state.reward_failure_count +
              Map.get(policy_update.counters, :reward_failure_count, 0),
          last_updated_from_reward_id: reward.id
        })
        |> Repo.update!()

      %PolicyUpdate{}
      |> PolicyUpdate.changeset(%{
        policy_state_id: updated_policy_state.id,
        reward_id: reward.id,
        condition_id: condition.id,
        previous_state: policy_update.previous_state,
        next_state: policy_update.next_state,
        algorithm_version: policy_update.algorithm_version,
        update_reason: policy_update.update_reason
      })
      |> Repo.insert!()
    end)
    |> case do
      {:ok, _policy_update} ->
        :telemetry.execute([:oli, :experiments, :policy, :updated], %{count: 1}, %{
          policy_state_id: policy_state.id,
          reward_id: reward.id
        })

        :ok

      {:error, reason} ->
        :telemetry.execute([:oli, :experiments, :policy, :update_failed], %{count: 1}, %{
          policy_state_id: policy_state.id,
          reward_id: reward.id,
          reason: reason
        })

        {:error,
         %ExperimentError{
           type: :persistence_error,
           message: "policy update could not be persisted",
           details: %{reason: reason}
         }}
    end
  end

  defp policy_module(:weighted_random), do: WeightedRandom
  defp policy_module(:thompson_sampling), do: ThompsonSampling

  defp get_scoped_assignment(assignment_id, scope) do
    with {:ok, scope} <- validate_scope(scope),
         %Assignment{} = assignment <- Repo.get(Assignment, assignment_id),
         :ok <- ensure_assignment_in_scope(assignment, scope) do
      {:ok, assignment}
    else
      nil -> not_found("assignment not found", %{assignment_id: assignment_id})
      {:error, %ExperimentError{}} = error -> error
    end
  end

  defp ensure_assignment_in_scope(assignment, scope) do
    cond do
      assignment.institution_id != scope.institution_id ->
        invalid_scope("assignment does not belong to institution")

      assignment.section_id != scope.section_id ->
        invalid_scope("assignment does not belong to section")

      assignment.enrollment_id != scope.enrollment_id ->
        invalid_scope("assignment does not belong to enrollment")

      assignment.user_id != scope.user_id ->
        invalid_scope("assignment does not belong to user")

      true ->
        :ok
    end
  end

  defp insert_definition(attrs) do
    %ExperimentDefinitionSchema{}
    |> ExperimentDefinitionSchema.changeset(attrs)
    |> Repo.insert()
    |> normalize_result()
  end

  defp update_definition(schema, attrs) do
    schema
    |> ExperimentDefinitionSchema.changeset(attrs)
    |> Repo.update()
    |> normalize_result()
  end

  defp get_scoped_definition(experiment_id, scope) do
    with {:ok, scope} <- validate_scope(scope),
         %ExperimentDefinitionSchema{} = schema <-
           Repo.get(ExperimentDefinitionSchema, experiment_id),
         :ok <- ensure_definition_in_scope(schema, scope) do
      {:ok, schema}
    else
      nil -> not_found("experiment not found", %{experiment_id: experiment_id})
      {:error, %ExperimentError{}} = error -> error
    end
  end

  defp create_attrs(request, scope) do
    %{
      institution_id: scope.institution_id,
      project_id: scope.project_id,
      publication_id: scope.publication_id,
      section_id: scope.section_id,
      slug: request.slug,
      name: request.name,
      description: request.description,
      algorithm: request.algorithm,
      assignment_unit: request.assignment_unit,
      policy_config: request.policy_config || %{}
    }
  end

  defp update_attrs(request) do
    request
    |> Map.from_struct()
    |> Map.take([:slug, :name, :description, :algorithm, :assignment_unit, :policy_config])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp transition_attrs(schema, target_state, transitioned_at) do
    now = transitioned_at || DateTime.utc_now() |> DateTime.truncate(:second)

    attrs = %{state: target_state}

    case {schema.state, target_state} do
      {_state, :active} when is_nil(schema.started_at) -> Map.put(attrs, :started_at, now)
      {_state, :completed} -> Map.put(attrs, :ended_at, now)
      _transition -> attrs
    end
  end

  defp validate_transition(current_state, target_state) do
    allowed_targets = Map.fetch!(@allowed_transitions, current_state)

    if target_state in allowed_targets do
      :ok
    else
      {:error,
       %ExperimentError{
         type: :invalid_state,
         message: "experiment cannot transition from #{current_state} to #{target_state}",
         details: %{current_state: current_state, target_state: target_state}
       }}
    end
  end

  defp require_state(schema, allowed_states) do
    if schema.state in allowed_states do
      :ok
    else
      {:error,
       %ExperimentError{
         type: :invalid_state,
         message: "experiment state does not allow this operation",
         details: %{state: schema.state, allowed_states: allowed_states}
       }}
    end
  end

  defp validate_scope(%Scope{} = scope) do
    with {:ok, scope} <- validate_institution(scope),
         {:ok, scope} <- validate_project(scope),
         {:ok, scope} <- validate_publication(scope),
         {:ok, scope} <- validate_section(scope),
         {:ok, scope} <- validate_user(scope),
         {:ok, scope} <- validate_enrollment(scope) do
      {:ok, scope}
    end
  end

  defp validate_scope(_scope), do: invalid_scope("scope is required")

  defp validate_institution(%Scope{institution_id: nil}),
    do: invalid_scope("institution_id is required")

  defp validate_institution(%Scope{institution_id: institution_id} = scope) do
    case Repo.get(Oli.Institutions.Institution, institution_id) do
      nil -> invalid_scope("institution not found", %{institution_id: institution_id})
      _institution -> {:ok, scope}
    end
  end

  defp validate_project(%Scope{project_id: nil, project_slug: nil}) do
    invalid_scope("project_id or project_slug is required")
  end

  defp validate_project(%Scope{project_id: project_id} = scope) when not is_nil(project_id) do
    case Repo.get(Project, project_id) do
      nil -> invalid_scope("project not found", %{project_id: project_id})
      project -> validate_project_slug(%{scope | project_id: project.id}, project)
    end
  end

  defp validate_project(%Scope{project_slug: project_slug} = scope) do
    case Repo.get_by(Project, slug: project_slug) do
      nil -> invalid_scope("project not found", %{project_slug: project_slug})
      project -> {:ok, %{scope | project_id: project.id}}
    end
  end

  defp validate_project_slug(%Scope{project_slug: nil} = scope, _project), do: {:ok, scope}

  defp validate_project_slug(%Scope{project_slug: project_slug} = scope, %Project{
         slug: project_slug
       }) do
    {:ok, scope}
  end

  defp validate_project_slug(%Scope{} = scope, %Project{} = project) do
    invalid_scope("project slug does not match project_id", %{
      project_id: scope.project_id,
      project_slug: scope.project_slug,
      actual_slug: project.slug
    })
  end

  defp validate_publication(%Scope{publication_id: nil} = scope), do: {:ok, scope}

  defp validate_publication(
         %Scope{publication_id: publication_id, project_id: project_id} = scope
       ) do
    case Repo.get(Publication, publication_id) do
      nil ->
        invalid_scope("publication not found", %{publication_id: publication_id})

      %Publication{project_id: ^project_id} ->
        {:ok, scope}

      %Publication{project_id: actual_project_id} ->
        invalid_scope("publication does not belong to project", %{
          publication_id: publication_id,
          project_id: project_id,
          actual_project_id: actual_project_id
        })
    end
  end

  defp validate_section(%Scope{section_id: nil, section_slug: nil} = scope), do: {:ok, scope}

  defp validate_section(%Scope{section_id: section_id} = scope) when not is_nil(section_id) do
    case Repo.get(Section, section_id) do
      nil -> invalid_scope("section not found", %{section_id: section_id})
      section -> validate_section_scope(%{scope | section_id: section.id}, section)
    end
  end

  defp validate_section(%Scope{section_slug: section_slug} = scope) do
    case Repo.get_by(Section, slug: section_slug) do
      nil -> invalid_scope("section not found", %{section_slug: section_slug})
      section -> validate_section_scope(%{scope | section_id: section.id}, section)
    end
  end

  defp validate_section_scope(scope, section) do
    cond do
      not is_nil(scope.section_slug) and section.slug != scope.section_slug ->
        invalid_scope("section slug does not match section_id", %{
          section_id: scope.section_id,
          section_slug: scope.section_slug,
          actual_slug: section.slug
        })

      section.institution_id != scope.institution_id ->
        invalid_scope("section does not belong to institution", %{
          section_id: section.id,
          institution_id: scope.institution_id,
          actual_institution_id: section.institution_id
        })

      section.base_project_id != scope.project_id ->
        invalid_scope("section does not belong to project", %{
          section_id: section.id,
          project_id: scope.project_id,
          actual_project_id: section.base_project_id
        })

      true ->
        {:ok, scope}
    end
  end

  defp validate_user(%Scope{user_id: nil} = scope), do: {:ok, scope}

  defp validate_user(%Scope{user_id: user_id} = scope) do
    case Repo.get(User, user_id) do
      nil -> invalid_scope("user not found", %{user_id: user_id})
      _user -> {:ok, scope}
    end
  end

  defp validate_enrollment(%Scope{enrollment_id: nil} = scope), do: {:ok, scope}

  defp validate_enrollment(%Scope{enrollment_id: enrollment_id} = scope) do
    case Repo.get(Enrollment, enrollment_id) do
      nil ->
        invalid_scope("enrollment not found", %{enrollment_id: enrollment_id})

      enrollment ->
        validate_enrollment_scope(scope, enrollment)
    end
  end

  defp validate_enrollment_scope(scope, enrollment) do
    cond do
      not is_nil(scope.section_id) and enrollment.section_id != scope.section_id ->
        invalid_scope("enrollment does not belong to section", %{
          enrollment_id: enrollment.id,
          section_id: scope.section_id,
          actual_section_id: enrollment.section_id
        })

      not is_nil(scope.user_id) and enrollment.user_id != scope.user_id ->
        invalid_scope("enrollment does not belong to user", %{
          enrollment_id: enrollment.id,
          user_id: scope.user_id,
          actual_user_id: enrollment.user_id
        })

      true ->
        {:ok, %{scope | section_id: enrollment.section_id, user_id: enrollment.user_id}}
    end
  end

  defp ensure_definition_in_scope(schema, scope) do
    cond do
      schema.institution_id != scope.institution_id ->
        invalid_scope("experiment does not belong to institution")

      schema.project_id != scope.project_id ->
        invalid_scope("experiment does not belong to project")

      not is_nil(scope.publication_id) and schema.publication_id != scope.publication_id ->
        invalid_scope("experiment does not belong to publication")

      not is_nil(scope.section_id) and schema.section_id != scope.section_id ->
        invalid_scope("experiment does not belong to section")

      true ->
        :ok
    end
  end

  defp to_definition(%ExperimentDefinitionSchema{} = schema) do
    %ExperimentDefinition{
      id: schema.id,
      uuid: schema.uuid,
      institution_id: schema.institution_id,
      project_id: schema.project_id,
      publication_id: schema.publication_id,
      section_id: schema.section_id,
      slug: schema.slug,
      name: schema.name,
      description: schema.description,
      state: schema.state,
      assignment_unit: schema.assignment_unit,
      algorithm: schema.algorithm,
      policy_config: schema.policy_config,
      started_at: schema.started_at,
      ended_at: schema.ended_at
    }
  end

  defp to_assignment_decision(nil, _condition, _reused?),
    do: %AssignmentDecision{status: :no_experiment}

  defp to_assignment_decision(%Assignment{} = assignment, %Condition{} = condition, reused?) do
    %AssignmentDecision{
      status: :assigned,
      experiment_id: assignment.experiment_id,
      decision_point_id: assignment.decision_point_id,
      condition_id: assignment.condition_id,
      condition_code: condition.condition_code,
      assignment_id: assignment.id,
      reused?: reused?
    }
  end

  defp to_exposure_receipt(%Exposure{} = exposure, reused?) do
    %ExposureReceipt{
      id: exposure.id,
      assignment_id: exposure.assignment_id,
      idempotency_key: exposure.idempotency_key,
      recorded_at: exposure.exposed_at,
      reused?: reused?
    }
  end

  defp to_outcome_receipt(%Outcome{} = outcome, reused?) do
    %OutcomeReceipt{
      id: outcome.id,
      assignment_id: outcome.assignment_id,
      idempotency_key: outcome.idempotency_key,
      recorded_at: outcome.observed_at,
      reused?: reused?
    }
  end

  defp to_reward_receipt(%Reward{} = reward, reused?) do
    %RewardReceipt{
      id: reward.id,
      assignment_id: reward.assignment_id,
      outcome_id: reward.outcome_id,
      idempotency_key: reward.idempotency_key,
      recorded_at: reward.inserted_at,
      reused?: reused?
    }
  end

  defp assignment_metadata(%Oli.Experiments.AssignConditionRequest{} = request) do
    scope = request.scope || %Scope{}

    %{
      institution_id: scope.institution_id,
      project_id: scope.project_id,
      publication_id: scope.publication_id,
      section_id: scope.section_id,
      user_id: scope.user_id,
      enrollment_id: scope.enrollment_id,
      alternatives_resource_id: request.alternatives_resource_id,
      alternatives_revision_id: request.alternatives_revision_id,
      decision_point_key: request.decision_point_key
    }
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp normalize_result({:ok, schema}), do: {:ok, schema}

  defp normalize_result({:error, %Ecto.Changeset{} = changeset}) do
    {:error,
     %ExperimentError{
       type: error_type(changeset),
       message: "experiment could not be persisted",
       details: %{errors: changeset_errors(changeset)}
     }}
  end

  defp error_type(%Ecto.Changeset{errors: errors}) do
    cond do
      Keyword.has_key?(errors, :state) ->
        :invalid_state

      Enum.any?(errors, fn {_field, {_message, opts}} -> opts[:constraint] == :unique end) ->
        :conflict

      true ->
        :persistence_error
    end
  end

  defp conflict?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {_field, {_message, opts}} -> opts[:constraint] == :unique end)
  end

  defp changeset_errors(changeset) do
    traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp invalid_request(message) do
    {:error, %ExperimentError{type: :persistence_error, message: message}}
  end

  defp invalid_scope(message, details \\ %{}) do
    {:error, %ExperimentError{type: :invalid_scope, message: message, details: details}}
  end

  defp not_found(message, details) do
    {:error, %ExperimentError{type: :not_found, message: message, details: details}}
  end

  defp invalid_condition(message, details \\ %{}) do
    {:error, %ExperimentError{type: :invalid_condition, message: message, details: details}}
  end
end
