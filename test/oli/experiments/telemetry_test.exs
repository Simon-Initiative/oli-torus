defmodule Oli.Experiments.TelemetryTest do
  use ExUnit.Case, async: true

  alias Oli.Experiments.{
    AssignmentDecision,
    AssignConditionRequest,
    ExposureReceipt,
    OutcomeReceipt,
    RecordExposureRequest,
    RecordOutcomeRequest,
    RecordRewardRequest,
    RewardReceipt,
    Scope,
    Telemetry
  }

  alias Oli.Experiments.Schemas.{
    Assignment,
    Exposure,
    ExperimentDefinition,
    Outcome,
    PolicyState,
    PolicyUpdate,
    Reward
  }

  @extension "http://oli.cmu.edu/extensions/"

  test "builds assignment statement with scoped identifiers and assignment idempotency key" do
    statement =
      Telemetry.assignment_statement(assignment_decision(false), assign_request(),
        assignment: assignment()
      )

    extensions = extensions(statement)
    base_url = Oli.Utils.get_base_url()

    assert verb(statement) == "http://oli.cmu.edu/extensions/verbs/experiment_assigned"
    assert get_in(statement, ["actor", "account", "homePage"]) == base_url
    assert get_in(statement, ["object", "id"]) =~ "#{base_url}/experiments/10/decision-points/20"
    assert extensions["#{@extension}event_type"] == "experiment_assigned"
    assert extensions["#{@extension}experiment_id"] == 10
    assert extensions["#{@extension}project_id"] == 100
    assert extensions["#{@extension}section_id"] == 300
    assert extensions["#{@extension}publication_id"] == 200
    assert extensions["#{@extension}decision_point_id"] == 20
    assert extensions["#{@extension}alternatives_resource_id"] == 700
    assert extensions["#{@extension}alternatives_revision_id"] == 701
    assert extensions["#{@extension}condition_id"] == 30
    assert extensions["#{@extension}condition_code"] == "a"
    assert extensions["#{@extension}assignment_key"] == "10:20:500"
    assert extensions["#{@extension}enrollment_id"] == 500
    assert extensions["#{@extension}user_id"] == 400
    assert extensions["#{@extension}assigned_by_policy"] == "weighted_random"
    assert extensions["#{@extension}policy_version"] == "weighted_random"
    assert extensions["#{@extension}idempotency_key"] == "10:20:500"
  end

  test "builds exposure, outcome, reward, and policy update statements" do
    exposure_statement =
      Telemetry.exposure_statement(exposure_receipt(), exposure_request(),
        assignment: assignment(),
        exposure: %Exposure{exposed_at: timestamp()}
      )

    outcome_statement =
      Telemetry.outcome_statement(outcome_receipt(), outcome_request(),
        assignment: assignment(),
        outcome: %Outcome{observed_at: timestamp()}
      )

    reward_statement =
      Telemetry.reward_statement(reward_receipt(), reward_request(),
        assignment: assignment(),
        reward: reward()
      )

    policy_statement =
      Telemetry.policy_update_statement(policy_update(), reward(),
        assignment: assignment(),
        experiment: experiment(),
        condition: %{condition_code: "a"},
        policy_state: policy_state()
      )

    assert extensions(exposure_statement)["#{@extension}event_type"] == "experiment_exposed"
    assert extensions(exposure_statement)["#{@extension}exposure_id"] == 60
    assert extensions(exposure_statement)["#{@extension}content_revision_id"] == 701

    assert extensions(outcome_statement)["#{@extension}event_type"] ==
             "experiment_outcome_recorded"

    assert extensions(outcome_statement)["#{@extension}outcome_id"] == 70
    assert extensions(outcome_statement)["#{@extension}activity_attempt_id"] == 800
    assert extensions(outcome_statement)["#{@extension}resource_attempt_id"] == 801
    assert extensions(outcome_statement)["#{@extension}activity_resource_id"] == 802
    assert get_in(outcome_statement, ["result", "score"]) == %{"raw" => 1.0, "max" => 1.0}

    assert extensions(reward_statement)["#{@extension}event_type"] == "experiment_reward_recorded"
    assert extensions(reward_statement)["#{@extension}reward_id"] == 80
    assert extensions(reward_statement)["#{@extension}outcome_id"] == 70

    assert extensions(reward_statement)["#{@extension}reward_source"] ==
             "activity_attempt:full_credit"

    assert get_in(reward_statement, ["result", "score"]) == %{
             "raw" => 1.0,
             "min" => 0,
             "max" => 1
           }

    assert extensions(policy_statement)["#{@extension}event_type"] == "experiment_policy_updated"
    assert extensions(policy_statement)["#{@extension}policy_update_id"] == 90
    assert extensions(policy_statement)["#{@extension}policy_state_id"] == 91
    assert extensions(policy_statement)["#{@extension}algorithm"] == "thompson_sampling"

    assert extensions(policy_statement)["#{@extension}algorithm_version"] ==
             "thompson_sampling:v2"

    assert byte_size(extensions(policy_statement)["#{@extension}previous_state_hash"]) == 64
    assert byte_size(extensions(policy_statement)["#{@extension}next_state_hash"]) == 64
  end

  test "statement payloads exclude learner names, raw responses, and full policy state" do
    statement =
      Telemetry.policy_update_statement(policy_update(), reward(),
        assignment: assignment(),
        experiment: experiment(),
        condition: %{condition_code: "a"},
        policy_state: policy_state()
      )

    encoded = Jason.encode!(statement)

    refute encoded =~ "Ada"
    refute encoded =~ "Lovelace"
    refute encoded =~ "student response"
    refute encoded =~ "posterior_alpha"
    refute encoded =~ "posterior_beta"
  end

  defp extensions(statement), do: get_in(statement, ["context", "extensions"])
  defp verb(statement), do: get_in(statement, ["verb", "id"])

  defp scope do
    %Scope{
      institution_id: 1,
      project_id: 100,
      publication_id: 200,
      section_id: 300,
      user_id: 400,
      enrollment_id: 500
    }
  end

  defp assign_request do
    %AssignConditionRequest{
      scope: scope(),
      alternatives_resource_id: 700,
      alternatives_revision_id: 701,
      decision_point_key: "alternatives:700",
      available_condition_codes: ["a", "b"]
    }
  end

  defp assignment_decision(reused?) do
    %AssignmentDecision{
      status: :assigned,
      experiment_id: 10,
      decision_point_id: 20,
      condition_id: 30,
      condition_code: "a",
      assignment_id: 40,
      reused?: reused?
    }
  end

  defp assignment do
    %Assignment{
      id: 40,
      experiment_id: 10,
      decision_point_id: 20,
      condition_id: 30,
      section_id: 300,
      enrollment_id: 500,
      user_id: 400,
      assigned_by_policy: "weighted_random",
      policy_version: "weighted_random",
      assignment_key: "10:20:500",
      assigned_at: timestamp()
    }
  end

  defp exposure_request do
    %RecordExposureRequest{
      scope: scope(),
      assignment_id: 40,
      content_revision_id: 701,
      idempotency_key: "exposure:40"
    }
  end

  defp exposure_receipt do
    %ExposureReceipt{
      id: 60,
      assignment_id: 40,
      idempotency_key: "exposure:40",
      recorded_at: timestamp(),
      reused?: false
    }
  end

  defp outcome_request do
    %RecordOutcomeRequest{
      scope: scope(),
      assignment_id: 40,
      activity_attempt_id: 800,
      resource_attempt_id: 801,
      activity_resource_id: 802,
      score: 1.0,
      out_of: 1.0,
      metadata: %{"raw_response" => "student response"},
      idempotency_key: "outcome:40"
    }
  end

  defp outcome_receipt do
    %OutcomeReceipt{
      id: 70,
      assignment_id: 40,
      idempotency_key: "outcome:40",
      recorded_at: timestamp(),
      reused?: false
    }
  end

  defp reward_request do
    %RecordRewardRequest{
      scope: scope(),
      assignment_id: 40,
      outcome_id: 70,
      reward_value: 1.0,
      reward_source: "activity_attempt:full_credit",
      metadata: %{"learner_name" => "Ada Lovelace"},
      idempotency_key: "reward:40"
    }
  end

  defp reward_receipt do
    %RewardReceipt{
      id: 80,
      assignment_id: 40,
      outcome_id: 70,
      idempotency_key: "reward:40",
      recorded_at: timestamp(),
      reused?: false
    }
  end

  defp reward do
    %Reward{
      id: 80,
      assignment_id: 40,
      outcome_id: 70,
      experiment_id: 10,
      decision_point_id: 20,
      condition_id: 30,
      reward_value: 1.0,
      reward_source: "activity_attempt:full_credit",
      idempotency_key: "reward:40",
      inserted_at: timestamp()
    }
  end

  defp policy_update do
    %PolicyUpdate{
      id: 90,
      policy_state_id: 91,
      reward_id: 80,
      condition_id: 30,
      previous_state: %{"a" => %{"posterior_alpha" => 1.0, "posterior_beta" => 1.0}},
      next_state: %{"a" => %{"posterior_alpha" => 2.0, "posterior_beta" => 1.0}},
      algorithm_version: "thompson_sampling:v2",
      update_reason: "reward_recorded",
      inserted_at: timestamp()
    }
  end

  defp policy_state do
    %PolicyState{
      id: 91,
      experiment_id: 10,
      decision_point_id: 20,
      algorithm: :thompson_sampling,
      algorithm_version: "thompson_sampling:v2"
    }
  end

  defp experiment do
    %ExperimentDefinition{
      id: 10,
      project_id: 100,
      section_id: 300,
      algorithm: :thompson_sampling
    }
  end

  defp timestamp, do: ~U[2026-07-14 12:00:00Z]
end
