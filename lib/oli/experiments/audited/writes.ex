defmodule Oli.Experiments.Audited.Writes do
  @moduledoc false

  # Experiment configuration writers, private to `Oli.Experiments.Audited`, which records each
  # change. Validation and read helpers shared with the queries live in `Oli.Experiments.Support`.

  import Ecto.Query

  import Oli.Experiments.Support,
    only: [
      assignment_counts_by_condition: 1,
      eligible_sections_query: 1,
      ensure_definition_in_scope: 2,
      get_or_create_policy_state: 1,
      get_scoped_definition: 2,
      invalid_condition: 2,
      invalid_request: 1,
      invalid_scope: 2,
      invalid_state: 2,
      normalize_transaction_result: 1,
      not_found: 2,
      require_authoring_access: 1,
      require_authoring_scope: 1,
      require_eligible_section_reader: 1,
      revision_option_ids: 1,
      section_participation: 2,
      to_definition: 1,
      validate_experiment_controlled_revision: 1,
      validate_scope: 1,
      invalid_condition: 1
    ]

  alias Oli.Experiments.Audited.{ConfigurationPersistence, Lifecycle}
  alias Oli.Experiments.{ActivationValidator, ExperimentError, ExperimentSectionParticipation}
  alias Oli.Experiments.{PolicyConfiguration, Scope}
  alias Oli.Experiments.Schemas.{AssessmentBinding, Condition, Intervention}
  alias Oli.Experiments.Schemas.ExperimentDefinition, as: ExperimentDefinitionSchema
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo
  alias Oli.Resources.{ResourceType, Revision}

  @transition_targets %{
    activate_experiment: :active,
    pause_experiment: :paused,
    complete_experiment: :completed,
    archive_experiment: :archived
  }

  @doc """
  Creates a native experiment definition.
  """
  def create_experiment(%Oli.Experiments.CreateExperimentRequest{} = request) do
    with {:ok, scope} <- validate_scope(request.scope),
         :ok <-
           maybe_require_authoring_scope(scope, structural_configuration_change?(request)),
         :ok <-
           validate_authoring_algorithm(
             request.algorithm,
             structural_configuration_change?(request)
           ),
         :ok <- validate_configuration_request(request, scope),
         {:ok, section_ids} <- validate_experiment_sections(request.section_ids, scope),
         attrs <- create_attrs(request, scope),
         {:ok, schema} <- insert_experiment_configuration(attrs, request, section_ids) do
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
    with {:ok, scope} <- validate_scope(request.scope),
         {:ok, schema} <- get_scoped_definition(experiment_id, scope),
         :ok <- require_authoring_access(scope),
         :ok <- validate_update_state(schema, request),
         :ok <- validate_immutable_algorithm(schema, request.algorithm),
         :ok <-
           validate_assignment_scope(
             request.algorithm || schema.algorithm,
             resolve_update_assignment_scope(request.assignment_scope, schema.assignment_scope)
           ),
         :ok <-
           validate_authoring_algorithm(
             request.algorithm || schema.algorithm,
             structural_configuration_change?(request)
           ),
         :ok <- validate_assignment_safe_update(schema, request),
         :ok <-
           validate_configuration_request(request, scope, request.algorithm || schema.algorithm),
         {:ok, section_ids} <- validate_experiment_sections(request.section_ids, scope),
         {:ok, updated} <- update_experiment_configuration(schema, request, section_ids) do
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
  Changes whether a condition is eligible for new assignments.

  Availability may be changed while an experiment is draft, active, or paused. Existing
  assignments remain sticky when their condition is made unavailable.
  """
  def update_condition_availability(experiment_id, condition_id, active, %Scope{} = scope)
      when is_integer(experiment_id) and is_integer(condition_id) and is_boolean(active) do
    with {:ok, updated} <-
           update_condition_availabilities(
             experiment_id,
             [%{id: condition_id, active: active}],
             scope
           ) do
      {:ok, Enum.find(updated, &(&1.id == condition_id))}
    end
  end

  def update_condition_availability(_experiment_id, _condition_id, _active, _scope),
    do: invalid_request("expected experiment, condition, availability, and authoring scope")

  @doc """
  Atomically changes condition availability and weighted-random allocation weights.
  """
  def update_condition_availabilities(experiment_id, availabilities, %Scope{} = scope)
      when is_integer(experiment_id) and is_list(availabilities) and availabilities != [] do
    with {:ok, scope} <- validate_scope(scope),
         {:ok, schema} <- get_scoped_definition(experiment_id, scope),
         :ok <- require_authoring_access(scope),
         :ok <- validate_availability_update_state(schema),
         {:ok, updates_by_id} <- normalize_condition_updates(availabilities),
         :ok <- validate_condition_weight_updates(schema, updates_by_id) do
      result =
        Repo.transaction(fn ->
          lock_experiment!(schema.id)
          locked_schema = Repo.get!(ExperimentDefinitionSchema, schema.id)

          case validate_availability_update_state(locked_schema) do
            :ok -> :ok
            {:error, %ExperimentError{} = error} -> Repo.rollback(error)
          end

          case validate_condition_weight_updates(locked_schema, updates_by_id) do
            :ok -> :ok
            {:error, %ExperimentError{} = error} -> Repo.rollback(error)
          end

          conditions =
            from(condition in Condition, where: condition.experiment_id == ^schema.id)
            |> Repo.all()

          unknown_ids = Map.keys(updates_by_id) -- Enum.map(conditions, & &1.id)

          if unknown_ids != [] do
            Repo.rollback(
              elem(
                not_found("experiment condition was not found", %{condition_ids: unknown_ids}),
                1
              )
            )
          end

          updated_conditions =
            conditions
            |> Enum.map(fn current ->
              update = Map.get(updates_by_id, current.id, %{})

              %{
                current
                | active: Map.get(update, :active, current.active),
                  weight: Map.get(update, :weight, current.weight)
              }
            end)

          case validate_available_conditions(updated_conditions, locked_schema.state) do
            :ok ->
              Enum.map(conditions, fn condition ->
                update = Map.get(updates_by_id, condition.id, %{})

                condition
                |> Condition.changeset(update)
                |> Repo.update!()
              end)

            {:error, %ExperimentError{} = error} ->
              Repo.rollback(error)
          end
        end)
        |> normalize_transaction_result()

      case result do
        {:ok, _updated} ->
          emit_authoring_telemetry(:condition_configuration, schema, %{
            condition_ids: Map.keys(updates_by_id)
          })

          result

        _error ->
          result
      end
    end
  end

  def update_condition_availabilities(_experiment_id, _availabilities, _scope),
    do: invalid_request("expected one or more condition availability changes")

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
  Atomically replaces the selected section set for a mutable experiment.
  """
  def update_section_participation(experiment_id, %Scope{} = scope, section_ids)
      when is_list(section_ids) do
    normalized_ids = section_ids |> Enum.uniq() |> Enum.sort()

    result =
      Repo.transaction(fn ->
        with {:ok, scope} <- validate_scope(scope),
             :ok <- require_authoring_scope(scope),
             :ok <- require_eligible_section_reader(scope),
             %ExperimentDefinitionSchema{} = schema <-
               Repo.one(
                 from(experiment in ExperimentDefinitionSchema,
                   where: experiment.id == ^experiment_id,
                   lock: "FOR UPDATE",
                   preload: :sections
                 )
               ),
             :ok <- ensure_definition_in_scope(schema, scope),
             :ok <- validate_participation_update_state(schema),
             :ok <- validate_eligible_section_ids(normalized_ids, scope) do
          previous_ids = Enum.map(schema.sections, & &1.id)
          replace_experiment_sections!(schema.id, normalized_ids)
          updated = Repo.preload(schema, :sections, force: true)
          participation = section_participation(updated, scope)

          emit_participation_updated(schema, previous_ids, normalized_ids, participation)
          participation
        else
          nil -> Repo.rollback(not_found("experiment not found", %{experiment_id: experiment_id}))
          {:error, %ExperimentError{} = error} -> Repo.rollback(error)
        end
      end)

    case result do
      {:ok, %ExperimentSectionParticipation{} = participation} ->
        {:ok, participation}

      {:error, %ExperimentError{} = error} ->
        emit_participation_validation_failed(experiment_id, scope, normalized_ids, error)
        {:error, error}
    end
  end

  def update_section_participation(_experiment_id, _scope, _section_ids),
    do: invalid_request("section_ids must be a list")

  @doc """
  Explicitly removes a draft assessment binding.
  """
  def remove_assessment_binding(experiment_id, binding_id, %Scope{} = scope) do
    reconcile_draft_dependency(experiment_id, scope, fn schema ->
      query =
        from(binding in AssessmentBinding,
          join: intervention in Intervention,
          on: intervention.id == binding.intervention_id,
          where: binding.id == ^binding_id and intervention.experiment_id == ^schema.id
        )

      delete_owned_dependency(query, :assessment_binding, binding_id)
    end)
  end

  @doc """
  Explicitly removes a draft intervention after its assessment binding is reconciled.
  """
  def remove_intervention(experiment_id, intervention_id, %Scope{} = scope) do
    reconcile_draft_dependency(experiment_id, scope, fn schema ->
      query =
        from(intervention in Intervention,
          where: intervention.id == ^intervention_id and intervention.experiment_id == ^schema.id
        )

      delete_owned_dependency(query, :intervention, intervention_id)
    end)
  end

  @doc """
  Explicitly removes a draft condition.
  """
  def remove_condition(experiment_id, condition_id, %Scope{} = scope) do
    reconcile_draft_dependency(experiment_id, scope, fn schema ->
      query =
        from(condition in Condition,
          where: condition.id == ^condition_id and condition.experiment_id == ^schema.id
        )

      delete_owned_dependency(query, :condition, condition_id)
    end)
  end

  defp reconcile_draft_dependency(experiment_id, scope, operation) do
    Repo.transaction(fn ->
      with {:ok, validated_scope} <- validate_scope(scope),
           :ok <- require_authoring_access(validated_scope),
           {:ok, schema} <- get_scoped_definition(experiment_id, validated_scope),
           %ExperimentDefinitionSchema{} = locked <- lock_experiment!(schema.id),
           :ok <- ensure_draft_reconciliation(locked) do
        operation.(locked)
      else
        {:error, %ExperimentError{} = error} -> Repo.rollback(error)
      end
    end)
    |> case do
      {:ok, result} ->
        {:ok, result}

      {:error, %ExperimentError{} = error} ->
        {:error, error}

      {:error, %Ecto.ConstraintError{}} ->
        invalid_condition("dependent experiment configuration must be reconciled first")
    end
  end

  defp ensure_draft_reconciliation(%ExperimentDefinitionSchema{state: :draft}), do: :ok

  defp ensure_draft_reconciliation(%ExperimentDefinitionSchema{state: state}) do
    {:error,
     %ExperimentError{
       type: :invalid_state,
       message: "only draft experiment dependencies can be reconciled",
       details: %{state: state}
     }}
  end

  defp delete_owned_dependency(query, type, id) do
    case Repo.one(query) do
      nil -> Repo.rollback(not_found("experiment dependency not found", %{type: type, id: id}))
      schema -> Repo.delete!(schema)
    end
  end

  defp transition(experiment_id, %Oli.Experiments.LifecycleRequest{} = request, action) do
    target_state = Map.fetch!(@transition_targets, action)

    with {:ok, {updated, previous_state}} <-
           Lifecycle.transition(
             experiment_id,
             request,
             action,
             &validate_activation_configuration/1,
             &normalize_transaction_result/1
           ) do
      emit_lifecycle_telemetry(:transition, updated, %{
        previous_state: previous_state,
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

  defp insert_experiment_configuration(attrs, request, section_ids) do
    ConfigurationPersistence.insert(
      attrs,
      request,
      section_ids,
      &get_or_create_policy_state/1,
      &normalize_transaction_result/1
    )
  end

  defp update_experiment_configuration(schema, request, section_ids) do
    ConfigurationPersistence.update(
      schema,
      update_attrs(request, schema.algorithm),
      request,
      section_ids,
      &get_or_create_policy_state/1,
      &validate_locked_update/2,
      &normalize_transaction_result/1
    )
  end

  defp lock_experiment!(experiment_id),
    do: ConfigurationPersistence.lock_experiment!(experiment_id)

  defp replace_experiment_sections!(experiment_id, section_ids),
    do: ConfigurationPersistence.replace_experiment_sections!(experiment_id, section_ids)

  defp validate_participation_update_state(%ExperimentDefinitionSchema{
         state: state
       })
       when state in [:draft, :active, :paused],
       do: :ok

  defp validate_participation_update_state(%ExperimentDefinitionSchema{state: state}) do
    invalid_state("section participation is read-only", %{state: state})
  end

  defp validate_eligible_section_ids(section_ids, scope) do
    if section_ids == [] do
      :ok
    else
      validate_nonempty_eligible_section_ids(section_ids, scope)
    end
  end

  defp validate_nonempty_eligible_section_ids(section_ids, scope) do
    eligible_ids =
      scope
      |> eligible_sections_query()
      |> where([section], section.id in ^section_ids)
      |> select([section], section.id)
      |> Repo.all()
      |> MapSet.new()

    invalid_ids = Enum.reject(section_ids, &MapSet.member?(eligible_ids, &1))

    case invalid_ids do
      [] -> :ok
      _ -> invalid_scope("one or more sections are not eligible", %{section_ids: invalid_ids})
    end
  end

  defp emit_participation_updated(schema, previous_ids, new_ids, participation) do
    previous = MapSet.new(previous_ids)
    current = MapSet.new(new_ids)

    :telemetry.execute([:oli, :experiments, :participation, :updated], %{count: 1}, %{
      experiment_id: schema.id,
      project_id: schema.project_id,
      previous_selected_count: MapSet.size(previous),
      selected_count: MapSet.size(current),
      added_count: MapSet.difference(current, previous) |> MapSet.size(),
      removed_count: MapSet.difference(previous, current) |> MapSet.size(),
      stale_count: length(participation.stale_sections),
      state: schema.state
    })
  end

  defp emit_participation_validation_failed(experiment_id, scope, section_ids, error) do
    :telemetry.execute(
      [:oli, :experiments, :participation, :validation_failed],
      %{count: 1},
      %{
        experiment_id: experiment_id,
        project_id: scope && scope.project_id,
        requested_count: length(section_ids),
        error_type: error.type
      }
    )
  end

  defp validate_experiment_sections(nil, scope) do
    {:ok, Enum.reject([scope.section_id], &is_nil/1)}
  end

  defp validate_experiment_sections(section_ids, scope) when is_list(section_ids) do
    section_ids
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, []}, fn section_id, {:ok, valid_ids} ->
      case validate_eligible_section_ids([section_id], scope) do
        :ok -> {:cont, {:ok, [section_id | valid_ids]}}
        {:error, %ExperimentError{}} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, valid_ids} -> {:ok, Enum.reverse(valid_ids)}
      error -> error
    end
  end

  defp validate_experiment_sections(_section_ids, _scope),
    do: invalid_request("section_ids must be a list")

  defp create_attrs(request, scope) do
    %{
      project_id: scope.project_id,
      slug: request.slug,
      name: request.name,
      description: request.description,
      algorithm: request.algorithm,
      alternatives_resource_id: request.alternatives_resource_id,
      prior_alpha: request.prior_alpha || 1.0,
      prior_beta: request.prior_beta || 1.0,
      warm_up_assignments: request.warm_up_assignments || 0,
      max_condition_share: request.max_condition_share || 1.0,
      fixed_control_allocation: request.fixed_control_allocation,
      imbalance_threshold: request.imbalance_threshold || 1.0,
      reward_source: request.reward_source || "assessment_page:normalized_score",
      assignment_unit: request.assignment_unit,
      assignment_scope: resolve_assignment_scope(request.assignment_scope, request.algorithm)
    }
  end

  defp update_attrs(request, _existing_algorithm) do
    request
    |> Map.from_struct()
    |> Map.take([
      :slug,
      :name,
      :description,
      :algorithm,
      :assignment_unit,
      :assignment_scope,
      :alternatives_resource_id,
      :prior_alpha,
      :prior_beta,
      :warm_up_assignments,
      :max_condition_share,
      :fixed_control_allocation,
      :imbalance_threshold,
      :reward_source
    ])
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp validate_activation_configuration(schema), do: ActivationValidator.validate(schema)

  defp validate_update_state(schema, _request) do
    cond do
      schema.state == :draft ->
        :ok

      schema.state in [:paused, :completed, :archived] ->
        {:error,
         %ExperimentError{
           type: :invalid_state,
           message: "non-draft experiments are read-only",
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

  defp validate_availability_update_state(%ExperimentDefinitionSchema{state: state})
       when state in [:draft, :active, :paused],
       do: :ok

  defp validate_availability_update_state(%ExperimentDefinitionSchema{state: state}) do
    {:error,
     %ExperimentError{
       type: :invalid_state,
       message: "condition availability cannot be changed for this experiment",
       details: %{state: state}
     }}
  end

  defp validate_available_conditions(conditions, state) do
    active_conditions = Enum.filter(conditions, & &1.active)
    minimum_active = if state == :draft, do: 2, else: 1

    cond do
      length(active_conditions) < minimum_active ->
        message =
          case state do
            :draft -> "experiments require at least two active conditions"
            _ -> "experiments require at least one active condition"
          end

        invalid_condition(message)

      Enum.reduce(active_conditions, 0.0, &(&1.weight + &2)) <= 0.0 ->
        invalid_condition("active condition weights must have a positive total")

      true ->
        :ok
    end
  end

  defp normalize_condition_updates(availabilities) do
    normalized =
      Enum.reduce_while(availabilities, {:ok, %{}}, fn availability, {:ok, acc} ->
        id = Map.get(availability, :id) || Map.get(availability, "id")
        active = Map.get(availability, :active, Map.get(availability, "active"))
        weight = Map.get(availability, :weight, Map.get(availability, "weight"))

        update =
          %{active: active}
          |> then(fn update ->
            case weight do
              nil -> update
              weight -> Map.put(update, :weight, weight)
            end
          end)

        case {id, active, weight, Map.has_key?(acc, id)} do
          {id, active, weight, false}
          when is_integer(id) and is_boolean(active) and
                 (is_nil(weight) or (is_number(weight) and weight >= 0)) ->
            {:cont, {:ok, Map.put(acc, id, update)}}

          _ ->
            {:halt, invalid_request("condition availability changes must have unique IDs")}
        end
      end)

    case normalized do
      {:ok, availability_by_id} when map_size(availability_by_id) > 0 ->
        {:ok, availability_by_id}

      _ ->
        invalid_request("expected one or more condition availability changes")
    end
  end

  defp validate_condition_weight_updates(
         %ExperimentDefinitionSchema{algorithm: :weighted_random},
         _updates
       ),
       do: :ok

  defp validate_condition_weight_updates(_schema, updates) do
    case Enum.any?(updates, fn {_id, update} -> Map.has_key?(update, :weight) end) do
      true -> invalid_condition("condition weights apply only to weighted random experiments")
      false -> :ok
    end
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
        select: {condition.id, condition}
      )
      |> Repo.all()
      |> Map.new()

    incoming =
      request.conditions
      |> Enum.map(&atomize_keys/1)
      |> Map.new(&{Map.get(&1, :id), &1})

    assigned_ids =
      existing
      |> Enum.filter(fn {_id, condition} -> Map.get(counts, condition.id, 0) > 0 end)
      |> Enum.map(fn {id, _condition} -> id end)

    changed =
      Enum.find(assigned_ids, fn id ->
        incoming_condition = Map.get(incoming, id)

        is_nil(incoming_condition) or Map.get(incoming_condition, :active, true) == false
      end)

    case changed do
      nil ->
        :ok

      id ->
        code = Map.fetch!(existing, id).condition_code

        invalid_condition(
          "learner assignments already exist for condition #{code}; condition identity and active state cannot be changed",
          %{condition_id: id, condition_code: code}
        )
    end
  end

  defp validate_authoring_algorithm(_algorithm, _structural_configuration_change?), do: :ok

  defp validate_assignment_scope(algorithm, scope)
       when scope in [:intervention, "intervention"] and
              algorithm in [:weighted_random, :thompson_sampling],
       do: :ok

  defp validate_assignment_scope(:weighted_random, scope)
       when scope in [:section_enrollment, "section_enrollment"],
       do: :ok

  defp validate_assignment_scope(:thompson_sampling, scope)
       when scope in [:section_enrollment, "section_enrollment"],
       do:
         invalid_condition(
           "section-and-enrollment scope is available only for weighted random experiments",
           %{field: :assignment_scope}
         )

  defp validate_assignment_scope(_algorithm, _scope),
    do:
      invalid_condition(
        "assignment scope must be intervention or section_enrollment",
        %{field: :assignment_scope}
      )

  defp default_assignment_scope(:weighted_random), do: :section_enrollment

  defp default_assignment_scope(_algorithm), do: :intervention

  defp resolve_assignment_scope(nil, algorithm), do: default_assignment_scope(algorithm)

  defp resolve_assignment_scope(scope, _algorithm), do: scope

  defp resolve_update_assignment_scope(nil, persisted_scope), do: persisted_scope

  defp resolve_update_assignment_scope(scope, _persisted_scope), do: scope

  defp validate_locked_update(schema, request), do: validate_update_state(schema, request)

  defp validate_immutable_algorithm(_schema, nil), do: :ok

  defp validate_immutable_algorithm(%ExperimentDefinitionSchema{algorithm: algorithm}, algorithm),
    do: :ok

  defp validate_immutable_algorithm(_schema, _algorithm),
    do: invalid_condition("assignment policy cannot be changed after experiment creation")

  defp validate_configuration_request(request, scope),
    do: validate_configuration_request(request, scope, request.algorithm)

  defp validate_configuration_request(request, scope, algorithm) do
    with :ok <-
           validate_assignment_scope(
             algorithm,
             resolve_assignment_scope(Map.get(request, :assignment_scope), algorithm)
           ) do
      case structural_configuration_change?(request) do
        false ->
          :ok

        true ->
          with :ok <- validate_authoring_conditions(request.conditions),
               {:ok, revision} <-
                 resolve_authoring_revision(scope.project_slug, request.alternatives_resource_id),
               :ok <- validate_experiment_controlled_revision(revision),
               :ok <- validate_singular_mapping(revision, request.conditions),
               :ok <-
                 validate_interventions(
                   request.interventions || [],
                   scope,
                   request.alternatives_resource_id,
                   algorithm
                 ),
               :ok <-
                 PolicyConfiguration.validate(algorithm, PolicyConfiguration.from_attrs(request)) do
            :ok
          end
      end
    end
  end

  defp validate_singular_mapping(revision, conditions) do
    available_options = revision_option_ids(revision)
    normalized = Enum.map(conditions, &atomize_keys/1)
    option_ids = Enum.map(normalized, &Map.get(&1, :option_id))
    weights = Enum.map(normalized, &Map.get(&1, :weight, 1.0))

    cond do
      Enum.any?(weights, &(not is_number(&1))) ->
        invalid_condition("condition mapping weights must be numeric")

      Enum.any?(weights, &(&1 < 0)) ->
        invalid_condition("condition mapping weights must be non-negative")

      length(option_ids) != length(Enum.uniq(option_ids)) ->
        invalid_condition("Alternatives options must be mapped exactly once")

      Enum.sort(option_ids) != Enum.sort(available_options) ->
        invalid_condition(
          "condition mappings must use every group alternative exactly once",
          %{expected_option_ids: available_options}
        )

      true ->
        :ok
    end
  end

  defp validate_interventions(interventions, scope, alternatives_resource_id, algorithm) do
    interventions = Enum.map(interventions, &atomize_keys/1)

    identities =
      Enum.map(interventions, &{Map.get(&1, :page_resource_id), Map.get(&1, :content_element_id)})

    placement_validation =
      validate_experiment_placements(interventions, scope, alternatives_resource_id)

    cond do
      interventions == [] ->
        :ok

      length(identities) != length(Enum.uniq(identities)) ->
        invalid_condition("intervention identities must be unique within an experiment")

      Enum.any?(
        interventions,
        &(not valid_project_page?(scope, Map.get(&1, :page_resource_id), false))
      ) ->
        invalid_condition("intervention page is not compatible with the experiment project")

      placement_validation != :ok ->
        placement_validation

      algorithm == :thompson_sampling ->
        validate_adaptive_bindings(interventions, scope)

      Enum.any?(interventions, &(not is_nil(Map.get(&1, :assessment_binding)))) ->
        invalid_condition("weighted-random interventions cannot have assessment bindings")

      true ->
        :ok
    end
  end

  defp validate_adaptive_bindings(interventions, scope) do
    bindings = Enum.map(interventions, &Map.get(&1, :assessment_binding))

    cond do
      Enum.any?(bindings, &is_nil/1) ->
        invalid_condition("every Thompson Sampling intervention requires an assessment binding")

      true ->
        bindings = Enum.map(bindings, &atomize_keys/1)
        assessment_ids = Enum.map(bindings, &Map.get(&1, :assessment_page_resource_id))

        cond do
          length(assessment_ids) != length(Enum.uniq(assessment_ids)) ->
            invalid_condition("assessment pages must be distinct within an experiment")

          Enum.any?(assessment_ids, &(not valid_project_page?(scope, &1, true))) ->
            invalid_condition("assessment binding must reference a compatible scored page")

          true ->
            :ok
        end
    end
  end

  defp valid_project_page?(scope, resource_id, require_graded?) when is_integer(resource_id) do
    case AuthoringResolver.from_resource_id(scope.project_slug, resource_id) do
      %Revision{resource_type_id: type_id, graded: graded} ->
        type_id == ResourceType.id_for_page() and (not require_graded? or graded)

      _ ->
        false
    end
  end

  defp valid_project_page?(_scope, _resource_id, _require_graded?), do: false

  defp validate_experiment_placements(interventions, scope, alternatives_resource_id) do
    Enum.reduce_while(interventions, :ok, fn intervention, :ok ->
      case validate_experiment_placement(intervention, scope, alternatives_resource_id) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_experiment_placement(intervention, scope, alternatives_resource_id) do
    page_resource_id = Map.get(intervention, :page_resource_id)
    content_element_id = Map.get(intervention, :content_element_id)

    case AuthoringResolver.from_resource_id(scope.project_slug, page_resource_id) do
      %Revision{content: %{"model" => model}} when is_list(model) ->
        content = %{"model" => model}

        case Enum.find(
               Oli.Resources.PageContent.alternatives_placements(content),
               &(Map.get(&1, "id") == content_element_id)
             ) do
          %{"alternatives_id" => ^alternatives_resource_id} ->
            :ok

          %{"alternatives_id" => placement_alternatives_resource_id} ->
            invalid_condition(
              "intervention placement must reference the experiment Alternatives Group",
              %{
                content_element_id: content_element_id,
                expected_alternatives_resource_id: alternatives_resource_id,
                placement_alternatives_resource_id: placement_alternatives_resource_id
              }
            )

          nil ->
            invalid_missing_or_nested_placement(content, content_element_id)
        end

      _ ->
        invalid_condition("intervention placement was not found on the selected page")
    end
  end

  defp invalid_missing_or_nested_placement(content, content_element_id) do
    nested? =
      content
      |> Oli.Resources.PageContent.flat_filter(fn element ->
        Map.get(element, "type") == "alternatives" and
          Map.get(element, "id") == content_element_id
      end)
      |> Enum.any?()

    case nested? do
      true ->
        invalid_condition("Alternatives placements cannot be nested within another Alternatives")

      false ->
        invalid_condition("intervention placement was not found on the selected page")
    end
  end

  defp validate_authoring_conditions(conditions) when is_list(conditions) do
    normalized = Enum.map(conditions, &atomize_keys/1)

    cond do
      length(normalized) < 2 ->
        invalid_condition("weighted random experiments require at least two conditions")

      Enum.any?(normalized, &(Map.get(&1, :label) in [nil, ""])) ->
        invalid_condition("condition label is required")

      Enum.any?(normalized, fn condition ->
        not is_number(Map.get(condition, :weight, 1.0))
      end) ->
        invalid_condition("condition weights must be numeric")

      Enum.any?(normalized, fn condition -> Map.get(condition, :weight, 1.0) < 0 end) ->
        invalid_condition("condition weights must be non-negative")

      normalized
      |> Enum.filter(&Map.get(&1, :active, true))
      |> Enum.reduce(0.0, fn condition, total -> total + Map.get(condition, :weight, 1.0) end)
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

  defp resolve_authoring_revision(project_slug, resource_id) do
    case AuthoringResolver.from_resource_id(project_slug, resource_id) do
      %Revision{} = revision ->
        case revision.resource_type_id == ResourceType.id_for_alternatives() do
          true -> {:ok, revision}
          false -> invalid_condition("selected resource is not an alternatives group")
        end

      nil ->
        not_found("alternatives resource is not in the project working publication", %{
          alternatives_resource_id: resource_id
        })
    end
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

  defp authoring_payload_key("title"), do: :title

  defp authoring_payload_key("position"), do: :position

  defp authoring_payload_key("algorithm"), do: :algorithm

  defp authoring_payload_key("prior_alpha"), do: :prior_alpha

  defp authoring_payload_key("prior_beta"), do: :prior_beta

  defp authoring_payload_key("warm_up_assignments"), do: :warm_up_assignments

  defp authoring_payload_key("max_condition_share"), do: :max_condition_share

  defp authoring_payload_key("fixed_control_allocation"), do: :fixed_control_allocation

  defp authoring_payload_key("imbalance_threshold"), do: :imbalance_threshold

  defp authoring_payload_key("reward_source"), do: :reward_source

  defp authoring_payload_key("client_ref"), do: :client_ref

  defp authoring_payload_key("id"), do: :id

  defp authoring_payload_key("condition_ref"), do: :condition_ref

  defp authoring_payload_key("condition_id"), do: :condition_id

  defp authoring_payload_key("mappings"), do: :mappings

  defp authoring_payload_key("interventions"), do: :interventions

  defp authoring_payload_key("page_resource_id"), do: :page_resource_id

  defp authoring_payload_key("content_element_id"), do: :content_element_id

  defp authoring_payload_key("assessment_binding"), do: :assessment_binding

  defp authoring_payload_key("assessment_page_resource_id"), do: :assessment_page_resource_id

  defp authoring_payload_key("reward_threshold"), do: :reward_threshold

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
          section_ids: Enum.map(schema.sections, & &1.id)
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
          section_ids: Enum.map(schema.sections, & &1.id),
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

  defp structural_configuration_change?(%{
         alternatives_resource_id: resource_id,
         interventions: interventions,
         conditions: conditions
       })
       when is_nil(resource_id) and interventions in [nil, []] and conditions in [nil, []],
       do: false

  defp structural_configuration_change?(_request), do: true

  defp maybe_require_authoring_scope(_scope, false), do: :ok

  defp maybe_require_authoring_scope(scope, true), do: require_authoring_access(scope)
end
