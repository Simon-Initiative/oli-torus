defmodule Oli.Experiments.ActivationValidator do
  @moduledoc """
  Validates that a draft experiment is complete and compatible with its deployed content.
  """

  import Ecto.Query

  alias Oli.Authoring.Course.Project
  alias Oli.Experiments.{ExperimentError, PolicyConfiguration}
  alias Oli.Experiments.Policies.ThompsonSampling
  alias Oli.Experiments.Schemas.{Condition, ExperimentDefinition, Intervention}
  alias Oli.Publishing.{AuthoringResolver, DeliveryResolver}
  alias Oli.Repo
  alias Oli.Resources.{ResourceType, Revision}

  @doc false
  def validate(%ExperimentDefinition{} = schema) do
    conditions = active_conditions(schema.id)

    interventions =
      from(intervention in Intervention,
        where: intervention.experiment_id == ^schema.id,
        preload: :assessment_binding
      )
      |> Repo.all()

    with :ok <- validate_assignment_scope(schema),
         {:ok, revisions} <- activation_revisions(schema),
         :ok <- validate_experiment_strategies(revisions),
         :ok <- validate_minimum_active_conditions(conditions),
         :ok <- validate_positive_active_weight(conditions),
         :ok <- validate_condition_option_mappings(revisions, conditions),
         :ok <- validate_interventions(schema, interventions),
         :ok <- validate_adaptive_policy(schema, conditions) do
      :ok
    end
  end

  defp validate_assignment_scope(%ExperimentDefinition{
         algorithm: :thompson_sampling,
         assignment_scope: scope
       })
       when scope != :intervention,
       do:
         invalid_condition(
           "section-and-enrollment scope is available only for weighted random experiments"
         )

  defp validate_assignment_scope(_experiment), do: :ok

  defp active_conditions(experiment_id) do
    Repo.all(
      from condition in Condition,
        where: condition.experiment_id == ^experiment_id and condition.active == true,
        order_by: [asc: condition.position, asc: condition.id]
    )
  end

  defp validate_interventions(experiment, interventions) do
    cond do
      experiment.algorithm == :thompson_sampling and interventions == [] ->
        invalid_condition("Thompson Sampling requires at least one intervention")

      experiment.algorithm == :thompson_sampling and
          Enum.any?(interventions, &is_nil(&1.assessment_binding)) ->
        invalid_condition("every Thompson Sampling intervention requires an assessment binding")

      experiment.algorithm == :weighted_random and
          Enum.any?(interventions, &(not is_nil(&1.assessment_binding))) ->
        invalid_condition("weighted-random interventions cannot have assessment bindings")

      true ->
        :ok
    end
  end

  defp validate_adaptive_policy(%ExperimentDefinition{algorithm: :weighted_random}, _conditions),
    do: :ok

  defp validate_adaptive_policy(
         %ExperimentDefinition{algorithm: :thompson_sampling} = experiment,
         conditions
       ) do
    policy_config = policy_config(experiment)

    with :ok <- PolicyConfiguration.validate(:thompson_sampling, policy_config),
         {:ok, _state} <- ThompsonSampling.initial_state(policy_config, conditions) do
      :ok
    else
      {:error, reason} ->
        invalid_condition("Thompson Sampling policy state could not be initialized", %{
          reason: inspect(reason)
        })
    end
  end

  defp validate_minimum_active_conditions(conditions) do
    case length(conditions) >= 2 do
      true ->
        :ok

      false ->
        invalid_condition("weighted random experiments require at least two active conditions")
    end
  end

  defp validate_positive_active_weight(conditions) do
    total = Enum.reduce(conditions, 0.0, fn condition, sum -> sum + (condition.weight || 0.0) end)

    if total > 0.0,
      do: :ok,
      else: invalid_condition("active condition weights must have a positive total")
  end

  defp validate_condition_option_mappings(revisions, conditions) do
    Enum.reduce_while(revisions, :ok, fn revision, :ok ->
      case validate_condition_option_mapping(revision, conditions) do
        :ok -> {:cont, :ok}
        {:error, %ExperimentError{}} = error -> {:halt, error}
      end
    end)
  end

  @doc false
  def validate_condition_option_mapping(revision, conditions) do
    missing =
      Enum.reject(
        conditions,
        &((&1.option_id || &1.condition_code) in revision_option_ids(revision))
      )

    case missing do
      [] ->
        :ok

      _ ->
        invalid_condition(
          "experiment conditions must match the currently resolved alternatives options",
          %{
            alternatives_revision_id: revision.id,
            missing_option_ids: Enum.map(missing, &(&1.option_id || &1.condition_code))
          }
        )
    end
  end

  defp activation_revisions(%ExperimentDefinition{sections: []} = schema) do
    project = Repo.get!(Project, schema.project_id)

    case AuthoringResolver.from_resource_id(project.slug, schema.alternatives_resource_id) do
      %Revision{resource_type_id: type_id} = revision ->
        if type_id == ResourceType.id_for_alternatives(),
          do: {:ok, [revision]},
          else: invalid_condition("selected resource is not an alternatives group")

      nil ->
        {:error,
         %ExperimentError{
           type: :not_found,
           message: "alternatives resource is not in the project working publication",
           details: %{alternatives_resource_id: schema.alternatives_resource_id}
         }}
    end
  end

  defp activation_revisions(schema) do
    resolved =
      Enum.map(schema.sections, fn section ->
        {section.id,
         DeliveryResolver.from_resource_id(section.slug, schema.alternatives_resource_id)}
      end)

    case for({section_id, nil} <- resolved, do: section_id) do
      [] ->
        {:ok, Enum.map(resolved, &elem(&1, 1))}

      missing ->
        invalid_condition("alternatives content is not deployed to every experiment section", %{
          missing_section_ids: missing
        })
    end
  end

  defp validate_experiment_strategies(revisions) do
    Enum.reduce_while(revisions, :ok, fn revision, :ok ->
      case get_in(revision.content || %{}, ["strategy"]) in [
             "experiment_controlled",
             "upgrade_decision_point"
           ] do
        true ->
          {:cont, :ok}

        false ->
          {:halt, invalid_condition("selected Alternatives Group is not experiment-controlled")}
      end
    end)
  end

  defp revision_option_ids(%Revision{content: %{"options" => options}}) when is_list(options),
    do: Enum.map(options, &(Map.get(&1, "id") || Map.get(&1, :id) || Map.get(&1, "name")))

  defp revision_option_ids(_revision), do: []

  defp policy_config(experiment) do
    %{
      "reward_source" => experiment.reward_source,
      "priors" => %{
        "default" => %{"alpha" => experiment.prior_alpha, "beta" => experiment.prior_beta}
      },
      "guardrails" => %{
        "warm_up_assignments" => experiment.warm_up_assignments,
        "max_condition_share" => experiment.max_condition_share,
        "fixed_control_allocation" => experiment.fixed_control_allocation,
        "imbalance_threshold" => experiment.imbalance_threshold
      }
    }
  end

  defp invalid_condition(message, details \\ %{}) do
    {:error, %ExperimentError{type: :invalid_condition, message: message, details: details}}
  end
end
