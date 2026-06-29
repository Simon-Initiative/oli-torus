defmodule Oli.Experiments.AnalyticsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Experiments

  alias Oli.Experiments.{
    AnalyticsQuery,
    AssignmentDecision,
    CreateExperimentRequest,
    LifecycleRequest,
    RecordExposureRequest,
    RecordRewardRequest,
    Scope
  }

  alias Oli.Experiments.Schemas.{Condition, DecisionPoint}

  describe "analytics reads" do
    test "returns scoped summary, counts, and policy snapshots" do
      %{scope: scope, revision: revision, definition_id: experiment_id} =
        active_experiment_with_conditions()

      {:ok, %AssignmentDecision{} = assignment} =
        Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      {:ok, _exposure} =
        Experiments.record_exposure(%RecordExposureRequest{
          scope: scope,
          assignment_id: assignment.assignment_id,
          content_revision_id: revision.id,
          idempotency_key: "analytics-exposure"
        })

      {:ok, _reward} =
        Experiments.record_reward(%RecordRewardRequest{
          scope: scope,
          assignment_id: assignment.assignment_id,
          reward_value: 1.0,
          reward_source: "analytics",
          idempotency_key: "analytics-reward"
        })

      query = %AnalyticsQuery{scope: scope, experiment_id: experiment_id}

      assert {:ok, %{experiments: 1, assignments: 1, exposures: 1, rewards: 1}} =
               Experiments.experiment_summary(query)

      assert {:ok, [%{condition_code: condition_code, count: 1}]} =
               Experiments.assignment_counts(query)

      assert condition_code in ["a", "b"]

      assert {:ok, [%{count: 1}]} = Experiments.exposure_counts(query)
      assert {:ok, [%{count: 1}]} = Experiments.reward_counts(query)

      assert {:ok, [%{assignment_count: 1, reward_success_count: 1}]} =
               Experiments.policy_state_snapshot(query)
    end

    test "rejects out-of-scope analytics queries" do
      %{definition_id: experiment_id} = active_experiment_with_conditions()
      other_scope = valid_scope()

      assert {:error, %{type: :invalid_scope, message: "experiment is outside analytics scope"}} =
               Experiments.experiment_summary(%AnalyticsQuery{
                 scope: other_scope,
                 experiment_id: experiment_id
               })
    end
  end

  defp active_experiment_with_conditions do
    scope = valid_scope()
    revision = insert(:revision)

    {:ok, definition} =
      Experiments.create_experiment(%CreateExperimentRequest{
        scope: scope,
        slug: "analytics-#{System.unique_integer([:positive])}",
        name: "Analytics experiment",
        algorithm: :thompson_sampling
      })

    {:ok, active} =
      Experiments.activate_experiment(definition.id, %LifecycleRequest{scope: scope})

    decision_point =
      %DecisionPoint{}
      |> DecisionPoint.changeset(%{
        experiment_id: active.id,
        alternatives_resource_id: revision.resource_id,
        alternatives_revision_id: revision.id,
        decision_point_key: decision_point_key(revision)
      })
      |> Repo.insert!()

    for {code, position} <- [{"a", 0}, {"b", 1}] do
      %Condition{}
      |> Condition.changeset(%{
        experiment_id: active.id,
        decision_point_id: decision_point.id,
        condition_code: code,
        label: code,
        weight: 1.0,
        position: position
      })
      |> Repo.insert!()
    end

    %{scope: scope, revision: revision, definition_id: active.id}
  end

  defp assign_request(scope, revision, condition_codes) do
    %Oli.Experiments.AssignConditionRequest{
      scope: scope,
      alternatives_resource_id: revision.resource_id,
      alternatives_revision_id: revision.id,
      decision_point_key: decision_point_key(revision),
      available_condition_codes: condition_codes
    }
  end

  defp decision_point_key(revision), do: "alternatives:#{revision.resource_id}"

  defp valid_scope do
    institution = insert(:institution)
    project = insert(:project)
    publication = insert(:publication, project: project)
    section = insert(:section, institution: institution, base_project: project)
    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)

    %Scope{
      institution_id: institution.id,
      project_id: project.id,
      publication_id: publication.id,
      section_id: section.id,
      user_id: user.id,
      enrollment_id: enrollment.id
    }
  end
end
