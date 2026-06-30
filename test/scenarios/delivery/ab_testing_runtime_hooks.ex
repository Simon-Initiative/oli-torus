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
  alias Oli.Experiments.{CreateExperimentRequest, LifecycleRequest, Scope}
  alias Oli.Experiments.Schemas.{Assignment, Condition, DecisionPoint, Exposure, Outcome, Reward}
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
  @fallback_student_name "ab_runtime_fallback_student"
  @page_title "AB Runtime Practice"
  @activity_virtual_id "runtime_mcq"
  @condition_code "condition-a"
  @option_id "alt-a"

  def wrap_activity_in_alternatives(%ExecutionState{} = state) do
    with {:ok, updated_state} <- wrap_project_page(state, @project_name) do
      updated_state
    else
      {:error, reason} -> flunk("wrap_activity_in_alternatives failed: #{inspect(reason)}")
    end
  end

  def wrap_fallback_activity_in_alternatives(%ExecutionState{} = state) do
    with {:ok, updated_state} <- wrap_project_page(state, @fallback_project_name) do
      updated_state
    else
      {:error, reason} ->
        flunk("wrap_fallback_activity_in_alternatives failed: #{inspect(reason)}")
    end
  end

  def activate_native_experiment(%ExecutionState{} = state) do
    with {:ok, scope} <- scope_for(state, @project_name, @section_name, @student_name),
         {:ok, alternatives_revision} <- alternatives_revision(state, @project_name),
         {:ok, definition} <-
           Experiments.create_experiment(%CreateExperimentRequest{
             scope: scope,
             slug: "scenario-delivery-runtime",
             name: "Scenario delivery runtime",
             algorithm: :weighted_random
           }),
         {:ok, active} <-
           Experiments.activate_experiment(definition.id, %LifecycleRequest{scope: scope}) do
      decision_point =
        %DecisionPoint{}
        |> DecisionPoint.changeset(%{
          experiment_id: active.id,
          alternatives_resource_id: alternatives_revision.resource_id,
          alternatives_revision_id: alternatives_revision.id,
          decision_point_key: "alternatives:#{alternatives_revision.resource_id}",
          title: "Scenario delivery runtime decision point",
          position: 0
        })
        |> Repo.insert!()

      %Condition{}
      |> Condition.changeset(%{
        experiment_id: active.id,
        decision_point_id: decision_point.id,
        condition_code: @condition_code,
        option_id: @option_id,
        label: "Condition A",
        weight: 1.0,
        active: true,
        position: 0
      })
      |> Repo.insert!()

      state
    else
      {:error, reason} -> flunk("activate_native_experiment failed: #{inspect(reason)}")
    end
  end

  def assert_assignment_and_exposure(%ExecutionState{} = state) do
    with {:ok, scope} <- scope_for(state, @project_name, @section_name, @student_name),
         {:ok, alternatives_revision} <- alternatives_revision(state, @project_name),
         {:ok, page_revision} <- delivery_page_revision(state, @project_name, @section_name),
         :ok <- render_delivery_page(state, scope, page_revision, @section_name, @student_name) do
      assert Repo.aggregate(assignment_query(scope, alternatives_revision), :count, :id) == 1
      assert Repo.aggregate(exposure_query(scope, alternatives_revision), :count, :id) == 1

      state
    else
      {:error, reason} -> flunk("assert_assignment_and_exposure failed: #{inspect(reason)}")
    end
  end

  def assert_reward_records_are_idempotent(%ExecutionState{} = state) do
    with {:ok, scope} <- scope_for(state, @project_name, @section_name, @student_name),
         {:ok, alternatives_revision} <- alternatives_revision(state, @project_name),
         {:ok, activity_revision} <- activity_revision(state, @project_name),
         {:ok, activity_attempt} <-
           evaluated_activity_attempt(scope, activity_revision.resource_id) do
      assert Repo.aggregate(assignment_query(scope, alternatives_revision), :count, :id) == 1
      assert Repo.aggregate(exposure_query(scope, alternatives_revision), :count, :id) == 1
      assert Repo.aggregate(outcome_query(scope, activity_attempt.id), :count, :id) == 1

      reward = Repo.one!(reward_query(scope, activity_attempt.id))
      assert reward.reward_value == 1.0
      assert reward.reward_source == "activity_attempt:evaluated"

      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.id)

      assert Repo.aggregate(outcome_query(scope, activity_attempt.id), :count, :id) == 1
      assert Repo.aggregate(reward_query(scope, activity_attempt.id), :count, :id) == 1

      state
    else
      {:error, reason} -> flunk("assert_reward_records_are_idempotent failed: #{inspect(reason)}")
    end
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
         {:ok, activity_attempt} <-
           evaluated_activity_attempt(scope, activity_revision.resource_id) do
      assert Repo.aggregate(assignment_query(scope, alternatives_revision), :count, :id) == 0
      assert Repo.aggregate(exposure_query(scope, alternatives_revision), :count, :id) == 0
      assert Repo.aggregate(outcome_query(scope, activity_attempt.id), :count, :id) == 0
      assert Repo.aggregate(reward_query(scope, activity_attempt.id), :count, :id) == 0

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
         {:ok, alternatives_revision} <- create_alternatives_group(state, built_project),
         {:ok, updated_page_revision} <-
           update_page_content(
             state,
             built_project,
             page_revision,
             alternatives_revision,
             activity_revision
           ) do
      updated_built_project =
        built_project
        |> put_revision(@page_title, updated_page_revision)
        |> put_revision("Scenario Decision Point", alternatives_revision)

      {:ok, %{state | projects: Map.put(state.projects, project_name, updated_built_project)}}
    end
  end

  defp create_alternatives_group(%ExecutionState{} = state, built_project) do
    case Course.create_and_attach_resource(built_project.project, %{
           objectives: %{},
           children: [],
           content: %{
             "strategy" => "upgrade_decision_point",
             "options" => [
               %{"id" => @option_id, "name" => @condition_code}
             ]
           },
           title: "Scenario Decision Point",
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
         activity_revision
       ) do
    content = %{
      "model" => [
        %{
          "type" => "alternatives",
          "id" => "scenario-ab-alternatives",
          "strategy" => "upgrade_decision_point",
          "alternatives_id" => alternatives_revision.resource_id,
          "children" => [
            %{
              "type" => "alternative",
              "id" => "scenario-ab-alt-a",
              "value" => @option_id,
              "children" => [
                %{
                  "type" => "activity-reference",
                  "activity_id" => activity_revision.resource_id,
                  "children" => []
                }
              ]
            }
          ]
        }
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
    case Map.get(built_project.rev_by_title, @page_title) do
      nil -> {:error, {:page_not_found, @page_title}}
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
    with {:ok, built_project} <- fetch_project(state, project_name) do
      case Map.get(built_project.rev_by_title, "Scenario Decision Point") do
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
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> {:error, {:evaluated_activity_attempt_not_found, activity_resource_id}}
      activity_attempt -> {:ok, activity_attempt}
    end
  end

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

      :ok
    end
  end

  defp assignment_query(%Scope{} = scope, alternatives_revision) do
    from(assignment in Assignment,
      join: decision_point in DecisionPoint,
      on: decision_point.id == assignment.decision_point_id,
      join: condition in Condition,
      on: condition.id == assignment.condition_id,
      where:
        assignment.section_id == ^scope.section_id and
          assignment.user_id == ^scope.user_id and
          decision_point.alternatives_resource_id == ^alternatives_revision.resource_id and
          decision_point.alternatives_revision_id == ^alternatives_revision.id and
          condition.condition_code == ^@condition_code
    )
  end

  defp exposure_query(%Scope{} = scope, alternatives_revision) do
    from(exposure in Exposure,
      join: decision_point in DecisionPoint,
      on: decision_point.id == exposure.decision_point_id,
      where:
        exposure.section_id == ^scope.section_id and
          exposure.user_id == ^scope.user_id and
          decision_point.alternatives_resource_id == ^alternatives_revision.resource_id and
          exposure.content_revision_id == ^alternatives_revision.id
    )
  end

  defp outcome_query(%Scope{} = scope, activity_attempt_id) do
    from(outcome in Outcome,
      join: assignment in Assignment,
      on: assignment.id == outcome.assignment_id,
      where:
        assignment.section_id == ^scope.section_id and
          assignment.user_id == ^scope.user_id and
          outcome.activity_attempt_id == ^activity_attempt_id
    )
  end

  defp reward_query(%Scope{} = scope, activity_attempt_id) do
    from(reward in Reward,
      join: outcome in Outcome,
      on: outcome.id == reward.outcome_id,
      join: assignment in Assignment,
      on: assignment.id == reward.assignment_id,
      where:
        assignment.section_id == ^scope.section_id and
          assignment.user_id == ^scope.user_id and
          outcome.activity_attempt_id == ^activity_attempt_id
    )
  end
end
