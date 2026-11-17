defmodule Oli.Experiments.Audited do
  @moduledoc """
  Application boundary for audited changes to native A/B experiment definitions.

  Each command records one `project_settings_changed` for the experiment's project, with the
  experiment's ID in `details.experiment_id` and up to three changed keys:

    * `experiment_status` - the lifecycle state (`draft`, `active`, `paused`, `completed`,
      `archived`).
    * `experiment_conditions` - the conditions, in order, with their code, label, alternatives
      option, availability, and weight.
    * `experiment_definition` - every other setting of the definition: name, description,
      algorithm and policy parameters, assignment unit and scope, reward source, alternatives
      group, interventions (pages and content elements) with their assessment bindings, and the
      participating sections.

  Values are compared by IDs only, so renaming a page does not count as a change of the
  experiment; recorded values carry page, alternatives, and section titles to be readable. A
  command that changes nothing records nothing. The writes keep their existing validation and
  errors; the before state is read inside the same transaction, after locking the definition.

  Commands do not authorize the actor; the experiment requests keep carrying their own scope.
  The writes live in the private `Oli.Experiments.Audited.Writes`, so this module is the only
  way to change an experiment's configuration.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  import Ecto.Query, only: [from: 2]

  alias Oli.Auditing
  alias Oli.Auditing.{Changes, Context}
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Experiments.Audited.Writes

  alias Oli.Experiments.{
    CreateExperimentRequest,
    LifecycleRequest,
    Scope,
    UpdateExperimentRequest
  }

  alias Oli.Experiments.Schemas.{
    AssessmentBinding,
    Condition,
    ExperimentDefinition,
    ExperimentSection,
    Intervention
  }

  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo

  @policy %{
    experiment_status: :value,
    experiment_conditions: :value,
    experiment_definition: :value
  }

  @definition_fields ~w(name description algorithm assignment_unit assignment_scope prior_alpha
    prior_beta warm_up_assignments max_condition_share fixed_control_allocation
    imbalance_threshold reward_source)a

  @transitions %{
    activate: :activate_experiment,
    pause: :pause_experiment,
    complete: :complete_experiment,
    archive: :archive_experiment
  }

  @doc "Creates an experiment definition and records its initial state, conditions, and settings."
  @spec create_experiment(Context.t(), CreateExperimentRequest.t()) ::
          {:ok, term()} | {:error, term()}
  def create_experiment(%Context{} = context, %CreateExperimentRequest{} = request) do
    audited(context, nil, fn -> Writes.create_experiment(request) end)
  end

  def create_experiment(_context, _request), do: {:error, :invalid_request}

  @doc "Updates a draft experiment definition and records what changed."
  @spec update_experiment(Context.t(), pos_integer(), UpdateExperimentRequest.t()) ::
          {:ok, term()} | {:error, term()}
  def update_experiment(%Context{} = context, experiment_id, %UpdateExperimentRequest{} = request)
      when is_integer(experiment_id) do
    audited(context, experiment_id, fn ->
      Writes.update_experiment(experiment_id, request)
    end)
  end

  def update_experiment(_context, _experiment_id, _request), do: {:error, :invalid_request}

  @doc "Changes condition availability and weights, and records the conditions that changed."
  @spec update_condition_availabilities(Context.t(), pos_integer(), [map()], Scope.t()) ::
          {:ok, term()} | {:error, term()}
  def update_condition_availabilities(
        %Context{} = context,
        experiment_id,
        availabilities,
        %Scope{} = scope
      )
      when is_integer(experiment_id) do
    audited(context, experiment_id, fn ->
      Writes.update_condition_availabilities(experiment_id, availabilities, scope)
    end)
  end

  def update_condition_availabilities(_context, _experiment_id, _availabilities, _scope),
    do: {:error, :invalid_request}

  @doc "Changes whether one condition is eligible for new assignments, and records the change."
  @spec update_condition_availability(
          Context.t(),
          pos_integer(),
          pos_integer(),
          boolean(),
          Scope.t()
        ) ::
          {:ok, term()} | {:error, term()}
  def update_condition_availability(
        %Context{} = context,
        experiment_id,
        condition_id,
        active,
        %Scope{} = scope
      )
      when is_integer(experiment_id) do
    audited(context, experiment_id, fn ->
      Writes.update_condition_availability(experiment_id, condition_id, active, scope)
    end)
  end

  def update_condition_availability(_context, _experiment_id, _condition_id, _active, _scope),
    do: {:error, :invalid_request}

  @doc """
  Replaces the sections an experiment runs in, and records the change in its definition.
  Returns the updated section participation.
  """
  @spec update_section_participation(Context.t(), pos_integer(), Scope.t(), [pos_integer()]) ::
          {:ok, term()} | {:error, term()}
  def update_section_participation(
        %Context{} = context,
        experiment_id,
        %Scope{} = scope,
        section_ids
      )
      when is_integer(experiment_id) do
    audited(context, experiment_id, fn ->
      Writes.update_section_participation(experiment_id, scope, section_ids)
    end)
  end

  def update_section_participation(_context, _experiment_id, _scope, _section_ids),
    do: {:error, :invalid_request}

  @doc "Removes a condition from a draft experiment, and records the conditions that changed."
  @spec remove_condition(Context.t(), pos_integer(), pos_integer(), Scope.t()) ::
          {:ok, term()} | {:error, term()}
  def remove_condition(%Context{} = context, experiment_id, condition_id, %Scope{} = scope)
      when is_integer(experiment_id) do
    audited(context, experiment_id, fn ->
      Writes.remove_condition(experiment_id, condition_id, scope)
    end)
  end

  def remove_condition(_context, _experiment_id, _condition_id, _scope),
    do: {:error, :invalid_request}

  @doc "Removes an intervention from a draft experiment, and records the change in its definition."
  @spec remove_intervention(Context.t(), pos_integer(), pos_integer(), Scope.t()) ::
          {:ok, term()} | {:error, term()}
  def remove_intervention(%Context{} = context, experiment_id, intervention_id, %Scope{} = scope)
      when is_integer(experiment_id) do
    audited(context, experiment_id, fn ->
      Writes.remove_intervention(experiment_id, intervention_id, scope)
    end)
  end

  def remove_intervention(_context, _experiment_id, _intervention_id, _scope),
    do: {:error, :invalid_request}

  @doc """
  Removes an assessment binding from a draft experiment, and records the change in its
  definition.
  """
  @spec remove_assessment_binding(Context.t(), pos_integer(), pos_integer(), Scope.t()) ::
          {:ok, term()} | {:error, term()}
  def remove_assessment_binding(%Context{} = context, experiment_id, binding_id, %Scope{} = scope)
      when is_integer(experiment_id) do
    audited(context, experiment_id, fn ->
      Writes.remove_assessment_binding(experiment_id, binding_id, scope)
    end)
  end

  def remove_assessment_binding(_context, _experiment_id, _binding_id, _scope),
    do: {:error, :invalid_request}

  @doc """
  Moves an experiment through its lifecycle (`:activate`, `:pause`, `:complete`, or `:archive`)
  and records the status change.
  """
  @spec transition_experiment(
          Context.t(),
          pos_integer(),
          :activate | :pause | :complete | :archive,
          LifecycleRequest.t()
        ) :: {:ok, term()} | {:error, term()}
  def transition_experiment(
        %Context{} = context,
        experiment_id,
        action,
        %LifecycleRequest{} = request
      )
      when is_integer(experiment_id) and is_map_key(@transitions, action) do
    function = Map.fetch!(@transitions, action)

    audited(context, experiment_id, fn ->
      apply(Writes, function, [experiment_id, request])
    end)
  end

  def transition_experiment(_context, _experiment_id, _action, _request),
    do: {:error, :invalid_request}

  # Locks the definition, reads its state, runs `write` (its own transaction becomes a savepoint),
  # and records the keys whose values changed. `experiment_id` is nil for a creation.
  defp audited(context, experiment_id, write) do
    Repo.transaction(fn ->
      with {:ok, before} <- before_state(experiment_id),
           {:ok, result} <- write.(),
           id = experiment_id || result.id,
           {:ok, after_state} <- state(id),
           :ok <- record(context, id, before, after_state) do
        result
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp before_state(nil), do: {:ok, nil}

  defp before_state(experiment_id) do
    from(d in ExperimentDefinition, where: d.id == ^experiment_id, lock: "FOR UPDATE")
    |> Repo.one()
    |> case do
      # A missing experiment is reported by the write with its usual error
      nil -> {:ok, nil}
      _definition -> state(experiment_id)
    end
  end

  # The compared state: IDs and values only, in a fixed order.
  defp state(experiment_id) do
    case Repo.get(ExperimentDefinition, experiment_id) do
      nil ->
        {:error, :not_found}

      definition ->
        {:ok,
         %{
           project_id: definition.project_id,
           experiment_status: Atom.to_string(definition.state),
           experiment_conditions: conditions(experiment_id),
           experiment_definition: definition_settings(definition)
         }}
    end
  end

  defp conditions(experiment_id) do
    from(c in Condition, where: c.experiment_id == ^experiment_id, order_by: [c.position, c.id])
    |> Repo.all()
    |> Enum.map(fn condition ->
      %{
        "condition_code" => condition.condition_code,
        "label" => condition.label,
        "option_id" => condition.option_id,
        "active" => condition.active,
        "weight" => condition.weight
      }
    end)
  end

  defp definition_settings(definition) do
    definition
    |> Map.take(@definition_fields)
    |> Map.new(fn {key, value} -> {Atom.to_string(key), plain(value)} end)
    |> Map.merge(%{
      "alternatives_resource_id" => definition.alternatives_resource_id,
      "interventions" => interventions(definition.id),
      "section_ids" => section_ids(definition.id)
    })
  end

  # Interventions and bindings are deleted and reinserted on every save, so their row IDs are
  # not part of the state.
  defp interventions(experiment_id) do
    bindings =
      from(b in AssessmentBinding,
        join: i in Intervention,
        on: i.id == b.intervention_id,
        where: i.experiment_id == ^experiment_id,
        select: {b.intervention_id, b.assessment_page_resource_id, b.reward_threshold}
      )
      |> Repo.all()
      |> Enum.group_by(&elem(&1, 0), fn {_, page_id, threshold} ->
        %{"assessment_page_resource_id" => page_id, "reward_threshold" => plain(threshold)}
      end)

    from(i in Intervention, where: i.experiment_id == ^experiment_id)
    |> Repo.all()
    |> Enum.map(fn intervention ->
      %{
        "page_resource_id" => intervention.page_resource_id,
        "content_element_id" => intervention.content_element_id,
        "bindings" =>
          bindings
          |> Map.get(intervention.id, [])
          |> Enum.sort_by(&{&1["assessment_page_resource_id"], &1["reward_threshold"]})
      }
    end)
    |> Enum.sort_by(&{&1["page_resource_id"], &1["content_element_id"]})
  end

  defp section_ids(experiment_id) do
    from(s in ExperimentSection,
      where: s.experiment_id == ^experiment_id,
      select: s.section_id,
      order_by: s.section_id
    )
    |> Repo.all()
  end

  defp plain(%Decimal{} = value), do: value |> Decimal.normalize() |> Decimal.to_string()

  defp plain(value) when is_atom(value) and not is_nil(value) and not is_boolean(value),
    do: Atom.to_string(value)

  defp plain(value), do: value

  defp record(context, experiment_id, before, after_state) do
    old = before && Map.take(before, Map.keys(@policy))
    new = Map.take(after_state, Map.keys(@policy))

    case Changes.diff(old, new, @policy) do
      changes when map_size(changes) == 0 ->
        :ok

      changes ->
        project = Repo.get!(Project, after_state.project_id)

        with {:ok, changeset} <-
               Auditing.build(context, %{
                 event_type: :project_settings_changed,
                 entity: {:project, project.id, project},
                 scope: %{project_id: project.id},
                 event_key: "project:#{project.id}:settings_changed",
                 changes: with_titles(changes, project),
                 details: %{experiment_id: experiment_id}
               }),
             {:ok, _event} <- Auditing.insert(changeset) do
          :ok
        end
    end
  end

  # Titles make a recorded definition readable; they are added after the comparison.
  defp with_titles(%{"experiment_definition" => record} = changes, project) do
    page_ids =
      [record["before"], record["after"]]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&resource_ids/1)
      |> Enum.uniq()

    titles =
      project.slug
      |> AuthoringResolver.from_resource_id(page_ids)
      |> Enum.reject(&is_nil/1)
      |> Map.new(&{&1.resource_id, &1.title})

    section_titles = section_titles(record)

    record =
      Map.new(record, fn
        {side, %{} = settings} when side in ["before", "after"] ->
          {side, titled(settings, titles, section_titles)}

        other ->
          other
      end)

    Map.put(changes, "experiment_definition", record)
  end

  defp with_titles(changes, _project), do: changes

  defp resource_ids(settings) do
    intervention_ids =
      Enum.flat_map(settings["interventions"], fn intervention ->
        [
          intervention["page_resource_id"]
          | Enum.map(intervention["bindings"], & &1["assessment_page_resource_id"])
        ]
      end)

    [settings["alternatives_resource_id"] | intervention_ids] |> Enum.reject(&is_nil/1)
  end

  defp section_titles(record) do
    ids =
      [record["before"], record["after"]]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(& &1["section_ids"])
      |> Enum.uniq()

    from(s in Section, where: s.id in ^ids, select: {s.id, s.title})
    |> Repo.all()
    |> Map.new()
  end

  defp titled(settings, titles, section_titles) do
    interventions =
      Enum.map(settings["interventions"], fn intervention ->
        bindings =
          Enum.map(intervention["bindings"], fn binding ->
            Map.put(binding, "title", titles[binding["assessment_page_resource_id"]])
          end)

        intervention
        |> Map.put("page_title", titles[intervention["page_resource_id"]])
        |> Map.put("bindings", bindings)
      end)

    sections =
      Enum.map(settings["section_ids"], fn id -> %{"id" => id, "title" => section_titles[id]} end)

    settings
    |> Map.put("alternatives_title", titles[settings["alternatives_resource_id"]])
    |> Map.put("interventions", interventions)
    |> Map.delete("section_ids")
    |> Map.put("sections", sections)
  end
end
