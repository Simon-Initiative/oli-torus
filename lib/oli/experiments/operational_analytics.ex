defmodule Oli.Experiments.OperationalAnalytics do
  @moduledoc """
  Builds bounded PostgreSQL operational reports for experiment product surfaces.
  """

  import Ecto.Query

  alias Oli.Experiments.{
    ExperimentAuthoringView,
    ExperimentError,
    PolicyGuardrails,
    Queries,
    Scope,
    ScopeValidator
  }

  alias Oli.Experiments.Schemas.{Assignment, Condition}
  alias Oli.Repo

  @doc false
  def experiment_summary(%Oli.Experiments.AnalyticsQuery{} = query) do
    with {:ok, scope} <- ScopeValidator.validate_scope(query.scope),
         :ok <- Queries.ensure_analytics_experiment_scope(scope, query.experiment_id) do
      experiment_query = Queries.scoped_experiment_query(scope, query.experiment_id)

      {:ok,
       %{
         experiments: Repo.aggregate(experiment_query, :count, :id),
         assignments:
           Repo.aggregate(
             Queries.scoped_assignment_query(scope, query.experiment_id),
             :count,
             :id
           ),
         exposures: 0,
         rewards: Queries.runtime_event_count(scope, query.experiment_id, "rewards")
       }}
    end
  end

  def experiment_summary(_query), do: invalid_request("expected AnalyticsQuery")

  @doc """
  Returns operational assignment counts. Durable analytics must read xAPI-derived projections.
  """

  def assignment_counts(%Oli.Experiments.AnalyticsQuery{} = query) do
    with {:ok, scope} <- ScopeValidator.validate_scope(query.scope),
         :ok <- Queries.ensure_analytics_experiment_scope(scope, query.experiment_id) do
      counts =
        scope
        |> Queries.scoped_assignment_query(query.experiment_id)
        |> join(:inner, [assignment, _experiment], condition in Condition,
          on: condition.id == assignment.condition_id
        )
        |> group_by([assignment, _experiment, condition], [
          assignment.experiment_id,
          assignment.condition_id,
          condition.condition_code
        ])
        |> select([assignment, _experiment, condition], %{
          experiment_id: assignment.experiment_id,
          condition_id: assignment.condition_id,
          condition_code: condition.condition_code,
          count: count(assignment.id)
        })
        |> Repo.all()

      {:ok, counts}
    end
  end

  def assignment_counts(_query), do: invalid_request("expected AnalyticsQuery")

  @doc """
  Exposure evidence is emitted through xAPI host statements and served from ClickHouse.
  PostgreSQL no longer retains exposure event state.
  """
  def exposure_counts(%Oli.Experiments.AnalyticsQuery{} = query) do
    with {:ok, scope} <- ScopeValidator.validate_scope(query.scope),
         :ok <- Queries.ensure_analytics_experiment_scope(scope, query.experiment_id) do
      {:ok, []}
    end
  end

  def exposure_counts(_query), do: invalid_request("expected AnalyticsQuery")

  @doc """
  Returns operational reward counts. Durable analytics must read xAPI-derived projections.
  """
  def reward_counts(%Oli.Experiments.AnalyticsQuery{} = query) do
    with {:ok, scope} <- ScopeValidator.validate_scope(query.scope),
         :ok <- Queries.ensure_analytics_experiment_scope(scope, query.experiment_id) do
      counts =
        scope
        |> Queries.scoped_assignment_query(query.experiment_id)
        |> join(:inner, [reward, _experiment], condition in Condition,
          on: condition.id == reward.condition_id
        )
        |> group_by([reward, _experiment, condition], [
          reward.experiment_id,
          reward.condition_id,
          condition.condition_code
        ])
        |> select([reward, _experiment, condition], %{
          experiment_id: reward.experiment_id,
          condition_id: reward.condition_id,
          condition_code: condition.condition_code,
          count: count(reward.id)
        })
        |> where(
          [reward, _experiment, _condition],
          fragment("? \\? 'rewards'", reward.runtime_event_state)
        )
        |> Repo.all()

      {:ok, counts}
    end
  end

  def reward_counts(_query), do: invalid_request("expected AnalyticsQuery")

  @doc """
  Returns operational policy state for runtime inspection. Durable analytics must read
  xAPI-derived projections.
  """
  def policy_state_snapshot(%Oli.Experiments.AnalyticsQuery{} = query) do
    with {:ok, scope} <- ScopeValidator.validate_scope(query.scope),
         :ok <- Queries.ensure_analytics_experiment_scope(scope, query.experiment_id) do
      snapshots =
        scope
        |> Queries.scoped_policy_state_query(query.experiment_id)
        |> select([policy_state, experiment], %{
          experiment_id: policy_state.experiment_id,
          algorithm: policy_state.algorithm,
          algorithm_version: policy_state.algorithm_version,
          warm_up_assignments: experiment.warm_up_assignments,
          max_condition_share: experiment.max_condition_share,
          fixed_control_allocation: experiment.fixed_control_allocation,
          imbalance_threshold: experiment.imbalance_threshold,
          state: policy_state.state,
          reward_success_count: policy_state.reward_success_count,
          reward_failure_count: policy_state.reward_failure_count,
          assignment_count: policy_state.assignment_count,
          updated_at: policy_state.updated_at
        })
        |> Repo.all()
        |> Enum.map(&add_policy_inspection_metadata/1)

      {:ok, snapshots}
    end
  end

  def policy_state_snapshot(_query), do: invalid_request("expected AnalyticsQuery")

  @doc """
  Returns the bounded PostgreSQL policy report used by experiment authoring.

  Draft experiments and weighted-random experiments intentionally return no
  posterior rows. The report is derived only from the persisted policy snapshot,
  mappings, and aggregate assignment counts; it never reads reward history or an
  analytics store.
  """
  def policy_snapshot(experiment_id, %Scope{} = scope) when is_integer(experiment_id) do
    with {:ok, scope} <- ScopeValidator.validate_scope(scope),
         :ok <- ScopeValidator.require_authoring_access(scope),
         {:ok, authoring_view} <-
           Oli.Experiments.get_experiment_authoring_view(experiment_id, scope) do
      policy_snapshot(authoring_view, scope)
    end
  end

  def policy_snapshot(%ExperimentAuthoringView{} = authoring_view, %Scope{} = scope) do
    with {:ok, scope} <- ScopeValidator.validate_scope(scope),
         :ok <- ScopeValidator.require_authoring_access(scope) do
      case authoring_view.definition.state do
        :draft -> {:ok, []}
        _state -> build_policy_snapshot(authoring_view, scope)
      end
    end
  end

  def policy_snapshot(_experiment_or_view, _scope),
    do: invalid_request("expected experiment id or authoring view and Scope")

  defp build_policy_snapshot(authoring_view, scope) do
    query = %Oli.Experiments.AnalyticsQuery{
      scope: scope,
      experiment_id: authoring_view.definition.id
    }

    with {:ok, snapshots} <- policy_state_snapshot(query) do
      assignment_counts = assignment_counts_by_condition(authoring_view.definition.id)

      rows =
        snapshots
        |> Enum.filter(&(&1.algorithm == :thompson_sampling))
        |> Enum.flat_map(fn snapshot ->
          total_assignments = max(snapshot.assignment_count, 0)

          Enum.map(authoring_view.conditions, fn condition ->
            condition_state = Map.get(snapshot.state, condition.condition_code, %{})
            alpha = numeric_value(condition_state["posterior_alpha"])
            beta = numeric_value(condition_state["posterior_beta"])

            assignment_count =
              Map.get(assignment_counts, condition.id, 0)

            %{
              condition_id: condition.id,
              condition_code: condition.condition_code,
              condition_label: condition.label || condition.condition_code,
              option_id: condition.option_id,
              posterior_alpha: alpha,
              posterior_beta: beta,
              estimated_success_probability: posterior_mean(alpha, beta),
              accepted_success_count: non_negative_integer(condition_state["successes"]),
              accepted_failure_count: non_negative_integer(condition_state["failures"]),
              assignment_count: assignment_count,
              assignment_share: assignment_share(assignment_count, total_assignments),
              updated_at: snapshot.updated_at,
              effective_mode:
                effective_policy_mode(
                  snapshot,
                  authoring_view.conditions,
                  assignment_counts
                ),
              guardrail_state: snapshot.guardrail_state,
              imbalance_warning?:
                imbalance_warning?(snapshot, assignment_count, total_assignments),
              lifecycle_state: authoring_view.definition.state
            }
          end)
        end)

      {:ok, rows}
    end
  end

  defp numeric_value(value) when is_integer(value), do: value / 1
  defp numeric_value(value) when is_float(value), do: value
  defp numeric_value(_value), do: 0.0

  defp non_negative_integer(value) when is_integer(value) and value >= 0, do: value
  defp non_negative_integer(_value), do: 0

  defp posterior_mean(alpha, beta) when alpha + beta > 0, do: alpha / (alpha + beta)
  defp posterior_mean(_alpha, _beta), do: 0.0

  defp assignment_share(_count, 0), do: 0.0
  defp assignment_share(count, total), do: count / total

  defp effective_policy_mode(snapshot, conditions, assignment_counts) do
    guardrails = snapshot.guardrail_state
    assignment_count = guardrails["assignment_count"] || 0

    counts =
      Map.new(conditions, &{&1.id, Map.get(assignment_counts, &1.id, 0)})

    cond do
      assignment_count < (guardrails["warm_up_assignments"] || 0) ->
        :warm_up_weighted_random

      PolicyGuardrails.fixed_control_condition(
        conditions,
        counts,
        guardrails["fixed_control_allocation"]
      ) ->
        :fixed_control

      PolicyGuardrails.cap_eligible_conditions(
        conditions,
        counts,
        guardrails["max_condition_share"]
      ) != conditions ->
        :traffic_cap

      true ->
        :thompson_sampling
    end
  end

  defp imbalance_warning?(snapshot, count, total) do
    threshold = snapshot.guardrail_state["imbalance_threshold"]
    is_number(threshold) and total > 0 and count / total > threshold
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

  defp add_policy_inspection_metadata(%{algorithm: :thompson_sampling} = snapshot) do
    snapshot
    |> Map.put(:guardrail_state, %{
      "warm_up_assignments" => snapshot.warm_up_assignments,
      "max_condition_share" => snapshot.max_condition_share,
      "fixed_control_allocation" => snapshot.fixed_control_allocation,
      "imbalance_threshold" => snapshot.imbalance_threshold,
      "assignment_count" => snapshot.assignment_count,
      "reward_count" => snapshot.reward_success_count + snapshot.reward_failure_count
    })
    |> Map.drop([
      :warm_up_assignments,
      :max_condition_share,
      :fixed_control_allocation,
      :imbalance_threshold
    ])
  end

  defp add_policy_inspection_metadata(snapshot), do: snapshot

  defp invalid_request(message) do
    {:error, %ExperimentError{type: :persistence_error, message: message}}
  end
end
