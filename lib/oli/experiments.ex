defmodule Oli.Experiments do
  @moduledoc """
  Public context boundary for native A/B testing experiments.
  """

  import Ecto.Query
  import Oli.Experiments.Support

  alias Oli.Delivery.Sections.{Section, SectionsProjectsPublications}

  alias Oli.Experiments.{
    ActivationValidator,
    AssignmentDecision,
    EligibleExperimentSection,
    ExperimentAuthoringView,
    ExperimentError,
    ExposureReceipt,
    OperationalAnalytics,
    PolicyConfiguration,
    PolicyGuardrails,
    Queries,
    RewardEligibleAssignment,
    RuntimeAssignment,
    RuntimeEvidence,
    Scope,
    ScopeValidator,
    Telemetry
  }

  alias Oli.Experiments.Schemas.{
    AssessmentBinding,
    Assignment,
    Condition,
    ExperimentSection,
    Intervention,
    PolicyState
  }

  alias Oli.Experiments.AssignmentIdentity
  alias Oli.Experiments.Policies.{ThompsonSampling, WeightedRandom}
  alias Oli.Experiments.XAPI.Attributions
  alias Oli.Experiments.XAPI.ConditionAssignmentEmitter

  alias Oli.Experiments.Schemas.ExperimentDefinition, as: ExperimentDefinitionSchema
  alias Oli.Publishing.{AuthoringResolver, DeliveryResolver}
  alias Oli.Repo
  alias Oli.Resources.{ResourceType, Revision}

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
  Returns a public experiment graph view for authoring.
  """
  def get_experiment_authoring_view(experiment_id, %Scope{} = scope) do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_access(scope),
         {:ok, schema} <- get_scoped_definition(experiment_id, scope) do
      conditions =
        from(condition in Condition,
          where: condition.experiment_id == ^schema.id,
          order_by: [asc: condition.position, asc: condition.id]
        )
        |> Repo.all()
        |> Enum.map(&public_condition/1)

      interventions =
        from(intervention in Intervention,
          where: intervention.experiment_id == ^schema.id,
          order_by: [asc: intervention.id],
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
         conditions: conditions,
         interventions:
           Enum.map(
             interventions,
             &Map.take(&1, [:id, :experiment_id, :page_resource_id, :content_element_id])
           ),
         assessment_bindings: assessment_bindings,
         assignment_counts: assignment_counts_by_condition(schema.id)
       }}
    end
  end

  def get_experiment_authoring_view(_experiment_id, _scope), do: invalid_request("expected Scope")

  @doc """
  Lists experiment-controlled Alternatives Groups available to the project.
  """
  def list_available_alternatives(%Scope{} = scope) do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_access(scope) do
      candidates =
        scope.project_slug
        |> AuthoringResolver.revisions_of_type(ResourceType.id_for_alternatives())
        |> Enum.filter(&experiment_controlled_revision?/1)
        |> Enum.sort_by(&{&1.title, &1.id})
        |> Enum.map(&to_alternatives_candidate/1)

      {:ok, candidates}
    end
  end

  def list_available_alternatives(_scope), do: invalid_request("expected Scope")

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
        |> Enum.filter(&experiment_controlled_revision?/1)
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
  Returns whether a project-scoped Alternatives Group is referenced by a non-archived experiment
  definition.
  """
  def experiment_group_in_use?(alternatives_resource_id, %Scope{} = scope)
      when is_integer(alternatives_resource_id) and alternatives_resource_id > 0 do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_scope(scope) do
      in_use? =
        Repo.exists?(
          from experiment in ExperimentDefinitionSchema,
            where:
              experiment.project_id == ^scope.project_id and
                experiment.state != :archived and
                experiment.alternatives_resource_id == ^alternatives_resource_id
        )

      {:ok, in_use?}
    end
  end

  def experiment_group_in_use?(_alternatives_resource_id, _scope),
    do: invalid_request("expected an Alternatives Group resource id and Scope")

  @doc """
  Returns experiment dependencies that must be reconciled before a resource can be deleted.
  """
  def configuration_dependencies(resource_id, %Scope{} = scope)
      when is_integer(resource_id) and resource_id > 0 do
    with {:ok, scope} <- validate_scope(scope),
         :ok <- require_authoring_access(scope) do
      dependencies =
        from(experiment in ExperimentDefinitionSchema,
          left_join: intervention in Intervention,
          on: intervention.experiment_id == experiment.id,
          left_join: binding in AssessmentBinding,
          on: binding.intervention_id == intervention.id,
          where:
            experiment.project_id == ^scope.project_id and
              (experiment.alternatives_resource_id == ^resource_id or
                 intervention.page_resource_id == ^resource_id or
                 binding.assessment_page_resource_id == ^resource_id),
          select: %{
            experiment_id: experiment.id,
            state: experiment.state,
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
  Assigns or reuses a condition for one delivered Alternatives placement.
  """
  def assign_condition(%Oli.Experiments.AssignConditionRequest{} = request),
    do: RuntimeAssignment.assign_condition(request, runtime_assignment_dependencies())

  def assign_condition(_request), do: invalid_request("expected AssignConditionRequest")

  @doc """
  Returns an existing assignment decision for a delivered Alternatives placement without
  creating an assignment or recording exposure.
  """
  def assigned_condition(%Oli.Experiments.AssignConditionRequest{} = request),
    do: RuntimeAssignment.assigned_condition(request, runtime_assignment_dependencies())

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
  def assign_page_conditions([%Oli.Experiments.AssignConditionRequest{} | _] = requests),
    do: RuntimeAssignment.assign_page_conditions(requests, runtime_assignment_dependencies())

  def assign_page_conditions([]), do: {:ok, %{}}
  def assign_page_conditions(_requests), do: invalid_request("expected assignment requests")

  defp runtime_assignment_dependencies do
    %{
      assign: &do_assign_condition/1,
      validate_scope: &validate_delivery_participation_scope/1,
      require_delivery: &require_delivery_scope/1,
      require_placement: &require_assignment_placement/1,
      resolve_revision: &resolve_delivery_revision/2,
      existing_assignment: &existing_assignment_decision/3,
      common_scope: &common_page_assignment_scope/1,
      validate_publication: &validate_publication/1,
      batch_assign: &batch_assign_page_conditions/2,
      emit_committed: &emit_committed_batch_assignment/1,
      emit_committed_single: &emit_committed_single_assignment/1
    }
  end

  @doc """
  Records exposure evidence for a page's assigned root Alternatives placements with
  one assignment read. Requests must be derived from server-resolved delivery state.
  """
  def record_page_exposures([%Oli.Experiments.RecordExposureRequest{} | _] = requests) do
    with {:ok, scope} <- common_exposure_scope(requests),
         {:ok, assignments} <- batch_exposure_assignments(requests, scope),
         {:ok, revisions} <- batch_exposure_revisions(requests, assignments),
         {:ok, interventions} <- batch_exposure_interventions(requests, assignments) do
      attributions =
        Enum.flat_map(requests, fn request ->
          assignment = Map.fetch!(assignments, request.assignment_id)
          _revision = Map.fetch!(revisions, request.content_revision_id)

          intervention =
            Map.fetch!(interventions, exposure_intervention_key(assignment, request))

          event = Map.put(runtime_event(request), "reused", false)
          receipt = exposure_receipt(assignment, event)

          :telemetry.execute([:oli, :experiments, :exposure, :recorded], %{count: 1}, %{
            experiment_id: assignment.experiment_id,
            intervention_id: intervention.id,
            assignment_scope: assignment.assignment_scope
          })

          Telemetry.emit(:exposure_recorded, {receipt, request},
            assignment: assignment,
            intervention: intervention
          )

          Attributions.attributions_for_page_view(receipt, request,
            assignment: assignment,
            intervention: intervention
          )
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
    RuntimeEvidence.record_exposure(request, runtime_evidence_dependencies())
  end

  def record_exposure(_request), do: invalid_request("expected RecordExposureRequest")

  @doc """
  Records operational outcome evidence and emits the durable xAPI outcome event.
  """
  def record_outcome(%Oli.Experiments.RecordOutcomeRequest{} = request) do
    RuntimeEvidence.record_outcome(request, runtime_evidence_dependencies())
  end

  def record_outcome(_request), do: invalid_request("expected RecordOutcomeRequest")

  @doc """
  Records operational reward evidence, mutates policy state, and emits durable xAPI events.
  """
  def record_reward(%Oli.Experiments.RecordRewardRequest{} = request) do
    RuntimeEvidence.record_reward(request, runtime_evidence_dependencies())
  end

  def record_reward(_request), do: invalid_request("expected RecordRewardRequest")

  defp runtime_evidence_dependencies do
    %{
      scoped_with_experiment: &get_scoped_assignment_with_experiment!/2,
      resolve_exposure_intervention: &resolve_exposure_intervention/2,
      scoped_assignment: &get_scoped_assignment!/3,
      record_policy_reward: &record_policy_reward/3,
      emit_policy_update: &emit_policy_update/1,
      normalize: &normalize_transaction_result/1
    }
  end

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
            join: condition in Condition,
            on: condition.id == assignment.condition_id,
            where:
              experiment.state == :active and assignment.section_id in ^section_ids and
                assignment.enrollment_id in ^enrollment_ids,
            distinct: true,
            select: %{
              assignment: assignment,
              experiment_project_id: experiment.project_id,
              experiment: experiment,
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
  def experiment_summary(query), do: OperationalAnalytics.experiment_summary(query)

  def assignment_counts(query), do: OperationalAnalytics.assignment_counts(query)

  def exposure_counts(query), do: OperationalAnalytics.exposure_counts(query)

  def reward_counts(query), do: OperationalAnalytics.reward_counts(query)

  def policy_state_snapshot(query), do: OperationalAnalytics.policy_state_snapshot(query)

  def policy_snapshot(experiment_or_view, scope),
    do: OperationalAnalytics.policy_snapshot(experiment_or_view, scope)

  defp scoped_project_experiments_query(scope),
    do: Queries.scoped_project_experiments_query(scope)

  defp reward_eligible_assignment_query(scope),
    do: Queries.reward_eligible_assignment_query(scope)

  defp participating_section_query(section_id),
    do: Queries.participating_section_query(section_id)

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
           experiment: %ExperimentDefinitionSchema{} = experiment,
           condition: %Condition{} = condition
         },
         matching_branches
       ) do
    option_ids = [condition.option_id, condition.condition_code] |> Enum.reject(&is_nil/1)

    Enum.any?(matching_branches, fn branch ->
      branch.alternatives_resource_id == experiment.alternatives_resource_id and
        branch.option_id in option_ids
    end)
  end

  defp to_reward_eligible_assignment(%{
         assignment: %Assignment{} = assignment,
         experiment: %ExperimentDefinitionSchema{} = experiment,
         condition: %Condition{} = condition
       }) do
    %RewardEligibleAssignment{
      assignment_id: assignment.id,
      experiment_id: assignment.experiment_id,
      condition_id: assignment.condition_id,
      condition_code: condition.condition_code,
      alternatives_resource_id: experiment.alternatives_resource_id
    }
  end

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
         true <-
           Enum.all?(rest, fn request ->
             request.scope == first.scope and
               request.page_resource_id == first.page_resource_id
           end) do
      {:ok, scope}
    else
      false -> invalid_scope("page exposure requests must share one scope and page")
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
        where:
          assignment.id in ^assignment_ids and
            experiment.project_id == ^scope.project_id and
            assignment.section_id == ^scope.section_id and
            assignment.enrollment_id == ^scope.enrollment_id and
            assignment.user_id == ^scope.user_id,
        preload: [experiment: experiment, condition: condition]
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
          revision.resource_id == assignment.experiment.alternatives_resource_id
        else
          _ -> false
        end
      end)

    case valid? do
      true -> {:ok, revisions}
      false -> invalid_condition("page exposure revision does not match its experiment")
    end
  end

  defp batch_exposure_interventions(requests, assignments) do
    with {:ok, keys} <- exposure_intervention_keys(requests, assignments) do
      predicate =
        Enum.reduce(keys, dynamic(false), fn
          {experiment_id, page_resource_id, content_element_id}, predicate ->
            dynamic(
              [intervention],
              ^predicate or
                (intervention.experiment_id == ^experiment_id and
                   intervention.page_resource_id == ^page_resource_id and
                   intervention.content_element_id == ^content_element_id)
            )
        end)

      # Exact placement predicates preserve the intervention identity index and avoid loading the
      # Cartesian superset produced by independent experiment/page/element IN lists.
      interventions =
        from(intervention in Intervention,
          where: ^predicate,
          select:
            struct(intervention, [
              :id,
              :experiment_id,
              :page_resource_id,
              :content_element_id
            ])
        )
        |> Repo.all()
        |> Map.new(fn intervention ->
          {{intervention.experiment_id, intervention.page_resource_id,
            intervention.content_element_id}, intervention}
        end)

      case Enum.all?(keys, &Map.has_key?(interventions, &1)) do
        true ->
          {:ok, interventions}

        false ->
          invalid_condition("one or more exposure placements do not belong to their experiment")
      end
    end
  end

  defp exposure_intervention_keys(requests, assignments) do
    Enum.reduce_while(requests, {:ok, []}, fn request, {:ok, keys} ->
      assignment = Map.fetch!(assignments, request.assignment_id)

      case exposure_intervention_key(assignment, request) do
        {_experiment_id, page_resource_id, content_element_id} = key
        when is_integer(page_resource_id) and is_binary(content_element_id) and
               content_element_id != "" ->
          {:cont, {:ok, [key | keys]}}

        _key ->
          {:halt, invalid_request("exposure placement identity is required")}
      end
    end)
  end

  defp resolve_exposure_intervention(%Assignment{} = assignment, request) do
    case exposure_intervention_key(assignment, request) do
      {experiment_id, page_resource_id, content_element_id}
      when is_integer(page_resource_id) and is_binary(content_element_id) and
             content_element_id != "" ->
        case Repo.get_by(Intervention,
               experiment_id: experiment_id,
               page_resource_id: page_resource_id,
               content_element_id: content_element_id
             ) do
          %Intervention{} = intervention ->
            {:ok, intervention}

          nil ->
            invalid_condition("exposure placement does not belong to the assignment experiment")
        end

      _key ->
        invalid_request("exposure placement identity is required")
    end
  end

  defp exposure_intervention_key(%Assignment{} = assignment, request) do
    {assignment.experiment_id, request.page_resource_id, request.content_element_id}
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

    experiment_ids = rows |> Enum.map(& &1.experiment.id) |> Enum.uniq()
    counts = batch_assignment_counts(experiment_ids)

    rows_by_placement =
      Enum.group_by(
        rows,
        &{&1.intervention.content_element_id, &1.experiment.alternatives_resource_id}
      )

    # The batch rows are a snapshot taken before any assignment is inserted. Carry assignments
    # created earlier in this reducer so later placements with the same identity can reuse them
    # without selecting again or waiting for a uniqueness conflict.
    {decisions, _counts, events, _assignments_by_identity} =
      Enum.reduce(requests, {%{}, counts, [], %{}}, fn request,
                                                       {decisions, current_counts, events,
                                                        assignments_by_identity} ->
        matching_rows =
          Map.get(
            rows_by_placement,
            {request.content_element_id, request.alternatives_resource_id},
            []
          )

        case batch_assignment_decision(
               matching_rows,
               request,
               scope,
               current_counts,
               assignments_by_identity
             ) do
          {:ok, decision, next_counts, event, next_assignments_by_identity} ->
            {Map.put(decisions, request.content_element_id, decision), next_counts,
             [event | events], next_assignments_by_identity}

          {:fallback, reason} ->
            emit_batch_fallback(reason, matching_rows)

            {Map.put(decisions, request.content_element_id, %AssignmentDecision{
               status: :no_experiment
             }), current_counts, events, assignments_by_identity}

          {:error, %ExperimentError{} = error} ->
            Repo.rollback(error)
        end
      end)

    {decisions, Enum.reverse(events)}
  end

  defp batch_assignment_rows(scope, page_resource_id, content_element_ids) do
    from(intervention in Intervention,
      join: experiment in ExperimentDefinitionSchema,
      as: :experiment,
      on: experiment.id == intervention.experiment_id,
      join: condition in Condition,
      on: condition.experiment_id == experiment.id and condition.active == true,
      left_join: policy_state in PolicyState,
      on:
        policy_state.experiment_id == experiment.id and
          policy_state.algorithm == experiment.algorithm,
      # Keep the two identity shapes in separate joins so each predicate matches its partial
      # sticky index. The selected row is collapsed to one `assignment` value after the query.
      left_join: intervention_assignment in Assignment,
      on:
        experiment.assignment_scope == :intervention and
          intervention_assignment.assignment_scope == :intervention and
          intervention_assignment.experiment_id == experiment.id and
          intervention_assignment.intervention_id == intervention.id and
          intervention_assignment.section_id == ^scope.section_id and
          intervention_assignment.enrollment_id == ^scope.enrollment_id and
          intervention_assignment.user_id == ^scope.user_id,
      left_join: section_enrollment_assignment in Assignment,
      on:
        experiment.assignment_scope == :section_enrollment and
          section_enrollment_assignment.assignment_scope == :section_enrollment and
          section_enrollment_assignment.experiment_id == experiment.id and
          section_enrollment_assignment.section_id == ^scope.section_id and
          section_enrollment_assignment.enrollment_id == ^scope.enrollment_id and
          section_enrollment_assignment.user_id == ^scope.user_id and
          is_nil(section_enrollment_assignment.intervention_id),
      where:
        intervention.page_resource_id == ^page_resource_id and
          intervention.content_element_id in ^content_element_ids and
          experiment.project_id == ^scope.project_id and
          experiment.state == :active and
          exists(participating_section_query(scope.section_id)),
      order_by: [asc: intervention.id, asc: condition.position, asc: condition.id],
      select: %{
        intervention: intervention,
        experiment: experiment,
        condition: condition,
        policy_state: policy_state,
        intervention_assignment: intervention_assignment,
        section_enrollment_assignment: section_enrollment_assignment
      }
    )
    |> Repo.all()
    |> Enum.map(fn row ->
      Map.put(
        row,
        :assignment,
        row.intervention_assignment || row.section_enrollment_assignment
      )
    end)
  end

  defp ensure_batch_policy_states(rows) do
    states =
      rows
      |> Enum.group_by(& &1.experiment.id)
      |> Map.new(fn {experiment_id, experiment_rows} ->
        first = hd(experiment_rows)

        state =
          first.policy_state ||
            get_or_create_policy_state(first.experiment)

        {experiment_id, state}
      end)

    Enum.map(rows, fn row ->
      %{row | policy_state: Map.fetch!(states, row.experiment.id)}
    end)
  end

  defp lock_batch_assignment_decisions(rows) do
    experiment_ids =
      rows
      |> Enum.map(& &1.experiment.id)
      |> Enum.uniq()
      |> Enum.sort()

    Enum.each(experiment_ids, fn experiment_id ->
      Repo.query!("SELECT pg_advisory_xact_lock($1)", [experiment_id])
    end)

    rows
  end

  defp batch_assignment_counts([]), do: %{}

  defp batch_assignment_counts(experiment_ids) do
    from(assignment in Assignment,
      where: assignment.experiment_id in ^experiment_ids,
      group_by: [assignment.experiment_id, assignment.condition_id],
      select: {{assignment.experiment_id, assignment.condition_id}, count(assignment.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp batch_assignment_decision([], _request, _scope, _counts, _assignments_by_identity),
    do: {:fallback, :no_experiment}

  defp batch_assignment_decision(rows, request, scope, counts, assignments_by_identity) do
    first = hd(rows)

    with :ok <- validate_runtime_assignment_scope(first.experiment),
         {:ok, identity} <- assignment_identity(first.experiment, first.intervention, scope) do
      # Prefer an assignment created earlier in this transaction; the original query rows cannot
      # contain it. Otherwise use the assignment that existed when the batch snapshot was loaded.
      existing =
        Map.get(assignments_by_identity, identity.map_key) ||
          Enum.find_value(rows, & &1.assignment)

      cond do
        Enum.any?(rows, &(&1.experiment.id != first.experiment.id)) ->
          {:fallback, :ambiguous_match}

        existing ->
          conditions = Enum.map(rows, & &1.condition)

          with :ok <- validate_batch_options(conditions, request.available_condition_codes) do
            case Enum.find(conditions, &(&1.id == existing.condition_id)) do
              %Condition{} = condition ->
                decision = to_assignment_decision(existing, condition, true, condition.option_id)
                event = batch_assignment_event(decision, request, existing, first, nil, true)

                {:ok, decision, counts, event,
                 Map.put(assignments_by_identity, identity.map_key, existing)}

              nil ->
                invalid_condition(
                  "sticky assignment condition is unavailable at this intervention"
                )
            end
          end

        true ->
          conditions = Enum.map(rows, & &1.condition)

          with :ok <- validate_batch_options(conditions, request.available_condition_codes),
               {:ok, selection} <-
                 select_batch_condition(first, conditions, identity, counts),
               {:ok, decision, assignment, inserted?} <-
                 insert_batch_assignment(first, selection, identity, scope, conditions) do
            next_counts =
              case inserted? do
                true ->
                  increment_batch_assignment_count(first)

                  Map.update(
                    counts,
                    {first.experiment.id, selection.condition.id},
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

            {:ok, decision, next_counts, event,
             Map.put(assignments_by_identity, identity.map_key, assignment)}
          end
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

  defp select_batch_condition(first, conditions, identity, counts) do
    experiment_counts =
      counts
      |> Enum.reduce(%{}, fn
        {{experiment_id, condition_id}, count}, acc
        when experiment_id == first.experiment.id ->
          Map.put(acc, condition_id, count)

        _, acc ->
          acc
      end)

    {policy_module, policy_conditions, guardrail_action} =
      assignment_policy_for_snapshot(
        first.experiment,
        conditions,
        first.policy_state,
        experiment_counts
      )

    context = %{
      conditions: policy_conditions,
      assignment_key: identity.assignment_key
    }

    case policy_module.assign(
           experiment_policy_config(first.experiment),
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
           assignment_counts: experiment_counts
         }}

      {:error, reason} ->
        invalid_condition("policy could not assign a condition", %{reason: reason})
    end
  end

  defp insert_batch_assignment(first, selection, identity, scope, conditions) do
    attrs = %{
      experiment_id: first.experiment.id,
      condition_id: selection.condition.id,
      intervention_id: identity.intervention_id,
      section_id: scope.section_id,
      enrollment_id: scope.enrollment_id,
      user_id: scope.user_id,
      assigned_by_policy: Atom.to_string(first.experiment.algorithm),
      policy_version: selection.policy_assignment.policy_version,
      assignment_scope: identity.scope,
      assignment_key: identity.assignment_key,
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
            assignment = find_assignment!(identity)

            case Enum.find(conditions, &(&1.id == assignment.condition_id)) do
              %Condition{} = condition ->
                {:ok, to_assignment_decision(assignment, condition, true), assignment, false}

              nil ->
                invalid_condition(
                  "sticky assignment condition is unavailable at this intervention"
                )
            end

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
    do: increment_assignment_count(first.experiment)

  defp batch_assignment_event(decision, request, assignment, first, selection, reused?) do
    %{
      decision: decision,
      request: request,
      assignment: assignment,
      experiment: first.experiment,
      selection: selection,
      reused?: reused?
    }
  end

  defp emit_committed_batch_assignment(event) do
    if event.reused? do
      :telemetry.execute([:oli, :experiments, :assignment, :reuse], %{count: 1}, %{
        experiment_id: event.assignment.experiment_id,
        assignment_scope: event.assignment.assignment_scope,
        algorithm: event.assignment.assigned_by_policy,
        algorithm_version: event.assignment.policy_version,
        selected_condition_id: event.assignment.condition_id,
        selected_condition_code: event.decision.condition_code,
        guardrail_action: :sticky_reuse
      })

      if event.selection do
        Telemetry.emit(:assignment_conflict, %{
          experiment_id: event.assignment.experiment_id,
          assignment_scope: event.assignment.assignment_scope
        })
      end
    else
      selection = event.selection

      emit_assignment_guardrail_telemetry(
        event.experiment,
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

    emit_condition_assignment_safely(
      event.assignment,
      event.experiment,
      event.decision,
      event.request.scope
    )
  end

  defp emit_committed_single_assignment(event) do
    emit_condition_assignment_safely(
      event.assignment,
      event.experiment,
      event.decision,
      event.request.scope
    )
  end

  defp emit_condition_assignment_safely(assignment, experiment, decision, scope) do
    ConditionAssignmentEmitter.emit(assignment, experiment, decision, scope)
  rescue
    exception -> emit_condition_assignment_failure(exception.__struct__)
  end

  defp emit_condition_assignment_failure(reason) do
    :telemetry.execute(
      [:oli, :experiments, :condition_assignment, :emit, :failed],
      %{count: 1},
      %{reason: reason}
    )

    :ok
  end

  defp emit_batch_fallback(reason, rows) do
    experiment = rows |> List.first() |> then(&(&1 && &1.experiment))
    emit_assignment_fallback(reason, experiment)
  end

  defp do_assign_condition_for_current_project(request, scope) do
    with :ok <- require_assignment_placement(request),
         {:ok, scope} <- validate_publication(scope),
         {:ok, revision} <- resolve_delivery_revision(request, scope),
         :ok <- materialize_weighted_random_intervention(request, scope),
         {:ok, match} <- active_experiment_match(request, scope, revision),
         {:ok, decision} <- assign_or_reuse(match, scope, request) do
      {:ok, decision}
    end
  end

  defp require_assignment_placement(%{
         page_resource_id: page_resource_id,
         content_element_id: content_element_id
       })
       when is_integer(page_resource_id) and is_binary(content_element_id) and
              content_element_id != "",
       do: :ok

  defp require_assignment_placement(_request),
    do: invalid_request("assignment placement identity is required")

  defp nonparticipating_assignment_fallback(reason) do
    emit_assignment_fallback(reason)

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
        join: intervention in Intervention,
        on: intervention.experiment_id == experiment.id,
        where:
          experiment.state == :active and
            experiment.project_id == ^scope.project_id and
            experiment.alternatives_resource_id == ^request.alternatives_resource_id and
            intervention.page_resource_id == ^page_resource_id and
            intervention.content_element_id == ^content_element_id,
        order_by: [asc: experiment.id],
        limit: 3,
        select: {experiment, intervention, exists(participating_section_query(scope.section_id))}

    case Repo.all(query) do
      [] ->
        no_experiment_match()

      [{_experiment, _intervention, false}] ->
        no_experiment_match()

      [{experiment, intervention, true}] ->
        with {:ok, conditions} <- validate_runtime_condition_compatibility(experiment, revision) do
          {:ok,
           %{
             experiment: experiment,
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
          fn {experiment, _intervention, _participating?} -> experiment.id end
        )
    end
  end

  defp active_experiment_match(request, scope, revision) do
    query =
      from experiment in ExperimentDefinitionSchema,
        as: :experiment,
        where:
          experiment.state == :active and
            experiment.project_id == ^scope.project_id and
            experiment.alternatives_resource_id == ^request.alternatives_resource_id,
        order_by: [asc: experiment.id],
        limit: 3,
        select: {experiment, exists(participating_section_query(scope.section_id))}

    case Repo.all(query) do
      [] ->
        no_experiment_match()

      [{_experiment, false}] ->
        no_experiment_match()

      [{experiment, true}] ->
        with {:ok, conditions} <- validate_runtime_condition_compatibility(experiment, revision) do
          {:ok,
           %{
             experiment: experiment,
             conditions: conditions,
             available_condition_codes: request.available_condition_codes
           }}
        end

      matches ->
        ambiguous_match(matches, scope, request, fn {experiment, _} -> experiment.id end)
    end
  end

  defp no_experiment_match do
    emit_assignment_fallback(:no_experiment)

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
        alternatives_resource_id: request.alternatives_resource_id
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
             :ok <- validate_experiment_controlled_revision(revision) do
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

  defp validate_runtime_condition_compatibility(experiment, revision) do
    conditions = active_conditions(experiment.id)

    with :ok <- validate_condition_option_mapping(revision, conditions) do
      {:ok, conditions}
    end
  end

  defp select_condition(_experiment, _conditions, [], _identity),
    do: invalid_condition("no condition codes supplied")

  defp select_condition(
         experiment,
         active_conditions,
         available_condition_codes,
         identity
       ) do
    conditions =
      Enum.filter(active_conditions, fn condition ->
        (condition.option_id || condition.condition_code) in available_condition_codes
      end)

    case conditions do
      [] ->
        emit_assignment_fallback(:invalid_condition, experiment)

        invalid_condition("no active experiment condition matches the available condition codes")

      conditions ->
        policy_state =
          get_policy_state(experiment.id, experiment.algorithm)

        {policy_module, policy_conditions, guardrail_action, assignment_counts} =
          assignment_policy_for(
            experiment,
            conditions,
            policy_state
          )

        policy_context = %{
          conditions: conditions,
          assignment_key: identity.assignment_key
        }

        policy_module
        |> apply(:assign, [
          experiment_policy_config(experiment),
          policy_state && policy_state.state,
          %{policy_context | conditions: policy_conditions}
        ])
        |> case do
          {:ok, policy_assignment} ->
            condition = Enum.find(conditions, &(&1.id == policy_assignment.condition_id))

            emit_assignment_guardrail_telemetry(
              experiment,
              condition,
              policy_assignment,
              guardrail_action,
              assignment_counts
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

  defp emit_assignment_fallback(reason, experiment \\ nil) do
    :telemetry.execute([:oli, :experiments, :assignment, :fallback], %{count: 1}, %{
      reason: reason,
      experiment_id: experiment && experiment.id,
      assignment_scope: experiment && experiment.assignment_scope
    })
  end

  defp assignment_policy_for(
         %ExperimentDefinitionSchema{algorithm: :thompson_sampling} = experiment,
         conditions,
         _policy_state
       ) do
    assignment_counts = assignment_counts_by_condition(experiment.id)
    guardrails = thompson_guardrails(experiment_policy_config(experiment))

    assignment_count =
      Enum.reduce(assignment_counts, 0, fn {_id, count}, total -> total + count end)

    cond do
      assignment_count < guardrails["warm_up_assignments"] ->
        {WeightedRandom, conditions, :warm_up, assignment_counts}

      fixed_control_condition =
          fixed_control_condition(
            conditions,
            assignment_counts,
            guardrails["fixed_control_allocation"]
          ) ->
        {WeightedRandom, [fixed_control_condition], :fixed_control, assignment_counts}

      capped_conditions =
          cap_eligible_conditions(
            conditions,
            assignment_counts,
            guardrails["max_condition_share"]
          ) ->
        {policy_module(experiment.algorithm), capped_conditions,
         cap_guardrail_action(capped_conditions, conditions), assignment_counts}
    end
  end

  defp assignment_policy_for(
         experiment,
         conditions,
         _policy_state
       ) do
    {policy_module(experiment.algorithm), conditions, :none, %{}}
  end

  defp assignment_policy_for_snapshot(
         %ExperimentDefinitionSchema{algorithm: :thompson_sampling} = experiment,
         conditions,
         _policy_state,
         assignment_counts
       ) do
    guardrails = thompson_guardrails(experiment_policy_config(experiment))

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
        {policy_module(experiment.algorithm), capped_conditions,
         cap_guardrail_action(capped_conditions, conditions)}
    end
  end

  defp assignment_policy_for_snapshot(
         experiment,
         conditions,
         _policy_state,
         _assignment_counts
       ),
       do: {policy_module(experiment.algorithm), conditions, :none}

  defp thompson_guardrails(policy_config) do
    policy_config
    |> Map.get("guardrails", %{})
    |> Map.merge(PolicyConfiguration.default_guardrails(), fn _key, configured, _default ->
      configured
    end)
  end

  defp fixed_control_condition(conditions, assignment_counts, allocation),
    do: PolicyGuardrails.fixed_control_condition(conditions, assignment_counts, allocation)

  defp cap_eligible_conditions(conditions, assignment_counts, max_share),
    do: PolicyGuardrails.cap_eligible_conditions(conditions, assignment_counts, max_share)

  defp cap_guardrail_action(capped_conditions, conditions) do
    if length(capped_conditions) == length(conditions), do: :none, else: :traffic_cap
  end

  defp emit_assignment_guardrail_telemetry(
         experiment,
         condition,
         policy_assignment,
         guardrail_action,
         assignment_counts
       ) do
    :telemetry.execute([:oli, :experiments, :assignment, :guardrail], %{count: 1}, %{
      experiment_id: experiment.id,
      assignment_scope: experiment.assignment_scope,
      algorithm: experiment.algorithm,
      algorithm_version: policy_assignment.policy_version,
      selected_condition_id: condition && condition.id,
      selected_condition_code: condition && condition.condition_code,
      guardrail_action: guardrail_action,
      imbalance_flag?:
        imbalance_flag?(
          experiment_policy_config(experiment),
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

  defp existing_assignment_decision(request, scope, revision) do
    with {:ok, match} <- active_experiment_match(request, scope, revision) do
      case match do
        %{status: :no_experiment} ->
          {:ok, %AssignmentDecision{status: :no_experiment}}

        %{experiment: experiment, intervention: intervention} ->
          with :ok <- validate_runtime_assignment_scope(experiment),
               {:ok, identity} <- assignment_identity(experiment, intervention, scope) do
            case find_assignment(identity) do
              %Assignment{} = assignment ->
                case Enum.find(match.conditions, &(&1.id == assignment.condition_id)) do
                  %Condition{} = condition ->
                    case (condition.option_id || condition.condition_code) in request.available_condition_codes do
                      true ->
                        {:ok,
                         to_assignment_decision(
                           assignment,
                           condition,
                           true,
                           condition.option_id
                         )}

                      false ->
                        invalid_condition(
                          "sticky assignment condition is unavailable at this intervention"
                        )
                    end

                  _ ->
                    invalid_condition(
                      "sticky assignment condition is unavailable at this intervention"
                    )
                end

              nil ->
                {:ok, %AssignmentDecision{status: :no_experiment}}
            end
          end
      end
    end
  end

  defp assign_or_reuse(%{status: :no_experiment}, _scope, _request),
    do: {:ok, %AssignmentDecision{status: :no_experiment}}

  defp assign_or_reuse(match, scope, request) do
    Repo.query!("SELECT pg_advisory_xact_lock($1)", [match.experiment.id])

    with :ok <- validate_runtime_assignment_scope(match.experiment),
         {:ok, identity} <-
           assignment_identity(match.experiment, Map.get(match, :intervention), scope) do
      case find_assignment(identity) do
        %Assignment{} = assignment ->
          case Enum.find(match.conditions, &(&1.id == assignment.condition_id)) do
            %Condition{} = condition ->
              case (condition.option_id || condition.condition_code) in match.available_condition_codes do
                true ->
                  decision = to_assignment_decision(assignment, condition, true)

                  :telemetry.execute([:oli, :experiments, :assignment, :reuse], %{count: 1}, %{
                    experiment_id: match.experiment.id,
                    assignment_scope: identity.scope,
                    algorithm: match.experiment.algorithm,
                    algorithm_version: assignment.policy_version,
                    selected_condition_id: assignment.condition_id,
                    selected_condition_code: condition.condition_code,
                    guardrail_action: :sticky_reuse
                  })

                  Telemetry.emit(:assignment_decided, {decision, request}, assignment: assignment)
                  {:ok, decision}

                false ->
                  invalid_condition(
                    "sticky assignment condition is unavailable at this intervention"
                  )
              end

            _ ->
              invalid_condition("sticky assignment condition is unavailable at this intervention")
          end

        nil ->
          with {:ok, selection} <-
                 select_condition(
                   match.experiment,
                   match.conditions,
                   match.available_condition_codes,
                   identity
                 ) do
            create_assignment(Map.merge(match, selection), identity, scope, request)
          end
      end
    end
  end

  defp validate_runtime_assignment_scope(
         %ExperimentDefinitionSchema{
           algorithm: algorithm,
           assignment_scope: scope
         } = experiment
       ) do
    case AssignmentIdentity.validate_scope(experiment) do
      :ok ->
        :ok

      {:error, %ExperimentError{}} = error ->
        :telemetry.execute(
          [:oli, :experiments, :assignment, :invalid_configuration],
          %{count: 1},
          %{algorithm: algorithm, assignment_scope: scope}
        )

        error
    end
  end

  defp assignment_identity(experiment, intervention, scope) do
    # Keep persistence lookup, deterministic policy input, and transaction-local reuse derived
    # from the same identity. Intervention assignments include the placement; canonical
    # section/enrollment assignments deliberately omit it so all experiment placements agree.
    AssignmentIdentity.derive(experiment, intervention, scope)
  end

  defp find_assignment(%{scope: :intervention} = identity) do
    Repo.get_by(Assignment,
      experiment_id: identity.experiment_id,
      intervention_id: identity.intervention_id,
      enrollment_id: identity.enrollment_id,
      assignment_scope: :intervention
    )
  end

  defp find_assignment(%{scope: :section_enrollment} = identity) do
    Repo.get_by(Assignment,
      experiment_id: identity.experiment_id,
      section_id: identity.section_id,
      enrollment_id: identity.enrollment_id,
      assignment_scope: :section_enrollment
    )
  end

  defp find_assignment!(identity), do: find_assignment(identity) || Repo.rollback(:not_found)

  defp create_assignment(match, identity, scope, request) do
    attrs = %{
      experiment_id: match.experiment.id,
      condition_id: match.condition.id,
      intervention_id: identity.intervention_id,
      section_id: scope.section_id,
      enrollment_id: scope.enrollment_id,
      user_id: scope.user_id,
      assigned_by_policy: Atom.to_string(match.experiment.algorithm),
      policy_version: match.policy_assignment.policy_version,
      assignment_scope: identity.scope,
      assignment_key: identity.assignment_key,
      assigned_at: now()
    }

    %Assignment{}
    |> Assignment.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, assignment} ->
        increment_assignment_count(match.experiment)
        decision = to_assignment_decision(assignment, match.condition, false)

        Telemetry.emit(:assignment_decided, {decision, request},
          assignment: assignment,
          experiment: match.experiment
        )

        event = %{
          decision: decision,
          request: request,
          assignment: assignment,
          experiment: match.experiment
        }

        {:ok, decision, event}

      {:error, %Ecto.Changeset{} = changeset} ->
        if conflict?(changeset) do
          assignment = find_assignment!(identity)

          Telemetry.emit(:assignment_conflict, %{
            experiment_id: match.experiment.id,
            assignment_scope: identity.scope
          })

          case Enum.find(match.conditions, &(&1.id == assignment.condition_id)) do
            %Condition{} = condition ->
              case (condition.option_id || condition.condition_code) in match.available_condition_codes do
                true ->
                  decision = to_assignment_decision(assignment, condition, true)

                  Telemetry.emit(:assignment_decided, {decision, request},
                    assignment: assignment,
                    experiment: match.experiment
                  )

                  {:ok, decision}

                false ->
                  invalid_condition(
                    "sticky assignment condition is unavailable at this intervention"
                  )
              end

            nil ->
              invalid_condition("sticky assignment condition is unavailable at this intervention")
          end
        else
          normalize_result({:error, changeset})
        end
    end
  end

  defp increment_assignment_count(experiment) do
    policy_state = get_or_create_policy_state(experiment)

    from(policy_state in PolicyState, where: policy_state.id == ^policy_state.id)
    |> Repo.update_all(inc: [assignment_count: 1])
  end

  defp runtime_event(%Oli.Experiments.RecordExposureRequest{} = request) do
    %{
      "assignment_id" => request.assignment_id,
      "key" => request.key,
      "page_resource_id" => request.page_resource_id,
      "content_element_id" => request.content_element_id,
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

  defp record_policy_reward(assignment, request, reward_event) do
    experiment =
      loaded_or_fetch(assignment.experiment, ExperimentDefinitionSchema, assignment.experiment_id)

    case experiment.algorithm do
      :weighted_random ->
        :ok

      _algorithm ->
        record_mutating_policy_reward(
          experiment,
          assignment,
          request,
          reward_event
        )
    end
  end

  defp record_mutating_policy_reward(
         experiment,
         assignment,
         request,
         reward_event
       ) do
    condition = loaded_or_fetch(assignment.condition, Condition, assignment.condition_id)

    policy_state =
      experiment
      |> get_or_create_policy_state()
      |> lock_policy_state()

    experiment.algorithm
    |> policy_module()
    |> apply(:record_reward, [
      experiment_policy_config(experiment),
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

  defp loaded_or_fetch(%Ecto.Association.NotLoaded{}, schema, id), do: Repo.get!(schema, id)
  defp loaded_or_fetch(association, _schema, _id), do: association

  defp lock_policy_state(policy_state) do
    Repo.one!(
      from(policy_state in PolicyState,
        where: policy_state.id == ^policy_state.id,
        lock: "FOR UPDATE"
      )
    )
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

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

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

  defp get_scoped_assignment_with_experiment!(assignment_id, scope) do
    case get_scoped_assignment_query(assignment_id, scope, false) do
      {:ok, query} ->
        case Repo.one(query) do
          %Assignment{experiment: %ExperimentDefinitionSchema{} = experiment} = assignment ->
            {assignment, experiment}

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
          where:
            assignment.id == ^assignment_id and
              experiment.project_id == ^scope.project_id and
              exists(participating_section_query(scope.section_id)) and
              assignment.section_id == ^scope.section_id and
              assignment.enrollment_id == ^scope.enrollment_id and
              assignment.user_id == ^scope.user_id,
          preload: [
            experiment: experiment,
            condition: condition
          ]

      {:ok, if(lock?, do: lock(query, "FOR UPDATE"), else: query)}
    end
  end

  defp validate_condition_option_mapping(revision, conditions),
    do: ActivationValidator.validate_condition_option_mapping(revision, conditions)

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

    experiments_by_resource =
      from(experiment in ExperimentDefinitionSchema,
        as: :experiment,
        where:
          experiment.project_id == ^scope.project_id and
            experiment.state == :active and
            experiment.algorithm == :weighted_random and
            experiment.alternatives_resource_id in ^alternatives_resource_ids and
            exists(participating_section_query(scope.section_id)),
        select: {experiment.alternatives_resource_id, experiment.id}
      )
      |> Repo.all()
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    now = now()

    candidate_entries =
      for request <- requests,
          experiment_id <-
            Map.get(experiments_by_resource, request.alternatives_resource_id, []) do
        %{
          experiment_id: experiment_id,
          page_resource_id: request.page_resource_id,
          content_element_id: request.content_element_id,
          inserted_at: now,
          updated_at: now
        }
      end

    entries =
      Enum.uniq_by(candidate_entries, fn entry ->
        {entry.experiment_id, entry.page_resource_id, entry.content_element_id}
      end)

    case entries do
      [] ->
        :ok

      entries ->
        Repo.insert_all(Intervention, entries,
          on_conflict: :nothing,
          conflict_target: [:experiment_id, :page_resource_id, :content_element_id]
        )

        :ok
    end
  end

  defp valid_intervention_identity?(request) do
    is_integer(request.page_resource_id) and request.page_resource_id > 0 and
      is_binary(request.content_element_id) and
      byte_size(request.content_element_id) in 1..255
  end

  defp to_alternatives_candidate(%Revision{} = revision) do
    %{
      alternatives_resource_id: revision.resource_id,
      alternatives_revision_id: revision.id,
      title: revision.title,
      options: revision_option_ids(revision),
      option_labels: revision_option_labels(revision)
    }
  end

  defp public_condition(%Condition{} = condition) do
    %{
      id: condition.id,
      condition_code: condition.condition_code,
      option_id: condition.option_id,
      label: condition.label,
      weight: condition.weight,
      active: condition.active,
      position: condition.position
    }
  end

  defp revision_option_labels(%Revision{content: %{"options" => options}})
       when is_list(options) do
    Map.new(options, fn option ->
      id = Map.get(option, "id") || Map.get(option, :id) || Map.get(option, "name")
      label = Map.get(option, "name") || Map.get(option, :name) || id
      {id, label}
    end)
  end

  defp revision_option_labels(_revision), do: %{}

  defp validate_publication(scope), do: ScopeValidator.validate_publication(scope)

  defp validate_delivery_participation_scope(scope),
    do: ScopeValidator.validate_delivery_participation_scope(scope)

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
      condition_id: assignment.condition_id,
      condition_code: condition.condition_code,
      option_id: option_id || assigned_option_id(assignment, condition),
      assignment_id: assignment.id,
      reused?: reused?
    }
  end

  defp assigned_option_id(%Assignment{}, %Condition{} = condition) do
    condition.option_id || condition.condition_code
  end

  defp exposure_receipt(%Assignment{} = assignment, event) do
    %ExposureReceipt{
      key: event["key"],
      assignment_id: assignment.id,
      recorded_at: event["recorded_at"],
      reused?: Map.get(event, "reused", false)
    }
  end

  defp hash_key(nil), do: nil

  defp hash_key(value) do
    :crypto.hash(:sha256, to_string(value))
    |> Base.encode16(case: :lower)
  end

  defp conflict?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn {_field, {_message, opts}} -> opts[:constraint] == :unique end)
  end
end
