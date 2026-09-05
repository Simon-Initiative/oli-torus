defmodule Oli.Experiments.Lifecycle do
  @moduledoc """
  Executes experiment lifecycle transitions and serializes active Decision Point ownership.
  """

  import Ecto.Query

  alias Oli.Experiments.{ExperimentError, Queries, ScopeValidator}
  alias Oli.Experiments.Schemas.ExperimentDefinition
  alias Oli.Repo
  alias Oli.Resources.Resource

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

  @doc false
  def transition(experiment_id, request, action, activation_validator, normalize) do
    target_state = Map.fetch!(@transition_targets, action)

    Repo.transaction(fn ->
      with {:ok, scope} <- ScopeValidator.validate_scope(request.scope),
           %ExperimentDefinition{} = schema <-
             scope
             |> Queries.scoped_experiment_query(experiment_id)
             |> lock("FOR UPDATE")
             |> preload(:sections)
             |> Repo.one(),
           :ok <- validate_transition(schema.state, target_state),
           :ok <- validate_prerequisites(schema, schema.state, target_state, activation_validator),
           :ok <- maybe_lock_active_binding(schema, target_state),
           attrs <- transition_attrs(schema, target_state, request.transitioned_at),
           {:ok, updated} <- schema |> ExperimentDefinition.changeset(attrs) |> Repo.update() do
        {Repo.preload(updated, :sections, force: true), schema.state}
      else
        nil -> Repo.rollback(not_found!(experiment_id))
        {:error, %ExperimentError{} = error} -> Repo.rollback(error)
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
      end
    end)
    |> normalize.()
  end

  defp validate_prerequisites(_schema, _current, target, _validator) when target != :active,
    do: :ok

  defp validate_prerequisites(schema, :draft, :active, validator), do: validator.(schema)
  defp validate_prerequisites(_schema, :paused, :active, _validator), do: :ok

  defp validate_transition(current_state, target_state) do
    case target_state in Map.fetch!(@allowed_transitions, current_state) do
      true ->
        :ok

      false ->
        {:error,
         %ExperimentError{
           type: :invalid_state,
           message: "experiment cannot transition from #{current_state} to #{target_state}",
           details: %{current_state: current_state, target_state: target_state}
         }}
    end
  end

  defp transition_attrs(schema, target_state, transitioned_at) do
    timestamp = transitioned_at || DateTime.utc_now() |> DateTime.truncate(:second)
    attrs = %{state: target_state}

    case {schema.state, target_state} do
      {_state, :active} when is_nil(schema.started_at) -> Map.put(attrs, :started_at, timestamp)
      {_state, :completed} -> Map.put(attrs, :ended_at, timestamp)
      _transition -> attrs
    end
  end

  defp maybe_lock_active_binding(schema, :active) do
    Repo.one!(
      from(resource in Resource,
        where: resource.id == ^schema.alternatives_resource_id,
        lock: "FOR UPDATE"
      )
    )

    query =
      from(experiment in ExperimentDefinition,
        where:
          experiment.state == :active and
            experiment.alternatives_resource_id == ^schema.alternatives_resource_id and
            experiment.id != ^schema.id,
        select: true,
        limit: 1
      )

    case Repo.one(query) do
      nil ->
        :ok

      true ->
        Repo.rollback(%ExperimentError{
          type: :conflict,
          message: "Decision Point is already used by an active experiment",
          details: %{alternatives_resource_id: schema.alternatives_resource_id}
        })
    end
  end

  defp maybe_lock_active_binding(_schema, _target), do: :ok

  defp not_found!(experiment_id) do
    %ExperimentError{
      type: :not_found,
      message: "experiment not found",
      details: %{experiment_id: experiment_id}
    }
  end
end
