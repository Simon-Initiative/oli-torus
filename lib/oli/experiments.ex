defmodule Oli.Experiments do
  @moduledoc """
  Public context boundary for native A/B testing experiments.
  """

  import Ecto.Changeset
  import Ecto.Query

  alias Oli.Accounts.User
  alias Oli.Authoring.Authors.AuthorProject
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.{Enrollment, Section, SectionsProjectsPublications}

  alias Oli.Experiments.{
    AssignmentDecision,
    DecisionPointCandidate,
    EligibleExperimentSection,
    ExperimentDefinition,
    ExperimentAuthoringView,
    ExperimentError,
    ExperimentSectionParticipation,
    ExposureReceipt,
    OutcomeReceipt,
    RewardEligibleAssignment,
    RewardReceipt,
    Scope,
    Telemetry
  }

  alias Oli.Experiments.Schemas.{
    AssessmentBinding,
    Assignment,
    Condition,
    DecisionPoint,
    DecisionPointCondition,
    ExperimentSection,
    Intervention,
    PolicyState
  }

  alias Oli.Experiments.Policies.{ThompsonSampling, WeightedRandom}
  alias Oli.Experiments.XAPI.Attributions

  alias Oli.Experiments.Schemas.ExperimentDefinition, as: ExperimentDefinitionSchema
  alias Oli.Publishing.{AuthoringResolver, DeliveryResolver}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources.{Resource, ResourceType, Revision}

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

  @thompson_reward_source "assessment_page:normalized_score"
  @thompson_default_guardrails %{
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
         :ok <-
           maybe_require_authoring_scope(scope, structural_configuration_change?(request)),
         :ok <-
           validate_authoring_algorithm(
             request.algorithm,
             structural_configuration_change?(request)
           ),
         :ok <- validate_graph_request(request, scope),
         :ok <- validate_current_bindings(request.decision_points, scope, nil),
         {:ok, section_ids} <- validate_experiment_sections(request.section_ids, scope),
         attrs <- create_attrs(request, scope),
         {:ok, schema} <- insert_definition_graph(attrs, request, section_ids) do
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
         :ok <-
           maybe_require_authoring_access(
             scope,
             structural_configuration_change?(request)
           ),
         :ok <- validate_update_state(schema, request),
         :ok <- validate_immutable_algorithm(schema, request.algorithm),
         :ok <-
           validate_authoring_algorithm(
             request.algorithm || schema.algorithm,
             structural_configuration_change?(request)
           ),
         :ok <- validate_assignment_safe_update(schema, request),
         :ok <- validate_graph_request(request, scope, request.algorithm || schema.algorithm),
         :ok <- validate_current_bindings(request.decision_points, scope, schema.id),
         {:ok, section_ids} <- validate_experiment_sections(request.section_ids, scope),
         {:ok, updated} <- update_definition_graph(schema, request, section_ids) do
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
  Returns whether a project has at least one native experiment that is not archived.

  Experiment lifecycle state is authoritative.
  """
  def project_has_experiments?(project_id) when is_integer(project_id) and project_id > 0 do
    Repo.exists?(
      from experiment in ExperimentDefinitionSchema,
        where: experiment.project_id == ^project_id and experiment.state != :archived
    )
  end

  def project_has_experiments?(_project_id), do: false

  @doc """
  Lists project-scoped experiment definitions for authoring.
  """
  def list_project_experiments(%Scope{} = scope) do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_access(scope) do
      experiments =
        scope
        |> scoped_project_experiments_query()
        |> order_by([experiment], desc: experiment.id)
        |> preload(:sections)
        |> Repo.all()
        |> Enum.map(&to_definition/1)

      {:ok, experiments}
    end
  end

  def list_project_experiments(_scope), do: invalid_request("expected Scope")

  @doc """
  Lists authoring-safe summaries for active sections currently related to the scoped project.
  """
  def list_eligible_sections(%Scope{} = scope) do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_scope(scope),
         :ok <- require_eligible_section_reader(scope) do
      sections =
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

      {:ok, sections}
    end
  end

  def list_eligible_sections(_scope), do: invalid_request("expected Scope")

  @doc """
  Returns eligible, selected, and stale section participation for an experiment.
  """
  def get_section_participation(experiment_id, %Scope{} = scope) do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_scope(scope),
         :ok <- require_eligible_section_reader(scope),
         {:ok, schema} <- get_scoped_definition(experiment_id, scope) do
      {:ok, section_participation(schema, scope)}
    end
  end

  def get_section_participation(_experiment_id, _scope),
    do: invalid_request("expected Scope")

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

      decision_point_ids = Enum.map(decision_points, & &1.id)

      mappings =
        from(mapping in DecisionPointCondition,
          where: mapping.decision_point_id in ^decision_point_ids,
          order_by: [asc: mapping.decision_point_id, asc: mapping.position, asc: mapping.id]
        )
        |> Repo.all()
        |> Enum.map(
          &Map.take(&1, [:id, :decision_point_id, :condition_id, :option_id, :weight, :position])
        )

      interventions =
        from(intervention in Intervention,
          where: intervention.decision_point_id in ^decision_point_ids,
          order_by: [asc: intervention.decision_point_id, asc: intervention.id],
          preload: :assessment_binding
        )
        |> Repo.all()

      assessment_bindings =
        interventions
        |> Enum.map(& &1.assessment_binding)
        |> Enum.reject(&is_nil/1)
        |> Enum.map(
          &Map.take(&1, [:id, :intervention_id, :assessment_page_resource_id, :reward_threshold])
        )

      {:ok,
       %ExperimentAuthoringView{
         definition: to_definition(schema),
         decision_points: Enum.map(decision_points, &public_decision_point(&1, schema.algorithm)),
         conditions: conditions,
         mappings: mappings,
         interventions:
           Enum.map(
             interventions,
             &Map.take(&1, [:id, :decision_point_id, :page_resource_id, :content_element_id])
           ),
         assessment_bindings: assessment_bindings,
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
        scope.project_slug
        |> AuthoringResolver.revisions_of_type(ResourceType.id_for_alternatives())
        |> Enum.filter(&experiment_decision_point_revision?/1)
        |> Enum.sort_by(&{&1.title, &1.id})
        |> Enum.map(&to_decision_point_candidate/1)

      {:ok, candidates}
    end
  end

  def list_available_decision_points(_scope), do: invalid_request("expected Scope")

  @doc """
  Lists current project pages available to experiment intervention and assessment pickers.
  """
  def list_available_pages(%Scope{} = scope) do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_access(scope) do
      pages =
        scope.project_slug
        |> AuthoringResolver.revisions_of_type(ResourceType.id_for_page())
        |> Enum.reject(& &1.deleted)
        |> Enum.sort_by(&{&1.title, &1.resource_id})
        |> Enum.map(&%{value: &1.resource_id, label: &1.title, graded: &1.graded})

      {:ok, pages}
    end
  end

  def list_available_pages(_scope), do: invalid_request("expected Scope")

  @doc """
  Lists Alternatives elements on a current project page and identifies experiment-controlled ones.
  """
  def list_page_alternatives_elements(page_resource_id, %Scope{} = scope)
      when is_integer(page_resource_id) and page_resource_id > 0 do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_access(scope),
         %Revision{} = page <-
           AuthoringResolver.from_resource_id(scope.project_slug, page_resource_id),
         true <- page.resource_type_id == ResourceType.id_for_page() do
      placements = Oli.Resources.PageContent.alternatives_placements(page.content || %{})

      ids =
        placements
        |> Enum.map(& &1["alternatives_id"])
        |> Enum.filter(&is_integer/1)
        |> Enum.uniq()

      experiment_ids =
        scope.project_slug
        |> AuthoringResolver.from_resource_id(ids)
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(&experiment_decision_point_revision?/1)
        |> MapSet.new(& &1.resource_id)

      {:ok,
       placements
       |> Enum.with_index(1)
       |> Enum.map(fn {placement, position} ->
         id = placement["id"]

         %{
           value: id,
           label: id,
           position: position,
           type: placement["type"],
           alternatives_resource_id: placement["alternatives_id"],
           content: placement["children"] || [],
           experiment_controlled?: MapSet.member?(experiment_ids, placement["alternatives_id"])
         }
       end)}
    else
      _ -> not_found("page not found", %{page_resource_id: page_resource_id})
    end
  end

  def list_page_alternatives_elements(_page_resource_id, _scope),
    do: invalid_request("expected a page resource ID and Scope")

  @doc """
  Returns whether a project-scoped decision point is referenced by a non-archived experiment
  definition.
  """
  def decision_point_in_use?(alternatives_resource_id, %Scope{} = scope)
      when is_integer(alternatives_resource_id) and alternatives_resource_id > 0 do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_scope(scope) do
      in_use? =
        Repo.exists?(
          from decision_point in DecisionPoint,
            join: experiment in ExperimentDefinitionSchema,
            on: experiment.id == decision_point.experiment_id,
            where:
              experiment.project_id == ^scope.project_id and
                experiment.state != :archived and
                decision_point.alternatives_resource_id == ^alternatives_resource_id
        )

      {:ok, in_use?}
    end
  end

  def decision_point_in_use?(_alternatives_resource_id, _scope),
    do: invalid_request("expected a decision point resource id and Scope")

  @doc """
  Returns experiment dependencies that must be reconciled before a resource can be deleted.
  """
  def configuration_dependencies(resource_id, %Scope{} = scope)
      when is_integer(resource_id) and resource_id > 0 do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_access(scope) do
      dependencies =
        from(experiment in ExperimentDefinitionSchema,
          left_join: point in DecisionPoint,
          on: point.experiment_id == experiment.id,
          left_join: intervention in Intervention,
          on: intervention.decision_point_id == point.id,
          left_join: binding in AssessmentBinding,
          on: binding.intervention_id == intervention.id,
          where:
            experiment.project_id == ^scope.project_id and
              (point.alternatives_resource_id == ^resource_id or
                 intervention.page_resource_id == ^resource_id or
                 binding.assessment_page_resource_id == ^resource_id),
          select: %{
            experiment_id: experiment.id,
            state: experiment.state,
            decision_point_id: point.id,
            intervention_id: intervention.id,
            assessment_binding_id: binding.id
          }
        )
        |> Repo.all()

      {:ok, dependencies}
    end
  end

  def configuration_dependencies(_resource_id, _scope),
    do: invalid_request("expected a resource id and Scope")

  @doc """
  Explicitly removes a draft assessment binding.
  """
  def remove_assessment_binding(experiment_id, binding_id, %Scope{} = scope) do
    reconcile_draft_dependency(experiment_id, scope, fn schema ->
      query =
        from(binding in AssessmentBinding,
          join: intervention in Intervention,
          on: intervention.id == binding.intervention_id,
          join: point in DecisionPoint,
          on: point.id == intervention.decision_point_id,
          where: binding.id == ^binding_id and point.experiment_id == ^schema.id
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
          join: point in DecisionPoint,
          on: point.id == intervention.decision_point_id,
          where: intervention.id == ^intervention_id and point.experiment_id == ^schema.id
        )

      delete_owned_dependency(query, :intervention, intervention_id)
    end)
  end

  @doc """
  Explicitly removes a draft condition mapping.
  """
  def remove_condition_mapping(experiment_id, mapping_id, %Scope{} = scope) do
    reconcile_draft_dependency(experiment_id, scope, fn schema ->
      query =
        from(mapping in DecisionPointCondition,
          join: point in DecisionPoint,
          on: point.id == mapping.decision_point_id,
          where: mapping.id == ^mapping_id and point.experiment_id == ^schema.id
        )

      delete_owned_dependency(query, :condition_mapping, mapping_id)
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
  Returns an existing assignment decision for a delivery/review decision point without
  creating an assignment or recording exposure.
  """
  def assigned_condition(%Oli.Experiments.AssignConditionRequest{} = request) do
    with {:ok, scope} <- validate_delivery_participation_scope(request.scope),
         :ok <- require_delivery_scope(scope),
         {:ok, _revision} <- resolve_delivery_revision(request, scope),
         {:ok, decision} <- existing_assignment_decision(request, scope) do
      {:ok, decision}
    end
  end

  def assigned_condition(_request), do: invalid_request("expected AssignConditionRequest")

  @doc """
  Assigns or reuses all valid experiment-controlled Alternatives placements on one
  delivered page, using a bounded set of reads.
  Decisions are keyed by stable content-element ID.

  Callers must pass requests derived from server-resolved page content and deployed
  Alternatives revisions. An Alternatives placement may be inside ordinary containers,
  but must not have another Alternatives placement as an ancestor. Every request must
  share one delivery scope and page resource ID.
  """
  def assign_page_conditions([%Oli.Experiments.AssignConditionRequest{} | _] = requests) do
    with {:ok, scope} <- common_page_assignment_scope(requests),
         :ok <- require_delivery_scope(scope),
         {:ok, scope} <- validate_publication(scope) do
      Repo.transaction(fn -> batch_assign_page_conditions(requests, scope) end)
      |> case do
        {:ok, {decisions, events}} ->
          Enum.each(events, &emit_committed_batch_assignment/1)
          {:ok, decisions}

        {:error, %ExperimentError{} = error} ->
          {:error, error}
      end
    end
  end

  def assign_page_conditions([]), do: {:ok, %{}}
  def assign_page_conditions(_requests), do: invalid_request("expected assignment requests")

  @doc """
  Records exposure evidence for a page's assigned root Alternatives placements with
  one assignment read. Requests must be derived from server-resolved delivery state.
  """
  def record_page_exposures([%Oli.Experiments.RecordExposureRequest{} | _] = requests) do
    with {:ok, scope} <- common_exposure_scope(requests),
         {:ok, assignments} <- batch_exposure_assignments(requests, scope),
         {:ok, revisions} <- batch_exposure_revisions(requests, assignments) do
      attributions =
        Enum.flat_map(requests, fn request ->
          assignment = Map.fetch!(assignments, request.assignment_id)
          _revision = Map.fetch!(revisions, request.content_revision_id)
          event = Map.put(runtime_event(request), "reused", false)
          receipt = exposure_receipt(assignment, event)

          :telemetry.execute([:oli, :experiments, :exposure, :recorded], %{count: 1}, %{
            experiment_id: assignment.experiment_id,
            decision_point_id: assignment.decision_point_id
          })

          Telemetry.emit(:exposure_recorded, {receipt, request}, assignment: assignment)
          Attributions.attributions_for_page_view(receipt, request, assignment: assignment)
        end)

      {:ok, attributions}
    end
  end

  def record_page_exposures([]), do: {:ok, []}
  def record_page_exposures(_requests), do: invalid_request("expected exposure requests")

  @doc """
  Returns whether a section and project have a relevant active experiment.

  This is the bounded delivery gate; callers must not enter experiment-specific
  resolution when it returns false.
  """
  @spec relevant_active_experiment?(integer(), integer()) :: boolean()
  def relevant_active_experiment?(section_id, project_id)
      when is_integer(section_id) and is_integer(project_id) do
    Repo.exists?(
      from experiment_section in ExperimentSection,
        join: experiment in ExperimentDefinitionSchema,
        on: experiment.id == experiment_section.experiment_id,
        where:
          experiment_section.section_id == ^section_id and
            experiment.project_id == ^project_id and
            experiment.state == :active
    )
  end

  def relevant_active_experiment?(_section_id, _project_id), do: false

  @doc """
  Records operational exposure evidence and emits the durable xAPI exposure event.
  """
  def record_exposure(%Oli.Experiments.RecordExposureRequest{} = request) do
    with {:ok, scope} <- validate_delivery_participation_scope(request.scope) do
      create_exposure(%{request | scope: scope})
    end
  end

  def record_exposure(_request), do: invalid_request("expected RecordExposureRequest")

  @doc """
  Records operational outcome evidence and emits the durable xAPI outcome event.
  """
  def record_outcome(%Oli.Experiments.RecordOutcomeRequest{} = request) do
    with {:ok, scope} <- validate_delivery_participation_scope(request.scope) do
      create_outcome(%{request | scope: scope})
    end
  end

  def record_outcome(_request), do: invalid_request("expected RecordOutcomeRequest")

  @doc """
  Records operational reward evidence, mutates policy state, and emits durable xAPI events.
  """
  def record_reward(%Oli.Experiments.RecordRewardRequest{} = request) do
    with {:ok, scope} <- validate_delivery_participation_scope(request.scope) do
      create_reward(%{request | scope: scope})
    end
  end

  def record_reward(_request), do: invalid_request("expected RecordRewardRequest")

  @doc """
  Returns native assignments whose selected alternatives branch contains the evaluated
  activity resource. Emits lookup duration, assignment count, and assignment-query count telemetry
  for AppSignal monitoring of reward handoff query amplification.
  """
  def reward_eligible_assignments(%Scope{} = scope, activity_resource_id, page_content) do
    start_time = System.monotonic_time()

    {result, assignment_query_count} =
      case validate_delivery_participation_scope(scope) do
        {:ok, scope} ->
          matching_branches = matching_alternatives_branches(page_content, activity_resource_id)

          case matching_branches do
            [] ->
              {{:ok, []}, 0}

            _ ->
              assignments =
                scope
                |> reward_eligible_assignment_query()
                |> Repo.all()
                |> Enum.filter(&assignment_matches_branch?(&1, matching_branches))
                |> Enum.map(&to_reward_eligible_assignment/1)

              {{:ok, assignments}, 1}
          end

        {:error, _error} = error ->
          {error, 0}
      end

    :telemetry.execute(
      [:oli, :experiments, :delivery_reward, :eligibility, :completed],
      %{
        duration_ms: elapsed_milliseconds(start_time),
        assignment_count: eligible_assignment_count(result),
        assignment_query_count: assignment_query_count
      },
      %{status: eligibility_status(result)}
    )

    result
  end

  def reward_eligible_assignments(_scope, _activity_resource_id, _page_content),
    do: invalid_request("expected Scope")

  @doc """
  Returns reward-eligible assignments for evaluated-attempt contexts in one set-based query.

  The result is keyed by activity-attempt ID. Contexts are expected to contain `:activity_attempt`,
  `:scope`, and `:page_content`, as produced by the delivery reward handoff.
  """
  def reward_eligible_assignments(contexts) when is_list(contexts) do
    start_time = System.monotonic_time()

    contexts_by_scope =
      Enum.group_by(contexts, fn context ->
        scope = context.scope

        {scope.project_id, scope.section_id, scope.enrollment_id, scope.user_id}
      end)

    section_ids = contexts |> Enum.map(& &1.scope.section_id) |> Enum.uniq()
    enrollment_ids = contexts |> Enum.map(& &1.scope.enrollment_id) |> Enum.uniq()

    assignments =
      case contexts do
        [] ->
          []

        _ ->
          from(assignment in Assignment,
            join: experiment in ExperimentDefinitionSchema,
            on: experiment.id == assignment.experiment_id,
            join: experiment_section in ExperimentSection,
            on:
              experiment_section.experiment_id == experiment.id and
                experiment_section.section_id == assignment.section_id,
            join: section in Section,
            on: section.id == assignment.section_id and section.status == :active,
            join: spp in SectionsProjectsPublications,
            on: spp.section_id == section.id and spp.project_id == experiment.project_id,
            join: decision_point in DecisionPoint,
            on: decision_point.id == assignment.decision_point_id,
            join: condition in Condition,
            on: condition.id == assignment.condition_id,
            where:
              experiment.state == :active and assignment.section_id in ^section_ids and
                assignment.enrollment_id in ^enrollment_ids,
            distinct: true,
            select: %{
              assignment: assignment,
              experiment_project_id: experiment.project_id,
              decision_point: decision_point,
              condition: condition
            }
          )
          |> Repo.all()
      end

    result =
      Enum.reduce(assignments, %{}, fn candidate, eligible_by_attempt ->
        assignment = candidate.assignment

        contexts_by_scope
        |> Map.get(
          {candidate.experiment_project_id, assignment.section_id, assignment.enrollment_id,
           assignment.user_id},
          []
        )
        |> Enum.reduce(eligible_by_attempt, fn context, acc ->
          matching_branches =
            matching_alternatives_branches(
              context.page_content,
              context.activity_attempt.resource_id
            )

          case assignment_matches_branch?(candidate, matching_branches) do
            true ->
              Map.update(
                acc,
                context.activity_attempt.id,
                [to_reward_eligible_assignment(candidate)],
                &[to_reward_eligible_assignment(candidate) | &1]
              )

            false ->
              acc
          end
        end)
      end)
      |> Map.new(fn {activity_attempt_id, assignments} ->
        {activity_attempt_id, Enum.reverse(assignments)}
      end)

    assignment_count = result |> Map.values() |> Enum.map(&length/1) |> Enum.sum()

    :telemetry.execute(
      [:oli, :experiments, :delivery_reward, :eligibility, :completed],
      %{
        duration_ms: elapsed_milliseconds(start_time),
        assignment_count: assignment_count,
        assignment_query_count: 1
      },
      %{status: if(assignment_count == 0, do: :empty, else: :matched)}
    )

    result
  end

  defp eligible_assignment_count({:ok, assignments}), do: length(assignments)
  defp eligible_assignment_count({:error, _error}), do: 0

  defp eligibility_status({:ok, []}), do: :empty
  defp eligibility_status({:ok, _assignments}), do: :matched
  defp eligibility_status({:error, _error}), do: :error

  defp elapsed_milliseconds(start_time) do
    start_time
    |> then(&(System.monotonic_time() - &1))
    |> System.convert_time_unit(:native, :millisecond)
  end

  @doc """
  Returns operational runtime counts from PostgreSQL for product surfaces that still need
  synchronous experiment state. Durable analytics must read xAPI-derived projections.
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
         exposures: 0,
         rewards: runtime_event_count(scope, query.experiment_id, "rewards")
       }}
    end
  end

  def experiment_summary(_query), do: invalid_request("expected AnalyticsQuery")

  @doc """
  Returns operational assignment counts. Durable analytics must read xAPI-derived projections.
  """
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

  @doc """
  Exposure evidence is emitted through xAPI host statements and served from ClickHouse.
  PostgreSQL no longer retains exposure event state.
  """
  def exposure_counts(%Oli.Experiments.AnalyticsQuery{} = query) do
    with {:ok, scope} <- validate_scope(query.scope),
         :ok <- ensure_analytics_experiment_scope(scope, query.experiment_id) do
      {:ok, []}
    end
  end

  def exposure_counts(_query), do: invalid_request("expected AnalyticsQuery")

  @doc """
  Returns operational reward counts. Durable analytics must read xAPI-derived projections.
  """
  def reward_counts(%Oli.Experiments.AnalyticsQuery{} = query) do
    with {:ok, scope} <- validate_scope(query.scope),
         :ok <- ensure_analytics_experiment_scope(scope, query.experiment_id) do
      counts =
        scope
        |> scoped_assignment_query(query.experiment_id)
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
    with {:ok, scope} <- validate_scope(query.scope),
         :ok <- ensure_analytics_experiment_scope(scope, query.experiment_id) do
      snapshots =
        scope
        |> scoped_policy_state_query(query.experiment_id)
        |> select([policy_state, _experiment, decision_point], %{
          experiment_id: policy_state.experiment_id,
          decision_point_id: policy_state.decision_point_id,
          algorithm: policy_state.algorithm,
          algorithm_version: policy_state.algorithm_version,
          warm_up_assignments: decision_point.warm_up_assignments,
          max_condition_share: decision_point.max_condition_share,
          fixed_control_allocation: decision_point.fixed_control_allocation,
          imbalance_threshold: decision_point.imbalance_threshold,
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

  Draft experiments and weighted-random decision points intentionally return no
  posterior rows. The report is derived only from the persisted policy snapshot,
  mappings, and aggregate assignment counts; it never reads reward history or an
  analytics store.
  """
  def policy_snapshot(experiment_id, %Scope{} = scope) when is_integer(experiment_id) do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_access(scope),
         {:ok, authoring_view} <- get_experiment_authoring_view(experiment_id, scope) do
      policy_snapshot(authoring_view, scope)
    end
  end

  def policy_snapshot(%ExperimentAuthoringView{} = authoring_view, %Scope{} = scope) do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_access(scope) do
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
      conditions = Map.new(authoring_view.conditions, &{&1.id, &1})
      mappings = Enum.group_by(authoring_view.mappings, & &1.decision_point_id)

      assignment_counts =
        assignment_counts_by_decision_point_condition(authoring_view.definition.id)

      rows =
        snapshots
        |> Enum.filter(&(&1.algorithm == :thompson_sampling))
        |> Enum.flat_map(fn snapshot ->
          decision_point_mappings = Map.get(mappings, snapshot.decision_point_id, [])
          total_assignments = max(snapshot.assignment_count, 0)

          Enum.map(decision_point_mappings, fn mapping ->
            condition = Map.fetch!(conditions, mapping.condition_id)
            condition_state = Map.get(snapshot.state, condition.condition_code, %{})
            alpha = numeric_value(condition_state["posterior_alpha"])
            beta = numeric_value(condition_state["posterior_beta"])

            assignment_count =
              Map.get(assignment_counts, {snapshot.decision_point_id, condition.id}, 0)

            %{
              decision_point_id: snapshot.decision_point_id,
              condition_id: condition.id,
              condition_code: condition.condition_code,
              condition_label: condition.label || condition.condition_code,
              option_id: mapping.option_id,
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
                  decision_point_mappings,
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

  defp effective_policy_mode(snapshot, mappings, assignment_counts) do
    guardrails = snapshot.guardrail_state
    assignment_count = guardrails["assignment_count"] || 0

    counts =
      Map.new(
        mappings,
        &{&1.condition_id,
         Map.get(assignment_counts, {snapshot.decision_point_id, &1.condition_id}, 0)}
      )

    conditions = Enum.map(mappings, &%{id: &1.condition_id})

    cond do
      assignment_count < (guardrails["warm_up_assignments"] || 0) ->
        :warm_up_weighted_random

      fixed_control_condition(conditions, counts, guardrails["fixed_control_allocation"]) ->
        :fixed_control

      cap_eligible_conditions(conditions, counts, guardrails["max_condition_share"]) != conditions ->
        :traffic_cap

      true ->
        :thompson_sampling
    end
  end

  defp imbalance_warning?(snapshot, count, total) do
    threshold = snapshot.guardrail_state["imbalance_threshold"]
    is_number(threshold) and total > 0 and count / total > threshold
  end

  defp transition(experiment_id, %Oli.Experiments.LifecycleRequest{} = request, action) do
    target_state = Map.fetch!(@transition_targets, action)

    result =
      Repo.transaction(fn ->
        with {:ok, scope} <- validate_scope(request.scope),
             %ExperimentDefinitionSchema{} = schema <-
               scope
               |> scoped_experiment_query(experiment_id)
               |> lock("FOR UPDATE")
               |> preload(:sections)
               |> Repo.one(),
             :ok <- validate_transition(schema.state, target_state),
             :ok <- validate_transition_prerequisites(schema, schema.state, target_state),
             attrs <- transition_attrs(schema, target_state, request.transitioned_at),
             {:ok, updated} <-
               schema
               |> ExperimentDefinitionSchema.changeset(attrs)
               |> Repo.update() do
          {Repo.preload(updated, :sections, force: true), schema.state}
        else
          nil ->
            Repo.rollback(
              elem(not_found("experiment not found", %{experiment_id: experiment_id}), 1)
            )

          {:error, %ExperimentError{} = error} ->
            Repo.rollback(error)

          {:error, %Ecto.Changeset{} = changeset} ->
            Repo.rollback(changeset)
        end
      end)
      |> normalize_transaction_result()

    with {:ok, {updated, previous_state}} <- result do
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

  defp scoped_experiment_query(scope, experiment_id) do
    query =
      from(experiment in ExperimentDefinitionSchema,
        as: :experiment,
        where: experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_experiment_id(experiment_id)
    |> maybe_filter_experiment_section(scope.section_id)
  end

  defp scoped_project_experiments_query(scope) do
    from(experiment in ExperimentDefinitionSchema,
      where: experiment.project_id == ^scope.project_id
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
        as: :experiment,
        on: experiment.id == assignment.experiment_id,
        where: experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_joined_experiment_id(experiment_id)
    |> maybe_filter_assignment_section(scope.section_id)
    |> maybe_filter_assignment_institution(scope)
  end

  defp reward_eligible_assignment_query(scope) do
    from(assignment in Assignment,
      join: experiment in ExperimentDefinitionSchema,
      as: :experiment,
      on: experiment.id == assignment.experiment_id,
      join: decision_point in DecisionPoint,
      on: decision_point.id == assignment.decision_point_id,
      join: condition in Condition,
      on: condition.id == assignment.condition_id,
      where:
        experiment.project_id == ^scope.project_id and
          experiment.state == :active and
          exists(participating_section_query(scope.section_id)) and
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
    where(query, [experiment: _experiment], exists(participating_section_query(section_id)))
  end

  defp maybe_filter_joined_experiment_section(query, nil), do: query

  defp maybe_filter_joined_experiment_section(query, section_id) do
    where(query, [experiment: _experiment], exists(participating_section_query(section_id)))
  end

  defp participating_section_query(section_id) do
    from(experiment_section in ExperimentSection,
      join: section in Section,
      on: section.id == experiment_section.section_id,
      join: spp in SectionsProjectsPublications,
      on:
        spp.section_id == section.id and
          spp.project_id == parent_as(:experiment).project_id,
      where:
        experiment_section.experiment_id == parent_as(:experiment).id and
          experiment_section.section_id == ^section_id and
          section.status == :active,
      select: 1
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

  defp maybe_filter_section_institution(query, nil), do: query

  defp maybe_filter_section_institution(query, institution_id) do
    where(
      query,
      [section],
      is_nil(section.institution_id) or section.institution_id == ^institution_id
    )
  end

  defp runtime_event_count(scope, experiment_id, event_group) do
    scope
    |> scoped_assignment_query(experiment_id)
    |> where(
      [assignment, _experiment],
      fragment("? \\? ?", assignment.runtime_event_state, ^event_group)
    )
    |> Repo.aggregate(:count, :id)
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
      alternatives_resource_id: decision_point.alternatives_resource_id
    }
  end

  defp scoped_policy_state_query(scope, experiment_id) do
    query =
      from(policy_state in PolicyState,
        join: experiment in ExperimentDefinitionSchema,
        as: :experiment,
        on: experiment.id == policy_state.experiment_id,
        join: decision_point in DecisionPoint,
        on: decision_point.id == policy_state.decision_point_id,
        where: experiment.project_id == ^scope.project_id
      )

    query
    |> maybe_filter_joined_experiment_id(experiment_id)
    |> maybe_filter_joined_experiment_section(scope.section_id)
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

  defp do_assign_condition(request) do
    with {:ok, scope} <- validate_delivery_participation_scope(request.scope),
         :ok <- require_delivery_scope(scope) do
      case scope.project_relationship? do
        true -> do_assign_condition_for_current_project(request, scope)
        false -> nonparticipating_assignment_fallback(:section_no_longer_eligible)
      end
    end
  end

  defp common_page_assignment_scope([first | rest]) do
    with {:ok, scope} <- validate_delivery_participation_scope(first.scope),
         true <-
           Enum.all?(rest, fn request ->
             request.scope == first.scope and
               request.page_resource_id == first.page_resource_id
           end) do
      {:ok, scope}
    else
      false -> invalid_scope("page assignment requests must share one scope and page")
      {:error, %ExperimentError{} = error} -> {:error, error}
    end
  end

  defp common_exposure_scope([first | rest]) do
    with {:ok, scope} <- validate_delivery_participation_scope(first.scope),
         true <- Enum.all?(rest, &(&1.scope == first.scope)) do
      {:ok, scope}
    else
      false -> invalid_scope("page exposure requests must share one scope")
      {:error, %ExperimentError{} = error} -> {:error, error}
    end
  end

  defp batch_exposure_assignments(requests, scope) do
    assignment_ids = Enum.map(requests, & &1.assignment_id)

    assignments =
      from(assignment in Assignment,
        join: experiment in assoc(assignment, :experiment),
        join: condition in assoc(assignment, :condition),
        on: condition.experiment_id == experiment.id,
        join: decision_point in assoc(assignment, :decision_point),
        on: decision_point.experiment_id == experiment.id,
        where:
          assignment.id in ^assignment_ids and
            experiment.project_id == ^scope.project_id and
            assignment.section_id == ^scope.section_id and
            assignment.enrollment_id == ^scope.enrollment_id and
            assignment.user_id == ^scope.user_id,
        preload: [experiment: experiment, condition: condition, decision_point: decision_point]
      )
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    case map_size(assignments) == length(Enum.uniq(assignment_ids)) do
      true -> {:ok, assignments}
      false -> invalid_scope("one or more page exposure assignments are outside delivery scope")
    end
  end

  defp batch_exposure_revisions(requests, assignments) do
    revision_ids = Enum.map(requests, & &1.content_revision_id)

    revisions =
      Revision
      |> where([revision], revision.id in ^revision_ids)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    valid? =
      Enum.all?(requests, fn request ->
        with %Revision{} = revision <- Map.get(revisions, request.content_revision_id),
             %Assignment{} = assignment <- Map.get(assignments, request.assignment_id) do
          revision.resource_id == assignment.decision_point.alternatives_resource_id
        else
          _ -> false
        end
      end)

    case valid? do
      true -> {:ok, revisions}
      false -> invalid_condition("page exposure revision does not match its decision point")
    end
  end

  defp batch_assign_page_conditions(requests, scope) do
    page_resource_id = hd(requests).page_resource_id
    content_element_ids = Enum.map(requests, & &1.content_element_id)

    materialize_weighted_random_interventions(requests, scope)

    rows =
      scope
      |> batch_assignment_rows(page_resource_id, content_element_ids)
      |> ensure_batch_policy_states()
      |> lock_batch_assignment_decisions()

    decision_point_ids = rows |> Enum.map(& &1.decision_point.id) |> Enum.uniq()
    counts = batch_assignment_counts(decision_point_ids)

    rows_by_placement =
      Enum.group_by(
        rows,
        &{&1.intervention.content_element_id, &1.decision_point.alternatives_resource_id}
      )

    {decisions, _counts, events} =
      Enum.reduce(requests, {%{}, counts, []}, fn request, {decisions, current_counts, events} ->
        matching_rows =
          Map.get(
            rows_by_placement,
            {request.content_element_id, request.alternatives_resource_id},
            []
          )

        case batch_assignment_decision(matching_rows, request, scope, current_counts) do
          {:ok, decision, next_counts, event} ->
            {Map.put(decisions, request.content_element_id, decision), next_counts,
             [event | events]}

          {:fallback, reason} ->
            emit_batch_fallback(reason, matching_rows)

            {Map.put(decisions, request.content_element_id, %AssignmentDecision{
               status: :no_experiment
             }), current_counts, events}

          {:error, %ExperimentError{} = error} ->
            Repo.rollback(error)
        end
      end)

    {decisions, Enum.reverse(events)}
  end

  defp batch_assignment_rows(scope, page_resource_id, content_element_ids) do
    from(intervention in Intervention,
      join: decision_point in DecisionPoint,
      on: decision_point.id == intervention.decision_point_id,
      join: experiment in ExperimentDefinitionSchema,
      as: :experiment,
      on: experiment.id == decision_point.experiment_id,
      join: mapping in DecisionPointCondition,
      on: mapping.decision_point_id == decision_point.id,
      join: condition in Condition,
      on: condition.id == mapping.condition_id and condition.active == true,
      left_join: policy_state in PolicyState,
      on:
        policy_state.experiment_id == experiment.id and
          policy_state.decision_point_id == decision_point.id and
          policy_state.algorithm == experiment.algorithm,
      left_join: assignment in Assignment,
      on:
        assignment.intervention_id == intervention.id and
          assignment.enrollment_id == ^scope.enrollment_id,
      where:
        intervention.page_resource_id == ^page_resource_id and
          intervention.content_element_id in ^content_element_ids and
          experiment.project_id == ^scope.project_id and
          experiment.state == :active and
          exists(participating_section_query(scope.section_id)),
      order_by: [asc: intervention.id, asc: mapping.position, asc: condition.id],
      select: %{
        intervention: intervention,
        decision_point: decision_point,
        experiment: experiment,
        condition: %{condition | option_id: mapping.option_id, weight: mapping.weight},
        policy_state: policy_state,
        assignment: assignment
      }
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      %{row | decision_point: runtime_decision_point(row.experiment, row.decision_point, [])}
    end)
  end

  defp ensure_batch_policy_states(rows) do
    states =
      rows
      |> Enum.group_by(& &1.decision_point.id)
      |> Map.new(fn {decision_point_id, point_rows} ->
        first = hd(point_rows)

        state =
          first.policy_state ||
            get_or_create_policy_state(first.experiment, decision_point_id)

        {decision_point_id, state}
      end)

    Enum.map(rows, fn row ->
      %{row | policy_state: Map.fetch!(states, row.decision_point.id)}
    end)
  end

  defp lock_batch_assignment_decisions(rows) do
    decision_point_ids =
      rows
      |> Enum.map(& &1.decision_point.id)
      |> Enum.uniq()
      |> Enum.sort()

    Enum.each(decision_point_ids, fn decision_point_id ->
      Repo.query!("SELECT pg_advisory_xact_lock($1)", [decision_point_id])
    end)

    rows
  end

  defp batch_assignment_counts([]), do: %{}

  defp batch_assignment_counts(decision_point_ids) do
    from(assignment in Assignment,
      where: assignment.decision_point_id in ^decision_point_ids,
      group_by: [assignment.decision_point_id, assignment.condition_id],
      select: {{assignment.decision_point_id, assignment.condition_id}, count(assignment.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp batch_assignment_decision([], _request, _scope, _counts),
    do: {:fallback, :no_experiment}

  defp batch_assignment_decision(rows, request, scope, counts) do
    first = hd(rows)

    cond do
      Enum.any?(rows, &(&1.experiment.id != first.experiment.id)) ->
        {:fallback, :ambiguous_match}

      existing = Enum.find_value(rows, & &1.assignment) ->
        condition = Enum.find(rows, &(&1.condition.id == existing.condition_id)).condition
        decision = to_assignment_decision(existing, condition, true, condition.option_id)
        event = batch_assignment_event(decision, request, existing, first, nil, true)
        {:ok, decision, counts, event}

      true ->
        conditions = Enum.map(rows, & &1.condition)

        with :ok <- validate_batch_options(conditions, request.available_condition_codes),
             {:ok, selection} <-
               select_batch_condition(first, conditions, request, scope, counts),
             {:ok, decision, assignment, inserted?} <-
               insert_batch_assignment(first, selection, request, scope) do
          next_counts =
            case inserted? do
              true ->
                increment_batch_assignment_count(first)

                Map.update(
                  counts,
                  {first.decision_point.id, selection.condition.id},
                  1,
                  &(&1 + 1)
                )

              false ->
                counts
            end

          event =
            batch_assignment_event(
              decision,
              request,
              assignment,
              first,
              selection,
              not inserted?
            )

          {:ok, decision, next_counts, event}
        end
    end
  end

  defp validate_batch_options(conditions, available_option_ids) do
    mapped = conditions |> Enum.map(& &1.option_id) |> MapSet.new()
    available = MapSet.new(available_option_ids)

    case mapped == available do
      true ->
        :ok

      false ->
        invalid_condition("delivery alternatives options do not match intervention mapping")
    end
  end

  defp select_batch_condition(first, conditions, _request, scope, counts) do
    decision_point = first.decision_point

    point_counts =
      counts
      |> Enum.reduce(%{}, fn
        {{point_id, condition_id}, count}, acc when point_id == decision_point.id ->
          Map.put(acc, condition_id, count)

        _, acc ->
          acc
      end)

    {policy_module, policy_conditions, guardrail_action} =
      assignment_policy_for_snapshot(
        first.experiment,
        decision_point,
        conditions,
        first.policy_state,
        point_counts
      )

    context = %{
      conditions: policy_conditions,
      assignment_key:
        assignment_key(
          first.experiment.id,
          decision_point.id,
          first.intervention.id,
          scope.enrollment_id
        )
    }

    case policy_module.assign(
           decision_point_policy_config(decision_point),
           first.policy_state && first.policy_state.state,
           context
         ) do
      {:ok, policy_assignment} ->
        condition = Enum.find(conditions, &(&1.id == policy_assignment.condition_id))

        {:ok,
         %{
           condition: condition,
           policy_assignment: policy_assignment,
           guardrail_action: guardrail_action,
           assignment_counts: point_counts
         }}

      {:error, reason} ->
        invalid_condition("policy could not assign a condition", %{reason: reason})
    end
  end

  defp insert_batch_assignment(first, selection, _request, scope) do
    attrs = %{
      experiment_id: first.experiment.id,
      decision_point_id: first.decision_point.id,
      condition_id: selection.condition.id,
      intervention_id: first.intervention.id,
      section_id: scope.section_id,
      enrollment_id: scope.enrollment_id,
      user_id: scope.user_id,
      assigned_by_policy: Atom.to_string(first.experiment.algorithm),
      policy_version: selection.policy_assignment.policy_version,
      assignment_key:
        assignment_key(
          first.experiment.id,
          first.decision_point.id,
          first.intervention.id,
          scope.enrollment_id
        ),
      assigned_at: now()
    }

    case Repo.insert(Assignment.changeset(%Assignment{}, attrs), mode: :savepoint) do
      {:ok, assignment} ->
        {:ok,
         to_assignment_decision(
           assignment,
           selection.condition,
           false,
           selection.condition.option_id
         ), assignment, true}

      {:error, %Ecto.Changeset{} = changeset} ->
        case conflict?(changeset) do
          true ->
            assignment =
              Repo.get_by!(Assignment,
                intervention_id: first.intervention.id,
                enrollment_id: scope.enrollment_id
              )

            condition = Repo.get!(Condition, assignment.condition_id)
            {:ok, to_assignment_decision(assignment, condition, true), assignment, false}

          false ->
            normalize_result({:error, changeset})
        end
    end
  end

  defp increment_batch_assignment_count(%{policy_state: %PolicyState{id: id}}) do
    from(policy_state in PolicyState, where: policy_state.id == ^id)
    |> Repo.update_all(inc: [assignment_count: 1])
  end

  defp increment_batch_assignment_count(first),
    do: increment_assignment_count(first.experiment, first.decision_point.id)

  defp batch_assignment_event(decision, request, assignment, first, selection, reused?) do
    %{
      decision: decision,
      request: request,
      assignment: assignment,
      experiment: first.experiment,
      decision_point: first.decision_point,
      selection: selection,
      reused?: reused?
    }
  end

  defp emit_committed_batch_assignment(event) do
    if event.reused? do
      :telemetry.execute([:oli, :experiments, :assignment, :reuse], %{count: 1}, %{
        experiment_id: event.assignment.experiment_id,
        decision_point_id: event.assignment.decision_point_id,
        algorithm: event.assignment.assigned_by_policy,
        algorithm_version: event.assignment.policy_version,
        selected_condition_id: event.assignment.condition_id,
        selected_condition_code: event.decision.condition_code,
        guardrail_action: :sticky_reuse
      })
    else
      selection = event.selection

      emit_assignment_guardrail_telemetry(
        event.experiment,
        event.decision_point,
        selection.condition,
        selection.policy_assignment,
        selection.guardrail_action,
        selection.assignment_counts
      )
    end

    Telemetry.emit(:assignment_decided, {event.decision, event.request},
      assignment: event.assignment,
      experiment: event.experiment
    )
  end

  defp emit_batch_fallback(reason, rows) do
    first = List.first(rows)

    :telemetry.execute([:oli, :experiments, :assignment, :fallback], %{count: 1}, %{
      reason: reason,
      experiment_id: first && first.experiment.id,
      decision_point_id: first && first.decision_point.id
    })
  end

  defp do_assign_condition_for_current_project(request, scope) do
    with {:ok, scope} <- validate_publication(scope),
         {:ok, revision} <- resolve_delivery_revision(request, scope),
         :ok <- materialize_weighted_random_intervention(request, scope),
         {:ok, match} <- active_experiment_match(request, scope, revision),
         {:ok, decision} <- assign_or_reuse(match, scope, request) do
      {:ok, decision}
    end
  end

  defp nonparticipating_assignment_fallback(reason) do
    :telemetry.execute(
      [:oli, :experiments, :assignment, :fallback],
      %{count: 1},
      %{reason: reason}
    )

    {:ok, %AssignmentDecision{status: :no_experiment}}
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

  defp active_experiment_match(
         %{page_resource_id: page_resource_id, content_element_id: content_element_id} = request,
         scope,
         revision
       )
       when is_integer(page_resource_id) and is_binary(content_element_id) do
    query =
      from experiment in ExperimentDefinitionSchema,
        as: :experiment,
        join: decision_point in DecisionPoint,
        on: decision_point.experiment_id == experiment.id,
        join: intervention in Intervention,
        on: intervention.decision_point_id == decision_point.id,
        where:
          experiment.state == :active and
            experiment.project_id == ^scope.project_id and
            decision_point.alternatives_resource_id == ^request.alternatives_resource_id and
            intervention.page_resource_id == ^page_resource_id and
            intervention.content_element_id == ^content_element_id,
        order_by: [asc: experiment.id],
        limit: 3,
        select:
          {experiment, decision_point, intervention,
           exists(participating_section_query(scope.section_id))}

    case Repo.all(query) do
      [] ->
        no_experiment_match()

      [{_experiment, _decision_point, _intervention, false}] ->
        no_experiment_match()

      [{experiment, decision_point, intervention, true}] ->
        with {:ok, conditions} <-
               validate_runtime_condition_compatibility(experiment, decision_point, revision) do
          decision_point = runtime_decision_point(experiment, decision_point, conditions)

          {:ok,
           %{
             experiment: experiment,
             decision_point: decision_point,
             intervention: intervention,
             conditions: conditions,
             available_condition_codes: request.available_condition_codes
           }}
        end

      matches ->
        ambiguous_match(
          matches,
          scope,
          request,
          fn {experiment, _decision_point, _intervention, _participating?} -> experiment.id end
        )
    end
  end

  defp active_experiment_match(request, scope, revision) do
    query =
      from experiment in ExperimentDefinitionSchema,
        as: :experiment,
        join: decision_point in DecisionPoint,
        on: decision_point.experiment_id == experiment.id,
        where:
          experiment.state == :active and
            experiment.project_id == ^scope.project_id and
            decision_point.alternatives_resource_id == ^request.alternatives_resource_id and
            decision_point.decision_point_key == ^request.decision_point_key,
        order_by: [asc: experiment.id],
        limit: 3,
        select:
          {experiment, decision_point, exists(participating_section_query(scope.section_id))}

    case Repo.all(query) do
      [] ->
        no_experiment_match()

      [{_experiment, _decision_point, false}] ->
        no_experiment_match()

      [{experiment, decision_point, true}] ->
        with {:ok, conditions} <-
               validate_runtime_condition_compatibility(
                 experiment,
                 decision_point,
                 revision
               ) do
          decision_point = runtime_decision_point(experiment, decision_point, conditions)

          {:ok,
           %{
             experiment: experiment,
             decision_point: decision_point,
             conditions: conditions,
             available_condition_codes: request.available_condition_codes
           }}
        end

      matches ->
        ambiguous_match(matches, scope, request, fn {experiment, _, _} -> experiment.id end)
    end
  end

  defp no_experiment_match do
    :telemetry.execute(
      [:oli, :experiments, :assignment, :fallback],
      %{count: 1},
      %{reason: :no_experiment}
    )

    {:ok, %{status: :no_experiment}}
  end

  defp ambiguous_match(matches, scope, request, experiment_id_fn) do
    experiment_ids = matches |> Enum.take(2) |> Enum.map(experiment_id_fn)

    :telemetry.execute(
      [:oli, :experiments, :assignment, :ambiguous_match],
      %{count: 1, sampled_match_count: length(experiment_ids)},
      %{
        experiment_ids: experiment_ids,
        truncated?: length(matches) > 2,
        project_id: scope.project_id,
        section_id: scope.section_id,
        alternatives_resource_id: request.alternatives_resource_id,
        decision_point_key: request.decision_point_key
      }
    )

    {:ok, %{status: :no_experiment}}
  end

  defp resolve_delivery_revision(request, scope) do
    case DeliveryResolver.from_resource_id(
           scope.section_slug,
           request.alternatives_resource_id
         ) do
      %Revision{} = revision ->
        with true <- revision.id == request.alternatives_revision_id,
             true <- revision.resource_type_id == ResourceType.id_for_alternatives(),
             :ok <- validate_experiment_decision_point_revision(revision) do
          {:ok, revision}
        else
          false ->
            invalid_condition(
              "delivery alternatives revision or options do not match the deployed publication",
              %{
                alternatives_resource_id: request.alternatives_resource_id,
                requested_revision_id: request.alternatives_revision_id,
                resolved_revision_id: revision.id
              }
            )

          {:error, %ExperimentError{}} = error ->
            error
        end

      nil ->
        invalid_condition("alternatives resource is not deployed to section", %{
          alternatives_resource_id: request.alternatives_resource_id,
          section_id: scope.section_id
        })
    end
  end

  defp validate_runtime_condition_compatibility(experiment, decision_point, revision) do
    conditions = active_conditions(experiment.id, decision_point.id)

    with :ok <- validate_condition_option_mapping(revision, conditions) do
      {:ok, conditions}
    end
  end

  defp runtime_decision_point(experiment, decision_point, _conditions),
    do: %{decision_point | algorithm: experiment.algorithm}

  defp select_condition(_experiment, _decision_point, _conditions, [], _scope, _intervention),
    do: invalid_condition("no condition codes supplied")

  defp select_condition(
         experiment,
         decision_point,
         active_conditions,
         available_condition_codes,
         scope,
         intervention
       ) do
    conditions =
      Enum.filter(active_conditions, fn condition ->
        (condition.option_id || condition.condition_code) in available_condition_codes
      end)

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
        policy_state =
          get_policy_state(experiment.id, decision_point.id, experiment.algorithm)

        {policy_module, policy_conditions, guardrail_action} =
          assignment_policy_for(
            experiment,
            decision_point,
            conditions,
            policy_state
          )

        policy_context = %{
          conditions: conditions,
          assignment_key:
            assignment_key(
              experiment.id,
              decision_point.id,
              intervention && intervention.id,
              scope.enrollment_id
            )
        }

        policy_module
        |> apply(:assign, [
          decision_point_policy_config(decision_point),
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
              assignment_counts_for_guardrails(experiment, decision_point)
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
         experiment,
         %DecisionPoint{algorithm: :thompson_sampling} = decision_point,
         conditions,
         _policy_state
       ) do
    assignment_counts = assignment_counts_by_condition(experiment.id, decision_point.id)
    guardrails = thompson_guardrails(decision_point_policy_config(decision_point))

    assignment_count =
      Enum.reduce(assignment_counts, 0, fn {_id, count}, total -> total + count end)

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
        {policy_module(decision_point.algorithm), capped_conditions,
         cap_guardrail_action(capped_conditions, conditions)}
    end
  end

  defp assignment_policy_for(
         _experiment,
         decision_point,
         conditions,
         _policy_state
       ) do
    {policy_module(decision_point.algorithm), conditions, :none}
  end

  defp assignment_policy_for_snapshot(
         _experiment,
         %DecisionPoint{algorithm: :thompson_sampling} = decision_point,
         conditions,
         _policy_state,
         assignment_counts
       ) do
    guardrails = thompson_guardrails(decision_point_policy_config(decision_point))

    assignment_count =
      Enum.reduce(assignment_counts, 0, fn {_id, count}, total -> total + count end)

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
        {policy_module(decision_point.algorithm), capped_conditions,
         cap_guardrail_action(capped_conditions, conditions)}
    end
  end

  defp assignment_policy_for_snapshot(
         _experiment,
         decision_point,
         conditions,
         _policy_state,
         _assignment_counts
       ),
       do: {policy_module(decision_point.algorithm), conditions, :none}

  defp assignment_counts_for_guardrails(experiment, decision_point),
    do: assignment_counts_by_condition(experiment.id, decision_point.id)

  defp thompson_guardrails(policy_config) do
    policy_config
    |> Map.get("guardrails", %{})
    |> Map.merge(@thompson_default_guardrails, fn _key, configured, _default -> configured end)
  end

  defp decision_point_policy_config(%DecisionPoint{} = decision_point) do
    %{
      "reward_source" => decision_point.reward_source,
      "priors" => %{
        "default" => %{
          "alpha" => decision_point.prior_alpha,
          "beta" => decision_point.prior_beta
        }
      },
      "guardrails" => %{
        "warm_up_assignments" => decision_point.warm_up_assignments,
        "max_condition_share" => decision_point.max_condition_share,
        "fixed_control_allocation" => decision_point.fixed_control_allocation,
        "imbalance_threshold" => decision_point.imbalance_threshold
      }
    }
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
      imbalance_flag?:
        imbalance_flag?(
          decision_point_policy_config(decision_point),
          condition,
          assignment_counts
        )
    })
  end

  defp imbalance_flag?(policy_config, condition, assignment_counts) do
    guardrails = thompson_guardrails(policy_config)

    total =
      Enum.reduce(assignment_counts, 0, fn {_condition_id, count}, total -> total + count end)

    (total > 0 and condition) &&
      Map.get(assignment_counts, condition.id, 0) / total > guardrails["imbalance_threshold"]
  end

  defp existing_assignment_decision(request, scope) do
    query =
      from assignment in Assignment,
        join: experiment in ExperimentDefinitionSchema,
        as: :experiment,
        on: experiment.id == assignment.experiment_id,
        join: decision_point in DecisionPoint,
        on: decision_point.id == assignment.decision_point_id,
        join: condition in Condition,
        on: condition.id == assignment.condition_id,
        left_join: mapping in DecisionPointCondition,
        on:
          mapping.decision_point_id == assignment.decision_point_id and
            mapping.condition_id == assignment.condition_id,
        where:
          experiment.project_id == ^scope.project_id and
            exists(participating_section_query(scope.section_id)) and
            assignment.section_id == ^scope.section_id and
            assignment.enrollment_id == ^scope.enrollment_id and
            assignment.user_id == ^scope.user_id and
            decision_point.alternatives_resource_id == ^request.alternatives_resource_id and
            decision_point.decision_point_key == ^request.decision_point_key and
            condition.active == true and
            (mapping.option_id in ^request.available_condition_codes or
               (is_nil(mapping.id) and
                  condition.condition_code in ^request.available_condition_codes)),
        order_by: [desc: assignment.id],
        limit: 1,
        select: {assignment, condition, mapping.option_id}

    query = maybe_filter_assignment_intervention(query, request)

    case Repo.one(query) do
      {%Assignment{} = assignment, %Condition{} = condition, option_id} ->
        {:ok, to_assignment_decision(assignment, condition, true, option_id)}

      nil ->
        {:ok, %AssignmentDecision{status: :no_experiment}}
    end
  end

  defp maybe_filter_assignment_intervention(
         query,
         %{page_resource_id: page_resource_id, content_element_id: content_element_id}
       )
       when is_integer(page_resource_id) and is_binary(content_element_id) do
    from [assignment, _experiment, _decision_point, _condition, _mapping] in query,
      join: intervention in Intervention,
      on: intervention.id == assignment.intervention_id,
      where:
        intervention.page_resource_id == ^page_resource_id and
          intervention.content_element_id == ^content_element_id
  end

  defp maybe_filter_assignment_intervention(query, _request), do: query

  defp assign_or_reuse(%{status: :no_experiment}, _scope, _request),
    do: {:ok, %AssignmentDecision{status: :no_experiment}}

  defp assign_or_reuse(match, scope, request) do
    case find_assignment(match, scope.enrollment_id) do
      %Assignment{} = assignment ->
        condition = Repo.get!(Condition, assignment.condition_id)
        decision = to_assignment_decision(assignment, condition, true)

        :telemetry.execute([:oli, :experiments, :assignment, :reuse], %{count: 1}, %{
          experiment_id: match.experiment.id,
          decision_point_id: match.decision_point.id,
          algorithm: match.experiment.algorithm,
          algorithm_version: assignment.policy_version,
          selected_condition_id: assignment.condition_id,
          selected_condition_code: condition.condition_code,
          guardrail_action: :sticky_reuse
        })

        Telemetry.emit(:assignment_decided, {decision, request}, assignment: assignment)
        {:ok, decision}

      nil ->
        with {:ok, selection} <-
               select_condition(
                 match.experiment,
                 match.decision_point,
                 match.conditions,
                 match.available_condition_codes,
                 scope,
                 Map.get(match, :intervention)
               ) do
          create_assignment(Map.merge(match, selection), scope, request)
        end
    end
  end

  defp find_assignment(%{intervention: %Intervention{id: intervention_id}}, enrollment_id) do
    Repo.one(
      from assignment in Assignment,
        where:
          assignment.intervention_id == ^intervention_id and
            assignment.enrollment_id == ^enrollment_id
    )
  end

  defp find_assignment(%{experiment: experiment, decision_point: decision_point}, enrollment_id) do
    Repo.one(
      from assignment in Assignment,
        where:
          assignment.experiment_id == ^experiment.id and
            assignment.decision_point_id == ^decision_point.id and
            is_nil(assignment.intervention_id) and
            assignment.enrollment_id == ^enrollment_id
    )
  end

  defp create_assignment(match, scope, request) do
    attrs = %{
      experiment_id: match.experiment.id,
      decision_point_id: match.decision_point.id,
      condition_id: match.condition.id,
      intervention_id: Map.get(match, :intervention) && match.intervention.id,
      section_id: scope.section_id,
      enrollment_id: scope.enrollment_id,
      user_id: scope.user_id,
      assigned_by_policy: Atom.to_string(match.experiment.algorithm),
      policy_version: match.policy_assignment.policy_version,
      assignment_key:
        assignment_key(
          match.experiment.id,
          match.decision_point.id,
          Map.get(match, :intervention) && match.intervention.id,
          scope.enrollment_id
        ),
      assigned_at: now()
    }

    %Assignment{}
    |> Assignment.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, assignment} ->
        increment_assignment_count(match.experiment, match.decision_point.id)
        decision = to_assignment_decision(assignment, match.condition, false)

        Telemetry.emit(:assignment_decided, {decision, request},
          assignment: assignment,
          experiment: match.experiment
        )

        {:ok, decision}

      {:error, %Ecto.Changeset{} = changeset} ->
        if conflict?(changeset) do
          assignment =
            find_assignment(match, scope.enrollment_id)

          condition = Repo.get!(Condition, assignment.condition_id)
          decision = to_assignment_decision(assignment, condition, true)

          Telemetry.emit(:assignment_decided, {decision, request},
            assignment: assignment,
            experiment: match.experiment
          )

          {:ok, decision}
        else
          normalize_result({:error, changeset})
        end
    end
  end

  defp assignment_key(experiment_id, decision_point_id, nil, enrollment_id) do
    "#{experiment_id}:#{decision_point_id}:#{enrollment_id}"
  end

  defp assignment_key(experiment_id, decision_point_id, intervention_id, enrollment_id) do
    "#{experiment_id}:#{decision_point_id}:#{intervention_id}:#{enrollment_id}"
  end

  defp increment_assignment_count(experiment, decision_point_id) do
    policy_state = get_or_create_policy_state(experiment, decision_point_id)

    from(policy_state in PolicyState, where: policy_state.id == ^policy_state.id)
    |> Repo.update_all(inc: [assignment_count: 1])
  end

  defp create_exposure(request) do
    Repo.transaction(fn ->
      {assignment, alternatives_resource_id} =
        get_scoped_assignment_with_decision_point!(
          request.assignment_id,
          request.scope
        )

      case validate_exposure_revision(alternatives_resource_id, request) do
        :ok ->
          {assignment, Map.put(runtime_event(request), "reused", false)}

        {:error, %ExperimentError{} = error} ->
          Repo.rollback(error)
      end
    end)
    |> normalize_transaction_result()
    |> case do
      {:ok, {assignment, event}} ->
        receipt = exposure_receipt(assignment, event)

        :telemetry.execute([:oli, :experiments, :exposure, :recorded], %{count: 1}, %{
          experiment_id: assignment.experiment_id,
          decision_point_id: assignment.decision_point_id
        })

        Telemetry.emit(:exposure_recorded, {receipt, request}, assignment: assignment)
        {:ok, receipt}

      {:error, %ExperimentError{}} = error ->
        error
    end
  end

  defp validate_exposure_revision(alternatives_resource_id, request) do
    case DeliveryResolver.from_resource_id(
           request.scope.section_slug,
           alternatives_resource_id
         ) do
      %Revision{id: revision_id} when revision_id == request.content_revision_id ->
        :ok

      %Revision{id: revision_id} ->
        invalid_condition(
          "exposure revision does not match the alternatives revision deployed to section",
          %{
            alternatives_resource_id: alternatives_resource_id,
            content_revision_id: request.content_revision_id,
            resolved_revision_id: revision_id
          }
        )

      nil ->
        invalid_condition("exposure alternatives resource is not deployed to section", %{
          alternatives_resource_id: alternatives_resource_id,
          section_id: request.scope.section_id
        })
    end
  end

  defp create_outcome(request) do
    Repo.transaction(fn ->
      assignment = get_scoped_assignment!(request.assignment_id, request.scope, lock: false)
      {assignment, Map.put(runtime_event(request), "reused", false)}
    end)
    |> normalize_transaction_result()
    |> case do
      {:ok, {assignment, event}} ->
        receipt = outcome_receipt(assignment, event)
        Telemetry.emit(:outcome_recorded, {receipt, request}, assignment: assignment)
        {:ok, receipt}

      {:error, %ExperimentError{}} = error ->
        error
    end
  end

  defp create_reward(request) do
    Repo.transaction(fn ->
      assignment = get_scoped_assignment!(request.assignment_id, request.scope, lock: true)
      state = assignment.runtime_event_state || %{}
      reward_events = Map.get(state, "rewards", %{})

      case Map.get(reward_events, request.key) do
        nil ->
          event = reward_event(request, assignment)
          update_assignment_event_state!(assignment, "rewards", request.key, event)

          case record_policy_reward(assignment, request, event) do
            :ok ->
              {assignment, Map.put(event, "reused", false), nil}

            {:ok, policy_update_emit} ->
              {assignment, Map.put(event, "reused", false), policy_update_emit}

            {:error, error} ->
              Repo.rollback(error)
          end

        event ->
          {assignment, Map.put(event, "reused", true), nil}
      end
    end)
    |> normalize_transaction_result()
    |> case do
      {:ok, {assignment, event, policy_update_emit}} ->
        receipt = reward_receipt(assignment, event)

        if receipt.reused? == false do
          :telemetry.execute([:oli, :experiments, :reward, :recorded], %{count: 1}, %{
            experiment_id: assignment.experiment_id,
            decision_point_id: assignment.decision_point_id,
            condition_id: assignment.condition_id,
            reward_class: reward_class(request.reward_value)
          })
        end

        Telemetry.emit(:reward_recorded, {receipt, request}, assignment: assignment)
        emit_policy_update(policy_update_emit)
        {:ok, receipt}

      {:error, %ExperimentError{}} = error ->
        error
    end
  end

  defp update_assignment_event_state!(assignment, event_group, key, event) do
    state = assignment.runtime_event_state || %{}
    events = Map.get(state, event_group, %{})
    updated_state = Map.put(state, event_group, Map.put(events, key, event))

    assignment
    |> Assignment.changeset(%{runtime_event_state: updated_state})
    |> Repo.update!()
  end

  defp runtime_event(%Oli.Experiments.RecordExposureRequest{} = request) do
    %{
      "assignment_id" => request.assignment_id,
      "key" => request.key,
      "content_revision_id" => request.content_revision_id,
      "publication_id" => request.scope && request.scope.publication_id,
      "recorded_at" => request.exposed_at || now()
    }
  end

  defp runtime_event(%Oli.Experiments.RecordOutcomeRequest{} = request) do
    %{
      "assignment_id" => request.assignment_id,
      "key" => request.key,
      "activity_attempt_id" => request.activity_attempt_id,
      "resource_attempt_id" => request.resource_attempt_id,
      "activity_resource_id" => request.activity_resource_id,
      "score" => request.score,
      "out_of" => request.out_of,
      "recorded_at" => request.observed_at || now()
    }
  end

  defp reward_event(%Oli.Experiments.RecordRewardRequest{} = request, %Assignment{} = assignment) do
    %{
      "assignment_id" => request.assignment_id,
      "experiment_id" => assignment.experiment_id,
      "decision_point_id" => assignment.decision_point_id,
      "condition_id" => assignment.condition_id,
      "outcome_key" => request.outcome_key,
      "key" => request.key,
      "reward_value" => request.reward_value,
      "reward_source" => request.reward_source,
      "recorded_at" => now()
    }
  end

  defp insert_definition_graph(attrs, request, section_ids) do
    case structural_configuration_change?(request) do
      false ->
        insert_definition(attrs, section_ids)

      true ->
        Repo.transaction(fn ->
          changeset =
            %ExperimentDefinitionSchema{}
            |> ExperimentDefinitionSchema.changeset(attrs)

          case Repo.insert(changeset) do
            {:ok, definition} ->
              replace_experiment_sections!(definition.id, section_ids)

              lock_experiment!(definition.id)

              lock_and_validate_current_bindings!(
                request.decision_points,
                scope_from_definition(definition),
                definition.id
              )

              conditions = insert_conditions!(definition.id, request.conditions)
              insert_decision_points!(definition, request.decision_points, conditions)
              Repo.preload(definition, :sections)

            {:error, changeset} ->
              Repo.rollback(changeset)
          end
        end)
        |> normalize_transaction_result()
    end
  end

  defp update_definition_graph(schema, request, section_ids) do
    case structural_configuration_change?(request) do
      false ->
        update_definition(
          schema,
          update_attrs(request, schema.algorithm),
          request.section_ids,
          section_ids
        )

      true ->
        Repo.transaction(fn ->
          updated =
            schema
            |> ExperimentDefinitionSchema.changeset(update_attrs(request, schema.algorithm))
            |> Repo.update!()

          maybe_replace_experiment_sections!(updated.id, request.section_ids, section_ids)
          lock_experiment!(updated.id)

          lock_and_validate_current_bindings!(
            request.decision_points,
            scope_from_definition(updated),
            updated.id
          )

          replace_definition_graph!(updated, request)
          Repo.preload(updated, :sections, force: true)
        end)
        |> normalize_transaction_result()
    end
  end

  defp replace_definition_graph!(schema, request) do
    delete_draft_graph!(schema.id, preserve_conditions: true)
    conditions = reconcile_conditions!(schema.id, request.conditions)
    insert_decision_points!(schema, request.decision_points, conditions)
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

  defp insert_decision_points!(definition, decision_points, conditions) do
    decision_points
    |> Enum.with_index()
    |> Enum.each(fn {point_attrs, position} ->
      point_attrs = atomize_keys(point_attrs)

      decision_point =
        %DecisionPoint{}
        |> DecisionPoint.changeset(decision_point_attrs(point_attrs, definition.id, position))
        |> Repo.insert!()

      point_attrs
      |> Map.get(:mappings, [])
      |> Enum.with_index()
      |> Enum.each(fn {mapping, mapping_position} ->
        mapping = atomize_keys(mapping)
        condition_ref = Map.get(mapping, :condition_id) || Map.get(mapping, :condition_ref)
        condition = Map.fetch!(conditions, condition_ref)

        %DecisionPointCondition{}
        |> DecisionPointCondition.changeset(%{
          decision_point_id: decision_point.id,
          condition_id: condition.id,
          option_id: Map.get(mapping, :option_id),
          weight: Map.get(mapping, :weight, 1.0),
          position: Map.get(mapping, :position, mapping_position)
        })
        |> Repo.insert!()
      end)

      point_attrs
      |> Map.get(:interventions, [])
      |> Enum.each(&insert_intervention!(decision_point.id, &1))

      get_or_create_policy_state(definition, decision_point.id)
    end)
  end

  defp insert_intervention!(decision_point_id, attrs) do
    attrs = atomize_keys(attrs)

    intervention =
      %Intervention{}
      |> Intervention.changeset(%{
        decision_point_id: decision_point_id,
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

  defp delete_draft_graph!(experiment_id, options) do
    decision_point_ids =
      from(point in DecisionPoint, where: point.experiment_id == ^experiment_id, select: point.id)

    intervention_ids =
      from(intervention in Intervention,
        where: intervention.decision_point_id in subquery(decision_point_ids),
        select: intervention.id
      )

    from(binding in AssessmentBinding,
      where: binding.intervention_id in subquery(intervention_ids)
    )
    |> Repo.delete_all()

    from(intervention in Intervention,
      where: intervention.decision_point_id in subquery(decision_point_ids)
    )
    |> Repo.delete_all()

    from(mapping in DecisionPointCondition,
      where: mapping.decision_point_id in subquery(decision_point_ids)
    )
    |> Repo.delete_all()

    from(policy_state in PolicyState, where: policy_state.experiment_id == ^experiment_id)
    |> Repo.delete_all()

    from(decision_point in DecisionPoint, where: decision_point.experiment_id == ^experiment_id)
    |> Repo.delete_all()

    unless Keyword.get(options, :preserve_conditions, false) do
      from(condition in Condition, where: condition.experiment_id == ^experiment_id)
      |> Repo.delete_all()
    end
  end

  defp lock_experiment!(experiment_id) do
    Repo.one!(
      from(experiment in ExperimentDefinitionSchema,
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

  defp decision_point_attrs(decision_point, experiment_id, fallback_position) do
    attrs = atomize_keys(decision_point)

    attrs
    |> Map.take([
      :alternatives_resource_id,
      :decision_point_key,
      :title,
      :position,
      :prior_alpha,
      :prior_beta,
      :warm_up_assignments,
      :max_condition_share,
      :fixed_control_allocation,
      :imbalance_threshold,
      :reward_source
    ])
    |> Map.put(:experiment_id, experiment_id)
    |> Map.update(:position, fallback_position, &(&1 || fallback_position))
  end

  defp record_policy_reward(assignment, request, reward_event) do
    experiment = Repo.get!(ExperimentDefinitionSchema, assignment.experiment_id)

    decision_point =
      experiment
      |> runtime_decision_point(Repo.get!(DecisionPoint, assignment.decision_point_id), [])

    case experiment.algorithm do
      :weighted_random ->
        :ok

      _algorithm ->
        record_mutating_policy_reward(
          experiment,
          decision_point,
          assignment,
          request,
          reward_event
        )
    end
  end

  defp record_mutating_policy_reward(
         experiment,
         decision_point,
         assignment,
         request,
         reward_event
       ) do
    condition = Repo.get!(Condition, assignment.condition_id)

    policy_state =
      experiment
      |> get_or_create_policy_state(assignment.decision_point_id)
      |> lock_policy_state()

    experiment.algorithm
    |> policy_module()
    |> apply(:record_reward, [
      decision_point_policy_config(decision_point),
      policy_state.state,
      %{condition_code: condition.condition_code, reward_value: request.reward_value}
    ])
    |> case do
      {:ok, policy_update} ->
        persist_policy_update(
          policy_state,
          request,
          reward_event,
          condition,
          policy_update,
          assignment,
          experiment
        )

      {:error, reason} ->
        :telemetry.execute([:oli, :experiments, :policy, :update_failed], %{count: 1}, %{
          policy_state_id: policy_state.id,
          reward_key_hash: hash_key(request.key),
          algorithm: experiment.algorithm,
          algorithm_version: policy_state.algorithm_version,
          reward_class: reward_class(request.reward_value),
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
    decision_point =
      experiment
      |> runtime_decision_point(Repo.get!(DecisionPoint, decision_point_id), [])

    case get_policy_state(experiment.id, decision_point_id, experiment.algorithm) do
      nil ->
        {algorithm_version, state} =
          initial_policy_state_attrs(experiment, decision_point)

        %PolicyState{}
        |> PolicyState.changeset(%{
          experiment_id: experiment.id,
          decision_point_id: decision_point_id,
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
         %ExperimentDefinitionSchema{} = experiment,
         %DecisionPoint{algorithm: :thompson_sampling} = decision_point
       ) do
    conditions = active_conditions(experiment.id, decision_point.id)

    policy_config =
      decision_point_policy_config(decision_point)

    {:ok, state} = ThompsonSampling.initial_state(policy_config, conditions)

    {ThompsonSampling.version(), state}
  end

  defp initial_policy_state_attrs(
         %ExperimentDefinitionSchema{},
         %DecisionPoint{algorithm: algorithm}
       ) do
    {Atom.to_string(algorithm), %{}}
  end

  defp persist_policy_update(
         policy_state,
         request,
         reward_event,
         condition,
         policy_update,
         assignment,
         experiment
       ) do
    policy_update_key = "policy_update:#{request.key}"

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
            Map.get(policy_update.counters, :reward_failure_count, 0)
      })
      |> Repo.update!()

    :telemetry.execute([:oli, :experiments, :policy, :updated], %{count: 1}, %{
      policy_state_id: policy_state.id,
      reward_key_hash: hash_key(request.key),
      condition_id: condition.id,
      condition_code: condition.condition_code,
      algorithm: policy_state.algorithm,
      algorithm_version: policy_update.algorithm_version,
      reward_class: reward_class(request.reward_value)
    })

    {:ok,
     {%{
        policy_state_id: updated_policy_state.id,
        reward_key: reward_event["key"],
        condition_id: condition.id,
        previous_state: policy_update.previous_state,
        next_state: policy_update.next_state,
        algorithm_version: policy_update.algorithm_version,
        update_reason: policy_update.update_reason,
        key: policy_update_key,
        inserted_at: now()
      },
      %{
        experiment_id: assignment.experiment_id,
        decision_point_id: assignment.decision_point_id,
        condition_id: assignment.condition_id,
        reward_value: request.reward_value,
        key: request.key
      },
      [
        assignment: assignment,
        condition: condition,
        experiment: experiment,
        policy_state: updated_policy_state
      ]}}
  end

  defp emit_policy_update(nil), do: :ok

  defp emit_policy_update({policy_update, reward, opts}) do
    Telemetry.emit(:policy_updated, {policy_update, reward}, opts)
  end

  defp reward_class(reward_value) when reward_value in [1, 1.0], do: :success
  defp reward_class(reward_value) when reward_value in [0, 0.0], do: :failure
  defp reward_class(_reward_value), do: :unknown

  defp policy_module(:weighted_random), do: WeightedRandom
  defp policy_module(:thompson_sampling), do: ThompsonSampling

  defp get_scoped_assignment!(assignment_id, scope, opts) do
    lock? = Keyword.get(opts, :lock, false)

    case get_scoped_assignment_query(assignment_id, scope, lock?) do
      {:ok, query} ->
        case Repo.one(query) do
          %Assignment{} = assignment ->
            assignment

          nil ->
            Repo.rollback(
              if Repo.exists?(
                   from assignment in Assignment, where: assignment.id == ^assignment_id
                 ) do
                elem(
                  invalid_scope("assignment is outside scope", %{assignment_id: assignment_id}),
                  1
                )
              else
                elem(not_found("assignment not found", %{assignment_id: assignment_id}), 1)
              end
            )
        end

      {:error, %ExperimentError{} = error} ->
        Repo.rollback(error)
    end
  end

  defp get_scoped_assignment_with_decision_point!(assignment_id, scope) do
    case get_scoped_assignment_query(assignment_id, scope, false) do
      {:ok, query} ->
        case Repo.one(query) do
          %Assignment{decision_point: %DecisionPoint{} = decision_point} = assignment ->
            {assignment, decision_point.alternatives_resource_id}

          nil ->
            scoped_assignment_not_found!(assignment_id)
        end

      {:error, %ExperimentError{} = error} ->
        Repo.rollback(error)
    end
  end

  defp scoped_assignment_not_found!(assignment_id) do
    Repo.rollback(
      if Repo.exists?(from assignment in Assignment, where: assignment.id == ^assignment_id) do
        elem(
          invalid_scope("assignment is outside scope", %{assignment_id: assignment_id}),
          1
        )
      else
        elem(not_found("assignment not found", %{assignment_id: assignment_id}), 1)
      end
    )
  end

  defp get_scoped_assignment_query(assignment_id, scope, lock?) do
    with {:ok, scope} <- validate_delivery_participation_scope(scope) do
      query =
        from assignment in Assignment,
          join: experiment in ExperimentDefinitionSchema,
          as: :experiment,
          on: experiment.id == assignment.experiment_id,
          join: condition in Condition,
          on:
            condition.id == assignment.condition_id and
              condition.experiment_id == experiment.id,
          join: decision_point in DecisionPoint,
          on:
            decision_point.id == assignment.decision_point_id and
              decision_point.experiment_id == experiment.id,
          where:
            assignment.id == ^assignment_id and
              experiment.project_id == ^scope.project_id and
              exists(participating_section_query(scope.section_id)) and
              assignment.section_id == ^scope.section_id and
              assignment.enrollment_id == ^scope.enrollment_id and
              assignment.user_id == ^scope.user_id,
          preload: [
            experiment: experiment,
            condition: condition,
            decision_point: decision_point
          ]

      {:ok, if(lock?, do: lock(query, "FOR UPDATE"), else: query)}
    end
  end

  defp insert_definition(attrs, section_ids) do
    Repo.transaction(fn ->
      changeset =
        %ExperimentDefinitionSchema{}
        |> ExperimentDefinitionSchema.changeset(attrs)

      case Repo.insert(changeset) do
        {:ok, definition} ->
          replace_experiment_sections!(definition.id, section_ids)
          Repo.preload(definition, :sections)

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> normalize_transaction_result()
  end

  defp update_definition(schema, attrs, requested_section_ids, section_ids) do
    Repo.transaction(fn ->
      updated =
        schema
        |> ExperimentDefinitionSchema.changeset(attrs)
        |> Repo.update!()

      maybe_replace_experiment_sections!(updated.id, requested_section_ids, section_ids)
      Repo.preload(updated, :sections, force: true)
    end)
    |> normalize_transaction_result()
  end

  defp maybe_replace_experiment_sections!(_experiment_id, nil, _section_ids), do: :ok

  defp maybe_replace_experiment_sections!(experiment_id, _requested_section_ids, section_ids),
    do: replace_experiment_sections!(experiment_id, section_ids)

  defp replace_experiment_sections!(experiment_id, section_ids) do
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

  defp eligible_sections_query(scope) do
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

  defp section_participation(schema, scope) do
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

  defp get_scoped_definition(experiment_id, scope) do
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
      assignment_unit: request.assignment_unit
    }
  end

  defp update_attrs(request, _existing_algorithm) do
    request
    |> Map.from_struct()
    |> Map.take([:slug, :name, :description, :algorithm, :assignment_unit])
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

    {:ok, decision_points}
  end

  defp validate_transition_prerequisites(_schema, _current_state, target_state)
       when target_state != :active,
       do: :ok

  defp validate_transition_prerequisites(schema, :draft, :active) do
    with :ok <- validate_activation_algorithm(schema),
         {:ok, decision_points} <- activation_decision_points(schema),
         :ok <- validate_activation_configuration(schema, decision_points),
         :ok <- validate_no_active_decision_point_conflict(schema, decision_points) do
      :ok
    end
  end

  defp validate_transition_prerequisites(schema, :paused, :active) do
    with {:ok, decision_points} <- activation_decision_points(schema),
         :ok <- validate_no_active_decision_point_conflict(schema, decision_points) do
      :ok
    end
  end

  defp validate_activation_configuration(_schema, []), do: :ok

  defp validate_activation_configuration(schema, decision_points) do
    point_ids = Enum.map(decision_points, & &1.id)

    conditions_by_point =
      from(condition in Condition,
        join: mapping in DecisionPointCondition,
        on: mapping.condition_id == condition.id,
        where:
          condition.experiment_id == ^schema.id and
            mapping.decision_point_id in ^point_ids and condition.active == true,
        order_by: [asc: mapping.position, asc: condition.id],
        select:
          {mapping.decision_point_id,
           %{
             condition
             | option_id: mapping.option_id,
               weight: mapping.weight,
               position: mapping.position
           }}
      )
      |> Repo.all()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    interventions_by_point =
      from(intervention in Intervention,
        where: intervention.decision_point_id in ^point_ids,
        preload: :assessment_binding
      )
      |> Repo.all()
      |> Enum.group_by(& &1.decision_point_id)

    Enum.reduce_while(decision_points, :ok, fn persisted_decision_point, :ok ->
      decision_point = runtime_decision_point(schema, persisted_decision_point, [])
      conditions = Map.get(conditions_by_point, decision_point.id, [])
      interventions = Map.get(interventions_by_point, decision_point.id, [])

      result =
        with {:ok, revisions} <- activation_revisions(schema, decision_point),
             :ok <- validate_decision_point_strategies(revisions),
             :ok <- validate_minimum_active_conditions(conditions),
             :ok <- validate_positive_active_weight(conditions),
             :ok <- validate_condition_option_mappings(revisions, conditions),
             :ok <- validate_activation_interventions(decision_point, interventions),
             :ok <- validate_adaptive_activation_for_point(decision_point, conditions) do
          :ok
        end

      case result do
        :ok -> {:cont, :ok}
        {:error, %ExperimentError{}} = error -> {:halt, error}
      end
    end)
  end

  defp validate_no_active_decision_point_conflict(schema, decision_points) do
    resource_ids =
      decision_points
      |> Enum.map(& &1.alternatives_resource_id)
      |> Enum.uniq()
      |> Enum.sort()

    # Competing experiments have different experiment rows, so their lifecycle locks cannot
    # serialize this exclusivity check. Lock the shared Alternatives Group resources before the
    # conflict query so concurrent activations cannot both observe "no conflict" and proceed.
    # Acquire multiple resource locks in a stable order to reduce deadlock risk.
    from(resource in Resource,
      where: resource.id in ^resource_ids,
      order_by: [asc: resource.id],
      lock: "FOR UPDATE"
    )
    |> Repo.all()

    conflict =
      from(experiment in ExperimentDefinitionSchema,
        join: point in DecisionPoint,
        on: point.experiment_id == experiment.id,
        where:
          experiment.id != ^schema.id and
            experiment.state in [:draft, :active, :paused] and
            point.alternatives_resource_id in ^resource_ids,
        select: {experiment.id, point.alternatives_resource_id, point.decision_point_key},
        limit: 1
      )
      |> Repo.one()

    case conflict do
      nil ->
        :ok

      {experiment_id, alternatives_resource_id, decision_point_key} ->
        {:error,
         %ExperimentError{
           type: :conflict,
           message: "another current experiment already targets this Alternatives Group",
           details: %{
             experiment_id: experiment_id,
             alternatives_resource_id: alternatives_resource_id,
             decision_point_key: decision_point_key
           }
         }}
    end
  end

  defp active_conditions(experiment_id, decision_point_id) do
    mapped =
      from(condition in Condition,
        join: mapping in DecisionPointCondition,
        on: mapping.condition_id == condition.id,
        where:
          condition.experiment_id == ^experiment_id and
            mapping.decision_point_id == ^decision_point_id and
            condition.active == true,
        order_by: [asc: mapping.position, asc: condition.id],
        select: %{
          condition
          | option_id: mapping.option_id,
            weight: mapping.weight,
            position: mapping.position
        }
      )
      |> Repo.all()

    case mapped do
      [] ->
        Repo.all(
          from condition in Condition,
            where:
              condition.experiment_id == ^experiment_id and
                condition.decision_point_id == ^decision_point_id and
                condition.active == true,
            order_by: [asc: condition.position, asc: condition.id]
        )

      conditions ->
        conditions
    end
  end

  defp validate_activation_interventions(decision_point, interventions) do
    cond do
      decision_point.algorithm == :thompson_sampling and interventions == [] ->
        invalid_condition("decision point requires at least one intervention", %{
          decision_point_id: decision_point.id
        })

      decision_point.algorithm == :thompson_sampling and
          Enum.any?(interventions, &is_nil(&1.assessment_binding)) ->
        invalid_condition(
          "every Thompson Sampling intervention requires an assessment binding",
          %{
            decision_point_id: decision_point.id
          }
        )

      decision_point.algorithm == :weighted_random and
          Enum.any?(interventions, &(not is_nil(&1.assessment_binding))) ->
        invalid_condition("weighted-random interventions cannot have assessment bindings", %{
          decision_point_id: decision_point.id
        })

      true ->
        :ok
    end
  end

  defp materialize_weighted_random_intervention(
         %{page_resource_id: page_resource_id, content_element_id: content_element_id} = request,
         scope
       )
       when is_integer(page_resource_id) and is_binary(content_element_id) do
    materialize_weighted_random_interventions([request], scope)
    :ok
  end

  defp materialize_weighted_random_intervention(_request, _scope), do: :ok

  defp materialize_weighted_random_interventions(requests, scope) do
    requests =
      requests
      |> Enum.filter(&valid_intervention_identity?/1)
      |> Enum.uniq_by(&{&1.alternatives_resource_id, &1.page_resource_id, &1.content_element_id})

    alternatives_resource_ids =
      requests
      |> Enum.map(& &1.alternatives_resource_id)
      |> Enum.uniq()

    decision_points_by_resource =
      from(decision_point in DecisionPoint,
        join: experiment in ExperimentDefinitionSchema,
        as: :experiment,
        on: experiment.id == decision_point.experiment_id,
        where:
          experiment.project_id == ^scope.project_id and
            experiment.state == :active and
            experiment.algorithm == :weighted_random and
            decision_point.alternatives_resource_id in ^alternatives_resource_ids and
            exists(participating_section_query(scope.section_id)),
        select: {decision_point.alternatives_resource_id, decision_point.id}
      )
      |> Repo.all()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    now = now()

    candidate_entries =
      for request <- requests,
          decision_point_id <-
            Map.get(decision_points_by_resource, request.alternatives_resource_id, []) do
        %{
          decision_point_id: decision_point_id,
          page_resource_id: request.page_resource_id,
          content_element_id: request.content_element_id,
          inserted_at: now,
          updated_at: now
        }
      end

    existing_identities =
      case candidate_entries do
        [] ->
          MapSet.new()

        entries ->
          decision_point_ids = entries |> Enum.map(& &1.decision_point_id) |> Enum.uniq()
          page_resource_ids = entries |> Enum.map(& &1.page_resource_id) |> Enum.uniq()
          content_element_ids = entries |> Enum.map(& &1.content_element_id) |> Enum.uniq()

          from(intervention in Intervention,
            where:
              intervention.decision_point_id in ^decision_point_ids and
                intervention.page_resource_id in ^page_resource_ids and
                intervention.content_element_id in ^content_element_ids,
            select:
              {intervention.decision_point_id, intervention.page_resource_id,
               intervention.content_element_id}
          )
          |> Repo.all()
          |> MapSet.new()
      end

    entries =
      Enum.reject(candidate_entries, fn entry ->
        MapSet.member?(existing_identities, {
          entry.decision_point_id,
          entry.page_resource_id,
          entry.content_element_id
        })
      end)

    case entries do
      [] ->
        :ok

      entries ->
        Repo.insert_all(Intervention, entries,
          on_conflict: :nothing,
          conflict_target: [:decision_point_id, :page_resource_id, :content_element_id]
        )

        :ok
    end
  end

  defp valid_intervention_identity?(request) do
    is_integer(request.page_resource_id) and request.page_resource_id > 0 and
      is_binary(request.content_element_id) and
      byte_size(request.content_element_id) in 1..255
  end

  defp validate_adaptive_activation_for_point(
         %DecisionPoint{algorithm: :weighted_random},
         _conditions
       ),
       do: :ok

  defp validate_adaptive_activation_for_point(
         %DecisionPoint{algorithm: :thompson_sampling} = decision_point,
         conditions
       ) do
    policy_config = decision_point_policy_config(decision_point)

    with :ok <- validate_policy_config(:thompson_sampling, policy_config || %{}),
         {:ok, _state} <- ThompsonSampling.initial_state(policy_config || %{}, conditions) do
      :ok
    else
      {:error, reason} ->
        invalid_condition("Thompson Sampling policy state could not be initialized", %{
          reason: inspect(reason)
        })
    end
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

  defp validate_condition_option_mappings(revisions, conditions) do
    Enum.reduce_while(revisions, :ok, fn revision, :ok ->
      case validate_condition_option_mapping(revision, conditions) do
        :ok -> {:cont, :ok}
        {:error, %ExperimentError{}} = error -> {:halt, error}
      end
    end)
  end

  defp validate_condition_option_mapping(revision, conditions) do
    option_ids = revision_option_ids(revision)
    missing = Enum.reject(conditions, &((&1.option_id || &1.condition_code) in option_ids))

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

  defp activation_revisions(schema, decision_point) do
    case schema.sections do
      [] ->
        project = Repo.get!(Project, schema.project_id)

        with {:ok, revision} <-
               resolve_authoring_revision(project.slug, decision_point.alternatives_resource_id) do
          {:ok, [revision]}
        end

      sections ->
        resolved =
          Enum.map(sections, fn section ->
            {section.id,
             DeliveryResolver.from_resource_id(
               section.slug,
               decision_point.alternatives_resource_id
             )}
          end)

        missing_section_ids =
          for {section_id, nil} <- resolved, do: section_id

        case missing_section_ids do
          [] ->
            {:ok, Enum.map(resolved, &elem(&1, 1))}

          _ ->
            invalid_condition(
              "alternatives content is not deployed to every experiment section",
              %{missing_section_ids: missing_section_ids}
            )
        end
    end
  end

  defp validate_decision_point_strategies(revisions) do
    Enum.reduce_while(revisions, :ok, fn revision, :ok ->
      case validate_experiment_decision_point_revision(revision) do
        :ok -> {:cont, :ok}
        {:error, %ExperimentError{}} = error -> {:halt, error}
      end
    end)
  end

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

  defp validate_immutable_algorithm(_schema, nil), do: :ok

  defp validate_immutable_algorithm(%ExperimentDefinitionSchema{algorithm: algorithm}, algorithm),
    do: :ok

  defp validate_immutable_algorithm(_schema, _algorithm),
    do: invalid_condition("assignment policy cannot be changed after experiment creation")

  defp validate_graph_request(request, scope),
    do: validate_graph_request(request, scope, request.algorithm)

  defp validate_graph_request(request, scope, algorithm) do
    case structural_configuration_change?(request) do
      false ->
        :ok

      true ->
        decision_points =
          Enum.map(request.decision_points, fn point ->
            point |> atomize_keys() |> Map.put(:algorithm, algorithm)
          end)

        with :ok <- validate_authoring_conditions(request.conditions),
             :ok <- validate_decision_points(decision_points, request.conditions, scope) do
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

  defp policy_config_from_attrs(attrs) do
    %{
      "reward_source" => Map.get(attrs, :reward_source, @thompson_reward_source),
      "priors" => %{
        "default" => %{
          "alpha" => Map.get(attrs, :prior_alpha, 1.0),
          "beta" => Map.get(attrs, :prior_beta, 1.0)
        }
      },
      "guardrails" => %{
        "warm_up_assignments" => Map.get(attrs, :warm_up_assignments, 0),
        "max_condition_share" => Map.get(attrs, :max_condition_share, 1.0),
        "fixed_control_allocation" => Map.get(attrs, :fixed_control_allocation),
        "imbalance_threshold" => Map.get(attrs, :imbalance_threshold, 1.0)
      }
    }
  end

  defp normalize_thompson_policy_config(policy_config) when is_map(policy_config) do
    defaults = ThompsonSampling.default_policy_config()

    with {:ok, priors} <- nested_map(policy_config, "priors"),
         {:ok, default_prior} <- nested_map(priors, "default"),
         :ok <- reject_condition_priors(priors),
         {:ok, guardrails} <- nested_map(policy_config, "guardrails") do
      normalized = %{
        "reward_source" => Map.get(policy_config, "reward_source", @thompson_reward_source),
        "priors" => %{
          "default" => %{
            "alpha" => Map.get(default_prior, "alpha", defaults["priors"]["default"]["alpha"]),
            "beta" => Map.get(default_prior, "beta", defaults["priors"]["default"]["beta"])
          }
        },
        "guardrails" => %{
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

  defp reject_condition_priors(priors) do
    case Map.get(priors, "conditions", %{}) do
      conditions when conditions == %{} -> :ok
      _ -> invalid_condition("Thompson Sampling per-condition priors are not supported")
    end
  end

  defp validate_thompson_priors(policy_config) do
    priors = policy_config["priors"]

    [priors["default"]]
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

  defp validate_decision_points(points, conditions, scope) when is_list(points) do
    condition_refs =
      conditions
      |> Enum.map(&atomize_keys/1)
      |> Enum.map(&(Map.get(&1, :client_ref) || Map.get(&1, :id)))

    cond do
      points == [] ->
        invalid_condition("at least one decision point is required")

      Enum.any?(condition_refs, &(&1 in [nil, ""])) ->
        invalid_condition("every condition requires a non-empty client_ref")

      length(condition_refs) != length(Enum.uniq(condition_refs)) ->
        invalid_condition("condition client_ref values must be unique")

      true ->
        Enum.reduce_while(points, :ok, fn point, :ok ->
          case validate_decision_point(point, condition_refs, scope) do
            :ok -> {:cont, :ok}
            {:error, %ExperimentError{}} = error -> {:halt, error}
          end
        end)
    end
  end

  defp validate_decision_points(_points, _conditions, _scope),
    do: invalid_condition("decision_points must be a list")

  defp validate_current_bindings(points, scope, excluded_experiment_id) when is_list(points) do
    resource_ids =
      points
      |> Enum.map(&atomize_keys/1)
      |> Enum.map(&Map.get(&1, :alternatives_resource_id))

    cond do
      resource_ids == [] ->
        :ok

      length(resource_ids) != length(Enum.uniq(resource_ids)) ->
        invalid_condition("an Alternatives Group can be bound only once in a current experiment")

      true ->
        conflict_query =
          from(point in DecisionPoint,
            join: experiment in ExperimentDefinitionSchema,
            on: experiment.id == point.experiment_id,
            where:
              experiment.project_id == ^scope.project_id and
                experiment.state in [:draft, :active, :paused] and
                point.alternatives_resource_id in ^resource_ids,
            select: {experiment.id, point.alternatives_resource_id},
            limit: 1
          )

        conflict_query =
          case excluded_experiment_id do
            nil -> conflict_query
            id -> where(conflict_query, [point, experiment], experiment.id != ^id)
          end

        conflict =
          conflict_query
          |> Repo.one()

        case conflict do
          nil ->
            :ok

          {experiment_id, resource_id} ->
            {:error,
             %ExperimentError{
               type: :conflict,
               message: "Alternatives Group is already bound to a current experiment",
               details: %{experiment_id: experiment_id, alternatives_resource_id: resource_id}
             }}
        end
    end
  end

  defp validate_current_bindings(_points, _scope, _excluded_experiment_id), do: :ok

  defp lock_and_validate_current_bindings!(points, scope, excluded_experiment_id) do
    resource_ids =
      points
      |> Enum.map(&atomize_keys/1)
      |> Enum.map(&Map.get(&1, :alternatives_resource_id))
      |> Enum.uniq()
      |> Enum.sort()

    from(resource in Resource,
      where: resource.id in ^resource_ids,
      order_by: [asc: resource.id],
      lock: "FOR UPDATE"
    )
    |> Repo.all()

    case validate_current_bindings(points, scope, excluded_experiment_id) do
      :ok -> :ok
      {:error, %ExperimentError{} = error} -> Repo.rollback(error)
    end
  end

  defp scope_from_definition(definition), do: %Scope{project_id: definition.project_id}

  defp validate_decision_point(point, condition_refs, scope) do
    attrs = atomize_keys(point)
    mappings = Enum.map(Map.get(attrs, :mappings, []), &atomize_keys/1)
    mapped_refs = Enum.map(mappings, &(Map.get(&1, :condition_ref) || Map.get(&1, :condition_id)))
    option_ids = Enum.map(mappings, &Map.get(&1, :option_id))

    with true <- is_integer(Map.get(attrs, :alternatives_resource_id)),
         {:ok, revision} <-
           resolve_authoring_revision(scope.project_slug, attrs.alternatives_resource_id),
         :ok <- validate_experiment_decision_point_revision(revision),
         :ok <-
           validate_mapping_bijection(attrs, revision, condition_refs, mapped_refs, option_ids),
         :ok <-
           validate_interventions(attrs, scope, attrs.alternatives_resource_id),
         :ok <-
           validate_policy_config(
             Map.get(attrs, :algorithm, :weighted_random),
             policy_config_from_attrs(attrs)
           ) do
      :ok
    else
      false -> invalid_condition("alternatives_resource_id is required")
      {:error, %ExperimentError{}} = error -> error
    end
  end

  defp validate_mapping_bijection(point, revision, condition_refs, mapped_refs, option_ids) do
    available_options = revision_option_ids(revision)
    mappings = Enum.map(Map.get(point, :mappings, []), &atomize_keys/1)
    weights = Enum.map(mappings, &Map.get(&1, :weight, 1.0))

    cond do
      Enum.any?(weights, &(not is_number(&1))) ->
        invalid_condition("decision point mapping weights must be numeric", %{
          decision_point_key: Map.get(point, :decision_point_key)
        })

      Enum.any?(weights, &(&1 < 0)) ->
        invalid_condition("decision point mapping weights must be non-negative", %{
          decision_point_key: Map.get(point, :decision_point_key)
        })

      Enum.sort(mapped_refs) != Enum.sort(condition_refs) ->
        invalid_condition("decision point must map every condition exactly once", %{
          decision_point_key: Map.get(point, :decision_point_key)
        })

      length(option_ids) != length(Enum.uniq(option_ids)) ->
        invalid_condition("decision point alternatives must be mapped exactly once", %{
          decision_point_key: Map.get(point, :decision_point_key)
        })

      Enum.sort(option_ids) != Enum.sort(available_options) ->
        invalid_condition(
          "decision point mappings must use every group alternative exactly once",
          %{
            decision_point_key: Map.get(point, :decision_point_key),
            expected_option_ids: available_options
          }
        )

      true ->
        :ok
    end
  end

  defp validate_interventions(point, scope, alternatives_resource_id) do
    interventions = Enum.map(Map.get(point, :interventions, []), &atomize_keys/1)

    identities =
      Enum.map(interventions, &{Map.get(&1, :page_resource_id), Map.get(&1, :content_element_id)})

    algorithm = Map.get(point, :algorithm, :weighted_random)

    placement_validation =
      validate_experiment_placements(interventions, scope, alternatives_resource_id)

    cond do
      interventions == [] ->
        :ok

      length(identities) != length(Enum.uniq(identities)) ->
        invalid_condition("intervention identities must be unique within a decision point")

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
              "intervention placement must reference the decision point Alternatives group",
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

  defp to_decision_point_candidate(%Revision{} = revision) do
    %DecisionPointCandidate{
      alternatives_resource_id: revision.resource_id,
      alternatives_revision_id: revision.id,
      decision_point_key: "alternatives:#{revision.resource_id}",
      title: revision.title,
      options: revision_option_ids(revision),
      option_labels: revision_option_labels(revision)
    }
  end

  defp experiment_decision_point_revision?(%Revision{} = revision) do
    get_in(revision.content || %{}, ["strategy"]) in [
      "experiment_controlled",
      "upgrade_decision_point"
    ]
  end

  defp validate_experiment_decision_point_revision(%Revision{} = revision) do
    if experiment_decision_point_revision?(revision) do
      :ok
    else
      invalid_condition("selected alternatives group is not an A/B Testing decision point")
    end
  end

  defp public_decision_point(%DecisionPoint{} = decision_point, algorithm) do
    %{
      id: decision_point.id,
      alternatives_resource_id: decision_point.alternatives_resource_id,
      decision_point_key: decision_point.decision_point_key,
      title: decision_point.title,
      position: decision_point.position,
      algorithm: algorithm,
      prior_alpha: decision_point.prior_alpha,
      prior_beta: decision_point.prior_beta,
      warm_up_assignments: decision_point.warm_up_assignments,
      max_condition_share: decision_point.max_condition_share,
      fixed_control_allocation: decision_point.fixed_control_allocation,
      imbalance_threshold: decision_point.imbalance_threshold,
      reward_source: decision_point.reward_source
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

  defp assignment_counts_by_condition(experiment_id, decision_point_id) do
    from(assignment in Assignment,
      where:
        assignment.experiment_id == ^experiment_id and
          assignment.decision_point_id == ^decision_point_id,
      group_by: assignment.condition_id,
      select: {assignment.condition_id, count(assignment.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp assignment_counts_by_decision_point_condition(experiment_id) do
    from(assignment in Assignment,
      where: assignment.experiment_id == ^experiment_id,
      group_by: [assignment.decision_point_id, assignment.condition_id],
      select: {{assignment.decision_point_id, assignment.condition_id}, count(assignment.id)}
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
  defp authoring_payload_key("decision_point_key"), do: :decision_point_key
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

  defp revision_option_ids(%Revision{content: %{"options" => options}}) when is_list(options) do
    Enum.map(options, &(Map.get(&1, "id") || Map.get(&1, :id) || Map.get(&1, "name")))
  end

  defp revision_option_ids(_revision), do: []

  defp revision_option_labels(%Revision{content: %{"options" => options}})
       when is_list(options) do
    Map.new(options, fn option ->
      id = Map.get(option, "id") || Map.get(option, :id) || Map.get(option, "name")
      label = Map.get(option, "name") || Map.get(option, :name) || id
      {id, label}
    end)
  end

  defp revision_option_labels(_revision), do: %{}

  defp structural_configuration_change?(%{decision_points: points, conditions: conditions})
       when points in [nil, []] and conditions in [nil, []],
       do: false

  defp structural_configuration_change?(_request), do: true

  defp maybe_require_authoring_scope(_scope, false), do: :ok
  defp maybe_require_authoring_scope(scope, true), do: require_authoring_access(scope)

  defp maybe_require_authoring_access(_scope, false), do: :ok
  defp maybe_require_authoring_access(scope, true), do: require_authoring_access(scope)

  defp require_authoring_access(scope) do
    with :ok <- require_authoring_scope(scope),
         :ok <- require_eligible_section_reader(scope) do
      :ok
    end
  end

  defp require_authoring_scope(%Scope{enrollment_id: nil}), do: :ok

  defp require_authoring_scope(_scope) do
    invalid_scope("authoring experiments must be project- or section-scoped")
  end

  defp require_eligible_section_reader(%Scope{
         author_id: author_id,
         project_id: project_id
       })
       when not is_nil(author_id) do
    author = Repo.get(Oli.Accounts.Author, author_id)

    accepted_collaborator? =
      Repo.exists?(
        from(author_project in AuthorProject,
          where:
            author_project.author_id == ^author_id and
              author_project.project_id == ^project_id and
              author_project.status == :accepted
        )
      )

    case accepted_collaborator? or Oli.Accounts.is_admin?(author) do
      true -> :ok
      false -> invalid_scope("author cannot access project sections")
    end
  end

  defp require_eligible_section_reader(_scope) do
    invalid_scope("author scope is required")
  end

  defp validate_scope(%Scope{} = scope) do
    with {:ok, scope} <- validate_institution(scope),
         {:ok, scope} <- validate_project(scope),
         {:ok, scope} <- validate_section(scope),
         {:ok, scope} <- validate_publication(scope),
         {:ok, scope} <- validate_user(scope),
         {:ok, scope} <- validate_enrollment(scope) do
      {:ok, scope}
    end
  end

  defp validate_scope(_scope), do: invalid_scope("scope is required")

  defp validate_delivery_participation_scope(
         %Scope{
           project_id: project_id,
           section_id: section_id,
           user_id: user_id,
           enrollment_id: enrollment_id
         } = scope
       )
       when is_integer(project_id) and is_integer(section_id) and is_integer(user_id) and
              is_integer(enrollment_id) do
    query =
      from(section in Section,
        as: :section,
        join: project in Project,
        on: project.id == ^project_id,
        join: user in User,
        on: user.id == ^user_id,
        join: enrollment in Enrollment,
        on:
          enrollment.id == ^enrollment_id and enrollment.section_id == section.id and
            enrollment.user_id == user.id,
        where: section.id == ^section_id,
        select:
          {section, project, user, enrollment,
           exists(
             from(spp in SectionsProjectsPublications,
               where: spp.section_id == parent_as(:section).id and spp.project_id == ^project_id
             )
           )}
      )

    case Repo.one(query) do
      {section, project, _user, _enrollment, project_relationship?} ->
        cond do
          not is_nil(scope.institution_id) and section.institution_id != scope.institution_id ->
            invalid_scope("section does not belong to institution", %{
              section_id: section.id,
              institution_id: scope.institution_id,
              actual_institution_id: section.institution_id
            })

          not is_nil(scope.project_slug) and project.slug != scope.project_slug ->
            invalid_scope("project slug does not match project_id", %{
              project_id: project.id,
              project_slug: scope.project_slug,
              actual_slug: project.slug
            })

          not is_nil(scope.section_slug) and section.slug != scope.section_slug ->
            invalid_scope("section slug does not match section_id", %{
              section_id: section.id,
              section_slug: scope.section_slug,
              actual_slug: section.slug
            })

          true ->
            {:ok,
             %{
               scope
               | project_slug: scope.project_slug || project.slug,
                 section_slug: scope.section_slug || section.slug,
                 project_relationship?: project_relationship?
             }}
        end

      nil ->
        invalid_scope("delivery participation scope is invalid")
    end
  end

  defp validate_delivery_participation_scope(%Scope{} = scope) do
    with {:ok, scope} <- validate_institution(scope),
         {:ok, scope} <- validate_project(scope),
         {:ok, scope} <- validate_participation_section(scope),
         {:ok, scope} <- validate_user(scope),
         {:ok, scope} <- validate_enrollment(scope) do
      {:ok, scope}
    end
  end

  defp validate_delivery_participation_scope(_scope), do: invalid_scope("scope is required")

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
      nil ->
        invalid_scope("project not found", %{project_id: project_id})

      project ->
        validate_project_slug(
          %{scope | project_id: project.id, project_slug: scope.project_slug || project.slug},
          project
        )
    end
  end

  defp validate_project(%Scope{project_slug: project_slug} = scope) do
    case Repo.get_by(Project, slug: project_slug) do
      nil -> invalid_scope("project not found", %{project_slug: project_slug})
      project -> {:ok, %{scope | project_id: project.id, project_slug: project.slug}}
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
        validate_section_publication(scope)

      %Publication{project_id: actual_project_id} ->
        invalid_scope("publication does not belong to project", %{
          publication_id: publication_id,
          project_id: project_id,
          actual_project_id: actual_project_id
        })
    end
  end

  defp validate_section_publication(%Scope{section_id: nil} = scope), do: {:ok, scope}

  defp validate_section_publication(%Scope{} = scope) do
    case Repo.exists?(
           from(spp in SectionsProjectsPublications,
             where:
               spp.section_id == ^scope.section_id and
                 spp.project_id == ^scope.project_id and
                 spp.publication_id == ^scope.publication_id
           )
         ) do
      true ->
        {:ok, scope}

      false ->
        invalid_scope("publication is not deployed to section", %{
          publication_id: scope.publication_id,
          project_id: scope.project_id,
          section_id: scope.section_id
        })
    end
  end

  defp validate_section(%Scope{section_id: nil, section_slug: nil} = scope), do: {:ok, scope}

  defp validate_section(%Scope{section_id: section_id} = scope) when not is_nil(section_id) do
    case Repo.get(Section, section_id) do
      nil ->
        invalid_scope("section not found", %{section_id: section_id})

      section ->
        validate_section_scope(
          %{scope | section_id: section.id, section_slug: scope.section_slug || section.slug},
          section
        )
    end
  end

  defp validate_section(%Scope{section_slug: section_slug} = scope) do
    case Repo.get_by(Section, slug: section_slug) do
      nil ->
        invalid_scope("section not found", %{section_slug: section_slug})

      section ->
        validate_section_scope(
          %{scope | section_id: section.id, section_slug: section.slug},
          section
        )
    end
  end

  defp validate_participation_section(%Scope{section_id: nil, section_slug: nil} = scope),
    do: {:ok, scope}

  defp validate_participation_section(%Scope{section_id: section_id} = scope)
       when not is_nil(section_id) do
    case participation_section(section_id, scope.project_id) do
      nil ->
        invalid_scope("section not found", %{section_id: section_id})

      {section, project_relationship?} ->
        validate_participation_section_scope(
          %{
            scope
            | section_id: section.id,
              section_slug: scope.section_slug || section.slug,
              project_relationship?: project_relationship?
          },
          section
        )
    end
  end

  defp validate_participation_section(%Scope{section_slug: section_slug} = scope) do
    case participation_section_by_slug(section_slug, scope.project_id) do
      nil ->
        invalid_scope("section not found", %{section_slug: section_slug})

      {section, project_relationship?} ->
        validate_participation_section_scope(
          %{
            scope
            | section_id: section.id,
              section_slug: section.slug,
              project_relationship?: project_relationship?
          },
          section
        )
    end
  end

  defp participation_section(section_id, project_id) do
    from(section in Section,
      as: :section,
      where: section.id == ^section_id,
      select:
        {section,
         exists(
           from(spp in SectionsProjectsPublications,
             where:
               spp.section_id == parent_as(:section).id and
                 spp.project_id == ^project_id
           )
         )}
    )
    |> Repo.one()
  end

  defp participation_section_by_slug(section_slug, project_id) do
    from(section in Section,
      as: :section,
      where: section.slug == ^section_slug,
      select:
        {section,
         exists(
           from(spp in SectionsProjectsPublications,
             where:
               spp.section_id == parent_as(:section).id and
                 spp.project_id == ^project_id
           )
         )}
    )
    |> Repo.one()
  end

  defp validate_participation_section_scope(scope, section) do
    cond do
      section.slug != scope.section_slug ->
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

      true ->
        {:ok, scope}
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

      not is_nil(scope.section_id) and
          not Repo.exists?(
            from(experiment in ExperimentDefinitionSchema,
              as: :experiment,
              where:
                experiment.id == ^schema.id and
                    exists(participating_section_query(scope.section_id))
            )
          ) ->
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
      section_ids: Enum.map(schema.sections, & &1.id),
      slug: schema.slug,
      name: schema.name,
      description: schema.description,
      state: schema.state,
      assignment_unit: schema.assignment_unit,
      algorithm: schema.algorithm,
      started_at: schema.started_at,
      ended_at: schema.ended_at
    }
  end

  defp to_assignment_decision(nil, _condition, _reused?),
    do: %AssignmentDecision{status: :no_experiment}

  defp to_assignment_decision(%Assignment{} = assignment, %Condition{} = condition, reused?) do
    to_assignment_decision(assignment, condition, reused?, nil)
  end

  defp to_assignment_decision(
         %Assignment{} = assignment,
         %Condition{} = condition,
         reused?,
         option_id
       ) do
    %AssignmentDecision{
      status: :assigned,
      experiment_id: assignment.experiment_id,
      decision_point_id: assignment.decision_point_id,
      condition_id: assignment.condition_id,
      condition_code: condition.condition_code,
      option_id: option_id || assigned_option_id(assignment, condition),
      assignment_id: assignment.id,
      reused?: reused?
    }
  end

  defp assigned_option_id(%Assignment{} = assignment, %Condition{} = condition) do
    condition.option_id ||
      Repo.one(
        from mapping in DecisionPointCondition,
          where:
            mapping.decision_point_id == ^assignment.decision_point_id and
              mapping.condition_id == ^condition.id,
          select: mapping.option_id
      ) || condition.condition_code
  end

  defp exposure_receipt(%Assignment{} = assignment, event) do
    %ExposureReceipt{
      key: event["key"],
      assignment_id: assignment.id,
      recorded_at: event["recorded_at"],
      reused?: Map.get(event, "reused", false)
    }
  end

  defp outcome_receipt(%Assignment{} = assignment, event) do
    %OutcomeReceipt{
      key: event["key"],
      assignment_id: assignment.id,
      recorded_at: event["recorded_at"],
      reused?: Map.get(event, "reused", false)
    }
  end

  defp reward_receipt(%Assignment{} = assignment, event) do
    %RewardReceipt{
      key: event["key"],
      assignment_id: assignment.id,
      outcome_key: event["outcome_key"],
      recorded_at: event["recorded_at"],
      reused?: Map.get(event, "reused", false)
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
      decision_point_key: request.decision_point_key,
      page_resource_id: request.page_resource_id,
      content_element_id: request.content_element_id
    }
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp hash_key(nil), do: nil

  defp hash_key(value) do
    :crypto.hash(:sha256, to_string(value))
    |> Base.encode16(case: :lower)
  end

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

  defp invalid_state(message, details) do
    {:error, %ExperimentError{type: :invalid_state, message: message, details: details}}
  end
end
