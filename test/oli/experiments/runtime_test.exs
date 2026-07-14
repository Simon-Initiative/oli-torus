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

  alias Oli.Experiments.Schemas.{
    Assignment,
    Condition,
    DecisionPoint,
    Exposure,
    PolicyState,
    PolicyUpdate
  }

  defmodule FailingXAPI do
    def emit(_category, _statement), do: raise("xAPI unavailable")
  end

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
      attach_telemetry([[:oli, :experiments, :xapi, :emit, :stop]])

      %{scope: scope, revision: revision} = active_experiment_with_conditions()

      assert {:ok, %AssignmentDecision{status: :assigned, reused?: false} = first} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert first.condition_code in ["a", "b"]
      assert first.assignment_id

      assert {:ok, %AssignmentDecision{status: :assigned, reused?: true} = second} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert second.assignment_id == first.assignment_id
      assert Repo.aggregate(Assignment, :count, :id) == 1

      assert_receive {:telemetry, [:oli, :experiments, :xapi, :emit, :stop], %{count: 1},
                      %{event_type: "experiment_assigned"}}

      assert_receive {:telemetry, [:oli, :experiments, :xapi, :emit, :stop], %{count: 1},
                      %{event_type: "experiment_assignment_reused"}}
    end

    test "matches an active decision point after compatible alternatives revision changes" do
      %{scope: scope, revision: revision, decision_point: decision_point} =
        active_experiment_with_conditions()

      updated_revision =
        insert(:revision, %{
          resource: revision.resource,
          resource_type_id: revision.resource_type_id,
          title: "Updated Decision Point",
          content: %{
            "strategy" => "upgrade_decision_point",
            "options" => [
              %{"id" => "a", "name" => "a"},
              %{"id" => "b", "name" => "b"}
            ]
          }
        })

      assert updated_revision.resource_id == revision.resource_id
      assert updated_revision.id != decision_point.alternatives_revision_id

      assert {:ok, %AssignmentDecision{status: :assigned} = assignment} =
               Experiments.assign_condition(assign_request(scope, updated_revision, ["a", "b"]))

      assert assignment.decision_point_id == decision_point.id
      assert assignment.condition_code in ["a", "b"]
      assert Repo.aggregate(Assignment, :count, :id) == 1
    end

    test "preserves Thompson Sampling sticky assignment after posterior updates" do
      %{scope: scope, revision: revision} =
        active_experiment_with_conditions(algorithm: :thompson_sampling)

      assert {:ok, %AssignmentDecision{reused?: false} = first} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      reward_request = %RecordRewardRequest{
        scope: scope,
        assignment_id: first.assignment_id,
        reward_value: 1.0,
        reward_source: "test",
        idempotency_key: "sticky-ts-reward:#{first.assignment_id}"
      }

      assert {:ok, %RewardReceipt{reused?: false}} = Experiments.record_reward(reward_request)

      assert {:ok, %AssignmentDecision{reused?: true} = second} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert second.assignment_id == first.assignment_id
      assert second.condition_id == first.condition_id
      assert second.condition_code == first.condition_code
    end

    test "emits Thompson Sampling guardrail metadata for first assignments" do
      attach_telemetry([[:oli, :experiments, :assignment, :guardrail]])

      %{scope: scope, revision: revision} =
        active_experiment_with_conditions(
          algorithm: :thompson_sampling,
          policy_config: %{"guardrails" => %{"warm_up_assignments" => 1}}
        )

      assert {:ok, %AssignmentDecision{status: :assigned}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      assert_receive {:telemetry, [:oli, :experiments, :assignment, :guardrail], %{count: 1},
                      %{algorithm: :thompson_sampling, guardrail_action: :warm_up}}
    end

    test "applies fixed-control and traffic-cap guardrails before Thompson Sampling" do
      %{scope: scope, revision: revision, definition: definition, decision_point: decision_point} =
        active_experiment_with_conditions(
          algorithm: :thompson_sampling,
          policy_config: %{"guardrails" => %{"fixed_control_allocation" => 0.5}}
        )

      assert {:ok, %AssignmentDecision{condition_code: "a"}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      %{
        scope: cap_scope,
        revision: cap_revision,
        definition: cap_definition,
        decision_point: cap_dp
      } =
        active_experiment_with_conditions(
          algorithm: :thompson_sampling,
          policy_config: %{"guardrails" => %{"max_condition_share" => 0.5}}
        )

      condition_a = Repo.get_by!(Condition, experiment_id: cap_definition.id, condition_code: "a")
      insert_assignment!(cap_definition, cap_dp, condition_a, valid_scope())

      assert {:ok, %AssignmentDecision{condition_code: "b"}} =
               Experiments.assign_condition(assign_request(cap_scope, cap_revision, ["a", "b"]))

      assert definition.id
      assert decision_point.id
    end

    test "reports imbalance guardrail flag without blocking sticky fallback" do
      attach_telemetry([[:oli, :experiments, :assignment, :guardrail]])

      %{scope: scope, revision: revision, definition: definition, decision_point: decision_point} =
        active_experiment_with_conditions(
          algorithm: :thompson_sampling,
          policy_config: %{"guardrails" => %{"imbalance_threshold" => 0.5}}
        )

      condition_a = Repo.get_by!(Condition, experiment_id: definition.id, condition_code: "a")
      insert_assignment!(definition, decision_point, condition_a, valid_scope())

      assert {:ok, %AssignmentDecision{condition_code: "a"}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      assert_receive {:telemetry, [:oli, :experiments, :assignment, :guardrail], %{count: 1},
                      %{guardrail_action: :none, imbalance_flag?: true}}
    end

    test "paused and malformed Thompson Sampling experiments use controlled fallback errors" do
      %{scope: scope, revision: revision, definition: definition} =
        active_experiment_with_conditions(algorithm: :thompson_sampling)

      assert {:ok, _paused} =
               Experiments.pause_experiment(definition.id, %LifecycleRequest{
                 scope: %{
                   scope
                   | section_id: nil,
                     user_id: nil,
                     enrollment_id: nil
                 }
               })

      assert {:ok, %AssignmentDecision{status: :no_experiment}} =
               Experiments.assign_condition(assign_request(scope, revision, ["a", "b"]))

      %{
        scope: bad_scope,
        revision: bad_revision,
        definition: bad_definition,
        decision_point: bad_decision_point
      } =
        active_experiment_with_conditions(algorithm: :thompson_sampling)

      %PolicyState{}
      |> PolicyState.changeset(%{
        experiment_id: bad_definition.id,
        decision_point_id: bad_decision_point.id,
        algorithm: :thompson_sampling,
        algorithm_version: "thompson_sampling:v2",
        state: %{"a" => %{"successes" => "bad"}},
        prior_config: %{},
        reward_success_count: 0,
        reward_failure_count: 0,
        assignment_count: 0
      })
      |> Repo.insert!()

      assert {:error, %{type: :invalid_condition, message: "policy could not assign a condition"}} =
               Experiments.assign_condition(assign_request(bad_scope, bad_revision, ["a", "b"]))
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
        [:oli, :experiments, :reward, :recorded],
        [:oli, :experiments, :xapi, :emit, :stop],
        [:oli, :experiments, :xapi, :emit, :skipped_duplicate]
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
      assert_xapi_stop("experiment_assigned")
      assert_xapi_stop("experiment_exposed")
      assert_xapi_stop("experiment_outcome_recorded")
      assert_xapi_stop("experiment_reward_recorded")
      refute_xapi_stop("experiment_exposed")
      refute_xapi_stop("experiment_outcome_recorded")
      refute_xapi_stop("experiment_reward_recorded")
      assert_duplicate_skip("experiment_exposed")
      assert_duplicate_skip("experiment_outcome_recorded")
      assert_duplicate_skip("experiment_reward_recorded")
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

    test "xAPI emission failure does not roll back runtime writes" do
      attach_telemetry([[:oli, :experiments, :xapi, :emit, :exception]])
      put_failing_xapi_module()

      %{scope: scope, revision: revision} = active_experiment_with_conditions()
      {:ok, assignment} = Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      exposure_request = %RecordExposureRequest{
        scope: scope,
        assignment_id: assignment.assignment_id,
        content_revision_id: revision.id,
        idempotency_key: "failed-xapi-exposure:#{assignment.assignment_id}"
      }

      assert {:ok, %ExposureReceipt{reused?: false} = receipt} =
               Experiments.record_exposure(exposure_request)

      assert Repo.get!(Exposure, receipt.id).id == receipt.id

      assert_receive {:telemetry, [:oli, :experiments, :xapi, :emit, :exception], %{count: 1},
                      %{event_type: "experiment_exposed", kind: :error}}
    end

    test "records Thompson Sampling policy state and audit updates idempotently" do
      attach_telemetry([[:oli, :experiments, :xapi, :emit, :stop]])

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
      assert_xapi_stop("experiment_policy_updated")
    end

    test "records concurrent Thompson Sampling rewards without losing posterior increments" do
      %{scope: scope, revision: revision} =
        active_experiment_with_conditions(algorithm: :thompson_sampling)

      second_scope = sibling_runtime_scope(scope)

      {:ok, first_assignment} =
        Experiments.assign_condition(assign_request(scope, revision, ["a"]))

      {:ok, second_assignment} =
        Experiments.assign_condition(assign_request(second_scope, revision, ["a"]))

      first_request = %RecordRewardRequest{
        scope: scope,
        assignment_id: first_assignment.assignment_id,
        reward_value: 1.0,
        reward_source: "test",
        idempotency_key: "concurrent-ts-reward:#{first_assignment.assignment_id}"
      }

      second_request = %RecordRewardRequest{
        scope: second_scope,
        assignment_id: second_assignment.assignment_id,
        reward_value: 1.0,
        reward_source: "test",
        idempotency_key: "concurrent-ts-reward:#{second_assignment.assignment_id}"
      }

      [first_result, second_result] =
        [first_request, second_request]
        |> Enum.map(&Task.async(fn -> Experiments.record_reward(&1) end))
        |> Enum.map(&Task.await(&1, 5_000))

      assert {:ok, %RewardReceipt{reused?: false}} = first_result
      assert {:ok, %RewardReceipt{reused?: false}} = second_result

      policy_state = Repo.get_by!(PolicyState, experiment_id: first_assignment.experiment_id)
      assert policy_state.reward_success_count == 2
      assert policy_state.state["a"]["successes"] == 2
      assert policy_state.state["a"]["posterior_alpha"] == 3.0
      assert Repo.aggregate(PolicyUpdate, :count, :id) == 2
    end
  end

  defp active_experiment_with_conditions(opts \\ []) do
    scope = valid_scope()
    revision = insert(:revision)
    algorithm = Keyword.get(opts, :algorithm, :weighted_random)
    policy_config = Keyword.get(opts, :policy_config, %{})

    {:ok, definition} =
      Experiments.create_experiment(%CreateExperimentRequest{
        scope: scope,
        slug: "runtime-#{System.unique_integer([:positive])}",
        name: "Runtime experiment",
        algorithm: algorithm,
        policy_config: policy_config
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

  defp sibling_runtime_scope(%Scope{} = scope) do
    section = Repo.get!(Oli.Delivery.Sections.Section, scope.section_id)
    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)

    %{scope | user_id: user.id, enrollment_id: enrollment.id}
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

  defp assert_xapi_stop(event_type) do
    assert_receive {:telemetry, [:oli, :experiments, :xapi, :emit, :stop], %{count: 1},
                    %{event_type: ^event_type}}
  end

  defp refute_xapi_stop(event_type) do
    refute_receive {:telemetry, [:oli, :experiments, :xapi, :emit, :stop], _measurements,
                    %{event_type: ^event_type}}
  end

  defp assert_duplicate_skip(event_type) do
    assert_receive {:telemetry, [:oli, :experiments, :xapi, :emit, :skipped_duplicate],
                    %{count: 1}, %{event_type: ^event_type, idempotency_key_hash: hash}}

    assert byte_size(hash) == 64
  end

  defp put_failing_xapi_module do
    previous = Application.get_env(:oli, :experiments_xapi_module)
    Application.put_env(:oli, :experiments_xapi_module, FailingXAPI)

    on_exit(fn ->
      case previous do
        nil -> Application.delete_env(:oli, :experiments_xapi_module)
        module -> Application.put_env(:oli, :experiments_xapi_module, module)
      end
    end)
  end

  defp insert_assignment!(definition, decision_point, condition, scope) do
    %Assignment{}
    |> Assignment.changeset(%{
      experiment_id: definition.id,
      decision_point_id: decision_point.id,
      condition_id: condition.id,
      section_id: scope.section_id,
      enrollment_id: scope.enrollment_id,
      user_id: scope.user_id,
      assigned_by_policy: Atom.to_string(definition.algorithm),
      policy_version: "test",
      assignment_key: "test-assignment-#{System.unique_integer([:positive])}",
      assigned_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert!()
  end
end
