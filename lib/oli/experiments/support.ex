defmodule Oli.Experiments.Support do
  @moduledoc false

  # Helpers shared by the experiment queries in `Oli.Experiments` and the audited configuration
  # writers in `Oli.Experiments.Audited.Writes`: scope and access checks, experiment lookup,
  # section participation, policy state, and error construction. Not part of the public API, and
  # nothing here writes experiment configuration.

  import Ecto.Changeset
  import Ecto.Query

  alias Oli.Delivery.Sections.{Section, SectionsProjectsPublications}

  alias Oli.Experiments.{
    EligibleExperimentSection,
    ExperimentDefinition,
    ExperimentError,
    ExperimentSectionParticipation,
    Queries,
    ScopeValidator
  }

  alias Oli.Experiments.Schemas.{Assignment, Condition, PolicyState}
  alias Oli.Experiments.Policies.ThompsonSampling
  alias Oli.Experiments.Schemas.ExperimentDefinition, as: ExperimentDefinitionSchema
  alias Oli.Repo
  alias Oli.Resources.Revision

  defp maybe_filter_section_institution(query, institution_id),
    do: Queries.maybe_filter_section_institution(query, institution_id)

  def experiment_policy_config(%ExperimentDefinitionSchema{} = experiment) do
    %{
      "reward_source" => experiment.reward_source,
      "priors" => %{
        "default" => %{
          "alpha" => experiment.prior_alpha,
          "beta" => experiment.prior_beta
        }
      },
      "guardrails" => %{
        "warm_up_assignments" => experiment.warm_up_assignments,
        "max_condition_share" => experiment.max_condition_share,
        "fixed_control_allocation" => experiment.fixed_control_allocation,
        "imbalance_threshold" => experiment.imbalance_threshold
      }
    }
  end

  def get_policy_state(experiment_id, algorithm) do
    Repo.get_by(PolicyState,
      experiment_id: experiment_id,
      algorithm: algorithm
    )
  end

  def get_or_create_policy_state(experiment) do
    case get_policy_state(experiment.id, experiment.algorithm) do
      nil ->
        {algorithm_version, state} =
          initial_policy_state_attrs(experiment)

        %PolicyState{}
        |> PolicyState.changeset(%{
          experiment_id: experiment.id,
          algorithm: experiment.algorithm,
          algorithm_version: algorithm_version,
          state: state,
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
         %ExperimentDefinitionSchema{algorithm: :thompson_sampling} = experiment
       ) do
    conditions = active_conditions(experiment.id)

    policy_config = experiment_policy_config(experiment)

    {:ok, state} = ThompsonSampling.initial_state(policy_config, conditions)

    {ThompsonSampling.version(), state}
  end

  defp initial_policy_state_attrs(%ExperimentDefinitionSchema{algorithm: algorithm}) do
    {Atom.to_string(algorithm), %{}}
  end

  def eligible_sections_query(scope) do
    Section
    |> join(:inner, [section], spp in SectionsProjectsPublications,
      on: spp.section_id == section.id
    )
    |> where(
      [section, spp],
      spp.project_id == ^scope.project_id and section.status == :active
    )
    |> maybe_filter_section_institution(scope.institution_id)
    |> distinct([section], section.id)
  end

  def section_participation(schema, scope) do
    eligible_sections =
      scope
      |> eligible_sections_query()
      |> order_by([section], asc: section.title, asc: section.id)
      |> select([section], %EligibleExperimentSection{
        id: section.id,
        slug: section.slug,
        title: section.title,
        status: section.status,
        start_date: section.start_date,
        end_date: section.end_date
      })
      |> Repo.all()

    eligible_ids = MapSet.new(eligible_sections, & &1.id)

    selected_ids =
      schema.sections |> Enum.map(& &1.id) |> Enum.filter(&MapSet.member?(eligible_ids, &1))

    stale_sections =
      schema.sections
      |> Enum.reject(&MapSet.member?(eligible_ids, &1.id))
      |> Enum.sort_by(&{&1.title, &1.id})
      |> Enum.map(&to_eligible_section/1)

    %ExperimentSectionParticipation{
      experiment_id: schema.id,
      eligible_sections: eligible_sections,
      selected_ids: Enum.sort(selected_ids),
      stale_sections: stale_sections
    }
  end

  defp to_eligible_section(%Section{} = section) do
    %EligibleExperimentSection{
      id: section.id,
      slug: section.slug,
      title: section.title,
      status: section.status,
      start_date: section.start_date,
      end_date: section.end_date
    }
  end

  def get_scoped_definition(experiment_id, scope) do
    with {:ok, scope} <- validate_scope(scope),
         %ExperimentDefinitionSchema{} = schema <-
           Repo.one(
             from(experiment in ExperimentDefinitionSchema,
               where: experiment.id == ^experiment_id,
               preload: :sections
             )
           ),
         :ok <- ensure_definition_in_scope(schema, scope) do
      {:ok, schema}
    else
      nil -> not_found("experiment not found", %{experiment_id: experiment_id})
      {:error, %ExperimentError{}} = error -> error
    end
  end

  def active_conditions(experiment_id) do
    Repo.all(
      from condition in Condition,
        where: condition.experiment_id == ^experiment_id and condition.active == true,
        order_by: [asc: condition.position, asc: condition.id]
    )
  end

  def experiment_controlled_revision?(%Revision{} = revision) do
    get_in(revision.content || %{}, ["strategy"]) in [
      "experiment_controlled",
      "upgrade_decision_point"
    ]
  end

  def validate_experiment_controlled_revision(%Revision{} = revision) do
    if experiment_controlled_revision?(revision) do
      :ok
    else
      invalid_condition("selected Alternatives Group is not experiment-controlled")
    end
  end

  def assignment_counts_by_condition(experiment_id) do
    from(assignment in Assignment,
      where: assignment.experiment_id == ^experiment_id,
      group_by: assignment.condition_id,
      select: {assignment.condition_id, count(assignment.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  def normalize_transaction_result({:ok, schema}), do: {:ok, schema}

  def normalize_transaction_result({:error, %Ecto.Changeset{} = changeset}),
    do: normalize_result({:error, changeset})

  def normalize_transaction_result({:error, %ExperimentError{} = error}), do: {:error, error}

  def normalize_transaction_result({:error, reason}) do
    {:error,
     %ExperimentError{
       type: :persistence_error,
       message: "experiment graph could not be persisted",
       details: %{reason: inspect(reason)}
     }}
  end

  def normalize_transaction_result({:error, _operation, %Ecto.Changeset{} = changeset, _changes}),
    do: normalize_result({:error, changeset})

  def normalize_transaction_result({:error, _operation, reason, _changes}),
    do: normalize_transaction_result({:error, reason})

  def normalize_transaction_result(result), do: result

  def revision_option_ids(%Revision{content: %{"options" => options}}) when is_list(options) do
    Enum.map(options, &(Map.get(&1, "id") || Map.get(&1, :id) || Map.get(&1, "name")))
  end

  def revision_option_ids(_revision), do: []

  def require_authoring_access(scope), do: ScopeValidator.require_authoring_access(scope)

  def require_authoring_scope(scope), do: ScopeValidator.require_authoring_scope(scope)

  def require_eligible_section_reader(scope),
    do: ScopeValidator.require_eligible_section_reader(scope)

  def validate_scope(scope), do: ScopeValidator.validate_scope(scope)

  def ensure_definition_in_scope(schema, scope),
    do: ScopeValidator.ensure_definition_in_scope(schema, scope)

  def to_definition(%ExperimentDefinitionSchema{} = schema) do
    %ExperimentDefinition{
      id: schema.id,
      uuid: schema.uuid,
      project_id: schema.project_id,
      section_ids: Enum.map(schema.sections, & &1.id),
      slug: schema.slug,
      name: schema.name,
      description: schema.description,
      state: schema.state,
      assignment_unit: schema.assignment_unit,
      assignment_scope: schema.assignment_scope,
      algorithm: schema.algorithm,
      alternatives_resource_id: schema.alternatives_resource_id,
      prior_alpha: schema.prior_alpha,
      prior_beta: schema.prior_beta,
      warm_up_assignments: schema.warm_up_assignments,
      max_condition_share: schema.max_condition_share,
      fixed_control_allocation: schema.fixed_control_allocation,
      imbalance_threshold: schema.imbalance_threshold,
      reward_source: schema.reward_source,
      started_at: schema.started_at,
      ended_at: schema.ended_at
    }
  end

  def normalize_result({:error, %Ecto.Changeset{} = changeset}) do
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

  defp changeset_errors(changeset) do
    traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  def invalid_request(message) do
    {:error, %ExperimentError{type: :persistence_error, message: message}}
  end

  def invalid_scope(message, details \\ %{}) do
    {:error, %ExperimentError{type: :invalid_scope, message: message, details: details}}
  end

  def not_found(message, details) do
    {:error, %ExperimentError{type: :not_found, message: message, details: details}}
  end

  def invalid_condition(message, details \\ %{}) do
    {:error, %ExperimentError{type: :invalid_condition, message: message, details: details}}
  end

  def invalid_state(message, details) do
    {:error, %ExperimentError{type: :invalid_state, message: message, details: details}}
  end
end
