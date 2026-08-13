defmodule Oli.Scenarios.Delivery.AbTestingRuntimeHooks do
  @moduledoc """
  Hooks for native A/B testing delivery runtime scenario coverage.
  """

  import Ecto.Query, warn: false
  import ExUnit.Assertions

  alias Oli.Authoring.Course
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Experiments.RewardHandoff
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Experiments

  alias Oli.Experiments.{
    AssignConditionRequest,
    CreateExperimentRequest,
    LifecycleRequest,
    RecordRewardRequest,
    Scope
  }

  alias Oli.Experiments.Schemas.{
    AcceptedReward,
    Assignment,
    Condition,
    ExperimentDefinition,
    ExperimentSection,
    PolicyState
  }

  alias Oli.Publishing
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Rendering.{Context, Page}
  alias Oli.Resources
  alias Oli.Resources.Alternatives
  alias Oli.Resources.ResourceType
  alias Oli.Scenarios.DirectiveTypes.ExecutionState

  @project_name "ab_runtime_project"
  @section_name "ab_runtime_section"
  @fallback_project_name "ab_runtime_fallback_project"
  @fallback_section_name "ab_runtime_fallback_section"
  @student_name "ab_runtime_student"
  @second_student_name "ab_runtime_student_b"
  @unselected_section_name "ab_runtime_unselected_section"
  @unselected_student_name "ab_runtime_unselected_student"
  @fallback_student_name "ab_runtime_fallback_student"
  @page_title "AB Runtime Practice"
  @assessment_title "AB Runtime Assessment"
  @later_intervention_title "AB Runtime Later Intervention"
  @later_assessment_title "AB Runtime Later Assessment"
  @adaptive_group_title "Scenario Adaptive Decision Point"
  @activity_virtual_id "runtime_mcq"
  @condition_code "alt-a"
  @option_id "alt-a"
  @option_b_id "alt-b"
  @condition_a_code "condition_a"
  @condition_b_code "condition_b"
  @reward_result_key :ab_testing_reward_result

  def assign_distinct_sticky_conditions(%ExecutionState{} = state) do
    with {:ok, alternatives_revision} <- alternatives_revision(state, @project_name),
         {:ok, page_revision} <- delivery_page_revision(state, @project_name, @section_name),
         {:ok, first_scope} <- scope_for(state, @project_name, @section_name, @student_name),
         {:ok, second_scope} <-
           scope_for(state, @project_name, @section_name, @second_student_name),
         :ok <-
           assign_each_intervention(
             first_scope,
             alternatives_revision,
             page_revision,
             @option_id,
             @condition_a_code
           ),
         :ok <-
           assign_each_intervention(
             second_scope,
             alternatives_revision,
             page_revision,
             @option_b_id,
             @condition_b_code
           ) do
      state
    else
      {:error, reason} -> flunk("assign_distinct_sticky_conditions failed: #{inspect(reason)}")
    end
  end

  def assert_two_learners_have_distinct_sticky_assignments(%ExecutionState{} = state) do
    with {:ok, first_scope} <- scope_for(state, @project_name, @section_name, @student_name),
         {:ok, second_scope} <-
           scope_for(state, @project_name, @section_name, @second_student_name) do
      first = intervention_assignments(first_scope)
      second = intervention_assignments(second_scope)

      assert length(first) == 2
      assert length(second) == 2
      assert Enum.map(first, & &1.condition_id) |> Enum.uniq() |> length() == 1
      assert Enum.map(second, & &1.condition_id) |> Enum.uniq() |> length() == 1
      refute hd(first).condition_id == hd(second).condition_id

      key = :ab_sticky_assignment_ids
      current = %{first: Enum.map(first, & &1.id), second: Enum.map(second, & &1.id)}

      case Map.get(state.params, key) do
        nil ->
          %{state | params: Map.put(state.params, key, current)}

        ^current ->
          state

        previous ->
          flunk("sticky assignments changed: #{inspect(previous)} -> #{inspect(current)}")
      end
    else
      {:error, reason} ->
        flunk("assert_two_learners_have_distinct_sticky_assignments failed: #{inspect(reason)}")
    end
  end

  def process_assessment_reward(%ExecutionState{} = state) do
    with {:ok, scope} <- scope_for(state, @project_name, @section_name, @student_name),
         {:ok, assessment_revision} <-
           delivery_revision(state, @project_name, @section_name, @assessment_title),
         resource_attempt when not is_nil(resource_attempt) <-
           resource_attempt(scope, assessment_revision.resource_id),
         {:ok, resource_attempt} <-
           resource_attempt
           |> ResourceAttempt.changeset(%{
             lifecycle_state: :evaluated,
             score: 1.0,
             out_of: 1.0
           })
           |> Repo.update(),
         :ok <- RewardHandoff.record_evaluated_resource_attempt(resource_attempt.id) do
      assert Repo.aggregate(
               from(reward in AcceptedReward,
                 where:
                   reward.enrollment_id == ^scope.enrollment_id and
                     reward.resource_attempt_id == ^resource_attempt.id
               ),
               :count,
               :id
             ) == 1

      state
    else
      reason -> flunk("process_assessment_reward failed: #{inspect(reason)}")
    end
  end

  def assert_posterior_reuse_and_experiment_isolation(%ExecutionState{} = state) do
    with {:ok, scope} <- scope_for(state, @project_name, @section_name, @student_name),
         {:ok, adaptive_revision} <-
           named_alternatives_revision(state, @project_name, @adaptive_group_title) do
      adaptive_state = Repo.one!(policy_state_query(scope, adaptive_revision))

      weighted_state =
        Repo.one!(
          policy_state_query(
            scope,
            Map.fetch!(state.projects[@project_name].rev_by_title, "Scenario Decision Point")
          )
        )

      assert adaptive_state.reward_success_count == 1

      assert Enum.any?(adaptive_state.state, fn {_code, values} ->
               values["posterior_alpha"] == 2.0
             end)

      assert adaptive_state.assignment_count >= 2

      later_assignment =
        Repo.one!(
          from(assignment in Assignment,
            join: intervention in assoc(assignment, :intervention),
            where:
              assignment.enrollment_id == ^scope.enrollment_id and
                intervention.content_element_id == "scenario-ts-alternatives-later"
          )
        )

      assert DateTime.compare(later_assignment.assigned_at, adaptive_state.updated_at) in [
               :eq,
               :gt
             ]

      assert weighted_state.reward_success_count == 0
      assert weighted_state.reward_failure_count == 0
      state
    else
      {:error, reason} ->
        flunk("assert_posterior_reuse_and_experiment_isolation failed: #{inspect(reason)}")
    end
  end

  defp assign_each_intervention(
         scope,
         alternatives_revision,
         page_revision,
         available_option_id,
         expected_condition_code
       ) do
    Enum.reduce_while(["scenario-ab-alternatives", "scenario-ab-alternatives-2"], :ok, fn id,
                                                                                          :ok ->
      request = %AssignConditionRequest{
        scope: scope,
        alternatives_resource_id: alternatives_revision.resource_id,
        alternatives_revision_id: alternatives_revision.id,
        page_resource_id: page_revision.resource_id,
        page_revision_id: page_revision.id,
        content_element_id: id,
        available_condition_codes: [available_option_id]
      }

      case Experiments.assign_condition(request) do
        {:ok, %{condition_code: ^expected_condition_code}} -> {:cont, :ok}
        other -> {:halt, {:error, {:assignment_failed, id, other}}}
      end
    end)
  end

  defp intervention_assignments(scope) do
    from(assignment in Assignment,
      join: experiment in ExperimentDefinition,
      on: experiment.id == assignment.experiment_id,
      where:
        assignment.section_id == ^scope.section_id and
          assignment.user_id == ^scope.user_id and
          not is_nil(assignment.intervention_id) and
          experiment.algorithm == :weighted_random,
      order_by: [asc: assignment.intervention_id]
    )
    |> Repo.all()
  end

  def wrap_activity_in_alternatives(%ExecutionState{} = state) do
    with {:ok, updated_state} <- wrap_project_page(state, @project_name) do
      updated_state
    else
      {:error, reason} -> flunk("wrap_activity_in_alternatives failed: #{inspect(reason)}")
    end
  end

  def wrap_fallback_activity_in_alternatives(%ExecutionState{} = state) do
    with {:ok, built_project} <- fetch_project(state, @fallback_project_name),
         {:ok, page_revision} <- page_revision(built_project),
         {:ok, activity_revision} <- activity_revision(state, @fallback_project_name),
         {:ok, alternatives_revision} <-
           create_alternatives_group(state, built_project, "Scenario Decision Point"),
         {:ok, updated_revision} <-
           update_page_content(
             state,
             built_project,
             page_revision,
             alternatives_revision,
             alternatives_revision,
             activity_revision
           ) do
      updated_project =
        built_project
        |> put_revision(@page_title, updated_revision)
        |> put_revision("Scenario Decision Point", alternatives_revision)

      %{state | projects: Map.put(state.projects, @fallback_project_name, updated_project)}
    else
      {:error, reason} ->
        flunk("wrap_fallback_activity_in_alternatives failed: #{inspect(reason)}")
    end
  end

  def activate_native_experiment(%ExecutionState{} = state) do
    with {:ok, scope} <- scope_for(state, @project_name, @section_name, @student_name),
         {:ok, alternatives_revision} <- alternatives_revision(state, @project_name),
         {:ok, adaptive_revision} <-
           named_alternatives_revision(state, @project_name, @adaptive_group_title),
         {:ok, page_revision} <- page_revision(Map.fetch!(state.projects, @project_name)),
         {:ok, assessment_revision} <-
           revision_by_title(Map.fetch!(state.projects, @project_name), @assessment_title),
         {:ok, later_revision} <-
           revision_by_title(Map.fetch!(state.projects, @project_name), @later_intervention_title),
         {:ok, later_assessment_revision} <-
           revision_by_title(Map.fetch!(state.projects, @project_name), @later_assessment_title),
         {:ok, weighted_definition} <-
           Experiments.create_experiment(%CreateExperimentRequest{
             scope: authoring_scope(scope, state),
             slug: "scenario-delivery-runtime",
             name: "Scenario delivery runtime",
             algorithm: :weighted_random,
             section_ids: [scope.section_id],
             conditions: [
               %{
                 client_ref: @condition_code,
                 label: "Condition A",
                 active: true,
                 position: 0,
                 option_id: @option_id,
                 weight: 1.0
               },
               %{
                 client_ref: @option_b_id,
                 label: "Condition B",
                 active: true,
                 position: 1,
                 option_id: @option_b_id,
                 weight: 1.0
               }
             ],
             alternatives_resource_id: alternatives_revision.resource_id,
             interventions: [
               %{
                 page_resource_id: page_revision.resource_id,
                 content_element_id: "scenario-ab-alternatives"
               },
               %{
                 page_resource_id: page_revision.resource_id,
                 content_element_id: "scenario-ab-alternatives-2"
               }
             ]
           }),
         {:ok, _active} <-
           Experiments.activate_experiment(weighted_definition.id, %LifecycleRequest{
             scope: authoring_scope(scope, state)
           }),
         {:ok, adaptive_definition} <-
           Experiments.create_experiment(%CreateExperimentRequest{
             scope: authoring_scope(scope, state),
             slug: "scenario-adaptive-runtime",
             name: "Scenario adaptive runtime",
             algorithm: :thompson_sampling,
             section_ids: [scope.section_id],
             alternatives_resource_id: adaptive_revision.resource_id,
             conditions: [
               %{
                 client_ref: @condition_code,
                 label: "Condition A",
                 active: true,
                 position: 0,
                 option_id: @option_id,
                 weight: 1.0
               },
               %{
                 client_ref: @option_b_id,
                 label: "Condition B",
                 active: true,
                 position: 1,
                 option_id: @option_b_id,
                 weight: 1.0
               }
             ],
             interventions: [
               %{
                 page_resource_id: page_revision.resource_id,
                 content_element_id: "scenario-ts-alternatives",
                 assessment_binding: %{
                   assessment_page_resource_id: assessment_revision.resource_id,
                   reward_threshold: Decimal.new("1.0")
                 }
               },
               %{
                 page_resource_id: later_revision.resource_id,
                 content_element_id: "scenario-ts-alternatives-later",
                 assessment_binding: %{
                   assessment_page_resource_id: later_assessment_revision.resource_id,
                   reward_threshold: Decimal.new("1.0")
                 }
               }
             ]
           }),
         {:ok, _active} <-
           Experiments.activate_experiment(adaptive_definition.id, %LifecycleRequest{
             scope: authoring_scope(scope, state)
           }) do
      state
    else
      {:error, reason} -> flunk("activate_native_experiment failed: #{inspect(reason)}")
    end
  end

  def assert_assignment_and_exposure(%ExecutionState{} = state) do
    with {:ok, scope} <- scope_for(state, @project_name, @section_name, @student_name),
         {:ok, alternatives_revision} <- alternatives_revision(state, @project_name),
         {:ok, page_revision} <- delivery_page_revision(state, @project_name, @section_name),
         {:ok, rendered_html} <-
           render_delivery_page(state, scope, page_revision, @section_name, @student_name) do
      assert rendered_html =~ "alternative-alt-a"
      assert Repo.aggregate(assignment_query(scope, alternatives_revision), :count, :id) == 1

      state
    else
      {:error, reason} -> flunk("assert_assignment_and_exposure failed: #{inspect(reason)}")
    end
  end

  def assert_unselected_section_has_no_experiment_records(%ExecutionState{} = state) do
    with {:ok, scope} <-
           scope_for(
             state,
             @project_name,
             @unselected_section_name,
             @unselected_student_name
           ),
         {:ok, alternatives_revision} <- alternatives_revision(state, @project_name),
         {:ok, page_revision} <-
           delivery_page_revision(state, @project_name, @unselected_section_name),
         {:ok, rendered_html} <-
           render_delivery_page(
             state,
             scope,
             page_revision,
             @unselected_section_name,
             @unselected_student_name
           ) do
      assert rendered_html =~ "alternative-alt-a"
      assert Repo.aggregate(assignment_query(scope, alternatives_revision), :count, :id) == 0
      assert event_count(scope, "exposures") == 0
      assert event_count(scope, "outcomes") == 0
      assert event_count(scope, "rewards") == 0
      state
    else
      {:error, reason} ->
        flunk("assert_unselected_section_has_no_experiment_records failed: #{inspect(reason)}")
    end
  end

  def record_reward(%ExecutionState{} = state) do
    with {:ok, scope} <- scope_for(state, @project_name, @section_name, @student_name),
         {:ok, alternatives_revision} <- alternatives_revision(state, @project_name),
         {:ok, activity_revision} <- activity_revision(state, @project_name),
         {:ok, activity_attempt} <-
           evaluated_activity_attempt(scope, activity_revision.resource_id),
         assignment <- Repo.one!(assignment_query(scope, alternatives_revision)),
         :ok <-
           RewardHandoff.record_evaluated_resource_attempt(activity_attempt.resource_attempt_id),
         reward <- only_event(scope, "rewards"),
         reward_request <- reward_request(reward, assignment.id, scope),
         {:ok, reused_reward_receipt} <- Experiments.record_reward(reward_request) do
      Map.put(state, @reward_result_key, %{
        alternatives_revision: alternatives_revision,
        receipt: reused_reward_receipt,
        reward: reward,
        scope: scope
      })
    else
      {:error, reason} -> flunk("record_reward failed: #{inspect(reason)}")
    end
  end

  def assert_reward_is_idempotent(%ExecutionState{} = state) do
    case Map.fetch(state, @reward_result_key) do
      {:ok,
       %{
         alternatives_revision: alternatives_revision,
         receipt: reused_reward_receipt,
         reward: reward,
         scope: scope
       }} ->
        assert event_count(scope, "outcomes") == 0
        assert event_count(scope, "rewards") == 1
        assert reused_reward_receipt.reused?
        assert reused_reward_receipt.key == reward["key"]
        assert reward["reward_value"] == 1.0
        assert reward["reward_source"] == "activity_attempt:full_credit"
        assert_thompson_policy_update(scope, alternatives_revision, reward)

        state

      :error ->
        flunk("record_reward must run before assert_reward_is_idempotent")
    end
  end

  def deselect_participating_section(%ExecutionState{} = state) do
    with {:ok, scope} <- scope_for(state, @project_name, @section_name, @student_name),
         {:ok, alternatives_revision} <- alternatives_revision(state, @project_name),
         experiment_id when not is_nil(experiment_id) <-
           Repo.one(
             from(experiment in Oli.Experiments.Schemas.ExperimentDefinition,
               where:
                 experiment.project_id == ^scope.project_id and
                   experiment.alternatives_resource_id == ^alternatives_revision.resource_id,
               select: experiment.id
             )
           ) do
      from(experiment_section in ExperimentSection,
        where:
          experiment_section.experiment_id == ^experiment_id and
            experiment_section.section_id == ^scope.section_id
      )
      |> Repo.delete_all()

      %{
        state
        | params:
            Map.put(
              state.params,
              :ab_assignment_count_before_deselection,
              Repo.aggregate(Assignment, :count, :id)
            )
      }
    else
      reason -> flunk("deselect_participating_section failed: #{inspect(reason)}")
    end
  end

  def assert_deselection_fallback_retains_history(%ExecutionState{} = state) do
    with {:ok, scope} <- scope_for(state, @project_name, @section_name, @student_name),
         {:ok, alternatives_revision} <- alternatives_revision(state, @project_name),
         {:ok, page_revision} <- delivery_page_revision(state, @project_name, @section_name),
         {:ok, rendered_html} <-
           render_delivery_page(state, scope, page_revision, @section_name, @student_name) do
      assert rendered_html =~ "alternative-alt-a"

      assert Repo.aggregate(assignment_query(scope, alternatives_revision), :count, :id) ==
               state.params.ab_assignment_count_before_deselection

      assert event_count(scope, "rewards") == 1
      state
    else
      {:error, reason} ->
        flunk("assert_deselection_fallback_retains_history failed: #{inspect(reason)}")
    end
  end

  defp reward_request(reward, assignment_id, scope) do
    %RecordRewardRequest{
      key: reward["key"],
      scope: scope,
      assignment_id: assignment_id,
      outcome_key: reward["outcome_key"],
      reward_value: reward["reward_value"],
      reward_source: reward["reward_source"]
    }
  end

  def assert_fallback_has_no_experiment_records(%ExecutionState{} = state) do
    with {:ok, scope} <-
           scope_for(
             state,
             @fallback_project_name,
             @fallback_section_name,
             @fallback_student_name
           ),
         {:ok, alternatives_revision} <- alternatives_revision(state, @fallback_project_name),
         {:ok, activity_revision} <- activity_revision(state, @fallback_project_name),
         {:ok, _activity_attempt} <-
           evaluated_activity_attempt(scope, activity_revision.resource_id) do
      assert Repo.aggregate(assignment_query(scope, alternatives_revision), :count, :id) == 0
      assert event_count(scope, "exposures") == 0
      assert event_count(scope, "outcomes") == 0
      assert event_count(scope, "rewards") == 0

      state
    else
      {:error, reason} ->
        flunk("assert_fallback_has_no_experiment_records failed: #{inspect(reason)}")
    end
  end

  defp wrap_project_page(%ExecutionState{} = state, project_name) do
    with {:ok, built_project} <- fetch_project(state, project_name),
         {:ok, page_revision} <- page_revision(built_project),
         {:ok, activity_revision} <- activity_revision(state, project_name),
         {:ok, alternatives_revision} <-
           create_alternatives_group(state, built_project, "Scenario Decision Point"),
         {:ok, adaptive_revision} <-
           create_alternatives_group(state, built_project, @adaptive_group_title),
         {:ok, updated_page_revision} <-
           update_page_content(
             state,
             built_project,
             page_revision,
             alternatives_revision,
             adaptive_revision,
             activity_revision
           ),
         {:ok, later_revision} <- revision_by_title(built_project, @later_intervention_title),
         {:ok, updated_later_revision} <-
           update_later_intervention(
             state,
             built_project,
             later_revision,
             adaptive_revision,
             activity_revision
           ) do
      updated_built_project =
        built_project
        |> put_revision(@page_title, updated_page_revision)
        |> put_revision("Scenario Decision Point", alternatives_revision)
        |> put_revision(@adaptive_group_title, adaptive_revision)
        |> put_revision(@later_intervention_title, updated_later_revision)

      {:ok, %{state | projects: Map.put(state.projects, project_name, updated_built_project)}}
    end
  end

  defp create_alternatives_group(%ExecutionState{} = state, built_project, title) do
    case Course.create_and_attach_resource(built_project.project, %{
           objectives: %{},
           children: [],
           content: %{
             "strategy" => "upgrade_decision_point",
             "options" => [
               %{"id" => @option_id, "name" => "condition-a"},
               %{"id" => @option_b_id, "name" => "condition-b"}
             ]
           },
           title: title,
           resource_type_id: ResourceType.id_for_alternatives(),
           author_id: state.current_author.id
         }) do
      {:ok, %{revision: revision}} ->
        upsert_working_publication(built_project.project.slug, revision)
        {:ok, revision}

      error ->
        error
    end
  end

  defp update_page_content(
         %ExecutionState{} = state,
         built_project,
         page_revision,
         alternatives_revision,
         adaptive_revision,
         activity_revision
       ) do
    content = %{
      "model" => [
        alternatives_placement(
          "scenario-ab-alternatives",
          alternatives_revision.resource_id,
          activity_revision.resource_id
        ),
        alternatives_placement(
          "scenario-ab-alternatives-2",
          alternatives_revision.resource_id,
          activity_revision.resource_id
        ),
        alternatives_placement(
          "scenario-ts-alternatives",
          adaptive_revision.resource_id,
          activity_revision.resource_id
        )
      ]
    }

    case Resources.update_revision(page_revision, %{
           content: content,
           title: @page_title,
           graded: false,
           author_id: state.current_author.id
         }) do
      {:ok, revision} ->
        upsert_working_publication(built_project.project.slug, revision)
        {:ok, revision}

      error ->
        error
    end
  end

  defp update_later_intervention(
         state,
         built_project,
         revision,
         adaptive_revision,
         activity_revision
       ) do
    content = %{
      "model" => [
        alternatives_placement(
          "scenario-ts-alternatives-later",
          adaptive_revision.resource_id,
          activity_revision.resource_id
        )
      ]
    }

    case Resources.update_revision(revision, %{
           content: content,
           title: @later_intervention_title,
           graded: false,
           author_id: state.current_author.id
         }) do
      {:ok, updated} ->
        upsert_working_publication(built_project.project.slug, updated)
        {:ok, updated}

      error ->
        error
    end
  end

  defp alternatives_placement(id, alternatives_resource_id, activity_resource_id) do
    %{
      "type" => "alternatives",
      "id" => id,
      "alternatives_id" => alternatives_resource_id,
      "children" => [
        alternative("#{id}-a", @condition_code, activity_resource_id),
        alternative("#{id}-b", @option_b_id, activity_resource_id)
      ]
    }
  end

  defp alternative(id, value, activity_resource_id) do
    %{
      "type" => "alternative",
      "id" => id,
      "value" => value,
      "children" => [
        %{
          "type" => "activity-reference",
          "activity_id" => activity_resource_id,
          "children" => []
        }
      ]
    }
  end

  defp upsert_working_publication(project_slug, revision) do
    case Publishing.project_working_publication(project_slug) do
      nil -> :ok
      publication -> Publishing.upsert_published_resource(publication, revision)
    end
  end

  defp fetch_project(%ExecutionState{} = state, name) do
    case Map.get(state.projects, name) do
      nil -> {:error, {:project_not_found, name}}
      built_project -> {:ok, built_project}
    end
  end

  defp page_revision(built_project) do
    revision_by_title(built_project, @page_title)
  end

  defp revision_by_title(built_project, title) do
    case Map.get(built_project.rev_by_title, title) do
      nil -> {:error, {:page_not_found, title}}
      revision -> {:ok, Resources.get_revision!(revision.id)}
    end
  end

  defp activity_revision(%ExecutionState{} = state, project_name) do
    case Map.get(state.activity_virtual_ids, {project_name, @activity_virtual_id}) do
      nil -> {:error, {:activity_not_found, project_name, @activity_virtual_id}}
      revision -> {:ok, Resources.get_revision!(revision.id)}
    end
  end

  defp alternatives_revision(%ExecutionState{} = state, project_name) do
    named_alternatives_revision(state, project_name, "Scenario Decision Point")
  end

  defp named_alternatives_revision(%ExecutionState{} = state, project_name, title) do
    with {:ok, built_project} <- fetch_project(state, project_name) do
      case Map.get(built_project.rev_by_title, title) do
        nil -> {:error, {:alternatives_not_found, project_name}}
        revision -> {:ok, Resources.get_revision!(revision.id)}
      end
    end
  end

  defp put_revision(built_project, title, revision) do
    %{built_project | rev_by_title: Map.put(built_project.rev_by_title, title, revision)}
  end

  defp scope_for(%ExecutionState{} = state, project_name, section_name, student_name) do
    with {:ok, built_project} <- fetch_project(state, project_name),
         {:ok, section} <- fetch_section(state, section_name),
         {:ok, user} <- fetch_user(state, student_name),
         {:ok, publication_id} <- publication_id(section.id, built_project.project.id),
         {:ok, enrollment} <- enrollment(section.id, user.id) do
      {:ok,
       %Scope{
         institution_id: section.institution_id,
         project_id: built_project.project.id,
         publication_id: publication_id,
         section_id: section.id,
         user_id: user.id,
         enrollment_id: enrollment.id
       }}
    end
  end

  defp authoring_scope(%Scope{} = scope, %ExecutionState{} = state) do
    %Scope{
      author_id: state.current_author.id,
      institution_id: scope.institution_id,
      project_id: scope.project_id
    }
  end

  defp fetch_section(%ExecutionState{} = state, name) do
    case Map.get(state.sections, name) do
      nil -> {:error, {:section_not_found, name}}
      section -> {:ok, section}
    end
  end

  defp fetch_user(%ExecutionState{} = state, name) do
    case Map.get(state.users, name) do
      nil -> {:error, {:user_not_found, name}}
      user -> {:ok, user}
    end
  end

  defp publication_id(section_id, project_id) do
    from(spp in SectionsProjectsPublications,
      where: spp.section_id == ^section_id and spp.project_id == ^project_id,
      select: spp.publication_id,
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> {:error, {:publication_not_found, section_id, project_id}}
      publication_id -> {:ok, publication_id}
    end
  end

  defp enrollment(section_id, user_id) do
    from(enrollment in Enrollment,
      where: enrollment.section_id == ^section_id and enrollment.user_id == ^user_id,
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> {:error, {:enrollment_not_found, section_id, user_id}}
      enrollment -> {:ok, enrollment}
    end
  end

  defp evaluated_activity_attempt(%Scope{} = scope, activity_resource_id) do
    from(activity_attempt in ActivityAttempt,
      join: resource_attempt in ResourceAttempt,
      on: resource_attempt.id == activity_attempt.resource_attempt_id,
      join: resource_access in ResourceAccess,
      on: resource_access.id == resource_attempt.resource_access_id,
      where:
        resource_access.section_id == ^scope.section_id and
          resource_access.user_id == ^scope.user_id and
          activity_attempt.resource_id == ^activity_resource_id and
          activity_attempt.lifecycle_state == :evaluated,
      order_by: [desc: activity_attempt.id],
      limit: 10,
      select: {activity_attempt, resource_attempt.content}
    )
    |> Repo.all()
    |> Enum.find(fn {_activity_attempt, content} -> alternatives_page_content?(content) end)
    |> case do
      nil ->
        {:error, {:evaluated_activity_attempt_not_found, activity_resource_id}}

      {activity_attempt, _content} ->
        {:ok, activity_attempt}
    end
  end

  defp resource_attempt(%Scope{} = scope, page_resource_id) do
    from(resource_attempt in ResourceAttempt,
      join: resource_access in ResourceAccess,
      on: resource_access.id == resource_attempt.resource_access_id,
      where:
        resource_access.section_id == ^scope.section_id and
          resource_access.user_id == ^scope.user_id and
          resource_access.resource_id == ^page_resource_id,
      order_by: [desc: resource_attempt.attempt_number, desc: resource_attempt.id],
      limit: 1
    )
    |> Repo.one()
  end

  defp alternatives_page_content?(%{"model" => _model} = content) do
    content
    |> Oli.Resources.PageContent.flat_filter(&(Map.get(&1, "type") == "alternatives"))
    |> Enum.any?()
  end

  defp alternatives_page_content?(_content), do: false

  defp delivery_page_revision(%ExecutionState{} = state, project_name, section_name) do
    with {:ok, built_project} <- fetch_project(state, project_name),
         {:ok, section} <- fetch_section(state, section_name),
         {:ok, project_page_revision} <- page_revision(built_project) do
      case DeliveryResolver.from_resource_id(section.slug, project_page_revision.resource_id) do
        nil ->
          {:error, {:delivery_page_not_found, section.slug, project_page_revision.resource_id}}

        revision ->
          {:ok, revision}
      end
    end
  end

  defp delivery_revision(state, project_name, section_name, title) do
    with {:ok, built_project} <- fetch_project(state, project_name),
         {:ok, section} <- fetch_section(state, section_name),
         {:ok, project_revision} <- revision_by_title(built_project, title) do
      case DeliveryResolver.from_resource_id(section.slug, project_revision.resource_id) do
        nil -> {:error, {:delivery_page_not_found, section.slug, project_revision.resource_id}}
        revision -> {:ok, revision}
      end
    end
  end

  defp render_delivery_page(
         %ExecutionState{} = state,
         %Scope{} = scope,
         page_revision,
         section_name,
         student_name
       ) do
    with {:ok, section} <- fetch_section(state, section_name),
         {:ok, user} <- fetch_user(state, student_name),
         {:ok, enrollment} <- enrollment(section.id, user.id) do
      rendered_html =
        Page.render(
          %Context{
            enrollment: enrollment,
            user: user,
            institution_id: scope.institution_id,
            project_id: scope.project_id,
            publication_id: scope.publication_id,
            section_id: scope.section_id,
            section_slug: section.slug,
            mode: :delivery,
            alternatives_groups_fn: fn ->
              Resources.alternatives_groups(section.slug, DeliveryResolver)
            end,
            alternatives_selector_fn: &Alternatives.select/2,
            extrinsic_read_section_fn: &Oli.Delivery.ExtrinsicState.read_section/3
          },
          page_revision.content,
          Page.Html
        )
        |> Phoenix.HTML.raw()
        |> Phoenix.HTML.safe_to_string()

      {:ok, rendered_html}
    end
  end

  defp assignment_query(%Scope{} = scope, alternatives_revision) do
    from(assignment in Assignment,
      join: experiment in ExperimentDefinition,
      on: experiment.id == assignment.experiment_id,
      where:
        assignment.section_id == ^scope.section_id and
          assignment.user_id == ^scope.user_id and
          experiment.alternatives_resource_id == ^alternatives_revision.resource_id
    )
  end

  defp assert_thompson_policy_update(%Scope{} = scope, alternatives_revision, reward) do
    condition = Repo.get!(Condition, reward["condition_id"])

    policy_state =
      scope
      |> policy_state_query(alternatives_revision)
      |> Repo.one!()

    assert policy_state.algorithm == :thompson_sampling
    assert policy_state.algorithm_version == "thompson_sampling:v2"
    assert policy_state.reward_success_count == 1
    assert policy_state.reward_failure_count == 0
    assert policy_state.assignment_count == 1
    assert policy_state.state[condition.condition_code]["successes"] == 1
    assert policy_state.state[condition.condition_code]["posterior_alpha"] == 2.0
  end

  defp policy_state_query(%Scope{} = scope, alternatives_revision) do
    from(policy_state in PolicyState,
      join: experiment in ExperimentDefinition,
      on: experiment.id == policy_state.experiment_id,
      where:
        policy_state.experiment_id in subquery(scoped_experiment_ids(scope)) and
          experiment.alternatives_resource_id == ^alternatives_revision.resource_id
    )
  end

  defp scoped_experiment_ids(%Scope{} = scope) do
    from(experiment in Oli.Experiments.Schemas.ExperimentDefinition,
      join: experiment_section in ExperimentSection,
      on:
        experiment_section.experiment_id == experiment.id and
          experiment_section.section_id == ^scope.section_id,
      where: experiment.project_id == ^scope.project_id,
      select: experiment.id
    )
  end

  defp event_count(%Scope{} = scope, event_group) do
    scope
    |> scoped_assignments()
    |> Repo.all()
    |> Enum.reduce(0, fn assignment, total ->
      total + map_size(Map.get(assignment.runtime_event_state || %{}, event_group, %{}))
    end)
  end

  defp only_event(%Scope{} = scope, event_group) do
    [event] =
      scope
      |> scoped_assignments()
      |> Repo.all()
      |> Enum.flat_map(fn assignment ->
        assignment.runtime_event_state
        |> Kernel.||(%{})
        |> Map.get(event_group, %{})
        |> Map.values()
      end)

    event
  end

  defp scoped_assignments(%Scope{} = scope) do
    from(assignment in Assignment,
      where:
        assignment.section_id == ^scope.section_id and
          assignment.user_id == ^scope.user_id
    )
  end
end
