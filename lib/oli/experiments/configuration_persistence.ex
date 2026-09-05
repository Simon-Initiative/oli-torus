defmodule Oli.Experiments.ConfigurationPersistence do
  @moduledoc """
  Persists an experiment definition and its owned configuration atomically.
  """

  import Ecto.Query

  alias Oli.Experiments.ExperimentError

  alias Oli.Experiments.Schemas.{
    AssessmentBinding,
    Condition,
    ExperimentDefinition,
    ExperimentSection,
    Intervention,
    PolicyState
  }

  alias Oli.Repo

  def insert(attrs, request, section_ids, policy_state_initializer, normalize) do
    case structural_configuration_change?(request) do
      false ->
        insert_definition(attrs, section_ids, normalize)

      true ->
        Repo.transaction(fn ->
          changeset =
            %ExperimentDefinition{}
            |> ExperimentDefinition.changeset(attrs)

          case Repo.insert(changeset) do
            {:ok, definition} ->
              replace_experiment_sections!(definition.id, section_ids)

              insert_conditions!(definition.id, request.conditions)
              insert_interventions!(definition.id, request.interventions || [])
              policy_state_initializer.(definition)
              Repo.preload(definition, :sections)

            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        end)
        |> normalize.()
    end
  end

  def update(
        schema,
        attrs,
        request,
        section_ids,
        policy_state_initializer,
        locked_update_validator,
        normalize
      ) do
    case structural_configuration_change?(request) do
      false ->
        update_definition(
          schema,
          attrs,
          request.section_ids,
          section_ids,
          request,
          locked_update_validator,
          normalize
        )

      true ->
        Repo.transaction(fn ->
          Repo.query!("SELECT pg_advisory_xact_lock($1)", [schema.id])
          locked = lock_experiment!(schema.id)
          validate_locked_update!(locked, request, locked_update_validator)

          updated =
            locked
            |> ExperimentDefinition.changeset(attrs)
            |> Repo.update!()

          maybe_replace_experiment_sections!(updated.id, request.section_ids, section_ids)
          replace_experiment_configuration!(updated, request, policy_state_initializer)
          Repo.preload(updated, :sections, force: true)
        end)
        |> normalize.()
    end
  end

  defp replace_experiment_configuration!(schema, request, policy_state_initializer) do
    delete_draft_configuration!(schema.id, preserve_conditions: true)
    reconcile_conditions!(schema.id, request.conditions)
    insert_interventions!(schema.id, request.interventions || [])
    policy_state_initializer.(schema)
  end

  defp reconcile_conditions!(experiment_id, conditions) do
    existing =
      from(condition in Condition, where: condition.experiment_id == ^experiment_id)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    incoming_ids =
      conditions
      |> Enum.map(&atomize_keys/1)
      |> Enum.map(&Map.get(&1, :id))
      |> Enum.reject(&is_nil/1)

    unknown_ids = incoming_ids -- Map.keys(existing)

    if unknown_ids != [] do
      {:error, error} =
        invalid_condition("condition does not belong to experiment", %{
          condition_ids: unknown_ids
        })

      Repo.rollback(error)
    end

    omitted_ids = Map.keys(existing) -- incoming_ids

    if omitted_ids != [] do
      from(condition in Condition, where: condition.id in ^omitted_ids)
      |> Repo.delete_all()
    end

    used_codes = existing |> Map.values() |> Enum.map(& &1.condition_code) |> MapSet.new()

    conditions
    |> Enum.with_index()
    |> Enum.map_reduce(used_codes, fn {condition_attrs, position}, codes ->
      attrs = atomize_keys(condition_attrs)

      case Map.get(attrs, :id) do
        nil ->
          client_ref = Map.get(attrs, :client_ref)
          code = next_condition_code(Map.get(attrs, :label), codes)

          condition =
            %Condition{}
            |> Condition.changeset(%{
              experiment_id: experiment_id,
              condition_code: code,
              option_id: Map.get(attrs, :option_id),
              label: Map.get(attrs, :label),
              weight: Map.get(attrs, :weight, 1.0),
              active: Map.get(attrs, :active, true),
              position: Map.get(attrs, :position, position)
            })
            |> Repo.insert!()

          {{client_ref, condition}, MapSet.put(codes, code)}

        id ->
          condition = Map.fetch!(existing, id)

          updated =
            condition
            |> Condition.changeset(%{
              label: Map.get(attrs, :label, condition.label),
              option_id: Map.get(attrs, :option_id, condition.option_id),
              weight: Map.get(attrs, :weight, condition.weight),
              active: Map.get(attrs, :active, condition.active),
              position: Map.get(attrs, :position, position)
            })
            |> Repo.update!()

          {{id, updated}, codes}
      end
    end)
    |> elem(0)
    |> Map.new()
  end

  defp insert_conditions!(experiment_id, conditions) do
    conditions
    |> Enum.with_index()
    |> Enum.map_reduce(MapSet.new(), fn {condition, position}, used_codes ->
      attrs = atomize_keys(condition)
      client_ref = Map.get(attrs, :client_ref)
      code = next_condition_code(Map.get(attrs, :label), used_codes)

      inserted =
        %Condition{}
        |> Condition.changeset(%{
          experiment_id: experiment_id,
          condition_code: code,
          option_id: Map.get(attrs, :option_id),
          label: Map.get(attrs, :label),
          weight: Map.get(attrs, :weight, 1.0),
          active: Map.get(attrs, :active, true),
          position: Map.get(attrs, :position, position)
        })
        |> Repo.insert!()

      {{client_ref, inserted}, MapSet.put(used_codes, code)}
    end)
    |> elem(0)
    |> Map.new()
  end

  defp insert_interventions!(experiment_id, interventions) do
    Enum.each(interventions, &insert_intervention!(experiment_id, &1))
  end

  defp insert_intervention!(experiment_id, attrs) do
    attrs = atomize_keys(attrs)

    intervention =
      %Intervention{}
      |> Intervention.changeset(%{
        experiment_id: experiment_id,
        page_resource_id: Map.get(attrs, :page_resource_id),
        content_element_id: Map.get(attrs, :content_element_id)
      })
      |> Repo.insert!()

    case Map.get(attrs, :assessment_binding) do
      nil ->
        intervention

      binding ->
        binding = atomize_keys(binding)

        %AssessmentBinding{}
        |> AssessmentBinding.changeset(%{
          intervention_id: intervention.id,
          assessment_page_resource_id: Map.get(binding, :assessment_page_resource_id),
          reward_threshold: Map.get(binding, :reward_threshold, Decimal.new(1))
        })
        |> Repo.insert!()
    end
  end

  defp delete_draft_configuration!(experiment_id, options) do
    intervention_ids =
      from(intervention in Intervention,
        where: intervention.experiment_id == ^experiment_id,
        select: intervention.id
      )

    from(binding in AssessmentBinding,
      where: binding.intervention_id in subquery(intervention_ids)
    )
    |> Repo.delete_all()

    from(intervention in Intervention,
      where: intervention.experiment_id == ^experiment_id
    )
    |> Repo.delete_all()

    from(policy_state in PolicyState, where: policy_state.experiment_id == ^experiment_id)
    |> Repo.delete_all()

    unless Keyword.get(options, :preserve_conditions, false) do
      from(condition in Condition, where: condition.experiment_id == ^experiment_id)
      |> Repo.delete_all()
    end
  end

  @doc false
  def lock_experiment!(experiment_id) do
    Repo.one!(
      from(experiment in ExperimentDefinition,
        where: experiment.id == ^experiment_id,
        lock: "FOR UPDATE"
      )
    )
  end

  defp next_condition_code(label, used_codes) do
    base =
      case Oli.Utils.Slug.slugify(label) do
        "" -> "condition"
        slug -> slug
      end

    Stream.iterate(1, &(&1 + 1))
    |> Enum.find_value(fn
      1 ->
        if MapSet.member?(used_codes, base), do: nil, else: base

      suffix ->
        candidate = "#{base}-#{suffix}"
        if MapSet.member?(used_codes, candidate), do: nil, else: candidate
    end)
  end

  defp insert_definition(attrs, section_ids, normalize) do
    Repo.transaction(fn ->
      changeset =
        %ExperimentDefinition{}
        |> ExperimentDefinition.changeset(attrs)

      case Repo.insert(changeset) do
        {:ok, definition} ->
          replace_experiment_sections!(definition.id, section_ids)
          Repo.preload(definition, :sections)

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> normalize.()
  end

  defp update_definition(
         schema,
         attrs,
         requested_section_ids,
         section_ids,
         request,
         locked_update_validator,
         normalize
       ) do
    Repo.transaction(fn ->
      Repo.query!("SELECT pg_advisory_xact_lock($1)", [schema.id])
      locked = lock_experiment!(schema.id)
      validate_locked_update!(locked, request, locked_update_validator)

      updated =
        locked
        |> ExperimentDefinition.changeset(attrs)
        |> Repo.update!()

      maybe_replace_experiment_sections!(updated.id, requested_section_ids, section_ids)
      Repo.preload(updated, :sections, force: true)
    end)
    |> normalize.()
  end

  defp validate_locked_update!(schema, request, validator) do
    case validator.(schema, request) do
      :ok -> :ok
      {:error, %ExperimentError{} = error} -> Repo.rollback(error)
    end
  end

  defp maybe_replace_experiment_sections!(_experiment_id, nil, _section_ids), do: :ok

  defp maybe_replace_experiment_sections!(experiment_id, _requested_section_ids, section_ids),
    do: replace_experiment_sections!(experiment_id, section_ids)

  @doc false
  def replace_experiment_sections!(experiment_id, section_ids) do
    from(experiment_section in ExperimentSection,
      where: experiment_section.experiment_id == ^experiment_id
    )
    |> Repo.delete_all()

    timestamp = now()

    section_ids
    |> Enum.map(fn section_id ->
      %{
        experiment_id: experiment_id,
        section_id: section_id,
        inserted_at: timestamp,
        updated_at: timestamp
      }
    end)
    |> case do
      [] -> :ok
      rows -> Repo.insert_all(ExperimentSection, rows)
    end
  end

  defp atomize_keys(nil), do: %{}

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {payload_key(key), value}
      pair -> pair
    end)
  end

  @payload_keys ~w(alternatives_resource_id title position algorithm prior_alpha prior_beta warm_up_assignments max_condition_share fixed_control_allocation imbalance_threshold reward_source client_ref id condition_ref condition_id mappings interventions page_resource_id content_element_id assessment_binding assessment_page_resource_id reward_threshold condition_code option_id label weight active)a
  defp payload_key(key), do: Enum.find(@payload_keys, &(Atom.to_string(&1) == key))

  defp structural_configuration_change?(%{
         alternatives_resource_id: resource_id,
         interventions: interventions,
         conditions: conditions
       })
       when is_nil(resource_id) and interventions in [nil, []] and conditions in [nil, []],
       do: false

  defp structural_configuration_change?(_request), do: true

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp invalid_condition(message, details),
    do: {:error, %ExperimentError{type: :invalid_condition, message: message, details: details}}
end
