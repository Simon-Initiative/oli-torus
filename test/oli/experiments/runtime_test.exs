defmodule Oli.Experiments.RuntimeTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Experiments

  alias Oli.Experiments.{
    AssignmentDecision,
    CreateExperimentRequest,
    ExposureReceipt,
    LifecycleRequest,
    OutcomeReceipt,
    RecordExposureRequest,
    RecordOutcomeRequest,
    RecordRewardRequest,
    RewardReceipt,
    Scope
  }

  alias Oli.Experiments.Schemas.{Assignment, Condition, DecisionPoint, PolicyState, PolicyUpdate}

  describe "assign_condition/1" do
    test "returns no_experiment when no active experiment matches and emits fallback telemetry" do
      attach_telemetry([[:oli, :experiments, :assignment, :fallback]])

      revision = insert(:revision)
      scope = valid_scope()

      assert {:ok, %AssignmentDecision{status: :no_experiment}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      assert_receive {:telemetry, [:oli, :experiments, :assignment, :fallback], %{count: 1},
                      %{reason: :no_experiment}}
    end

    test "creates and reuses sticky assignments by enrollment" do
      %{scope: scope, revision: revision} = active_experiment_with_conditions()

      assert {:ok, %AssignmentDecision{status: :assigned, reused?: false} = first} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert first.condition_code in ["a", "b"]
      assert first.assignment_id

      assert {:ok, %AssignmentDecision{status: :assigned, reused?: true} = second} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert second.assignment_id == first.assignment_id
      assert Repo.aggregate(Assignment, :count, :id) == 1
    end

    test "rejects active experiment condition mismatches" do
      %{scope: scope, revision: revision} = active_experiment_with_conditions()

      assert {:error, %{type: :invalid_condition}} =
               Experiments.assign_condition(assign_request(scope, revision, ["missing"]))
    end
  end

  describe "runtime evidence commands" do
    test "records exposure, outcome, and reward idempotently" do
      attach_telemetry([
        [:oli, :experiments, :exposure, :recorded],
        [:oli, :experiments, :reward, :recorded]
      ])

      %{scope: scope, revision: revision} = active_experiment_with_conditions()
      {:ok, assignment} = Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      exposure_request = %RecordExposureRequest{
        scope: scope,
        assignment_id: assignment.assignment_id,
        content_revision_id: revision.id,
        idempotency_key: "exposure:#{assignment.assignment_id}"
      }

      assert {:ok, %ExposureReceipt{reused?: false} = exposure} =
               Experiments.record_exposure(exposure_request)

      assert {:ok, %ExposureReceipt{reused?: true, id: exposure_id}} =
               Experiments.record_exposure(exposure_request)

      assert exposure_id == exposure.id

      outcome_request = %RecordOutcomeRequest{
        scope: scope,
        assignment_id: assignment.assignment_id,
        score: 1.0,
        out_of: 1.0,
        idempotency_key: "outcome:#{assignment.assignment_id}"
      }

      assert {:ok, %OutcomeReceipt{reused?: false} = outcome} =
               Experiments.record_outcome(outcome_request)

      assert {:ok, %OutcomeReceipt{reused?: true, id: outcome_id}} =
               Experiments.record_outcome(outcome_request)

      assert outcome_id == outcome.id

      reward_request = %RecordRewardRequest{
        scope: scope,
        assignment_id: assignment.assignment_id,
        outcome_id: outcome.id,
        reward_value: 1.0,
        reward_source: "test",
        idempotency_key: "reward:#{assignment.assignment_id}"
      }

      assert {:ok, %RewardReceipt{reused?: false} = reward} =
               Experiments.record_reward(reward_request)

      assert {:ok, %RewardReceipt{reused?: true, id: reward_id}} =
               Experiments.record_reward(reward_request)

      assert reward_id == reward.id

      assert_receive {:telemetry, [:oli, :experiments, :exposure, :recorded], %{count: 1}, _}
      assert_receive {:telemetry, [:oli, :experiments, :reward, :recorded], %{count: 1}, _}
    end

    test "rejects idempotent receipts outside the caller scope" do
      %{scope: scope, revision: revision} = active_experiment_with_conditions()
      {:ok, assignment} = Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      exposure_request = %RecordExposureRequest{
        scope: scope,
        assignment_id: assignment.assignment_id,
        content_revision_id: revision.id,
        idempotency_key: "shared-key"
      }

      assert {:ok, %ExposureReceipt{}} = Experiments.record_exposure(exposure_request)

      other_scope = valid_scope()

      assert {:error, %{type: :invalid_scope}} =
               Experiments.record_exposure(%{exposure_request | scope: other_scope})
    end

    test "records Thompson Sampling policy state and audit updates idempotently" do
      %{scope: scope, revision: revision} =
        active_experiment_with_conditions(algorithm: :thompson_sampling)

      {:ok, assignment} = Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      reward_request = %RecordRewardRequest{
        scope: scope,
        assignment_id: assignment.assignment_id,
        reward_value: 1.0,
        reward_source: "test",
        idempotency_key: "ts-reward:#{assignment.assignment_id}"
      }

      assert {:ok, %RewardReceipt{reused?: false} = reward} =
               Experiments.record_reward(reward_request)

      assert {:ok, %RewardReceipt{reused?: true}} = Experiments.record_reward(reward_request)

      policy_state = Repo.get_by!(PolicyState, experiment_id: assignment.experiment_id)
      assert policy_state.algorithm == :thompson_sampling
      assert policy_state.reward_success_count == 1
      assert policy_state.reward_failure_count == 0
      assert policy_state.last_updated_from_reward_id == reward.id

      policy_update = Repo.get_by!(PolicyUpdate, reward_id: reward.id)
      assert policy_update.next_state[assignment.condition_code]["successes"] == 1
      assert Repo.aggregate(PolicyUpdate, :count, :id) == 1
    end
  end

  defp active_experiment_with_conditions(opts \\ []) do
    scope = valid_scope()
    revision = insert(:revision)
    algorithm = Keyword.get(opts, :algorithm, :weighted_random)

    {:ok, definition} =
      Experiments.create_experiment(%CreateExperimentRequest{
        scope: scope,
        slug: "runtime-#{System.unique_integer([:positive])}",
        name: "Runtime experiment",
        algorithm: algorithm
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

    %{scope: scope, revision: revision, definition: active, decision_point: decision_point}
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

  defp attach_telemetry(events) do
    parent = self()
    handler_id = "experiment-runtime-test-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      events,
      fn event, measurements, metadata, _config ->
        send(parent, {:telemetry, event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end
end
