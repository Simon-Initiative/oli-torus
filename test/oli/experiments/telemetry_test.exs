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
    ExperimentDefinition,
    PolicyState
  }

  @extension "http://oli.cmu.edu/extensions/experiment_attributions"

  test "builds assignment attribution without a dedicated xAPI statement" do
    attribution =
      Telemetry.assignment_attribution(assignment_decision(false), assign_request(),
        assignment: assignment()
      )

    assert attribution["role"] == "assignment"
    assert attribution["experiment_id"] == 10
    assert attribution["project_id"] == 100
    assert attribution["section_id"] == 300
    assert attribution["publication_id"] == 200
    assert attribution["decision_point_id"] == 20
    assert attribution["alternatives_resource_id"] == 700
    assert attribution["alternatives_revision_id"] == 701
    assert attribution["condition_id"] == 30
    assert attribution["condition_code"] == "a"
    assert attribution["assignment_key"] == "10:20:500"
    assert attribution["enrollment_id"] == 500
    assert attribution["user_id"] == 400
    assert attribution["algorithm"] == "weighted_random"
    assert attribution["policy_version"] == "weighted_random"
    assert attribution["idempotency_key"] == "10:20:500"
  end

  test "builds exposure, outcome, reward, and policy update attribution evidence" do
    [exposure] =
      Telemetry.attributions_for_page_view(exposure_receipt(), exposure_request(),
        assignment: assignment()
      )

    [outcome] =
      Telemetry.attributions_for_part_attempt(outcome_receipt(), outcome_request(),
        assignment: assignment()
      )

    [reward] =
      Telemetry.attributions_for_part_attempt(reward_receipt(), reward_request(),
        assignment: assignment()
      )

    policy_update =
      Telemetry.policy_update_evidence(policy_update(), reward(),
        assignment: assignment(),
        experiment: experiment(),
        condition: %{condition_code: "a"},
        policy_state: policy_state()
      )

    assert exposure["role"] == "exposure"
    assert exposure["exposure_id"] == 60
    assert exposure["content_revision_id"] == 701

    assert outcome["role"] == "outcome"
    assert outcome["outcome_id"] == 70
    assert outcome["activity_attempt_id"] == 800
    assert outcome["resource_attempt_id"] == 801
    assert outcome["activity_resource_id"] == 802
    assert outcome["score"] == 1.0
    assert outcome["out_of"] == 1.0

    assert reward["role"] == "reward"
    assert reward["reward_id"] == 80
    assert reward["outcome_id"] == 70
    assert reward["reward_source"] == "activity_attempt:full_credit"
    assert reward["reward_value"] == 1.0

    assert policy_update["role"] == "policy_update"
    assert policy_update["policy_update_id"] == 90
    assert policy_update["policy_state_id"] == 91
    assert policy_update["algorithm"] == "thompson_sampling"
    assert policy_update["algorithm_version"] == "thompson_sampling:v2"
    assert byte_size(policy_update["previous_policy_state_hash"]) == 64
    assert byte_size(policy_update["next_policy_state_hash"]) == 64
  end

  test "attaches optional experiment_attributions array to host statements" do
    statement = %{
      "context" => %{"extensions" => %{"http://oli.cmu.edu/extensions/page_id" => 44}}
    }

    attribution =
      Telemetry.exposure_attribution(exposure_receipt(), exposure_request(),
        assignment: assignment()
      )

    statement = Telemetry.attach_attributions(statement, [attribution])

    assert [attached] = get_in(statement, ["context", "extensions", @extension])
    assert attached["role"] == "exposure"
    assert attached["experiment_id"] == 10
  end

  test "rollup and media helpers rewrite roles on existing attribution payloads" do
    attribution =
      Telemetry.exposure_attribution(exposure_receipt(), exposure_request(),
        assignment: assignment()
      )

    assert [%{"role" => "rollup"}] = Telemetry.attributions_for_activity_attempt([attribution])
    assert [%{"role" => "rollup"}] = Telemetry.attributions_for_page_attempt([attribution])

    assert [%{"role" => "media_interaction"}] =
             Telemetry.attributions_for_media_event([attribution])
  end

  test "attribution payloads exclude learner names, raw responses, and full policy state" do
    policy_update =
      Telemetry.policy_update_evidence(policy_update(), reward(),
        assignment: assignment(),
        experiment: experiment(),
        condition: %{condition_code: "a"},
        policy_state: policy_state()
      )

    encoded = Jason.encode!(policy_update)

    refute encoded =~ "Ada"
    refute encoded =~ "Lovelace"
    refute encoded =~ "student response"
    refute encoded =~ "posterior_alpha"
    refute encoded =~ "posterior_beta"
  end

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
    %{
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
    %{
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
