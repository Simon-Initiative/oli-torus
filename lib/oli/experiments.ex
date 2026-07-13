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
    DecisionPointCandidate,
    ExperimentDefinition,
    ExperimentAuthoringView,
    ExperimentError,
    ExposureReceipt,
    OutcomeReceipt,
    RewardEligibleAssignment,
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
  alias Oli.Authoring.Course.ProjectResource
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources.{ResourceType, Revision}

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

  @thompson_reward_source "activity_attempt:full_credit"
  @thompson_default_guardrails %{
    "manual_pause_enabled" => true,
    "warm_up_assignments" => 0,
    "max_condition_share" => 1.0,
    "fixed_control_allocation" => nil,
    "imbalance_threshold" => 1.0
  }

  @doc """
  Creates a native experiment definition.
  """
  def create_experiment(%Oli.Experiments.CreateExperimentRequest{} = request) do
    with {:ok, scope} <- validate_scope(request.scope),
         :ok <- maybe_require_authoring_scope(scope, graph_request?(request)),
         :ok <- validate_authoring_algorithm(request.algorithm, graph_request?(request)),
         :ok <- validate_policy_config(request.algorithm, request.policy_config || %{}),
         :ok <- validate_graph_request(request, scope),
         attrs <- create_attrs(request, scope),
         {:ok, schema} <- insert_definition_graph(attrs, request) do
      emit_authoring_telemetry(:create, schema, %{algorithm: schema.algorithm})
      {:ok, to_definition(schema)}
    else
      {:error, %ExperimentError{} = error} = result ->
        emit_authoring_validation_failed(:create, request.scope, error)
        result
    end
  end

  def create_experiment(_request), do: invalid_request("expected CreateExperimentRequest")

  @doc """
  Updates mutable fields on a draft experiment definition.
  """
  def update_experiment(experiment_id, %Oli.Experiments.UpdateExperimentRequest{} = request) do
    with {:ok, schema} <- get_scoped_definition(experiment_id, request.scope),
         :ok <- validate_update_state(schema, request),
         :ok <-
           validate_authoring_algorithm(
             request.algorithm || schema.algorithm,
             graph_request?(request)
           ),
         :ok <-
           validate_policy_config(
             request.algorithm || schema.algorithm,
             request.policy_config || %{}
           ),
         :ok <- validate_assignment_safe_update(schema, request),
         :ok <- validate_graph_request(request, request.scope),
         {:ok, updated} <- update_definition_graph(schema, request) do
      emit_authoring_telemetry(:update, updated, %{algorithm: updated.algorithm})
      {:ok, to_definition(updated)}
    else
      {:error, %ExperimentError{} = error} = result ->
        emit_authoring_validation_failed(:update, request.scope, error, %{
          experiment_id: experiment_id
        })

        result
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
  Lists project-scoped experiment definitions for authoring.
  """
  def list_project_experiments(%Scope{} = scope) do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_scope(scope) do
      experiments =
        scope
        |> scoped_project_experiments_query()
        |> order_by([experiment], asc: experiment.inserted_at, asc: experiment.id)
        |> Repo.all()
        |> Enum.map(&to_definition/1)

      {:ok, experiments}
    end
  end

  def list_project_experiments(_scope), do: invalid_request("expected Scope")

  @doc """
  Returns a public experiment graph view for authoring.
  """
  def get_experiment_authoring_view(experiment_id, %Scope{} = scope) do
    with {:ok, schema} <- get_scoped_definition(experiment_id, scope) do
      decision_points =
        from(decision_point in DecisionPoint,
          where: decision_point.experiment_id == ^schema.id,
          order_by: [asc: decision_point.position, asc: decision_point.id]
        )
        |> Repo.all()

      conditions =
        from(condition in Condition,
          where: condition.experiment_id == ^schema.id,
          order_by: [asc: condition.position, asc: condition.id]
        )
        |> Repo.all()
        |> Enum.map(&public_condition/1)

      {:ok,
       %ExperimentAuthoringView{
         definition: to_definition(schema),
         decision_points: Enum.map(decision_points, &public_decision_point/1),
         conditions: conditions,
         assignment_counts: assignment_counts_by_condition(schema.id)
       }}
    end
  end

  def get_experiment_authoring_view(_experiment_id, _scope), do: invalid_request("expected Scope")

  @doc """
  Lists alternatives revisions in the project that can be used as one-decision-point candidates.
  """
  def list_available_decision_points(%Scope{} = scope) do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_scope(scope) do
      candidates =
        from(revision in Revision,
          join: project_resource in ProjectResource,
          on: project_resource.resource_id == revision.resource_id,
          where:
            project_resource.project_id == ^scope.project_id and
              revision.resource_type_id == ^ResourceType.id_for_alternatives() and
              revision.deleted == false,
          order_by: [asc: revision.title, desc: revision.id],
          select: revision
        )
        |> Repo.all()
        |> Enum.filter(&experiment_decision_point_revision?/1)
        |> Enum.uniq_by(& &1.resource_id)
        |> Enum.map(&to_decision_point_candidate/1)

      {:ok, candidates}
    end
  end

  def list_available_decision_points(_scope), do: invalid_request("expected Scope")

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
  Returns exposed native assignments whose selected alternatives branch contains
  the evaluated activity resource.
  """
  def reward_eligible_assignments(%Scope{} = scope, activity_resource_id, page_content) do
    with {:ok, scope} <- validate_scope(scope) do
      matching_branches = matching_alternatives_branches(page_content, activity_resource_id)

      case matching_branches do
        [] ->
          {:ok, []}

        _ ->
          assignments =
            scope
            |> reward_eligible_assignment_query()
            |> Repo.all()
            |> Enum.filter(&assignment_matches_branch?(&1, matching_branches))
            |> Enum.map(&to_reward_eligible_assignment/1)

          {:ok, assignments}
      end
    end
  end

  def reward_eligible_assignments(_scope, _activity_resource_id, _page_content),
    do: invalid_request("expected Scope")

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
        |> select([policy_state, experiment], %{
          experiment_id: policy_state.experiment_id,
          decision_point_id: policy_state.decision_point_id,
          algorithm: policy_state.algorithm,
          algorithm_version: policy_state.algorithm_version,
          policy_config: experiment.policy_config,
          prior_config: policy_state.prior_config,
          state: policy_state.state,
          reward_success_count: policy_state.reward_success_count,
          reward_failure_count: policy_state.reward_failure_count,
          assignment_count: policy_state.assignment_count,
          last_updated_from_reward_id: policy_state.last_updated_from_reward_id,
          updated_at: policy_state.updated_at
        })
        |> Repo.all()
        |> Enum.map(&add_policy_inspection_metadata/1)

      {:ok, snapshots}
    end
  end

  def policy_state_snapshot(_query), do: invalid_request("expected AnalyticsQuery")

  defp transition(experiment_id, %Oli.Experiments.LifecycleRequest{} = request, action) do
    target_state = Map.fetch!(@transition_targets, action)

    with {:ok, schema} <- get_scoped_definition(experiment_id, request.scope),
         :ok <- validate_transition(schema.state, target_state),
         :ok <- validate_transition_prerequisites(schema, target_state),
         attrs <- transition_attrs(schema, target_state, request.transitioned_at),
         {:ok, updated} <- update_definition(schema, attrs) do
      emit_lifecycle_telemetry(:transition, updated, %{
        previous_state: schema.state,
        target_state: target_state
      })

      {:ok, to_definition(updated)}
    else
      {:error, %ExperimentError{} = error} = result ->
        emit_lifecycle_failed(request.scope, error, %{
          experiment_id: experiment_id,
          target_state: target_state
        })

        result
    end
  end

  defp transition(_experiment_id, _request, _action),
    do: invalid_request("expected LifecycleRequest")

  defp scoped_experiment_query(scope, experiment_id) do
    query =
      from(experiment in ExperimentDefinitionSchema,
        where: experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_experiment_id(experiment_id)
    |> maybe_filter_experiment_section(scope.section_id)
  end

  defp scoped_project_experiments_query(scope) do
    from(experiment in ExperimentDefinitionSchema,
      where:
        experiment.project_id == ^scope.project_id and
          is_nil(experiment.section_id)
    )
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
        where: experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_joined_experiment_id(experiment_id)
    |> maybe_filter_assignment_section(scope.section_id)
    |> maybe_filter_assignment_institution(scope)
  end

  defp scoped_exposure_query(scope, experiment_id) do
    query =
      from(exposure in Exposure,
        join: experiment in ExperimentDefinitionSchema,
        on: experiment.id == exposure.experiment_id,
        where: experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_joined_experiment_id(experiment_id)
    |> maybe_filter_exposure_publication(scope.publication_id)
    |> maybe_filter_exposure_section(scope.section_id)
    |> maybe_filter_exposure_institution(scope)
  end

  defp scoped_reward_query(scope, experiment_id) do
    query =
      from(reward in Reward,
        join: experiment in ExperimentDefinitionSchema,
        on: experiment.id == reward.experiment_id,
        where: experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_joined_experiment_id(experiment_id)
    |> maybe_filter_reward_section(scope.section_id)
    |> maybe_filter_reward_institution(scope)
  end

  defp reward_eligible_assignment_query(scope) do
    from(assignment in Assignment,
      join: experiment in ExperimentDefinitionSchema,
      on: experiment.id == assignment.experiment_id,
      join: decision_point in DecisionPoint,
      on: decision_point.id == assignment.decision_point_id,
      join: condition in Condition,
      on: condition.id == assignment.condition_id,
      join: exposure in Exposure,
      on: exposure.assignment_id == assignment.id,
      where:
        experiment.project_id == ^scope.project_id and
          experiment.state == :active and
          assignment.section_id == ^scope.section_id and
          assignment.enrollment_id == ^scope.enrollment_id and
          assignment.user_id == ^scope.user_id,
      select: %{
        assignment: assignment,
        decision_point: decision_point,
        condition: condition
      },
      distinct: assignment.id
    )
  end

  defp maybe_filter_experiment_id(query, nil), do: query

  defp maybe_filter_experiment_id(query, experiment_id) do
    where(query, [experiment], experiment.id == ^experiment_id)
  end

  defp maybe_filter_joined_experiment_id(query, nil), do: query

  defp maybe_filter_joined_experiment_id(query, experiment_id) do
    where(query, [_record, experiment], experiment.id == ^experiment_id)
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

  defp maybe_filter_assignment_section(query, nil), do: query

  defp maybe_filter_assignment_section(query, section_id) do
    where(query, [assignment, _experiment], assignment.section_id == ^section_id)
  end

  defp maybe_filter_assignment_institution(query, %{institution_id: nil}), do: query

  defp maybe_filter_assignment_institution(query, %{section_id: section_id})
       when not is_nil(section_id), do: query

  defp maybe_filter_assignment_institution(query, %{institution_id: institution_id}) do
    where(
      query,
      [assignment, _experiment],
      fragment(
        "EXISTS (SELECT 1 FROM sections s WHERE s.id = ? AND s.institution_id = ?)",
        assignment.section_id,
        ^institution_id
      )
    )
  end

  defp maybe_filter_exposure_publication(query, nil), do: query

  defp maybe_filter_exposure_publication(query, publication_id) do
    where(query, [exposure, _experiment], exposure.publication_id == ^publication_id)
  end

  defp maybe_filter_exposure_section(query, nil), do: query

  defp maybe_filter_exposure_section(query, section_id) do
    where(query, [exposure, _experiment], exposure.section_id == ^section_id)
  end

  defp maybe_filter_exposure_institution(query, %{institution_id: nil}), do: query

  defp maybe_filter_exposure_institution(query, %{section_id: section_id})
       when not is_nil(section_id), do: query

  defp maybe_filter_exposure_institution(query, %{institution_id: institution_id}) do
    where(
      query,
      [exposure, _experiment],
      fragment(
        "EXISTS (SELECT 1 FROM sections s WHERE s.id = ? AND s.institution_id = ?)",
        exposure.section_id,
        ^institution_id
      )
    )
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

  defp maybe_filter_reward_institution(query, %{institution_id: nil}), do: query

  defp maybe_filter_reward_institution(query, %{section_id: section_id})
       when not is_nil(section_id), do: query

  defp maybe_filter_reward_institution(query, %{institution_id: institution_id}) do
    where(
      query,
      [reward, _experiment],
      fragment(
        "EXISTS (SELECT 1 FROM experiment_assignments ea JOIN sections s ON s.id = ea.section_id WHERE ea.id = ? AND s.institution_id = ?)",
        reward.assignment_id,
        ^institution_id
      )
    )
  end

  defp matching_alternatives_branches(%{"model" => _model} = page_content, activity_resource_id) do
    page_content
    |> Oli.Resources.PageContent.flat_filter(&(Map.get(&1, "type") == "alternatives"))
    |> Enum.flat_map(fn alternatives ->
      alternatives
      |> Map.get("children", [])
      |> Enum.filter(&branch_contains_activity?(&1, activity_resource_id))
      |> Enum.map(fn branch ->
        %{
          alternatives_resource_id: Map.get(alternatives, "alternatives_id"),
          option_id: Map.get(branch, "value")
        }
      end)
    end)
    |> Enum.reject(fn branch ->
      is_nil(branch.alternatives_resource_id) or is_nil(branch.option_id)
    end)
  end

  defp matching_alternatives_branches(_page_content, _activity_resource_id), do: []

  defp branch_contains_activity?(%{"children" => children}, activity_resource_id) do
    %{"model" => children}
    |> Oli.Resources.PageContent.flat_filter(fn
      %{"type" => "activity-reference", "activity_id" => ^activity_resource_id} -> true
      %{"type" => "activity-reference", "resourceId" => ^activity_resource_id} -> true
      _ -> false
    end)
    |> Enum.any?()
  end

  defp branch_contains_activity?(_branch, _activity_resource_id), do: false

  defp assignment_matches_branch?(
         %{
           decision_point: %DecisionPoint{} = decision_point,
           condition: %Condition{} = condition
         },
         matching_branches
       ) do
    option_ids = [condition.option_id, condition.condition_code] |> Enum.reject(&is_nil/1)

    Enum.any?(matching_branches, fn branch ->
      branch.alternatives_resource_id == decision_point.alternatives_resource_id and
        branch.option_id in option_ids
    end)
  end

  defp to_reward_eligible_assignment(%{
         assignment: %Assignment{} = assignment,
         decision_point: %DecisionPoint{} = decision_point,
         condition: %Condition{} = condition
       }) do
    %RewardEligibleAssignment{
      assignment_id: assignment.id,
      experiment_id: assignment.experiment_id,
      decision_point_id: assignment.decision_point_id,
      condition_id: assignment.condition_id,
      condition_code: condition.condition_code,
      alternatives_resource_id: decision_point.alternatives_resource_id,
      alternatives_revision_id: decision_point.alternatives_revision_id
    }
  end

  defp scoped_policy_state_query(scope, experiment_id) do
    query =
      from(policy_state in PolicyState,
        join: experiment in ExperimentDefinitionSchema,
        on: experiment.id == policy_state.experiment_id,
        where: experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_joined_experiment_id(experiment_id)
    |> maybe_filter_joined_experiment_section(scope.section_id)
  end

  defp add_policy_inspection_metadata(%{algorithm: :thompson_sampling} = snapshot) do
    guardrails =
      snapshot
      |> Map.get(:policy_config, %{})
      |> thompson_guardrails()

    snapshot
    |> Map.delete(:policy_config)
    |> Map.put(:guardrail_state, %{
      "manual_pause_enabled" => guardrails["manual_pause_enabled"],
      "warm_up_assignments" => guardrails["warm_up_assignments"],
      "max_condition_share" => guardrails["max_condition_share"],
      "fixed_control_allocation" => guardrails["fixed_control_allocation"],
      "imbalance_threshold" => guardrails["imbalance_threshold"],
      "assignment_count" => snapshot.assignment_count,
      "reward_count" => snapshot.reward_success_count + snapshot.reward_failure_count
    })
  end

  defp add_policy_inspection_metadata(snapshot), do: Map.delete(snapshot, :policy_config)

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
            experiment.project_id == ^scope.project_id and
            decision_point.alternatives_resource_id == ^request.alternatives_resource_id and
            decision_point.decision_point_key == ^request.decision_point_key,
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
        {:ok,
         %{
           experiment: experiment,
           decision_point: decision_point,
           available_condition_codes: request.available_condition_codes
         }}
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

        {policy_module, policy_conditions, guardrail_action} =
          assignment_policy_for(
            experiment,
            decision_point,
            conditions,
            policy_state
          )

        policy_context = %{
          conditions: conditions,
          assignment_key: assignment_key(experiment.id, decision_point.id, scope.enrollment_id)
        }

        policy_module
        |> apply(:assign, [
          experiment.policy_config,
          policy_state && policy_state.state,
          %{policy_context | conditions: policy_conditions}
        ])
        |> case do
          {:ok, policy_assignment} ->
            condition = Enum.find(conditions, &(&1.id == policy_assignment.condition_id))

            emit_assignment_guardrail_telemetry(
              experiment,
              decision_point,
              condition,
              policy_assignment,
              guardrail_action,
              assignment_counts_for_guardrails(experiment)
            )

            {:ok,
             %{
               condition: condition,
               policy_assignment: policy_assignment,
               guardrail_action: guardrail_action
             }}

          {:error, reason} ->
            invalid_condition("policy could not assign a condition", %{reason: reason})
        end
    end
  end

  defp assignment_policy_for(
         %ExperimentDefinitionSchema{algorithm: :thompson_sampling} = experiment,
         _decision_point,
         conditions,
         policy_state
       ) do
    assignment_counts = assignment_counts_by_condition(experiment.id)
    guardrails = thompson_guardrails(experiment.policy_config)
    assignment_count = (policy_state && policy_state.assignment_count) || 0

    cond do
      assignment_count < guardrails["warm_up_assignments"] ->
        {WeightedRandom, conditions, :warm_up}

      fixed_control_condition =
          fixed_control_condition(
            conditions,
            assignment_counts,
            guardrails["fixed_control_allocation"]
          ) ->
        {WeightedRandom, [fixed_control_condition], :fixed_control}

      capped_conditions =
          cap_eligible_conditions(
            conditions,
            assignment_counts,
            guardrails["max_condition_share"]
          ) ->
        {policy_module(experiment.algorithm), capped_conditions,
         cap_guardrail_action(capped_conditions, conditions)}
    end
  end

  defp assignment_policy_for(
         experiment,
         _decision_point,
         conditions,
         _policy_state
       ) do
    {policy_module(experiment.algorithm), conditions, :none}
  end

  defp assignment_counts_for_guardrails(
         %ExperimentDefinitionSchema{algorithm: :thompson_sampling} = experiment
       ),
       do: assignment_counts_by_condition(experiment.id)

  defp assignment_counts_for_guardrails(_experiment), do: %{}

  defp thompson_guardrails(policy_config) do
    policy_config
    |> Map.get("guardrails", %{})
    |> Map.merge(@thompson_default_guardrails, fn _key, configured, _default -> configured end)
  end

  defp fixed_control_condition(_conditions, _assignment_counts, nil), do: nil

  defp fixed_control_condition(conditions, assignment_counts, fixed_control_allocation) do
    total =
      Enum.reduce(assignment_counts, 0, fn {_condition_id, count}, total -> total + count end)

    control = List.first(conditions)
    control_count = Map.get(assignment_counts, control.id, 0)

    cond do
      total == 0 -> control
      control_count / total < fixed_control_allocation -> control
      true -> nil
    end
  end

  defp cap_eligible_conditions(conditions, assignment_counts, max_condition_share) do
    total =
      Enum.reduce(assignment_counts, 0, fn {_condition_id, count}, total -> total + count end)

    eligible =
      Enum.filter(conditions, fn condition ->
        total == 0 or Map.get(assignment_counts, condition.id, 0) / total < max_condition_share
      end)

    case eligible do
      [] -> conditions
      _ -> eligible
    end
  end

  defp cap_guardrail_action(capped_conditions, conditions) do
    if length(capped_conditions) == length(conditions), do: :none, else: :traffic_cap
  end

  defp emit_assignment_guardrail_telemetry(
         experiment,
         decision_point,
         condition,
         policy_assignment,
         guardrail_action,
         assignment_counts
       ) do
    :telemetry.execute([:oli, :experiments, :assignment, :guardrail], %{count: 1}, %{
      experiment_id: experiment.id,
      decision_point_id: decision_point.id,
      algorithm: experiment.algorithm,
      algorithm_version: policy_assignment.policy_version,
      selected_condition_id: condition && condition.id,
      selected_condition_code: condition && condition.condition_code,
      guardrail_action: guardrail_action,
      imbalance_flag?: imbalance_flag?(experiment.policy_config, condition, assignment_counts)
    })
  end

  defp imbalance_flag?(policy_config, condition, assignment_counts) do
    guardrails = thompson_guardrails(policy_config)

    total =
      Enum.reduce(assignment_counts, 0, fn {_condition_id, count}, total -> total + count end)

    (total > 0 and condition) &&
      Map.get(assignment_counts, condition.id, 0) / total > guardrails["imbalance_threshold"]
  end

  defp assign_or_reuse(%{status: :no_experiment}, _scope),
    do: {:ok, %AssignmentDecision{status: :no_experiment}}

  defp assign_or_reuse(match, scope) do
    case find_assignment(match.experiment.id, match.decision_point.id, scope.enrollment_id) do
      %Assignment{} = assignment ->
        condition = Repo.get!(Condition, assignment.condition_id)

        :telemetry.execute([:oli, :experiments, :assignment, :reuse], %{count: 1}, %{
          experiment_id: match.experiment.id,
          decision_point_id: match.decision_point.id,
          algorithm: match.experiment.algorithm,
          algorithm_version: assignment.policy_version,
          selected_condition_id: assignment.condition_id,
          selected_condition_code: condition.condition_code,
          guardrail_action: :sticky_reuse
        })

        {:ok, to_assignment_decision(assignment, condition, true)}

      nil ->
        with {:ok, selection} <-
               select_condition(
                 match.experiment,
                 match.decision_point,
                 match.available_condition_codes,
                 scope
               ) do
          create_assignment(Map.merge(match, selection), scope)
        end
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
      section_id: scope.section_id,
      enrollment_id: scope.enrollment_id,
      user_id: scope.user_id,
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

    from(policy_state in PolicyState, where: policy_state.id == ^policy_state.id)
    |> Repo.update_all(inc: [assignment_count: 1])
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
           publication_id: request.scope.publication_id,
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
         {:ok, reward} <- insert_reward_and_update_policy(assignment, attrs) do
      :telemetry.execute([:oli, :experiments, :reward, :recorded], %{count: 1}, %{
        experiment_id: assignment.experiment_id,
        decision_point_id: assignment.decision_point_id,
        condition_id: assignment.condition_id,
        reward_class: reward_class(reward.reward_value)
      })

      {:ok, to_reward_receipt(reward, false)}
    end
  end

  defp insert_reward_and_update_policy(assignment, attrs) do
    Repo.transaction(fn ->
      reward =
        %Reward{}
        |> Reward.changeset(attrs)
        |> Repo.insert!()

      case record_policy_reward(assignment, reward) do
        :ok -> reward
        {:error, error} -> Repo.rollback(error)
      end
    end)
    |> normalize_transaction_result()
  end

  defp insert_runtime_record(changeset) do
    changeset
    |> Repo.insert()
    |> normalize_result()
  end

  defp insert_definition_graph(attrs, request) do
    case graph_request?(request) do
      false ->
        insert_definition(attrs)

      true ->
        Repo.transaction(fn ->
          definition =
            %ExperimentDefinitionSchema{}
            |> ExperimentDefinitionSchema.changeset(attrs)
            |> Repo.insert!()

          decision_point =
            %DecisionPoint{}
            |> DecisionPoint.changeset(
              decision_point_attrs(request.decision_point, definition.id)
            )
            |> Repo.insert!()

          request.conditions
          |> Enum.with_index()
          |> Enum.each(fn {condition, index} ->
            %Condition{}
            |> Condition.changeset(
              condition_attrs(condition, definition.id, decision_point.id, index)
            )
            |> Repo.insert!()
          end)

          get_or_create_policy_state(definition, decision_point.id)
          definition
        end)
        |> normalize_transaction_result()
    end
  end

  defp update_definition_graph(schema, request) do
    case graph_request?(request) do
      false ->
        update_definition(schema, update_attrs(request, schema.algorithm))

      true ->
        Repo.transaction(fn ->
          updated =
            schema
            |> ExperimentDefinitionSchema.changeset(update_attrs(request, schema.algorithm))
            |> Repo.update!()

          replace_definition_graph!(updated, request)
          updated
        end)
        |> normalize_transaction_result()
    end
  end

  defp replace_definition_graph!(schema, request) do
    from(condition in Condition, where: condition.experiment_id == ^schema.id)
    |> Repo.delete_all()

    from(policy_state in PolicyState, where: policy_state.experiment_id == ^schema.id)
    |> Repo.delete_all()

    from(decision_point in DecisionPoint, where: decision_point.experiment_id == ^schema.id)
    |> Repo.delete_all()

    decision_point =
      %DecisionPoint{}
      |> DecisionPoint.changeset(decision_point_attrs(request.decision_point, schema.id))
      |> Repo.insert!()

    request.conditions
    |> Enum.with_index()
    |> Enum.each(fn {condition, index} ->
      %Condition{}
      |> Condition.changeset(condition_attrs(condition, schema.id, decision_point.id, index))
      |> Repo.insert!()
    end)

    get_or_create_policy_state(schema, decision_point.id)
  end

  defp decision_point_attrs(decision_point, experiment_id) do
    decision_point
    |> atomize_keys()
    |> Map.take([
      :alternatives_resource_id,
      :alternatives_revision_id,
      :decision_point_key,
      :title,
      :position
    ])
    |> Map.put(:experiment_id, experiment_id)
    |> Map.update(:position, 0, &(&1 || 0))
  end

  defp condition_attrs(condition, experiment_id, decision_point_id, fallback_position) do
    condition
    |> atomize_keys()
    |> Map.take([:condition_code, :option_id, :label, :weight, :active, :position])
    |> Map.put(:experiment_id, experiment_id)
    |> Map.put(:decision_point_id, decision_point_id)
    |> Map.update(:active, true, &(&1 != false))
    |> Map.update(:position, fallback_position, &(&1 || fallback_position))
  end

  defp record_policy_reward(assignment, reward) do
    experiment = Repo.get!(ExperimentDefinitionSchema, assignment.experiment_id)

    case experiment.algorithm do
      :weighted_random -> :ok
      _algorithm -> record_mutating_policy_reward(experiment, assignment, reward)
    end
  end

  defp record_mutating_policy_reward(experiment, assignment, reward) do
    condition = Repo.get!(Condition, assignment.condition_id)

    policy_state =
      experiment
      |> get_or_create_policy_state(assignment.decision_point_id)
      |> lock_policy_state()

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
        :telemetry.execute([:oli, :experiments, :policy, :update_failed], %{count: 1}, %{
          policy_state_id: policy_state.id,
          reward_id: reward.id,
          algorithm: experiment.algorithm,
          algorithm_version: policy_state.algorithm_version,
          reward_class: reward_class(reward.reward_value),
          error_type: reason
        })

        {:error,
         %ExperimentError{
           type: :persistence_error,
           message: "policy reward update failed",
           details: %{reason: reason}
         }}
    end
  end

  defp lock_policy_state(policy_state) do
    Repo.one!(
      from(policy_state in PolicyState,
        where: policy_state.id == ^policy_state.id,
        lock: "FOR UPDATE"
      )
    )
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
        {algorithm_version, state, prior_config} =
          initial_policy_state_attrs(experiment, decision_point_id)

        %PolicyState{}
        |> PolicyState.changeset(%{
          experiment_id: experiment.id,
          decision_point_id: decision_point_id,
          algorithm: experiment.algorithm,
          algorithm_version: algorithm_version,
          state: state,
          prior_config: prior_config,
          reward_success_count: 0,
          reward_failure_count: 0,
          assignment_count: 0
        })
        |> Repo.insert!()

      policy_state ->
        policy_state
    end
  end

  defp initial_policy_state_attrs(
         %ExperimentDefinitionSchema{algorithm: :thompson_sampling} = experiment,
         decision_point_id
       ) do
    conditions = active_conditions(experiment.id, decision_point_id)
    policy_config = normalize_policy_config!(:thompson_sampling, experiment.policy_config || %{})
    {:ok, state} = ThompsonSampling.initial_state(policy_config, conditions)

    {ThompsonSampling.version(), state, policy_config["priors"]}
  end

  defp initial_policy_state_attrs(
         %ExperimentDefinitionSchema{algorithm: algorithm},
         _decision_point_id
       ) do
    {Atom.to_string(algorithm), %{}, %{}}
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
          reward_id: reward.id,
          condition_id: condition.id,
          condition_code: condition.condition_code,
          algorithm: policy_state.algorithm,
          algorithm_version: policy_update.algorithm_version,
          reward_class: reward_class(reward.reward_value)
        })

        :ok

      {:error, reason} ->
        :telemetry.execute([:oli, :experiments, :policy, :update_failed], %{count: 1}, %{
          policy_state_id: policy_state.id,
          reward_id: reward.id,
          algorithm: policy_state.algorithm,
          algorithm_version: policy_state.algorithm_version,
          error_type: reason
        })

        {:error,
         %ExperimentError{
           type: :persistence_error,
           message: "policy update could not be persisted",
           details: %{reason: reason}
         }}
    end
  end

  defp reward_class(reward_value) when reward_value in [1, 1.0], do: :success
  defp reward_class(reward_value) when reward_value in [0, 0.0], do: :failure
  defp reward_class(_reward_value), do: :unknown

  defp policy_module(:weighted_random), do: WeightedRandom
  defp policy_module(:thompson_sampling), do: ThompsonSampling

  defp get_scoped_assignment(assignment_id, scope) do
    with {:ok, scope} <- validate_scope(scope) do
      query =
        from assignment in Assignment,
          join: experiment in ExperimentDefinitionSchema,
          on: experiment.id == assignment.experiment_id,
          where:
            assignment.id == ^assignment_id and
              experiment.project_id == ^scope.project_id and
              assignment.section_id == ^scope.section_id and
              assignment.enrollment_id == ^scope.enrollment_id and
              assignment.user_id == ^scope.user_id

      case Repo.one(query) do
        %Assignment{} = assignment ->
          {:ok, assignment}

        nil ->
          if Repo.exists?(from assignment in Assignment, where: assignment.id == ^assignment_id) do
            invalid_scope("assignment is outside scope", %{assignment_id: assignment_id})
          else
            not_found("assignment not found", %{assignment_id: assignment_id})
          end
      end
    else
      {:error, %ExperimentError{}} = error -> error
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
    policy_config = normalize_policy_config!(request.algorithm, request.policy_config || %{})

    %{
      project_id: scope.project_id,
      section_id: scope.section_id,
      slug: request.slug,
      name: request.name,
      description: request.description,
      algorithm: request.algorithm,
      assignment_unit: request.assignment_unit,
      policy_config: policy_config
    }
  end

  defp update_attrs(request, existing_algorithm) do
    attrs =
      request
      |> Map.from_struct()
      |> Map.take([:slug, :name, :description, :algorithm, :assignment_unit, :policy_config])
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
      |> Map.new()

    case {Map.get(attrs, :algorithm, existing_algorithm), Map.get(attrs, :policy_config)} do
      {nil, nil} ->
        attrs

      {nil, _policy_config} ->
        attrs

      {algorithm, policy_config} ->
        Map.put(attrs, :policy_config, normalize_policy_config!(algorithm, policy_config || %{}))
    end
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

  defp validate_activation_algorithm(%ExperimentDefinitionSchema{algorithm: :weighted_random}),
    do: :ok

  defp validate_activation_algorithm(%ExperimentDefinitionSchema{algorithm: :thompson_sampling}),
    do: :ok

  defp activation_decision_points(schema) do
    decision_points =
      from(decision_point in DecisionPoint,
        where: decision_point.experiment_id == ^schema.id,
        order_by: [asc: decision_point.position, asc: decision_point.id]
      )
      |> Repo.all()

    case decision_points do
      [_decision_point] -> {:ok, decision_points}
      [] -> {:ok, []}
      _ -> invalid_condition("MVP experiments support exactly one decision point")
    end
  end

  defp validate_transition_prerequisites(_schema, target_state) when target_state != :active,
    do: :ok

  defp validate_transition_prerequisites(schema, :active) do
    with :ok <- validate_activation_algorithm(schema),
         {:ok, decision_points} <- activation_decision_points(schema) do
      case decision_points do
        [] ->
          :ok

        [decision_point] ->
          conditions = active_conditions(schema.id, decision_point.id)

          with :ok <- validate_decision_point_strategy(decision_point),
               :ok <- validate_minimum_active_conditions(conditions),
               :ok <- validate_positive_active_weight(conditions),
               :ok <- validate_condition_option_mapping(decision_point, conditions),
               :ok <- validate_adaptive_activation(schema, conditions) do
            :ok
          end
      end
    end
  end

  defp active_conditions(experiment_id, decision_point_id) do
    from(condition in Condition,
      where:
        condition.experiment_id == ^experiment_id and
          condition.decision_point_id == ^decision_point_id and
          condition.active == true,
      order_by: [asc: condition.position, asc: condition.id]
    )
    |> Repo.all()
  end

  defp validate_minimum_active_conditions(conditions) do
    if length(conditions) >= 2 do
      :ok
    else
      invalid_condition("weighted random experiments require at least two active conditions")
    end
  end

  defp validate_positive_active_weight(conditions) do
    active_total =
      conditions
      |> Enum.filter(& &1.active)
      |> Enum.reduce(0.0, fn condition, total -> total + (condition.weight || 0.0) end)

    if active_total > 0.0 do
      :ok
    else
      invalid_condition("active condition weights must have a positive total")
    end
  end

  defp validate_condition_option_mapping(decision_point, conditions) do
    with {:ok, revision} <- get_alternatives_revision(decision_point.alternatives_revision_id),
         option_ids <- revision_option_ids(revision),
         missing <- Enum.reject(conditions, &((&1.option_id || &1.condition_code) in option_ids)) do
      case missing do
        [] ->
          :ok

        _ ->
          invalid_condition(
            "experiment conditions must match the selected alternatives options",
            %{
              missing_option_ids: Enum.map(missing, &(&1.option_id || &1.condition_code))
            }
          )
      end
    end
  end

  defp validate_update_state(schema, request) do
    cond do
      schema.state == :draft ->
        :ok

      schema.state == :paused and (safe_paused_update?(request) or graph_request?(request)) ->
        :ok

      schema.state in [:completed, :archived] ->
        {:error,
         %ExperimentError{
           type: :invalid_state,
           message: "completed or archived experiments are read-only",
           details: %{state: schema.state}
         }}

      true ->
        {:error,
         %ExperimentError{
           type: :invalid_state,
           message: "experiment state does not allow this edit",
           details: %{state: schema.state}
         }}
    end
  end

  defp metadata_only_update?(request) do
    request
    |> Map.from_struct()
    |> Map.drop([:__struct__, :scope, :name, :description])
    |> Enum.all?(fn {_key, value} -> is_nil(value) end)
  end

  defp safe_paused_update?(request) do
    metadata_only_update?(request) or
      (not is_nil(request.conditions) and
         is_nil(request.algorithm) and
         is_nil(request.assignment_unit) and
         is_nil(request.decision_point))
  end

  defp validate_assignment_safe_update(_schema, %Oli.Experiments.UpdateExperimentRequest{
         conditions: nil
       }),
       do: :ok

  defp validate_assignment_safe_update(schema, request) do
    case assignment_counts_by_condition(schema.id) do
      counts when counts == %{} ->
        :ok

      counts ->
        validate_assigned_conditions_unchanged(schema, request, counts)
    end
  end

  defp validate_assigned_conditions_unchanged(schema, request, counts) do
    existing =
      from(condition in Condition,
        where: condition.experiment_id == ^schema.id,
        select: {condition.condition_code, condition}
      )
      |> Repo.all()
      |> Map.new()

    incoming =
      request.conditions
      |> Enum.map(&atomize_keys/1)
      |> Map.new(&{Map.get(&1, :condition_code), &1})

    assigned_codes =
      existing
      |> Enum.filter(fn {_code, condition} -> Map.get(counts, condition.id, 0) > 0 end)
      |> Enum.map(fn {code, _condition} -> code end)

    changed =
      Enum.find(assigned_codes, fn code ->
        existing_condition = Map.fetch!(existing, code)
        incoming_condition = Map.get(incoming, code)

        is_nil(incoming_condition) or
          incoming_condition.option_id != existing_condition.option_id or
          incoming_condition.active == false
      end)

    case changed do
      nil ->
        :ok

      code ->
        invalid_condition(
          "learner assignments already exist for condition #{code}; condition identity, option mapping, and active state cannot be changed",
          %{condition_code: code}
        )
    end
  end

  defp validate_authoring_algorithm(_algorithm, _graph_request?), do: :ok

  defp validate_graph_request(request, scope) do
    case graph_request?(request) do
      false ->
        :ok

      true ->
        with :ok <- validate_one_decision_point(request.decision_point),
             :ok <- validate_authoring_conditions(request.conditions),
             :ok <- validate_alternatives_reference(request.decision_point, scope),
             :ok <- validate_condition_options(request.decision_point, request.conditions),
             :ok <- validate_policy_config(request.algorithm, request.policy_config || %{}) do
          :ok
        end
    end
  end

  defp validate_policy_config(:weighted_random, _policy_config), do: :ok

  defp validate_policy_config(:thompson_sampling, policy_config) when is_map(policy_config) do
    with {:ok, normalized} <- normalize_thompson_policy_config(policy_config),
         :ok <- validate_thompson_priors(normalized),
         :ok <- validate_thompson_guardrails(normalized) do
      :ok
    end
  end

  defp validate_policy_config(:thompson_sampling, _policy_config),
    do: invalid_condition("Thompson Sampling policy config must be a map")

  defp validate_policy_config(_algorithm, _policy_config), do: :ok

  defp validate_adaptive_activation(
         %ExperimentDefinitionSchema{algorithm: :weighted_random},
         _conditions
       ),
       do: :ok

  defp validate_adaptive_activation(
         %ExperimentDefinitionSchema{algorithm: :thompson_sampling, policy_config: policy_config},
         conditions
       ) do
    with :ok <- validate_policy_config(:thompson_sampling, policy_config || %{}),
         true <- Map.get(policy_config || %{}, "reward_source") == @thompson_reward_source,
         {:ok, _state} <- ThompsonSampling.initial_state(policy_config || %{}, conditions) do
      :ok
    else
      false ->
        invalid_condition("Thompson Sampling requires full-credit binary reward readiness")

      {:error, reason} ->
        invalid_condition("Thompson Sampling policy state could not be initialized", %{
          reason: reason
        })
    end
  end

  defp normalize_policy_config!(:thompson_sampling, policy_config) do
    {:ok, normalized} = normalize_thompson_policy_config(policy_config)
    normalized
  end

  defp normalize_policy_config!(_algorithm, policy_config), do: policy_config || %{}

  defp normalize_thompson_policy_config(policy_config) when is_map(policy_config) do
    defaults = ThompsonSampling.default_policy_config()

    with {:ok, priors} <- nested_map(policy_config, "priors"),
         {:ok, default_prior} <- nested_map(priors, "default"),
         {:ok, condition_priors} <- nested_map(priors, "conditions"),
         {:ok, guardrails} <- nested_map(policy_config, "guardrails"),
         {:ok, normalized_condition_priors} <- normalize_condition_priors(condition_priors) do
      normalized = %{
        "reward_source" => Map.get(policy_config, "reward_source", @thompson_reward_source),
        "priors" => %{
          "default" => %{
            "alpha" => Map.get(default_prior, "alpha", defaults["priors"]["default"]["alpha"]),
            "beta" => Map.get(default_prior, "beta", defaults["priors"]["default"]["beta"])
          },
          "conditions" => normalized_condition_priors
        },
        "guardrails" => %{
          "manual_pause_enabled" =>
            Map.get(
              guardrails,
              "manual_pause_enabled",
              @thompson_default_guardrails["manual_pause_enabled"]
            ),
          "warm_up_assignments" =>
            Map.get(
              guardrails,
              "warm_up_assignments",
              @thompson_default_guardrails["warm_up_assignments"]
            ),
          "max_condition_share" =>
            Map.get(
              guardrails,
              "max_condition_share",
              @thompson_default_guardrails["max_condition_share"]
            ),
          "fixed_control_allocation" =>
            Map.get(
              guardrails,
              "fixed_control_allocation",
              @thompson_default_guardrails["fixed_control_allocation"]
            ),
          "imbalance_threshold" =>
            Map.get(
              guardrails,
              "imbalance_threshold",
              @thompson_default_guardrails["imbalance_threshold"]
            )
        }
      }

      {:ok, normalized}
    end
  end

  defp normalize_thompson_policy_config(_policy_config),
    do: invalid_condition("Thompson Sampling policy config must be a map")

  defp nested_map(map, key) do
    case Map.get(map, key, %{}) do
      value when is_map(value) ->
        {:ok, value}

      _value ->
        invalid_condition("Thompson Sampling #{key} config must be a map")
    end
  end

  defp normalize_condition_priors(condition_priors) when is_map(condition_priors) do
    Enum.reduce_while(condition_priors, {:ok, %{}}, fn {condition_code, prior},
                                                       {:ok, normalized} ->
      case prior do
        prior when is_map(prior) ->
          condition_prior =
            %{
              "alpha" => Map.get(prior, "alpha"),
              "beta" => Map.get(prior, "beta")
            }
            |> Enum.reject(fn {_key, value} -> is_nil(value) end)
            |> Map.new()

          {:cont, {:ok, Map.put(normalized, condition_code, condition_prior)}}

        _value ->
          {:halt,
           invalid_condition("Thompson Sampling per-condition prior config must be a map", %{
             condition_code: condition_code
           })}
      end
    end)
  end

  defp normalize_condition_priors(_condition_priors),
    do: invalid_condition("Thompson Sampling condition priors config must be a map")

  defp validate_thompson_priors(policy_config) do
    priors = policy_config["priors"]

    [priors["default"] | Map.values(priors["conditions"])]
    |> Enum.reduce_while(:ok, fn prior, :ok ->
      with :ok <- validate_positive_prior(prior, "alpha"),
           :ok <- validate_positive_prior(prior, "beta") do
        {:cont, :ok}
      else
        {:error, %ExperimentError{}} = error -> {:halt, error}
      end
    end)
  end

  defp validate_positive_prior(prior, key) do
    case Map.get(prior, key) do
      value when is_number(value) and value >= 0.0001 and value <= 1_000.0 ->
        :ok

      _value ->
        invalid_condition("Thompson Sampling prior #{key} must be between 0.0001 and 1000")
    end
  end

  defp validate_thompson_guardrails(policy_config) do
    guardrails = policy_config["guardrails"]

    cond do
      not is_boolean(guardrails["manual_pause_enabled"]) ->
        invalid_condition("Thompson Sampling manual pause guardrail must be enabled or disabled")

      not non_negative_integer?(guardrails["warm_up_assignments"]) ->
        invalid_condition("Thompson Sampling warm-up assignments must be a non-negative integer")

      not share?(guardrails["max_condition_share"]) ->
        invalid_condition(
          "Thompson Sampling max condition share must be greater than 0 and at most 1"
        )

      not is_nil(guardrails["fixed_control_allocation"]) and
          not share?(guardrails["fixed_control_allocation"]) ->
        invalid_condition(
          "Thompson Sampling fixed control allocation must be greater than 0 and at most 1"
        )

      not share?(guardrails["imbalance_threshold"]) ->
        invalid_condition(
          "Thompson Sampling imbalance threshold must be greater than 0 and at most 1"
        )

      true ->
        :ok
    end
  end

  defp non_negative_integer?(value), do: is_integer(value) and value >= 0
  defp share?(value), do: is_number(value) and value > 0.0 and value <= 1.0

  defp validate_one_decision_point(nil), do: invalid_condition("decision point is required")
  defp validate_one_decision_point(_decision_point), do: :ok

  defp validate_authoring_conditions(conditions) when is_list(conditions) do
    normalized = Enum.map(conditions, &atomize_keys/1)
    codes = Enum.map(normalized, &Map.get(&1, :condition_code))

    cond do
      length(normalized) < 2 ->
        invalid_condition("weighted random experiments require at least two conditions")

      Enum.any?(codes, &is_nil/1) ->
        invalid_condition("condition_code is required")

      length(codes) != length(Enum.uniq(codes)) ->
        invalid_condition("condition codes must be unique")

      Enum.any?(normalized, fn condition -> (condition.weight || 0) < 0 end) ->
        invalid_condition("condition weights must be non-negative")

      normalized
      |> Enum.filter(&Map.get(&1, :active, true))
      |> Enum.reduce(0.0, fn condition, total -> total + (condition.weight || 0.0) end)
      |> Kernel.<=(0.0) ->
        invalid_condition("active condition weights must have a positive total")

      normalized |> Enum.count(&Map.get(&1, :active, true)) < 2 ->
        invalid_condition("weighted random experiments require at least two active conditions")

      true ->
        :ok
    end
  end

  defp validate_authoring_conditions(_conditions),
    do: invalid_condition("conditions are required")

  defp validate_alternatives_reference(decision_point, scope) do
    attrs = atomize_keys(decision_point)

    alternatives_revision_id = Map.get(attrs, :alternatives_revision_id)
    alternatives_resource_id = Map.get(attrs, :alternatives_resource_id)

    with {:ok, revision} <- get_alternatives_revision(alternatives_revision_id),
         true <- revision.resource_id == alternatives_resource_id,
         true <- project_resource?(scope.project_id, alternatives_resource_id),
         :ok <- validate_experiment_decision_point_revision(revision) do
      :ok
    else
      false -> invalid_condition("selected alternatives content does not belong to the project")
      {:error, %ExperimentError{}} = error -> error
    end
  end

  defp validate_decision_point_strategy(decision_point) do
    with {:ok, revision} <- get_alternatives_revision(decision_point.alternatives_revision_id) do
      validate_experiment_decision_point_revision(revision)
    end
  end

  defp validate_condition_options(decision_point, conditions) do
    attrs = atomize_keys(decision_point)

    with {:ok, revision} <- get_alternatives_revision(Map.get(attrs, :alternatives_revision_id)) do
      option_ids = revision_option_ids(revision)

      missing =
        conditions
        |> Enum.map(&atomize_keys/1)
        |> Enum.reject(fn condition ->
          (condition.option_id || condition.condition_code) in option_ids
        end)

      case missing do
        [] ->
          :ok

        _ ->
          invalid_condition("condition options must match the selected alternatives options", %{
            missing_option_ids: Enum.map(missing, &(&1.option_id || &1.condition_code))
          })
      end
    end
  end

  defp get_alternatives_revision(nil),
    do: invalid_condition("alternatives_revision_id is required")

  defp get_alternatives_revision(revision_id) do
    case Repo.get(Revision, revision_id) do
      %Revision{} = revision ->
        if revision.resource_type_id == ResourceType.id_for_alternatives() do
          {:ok, revision}
        else
          invalid_condition("selected revision is not an alternatives group")
        end

      nil ->
        not_found("alternatives revision not found", %{alternatives_revision_id: revision_id})
    end
  end

  defp to_decision_point_candidate(%Revision{} = revision) do
    %DecisionPointCandidate{
      alternatives_resource_id: revision.resource_id,
      alternatives_revision_id: revision.id,
      decision_point_key: "alternatives:#{revision.resource_id}",
      title: revision.title,
      options: revision_option_ids(revision)
    }
  end

  defp experiment_decision_point_revision?(%Revision{} = revision) do
    get_in(revision.content || %{}, ["strategy"]) == "upgrade_decision_point"
  end

  defp validate_experiment_decision_point_revision(%Revision{} = revision) do
    if experiment_decision_point_revision?(revision) do
      :ok
    else
      invalid_condition("selected alternatives group is not an A/B Testing decision point")
    end
  end

  defp public_decision_point(%DecisionPoint{} = decision_point) do
    %{
      id: decision_point.id,
      alternatives_resource_id: decision_point.alternatives_resource_id,
      alternatives_revision_id: decision_point.alternatives_revision_id,
      decision_point_key: decision_point.decision_point_key,
      title: decision_point.title,
      position: decision_point.position
    }
  end

  defp public_condition(%Condition{} = condition) do
    %{
      id: condition.id,
      decision_point_id: condition.decision_point_id,
      condition_code: condition.condition_code,
      option_id: condition.option_id,
      label: condition.label,
      weight: condition.weight,
      active: condition.active,
      position: condition.position
    }
  end

  defp assignment_counts_by_condition(experiment_id) do
    from(assignment in Assignment,
      where: assignment.experiment_id == ^experiment_id,
      group_by: assignment.condition_id,
      select: {assignment.condition_id, count(assignment.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp atomize_keys(nil), do: %{}

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {authoring_payload_key(key), value}
      {key, value} -> {key, value}
    end)
    |> Enum.reject(fn {key, _value} -> is_nil(key) end)
    |> Map.new()
  end

  defp authoring_payload_key("alternatives_resource_id"), do: :alternatives_resource_id
  defp authoring_payload_key("alternatives_revision_id"), do: :alternatives_revision_id
  defp authoring_payload_key("decision_point_key"), do: :decision_point_key
  defp authoring_payload_key("title"), do: :title
  defp authoring_payload_key("position"), do: :position
  defp authoring_payload_key("condition_code"), do: :condition_code
  defp authoring_payload_key("option_id"), do: :option_id
  defp authoring_payload_key("label"), do: :label
  defp authoring_payload_key("weight"), do: :weight
  defp authoring_payload_key("active"), do: :active
  defp authoring_payload_key(_key), do: nil

  defp emit_authoring_telemetry(action, schema, extra_metadata) do
    :telemetry.execute(
      [:oli, :experiments, :authoring, action],
      %{count: 1},
      Map.merge(
        %{
          experiment_id: schema.id,
          project_id: schema.project_id,
          section_id: schema.section_id
        },
        extra_metadata
      )
    )
  end

  defp emit_authoring_validation_failed(action, scope, error, extra_metadata \\ %{}) do
    scope = scope || %Scope{}

    :telemetry.execute(
      [:oli, :experiments, :authoring, :validation_failed],
      %{count: 1},
      Map.merge(
        %{
          action: action,
          project_id: scope.project_id,
          section_id: scope.section_id,
          error_type: error.type
        },
        extra_metadata
      )
    )
  end

  defp emit_lifecycle_telemetry(action, schema, extra_metadata) do
    :telemetry.execute(
      [:oli, :experiments, :lifecycle, action],
      %{count: 1},
      Map.merge(
        %{
          experiment_id: schema.id,
          project_id: schema.project_id,
          section_id: schema.section_id,
          algorithm: schema.algorithm
        },
        extra_metadata
      )
    )
  end

  defp emit_lifecycle_failed(scope, error, extra_metadata) do
    scope = scope || %Scope{}

    :telemetry.execute(
      [:oli, :experiments, :lifecycle, :transition_failed],
      %{count: 1},
      Map.merge(
        %{
          project_id: scope.project_id,
          section_id: scope.section_id,
          error_type: error.type
        },
        extra_metadata
      )
    )
  end

  defp normalize_transaction_result({:ok, schema}), do: {:ok, schema}

  defp normalize_transaction_result({:error, %Ecto.Changeset{} = changeset}),
    do: normalize_result({:error, changeset})

  defp normalize_transaction_result({:error, %ExperimentError{} = error}), do: {:error, error}

  defp normalize_transaction_result({:error, reason}) do
    {:error,
     %ExperimentError{
       type: :persistence_error,
       message: "experiment graph could not be persisted",
       details: %{reason: inspect(reason)}
     }}
  end

  defp normalize_transaction_result(
         {:error, _operation, %Ecto.Changeset{} = changeset, _changes}
       ),
       do: normalize_result({:error, changeset})

  defp normalize_transaction_result({:error, _operation, reason, _changes}),
    do: normalize_transaction_result({:error, reason})

  defp normalize_transaction_result(result), do: result

  defp project_resource?(project_id, resource_id) do
    Repo.exists?(
      from(project_resource in ProjectResource,
        where:
          project_resource.project_id == ^project_id and
            project_resource.resource_id == ^resource_id
      )
    )
  end

  defp revision_option_ids(%Revision{content: %{"options" => options}}) when is_list(options) do
    Enum.map(options, &(Map.get(&1, "id") || Map.get(&1, :id) || Map.get(&1, "name")))
  end

  defp revision_option_ids(_revision), do: []

  defp graph_request?(%{decision_point: nil, conditions: conditions})
       when conditions in [nil, []],
       do: false

  defp graph_request?(_request), do: true

  defp maybe_require_authoring_scope(_scope, false), do: :ok
  defp maybe_require_authoring_scope(scope, true), do: require_authoring_scope(scope)

  defp require_authoring_scope(%Scope{enrollment_id: nil}), do: :ok

  defp require_authoring_scope(_scope) do
    invalid_scope("authoring experiments must be project- or section-scoped")
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

  defp validate_institution(%Scope{institution_id: nil} = scope), do: {:ok, scope}

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

      not is_nil(scope.institution_id) and not is_nil(section.institution_id) and
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
      schema.project_id != scope.project_id ->
        invalid_scope("experiment does not belong to project")

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
      project_id: schema.project_id,
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
