defmodule Oli.Test.Support.UpgradeDataCaptureParityFixtures do
  @moduledoc """
  Golden phase-one fixtures for the UpGrade data-capture parity contract.

  These fixtures deliberately describe only existing attempt and media host statements. They keep
  causal experiment attribution separate from the unconditional raw activity outcome contract.
  """

  alias Oli.Analytics.XAPI.Events.Attempt.{
    ActivityAttemptEvaluated,
    PageAttemptEvaluated,
    PartAttemptEvaluated
  }

  alias Oli.Analytics.XAPI.Events.Context
  alias Oli.Analytics.XAPI.Events.Video.Played
  alias Oli.Delivery.Attempts.Core.ActivityAttempt

  alias Oli.Experiments.{
    AssignmentDecision,
    AssignConditionRequest,
    OutcomeReceipt,
    RecordOutcomeRequest,
    RecordRewardRequest,
    RewardReceipt,
    Scope
  }

  alias Oli.Experiments.Schemas.{Assignment, Condition, ExperimentDefinition}
  alias Oli.Experiments.XAPI.Attributions

  @doc "Returns schema-valid host statement fixtures for the supported producer contract."
  def statements do
    [
      fixture(:attributed_part_attempt, attributed_part_attempt_statement()),
      fixture(:attributed_activity_attempt, attributed_activity_attempt_statement()),
      fixture(
        :attributed_page_attempt,
        attributed_page_attempt_statement(intervention_outcome())
      ),
      fixture(
        :section_enrollment_attempt,
        attributed_page_attempt_statement(section_enrollment_outcome())
      ),
      fixture(:thompson_attempt, thompson_attempt_statement()),
      fixture(:attributed_media, attributed_media_statement()),
      fixture(:unattributed_media, media_statement()),
      fixture(:unattributed_historical_attempt, historical_attempt_statement())
    ]
  end

  @doc "Returns the v0.33.0 score/out-of inputs and expected compatibility correctness rows."
  def compatibility_rows do
    [
      %{
        enrollment_id: 501,
        condition: "condition-a",
        timestamp: ~U[2026-08-19 12:00:00Z],
        score: 1.0,
        out_of: 2.0,
        correctness: 0.5
      },
      %{
        enrollment_id: 502,
        condition: "condition-b",
        timestamp: ~U[2026-08-19 12:01:00Z],
        score: 0.0,
        out_of: 2.0,
        correctness: 0.0
      },
      %{
        enrollment_id: 503,
        condition: "condition-a",
        timestamp: ~U[2026-08-19 12:02:00Z],
        score: 1.0,
        out_of: 0.0,
        correctness: 0.0
      },
      %{
        enrollment_id: 504,
        condition: "condition-b",
        timestamp: ~U[2026-08-19 12:03:00Z],
        score: nil,
        out_of: 2.0,
        correctness: 0.0
      }
    ]
  end

  @doc "Returns assignment/exposure evidence used by the v0.33.0 compatibility proof."
  def compatibility_assignment_evidence do
    [
      evidence(501, "condition-a", "weighted_random", "intervention", ~U[2026-08-19 11:59:00Z],
        attribution_hash: "tie-z"
      ),
      evidence(501, "loses-tie", "weighted_random", "intervention", ~U[2026-08-19 11:59:00Z],
        attribution_hash: "tie-a"
      ),
      evidence(
        502,
        "condition-b",
        "weighted_random",
        "section_enrollment",
        ~U[2026-08-19 11:59:30Z]
      ),
      evidence(503, "condition-c", "thompson_sampling", "intervention", ~U[2026-08-19 11:59:45Z]),
      evidence(
        501,
        "wrong-project",
        "weighted_random",
        "intervention",
        ~U[2026-08-19 11:59:59Z],
        project_id: 9999
      ),
      evidence(501, "wrong-type", "weighted_random", "intervention", ~U[2026-08-19 11:59:58Z],
        attribution_type: "outcome"
      ),
      evidence(501, nil, "weighted_random", "intervention", ~U[2026-08-19 11:59:59Z]),
      evidence(
        501,
        "before-horizon",
        "weighted_random",
        "intervention",
        ~U[2026-07-31 23:59:59Z]
      ),
      evidence(501, "after-horizon", "weighted_random", "intervention", ~U[2026-08-20 00:00:01Z]),
      evidence(
        nil,
        "missing-enrollment",
        "weighted_random",
        "intervention",
        ~U[2026-08-19 11:59:59Z]
      ),
      evidence(
        501,
        "missing-project",
        "weighted_random",
        "intervention",
        ~U[2026-08-19 11:59:59Z],
        project_id: nil
      )
    ]
  end

  @doc "Returns section-wide evaluated activities for the compatibility join proof."
  def compatibility_activity_events do
    [
      activity_event(
        501,
        8001,
        "attempt-501-a",
        "event-1",
        ~U[2026-08-19 12:00:00Z],
        1.0,
        2.0,
        :in_branch
      ),
      activity_event(
        501,
        8001,
        "attempt-501-a",
        "event-2",
        ~U[2026-08-19 12:05:00Z],
        2.0,
        2.0,
        :in_branch
      ),
      activity_event(
        501,
        8002,
        "attempt-501-b",
        "event-3",
        ~U[2026-08-19 12:06:00Z],
        1.0,
        4.0,
        :out_of_branch
      ),
      activity_event(
        502,
        8003,
        "attempt-502-a",
        "event-4",
        ~U[2026-08-19 12:07:00Z],
        3.0,
        4.0,
        :out_of_branch
      ),
      activity_event(
        503,
        8004,
        "attempt-503-a",
        "event-5",
        ~U[2026-08-19 12:08:00Z],
        1.0,
        0.0,
        :in_branch
      ),
      activity_event(
        503,
        8005,
        "attempt-503-b",
        "event-6",
        ~U[2026-08-19 12:09:00Z],
        nil,
        2.0,
        :out_of_branch
      )
    ]
  end

  defp evidence(
         enrollment_id,
         condition,
         algorithm,
         assignment_scope,
         timestamp,
         opts \\ []
       ) do
    %{
      section_id: 2001,
      project_id: Keyword.get(opts, :project_id, 1001),
      enrollment_id: enrollment_id,
      condition: condition,
      algorithm: algorithm,
      assignment_scope: assignment_scope,
      attribution_type: Keyword.get(opts, :attribution_type, "assignment"),
      evidence_source: :exposure,
      timestamp: timestamp,
      event_version: Keyword.get(opts, :event_version, timestamp),
      attribution_hash: Keyword.get(opts, :attribution_hash, condition || "nil-condition")
    }
  end

  @doc "Returns edge rows that the compatibility query must exclude."
  def compatibility_excluded_activity_events do
    [
      activity_event(
        504,
        8006,
        "attempt-no-evidence",
        "excluded-1",
        ~U[2026-08-19 12:10:00Z],
        1.0,
        1.0,
        :out_of_branch
      ),
      activity_event(
        501,
        8007,
        "attempt-before-evidence",
        "excluded-2",
        ~U[2026-08-19 11:58:00Z],
        1.0,
        1.0,
        :in_branch
      ),
      activity_event(
        501,
        8008,
        "attempt-wrong-verb",
        "excluded-3",
        ~U[2026-08-19 12:11:00Z],
        1.0,
        1.0,
        :in_branch,
        "activity_attempt",
        "http://adlnet.gov/expapi/verbs/answered"
      ),
      activity_event(
        501,
        8009,
        "attempt-wrong-type",
        "excluded-4",
        ~U[2026-08-19 12:12:00Z],
        1.0,
        1.0,
        :in_branch,
        "page_attempt"
      )
    ]
  end

  defp activity_event(
         enrollment_id,
         activity_id,
         attempt_guid,
         event_hash,
         timestamp,
         score,
         out_of,
         branch_relationship,
         event_type \\ "activity_attempt",
         verb_id \\ "http://adlnet.gov/expapi/verbs/evaluated"
       ) do
    %{
      section_id: 2001,
      project_id: 1001,
      enrollment_id: enrollment_id,
      activity_id: activity_id,
      activity_attempt_guid: attempt_guid,
      event_hash: event_hash,
      timestamp: timestamp,
      score: score,
      out_of: out_of,
      branch_relationship: branch_relationship,
      event_type: event_type,
      verb_id: verb_id
    }
  end

  defp fixture(name, statement), do: %{name: name, statement: statement}

  defp attributed_part_attempt_statement do
    part_attempt = %{
      activity_revision: %{id: 8101, resource_id: 8001, objectives: []},
      activity_attempt: activity_attempt(),
      attempt_guid: "part-attempt-guid",
      attempt_number: 1,
      hints: [],
      response: "fixture response",
      score: 1.0,
      out_of: 2.0,
      feedback: "fixture feedback",
      date_evaluated: ~U[2026-08-19 12:00:00Z],
      part_id: "part-1",
      datashop_session_id: "session-1"
    }

    PartAttemptEvaluated.new(context(), part_attempt, resource_attempt())
    |> Attributions.attach_attributions([direct_outcome(), direct_reward()])
  end

  defp attributed_activity_attempt_statement do
    ActivityAttemptEvaluated.new(context(), activity_attempt(), resource_attempt())
    |> Attributions.attach_attributions([intervention_outcome()])
  end

  defp attributed_page_attempt_statement(attribution) do
    PageAttemptEvaluated.new(context(), evaluated_resource_attempt())
    |> Attributions.attach_attributions([attribution])
  end

  defp thompson_attempt_statement do
    PageAttemptEvaluated.new(context(), evaluated_resource_attempt())
    |> Attributions.attach_attributions([thompson_outcome(), thompson_reward()])
  end

  defp historical_attempt_statement do
    PageAttemptEvaluated.new(context(), evaluated_resource_attempt())
  end

  defp attributed_media_statement do
    media_statement()
    |> Attributions.attach_attributions([media_assignment()])
  end

  defp media_statement do
    Played.new(context(), %{
      attempt_guid: "page-attempt-guid",
      attempt_number: 1,
      resource_id: 7001,
      timestamp: "2026-08-19T12:04:00Z",
      video_url: "https://media.example.edu/video.mp4",
      video_title: "Example video",
      video_length: 60.0,
      video_play_time: 5.0,
      content_element_id: "video-in-selected-branch"
    })
  end

  defp context do
    %Context{
      user_id: 123,
      host_name: "https://torus.example.edu",
      section_id: 2001,
      project_id: 1001,
      publication_id: 3001
    }
  end

  defp resource_attempt do
    %{attempt_guid: "page-attempt-guid", attempt_number: 1, resource_id: 7001}
  end

  defp evaluated_resource_attempt do
    resource_attempt()
    |> Map.merge(%{
      score: 1.0,
      out_of: 2.0,
      date_evaluated: ~U[2026-08-19 12:00:00Z]
    })
  end

  defp activity_attempt do
    %ActivityAttempt{
      id: 801,
      attempt_guid: "activity-attempt-guid",
      attempt_number: 1,
      score: 1.0,
      out_of: 2.0,
      date_evaluated: ~U[2026-08-19 12:00:00Z],
      resource_id: 8001,
      revision_id: 8101
    }
  end

  defp intervention_outcome do
    [direct_outcome()]
    |> Attributions.attributions_for_activity_attempt()
    |> hd()
  end

  defp section_enrollment_outcome do
    outcome_attribution(section_enrollment_assignment())
    |> then(&Attributions.attributions_for_page_attempt([&1]))
    |> hd()
  end

  defp thompson_outcome do
    outcome_attribution(thompson_assignment())
    |> then(&Attributions.attributions_for_page_attempt([&1]))
    |> hd()
  end

  defp thompson_reward do
    reward_attribution(thompson_assignment())
    |> then(&Attributions.attributions_for_page_attempt([&1]))
    |> hd()
  end

  defp media_assignment do
    decision = %AssignmentDecision{
      status: :assigned,
      experiment_id: 101,
      condition_id: 303,
      condition_code: "condition-a",
      assignment_id: 404,
      reused?: true
    }

    request = %AssignConditionRequest{
      scope: scope(),
      alternatives_resource_id: 7101,
      alternatives_revision_id: 7102,
      available_condition_codes: ["condition-a", "condition-b"]
    }

    decision
    |> Attributions.assignment_attribution(request, assignment: weighted_assignment())
    |> then(&Attributions.attributions_for_media_event([&1]))
    |> hd()
  end

  defp direct_outcome, do: outcome_attribution(weighted_assignment())
  defp direct_reward, do: reward_attribution(weighted_assignment())

  defp outcome_attribution(assignment) do
    receipt = %OutcomeReceipt{
      key: "outcome:assignment-404:activity-attempt-801",
      assignment_id: assignment.id,
      recorded_at: ~U[2026-08-19 12:00:00Z],
      reused?: false
    }

    request = %RecordOutcomeRequest{
      key: receipt.key,
      scope: scope(),
      assignment_id: assignment.id,
      activity_attempt_id: 801,
      resource_attempt_id: 901,
      activity_resource_id: 8001,
      score: 1.0,
      out_of: 2.0
    }

    Attributions.outcome_attribution(receipt, request, assignment: assignment)
  end

  defp reward_attribution(assignment) do
    receipt = %RewardReceipt{
      key: "reward:activity_attempt:801:assignment:404",
      assignment_id: assignment.id,
      outcome_key: "outcome:assignment-404:activity-attempt-801",
      recorded_at: ~U[2026-08-19 12:00:01Z],
      reused?: false
    }

    request = %RecordRewardRequest{
      key: receipt.key,
      scope: scope(),
      assignment_id: assignment.id,
      outcome_key: receipt.outcome_key,
      reward_value: 1.0,
      reward_source: "activity_attempt:full_credit"
    }

    Attributions.reward_attribution(receipt, request, assignment: assignment)
  end

  defp weighted_assignment, do: assignment(:intervention, "weighted_random")
  defp thompson_assignment, do: assignment(:intervention, "thompson_sampling")
  defp section_enrollment_assignment, do: assignment(:section_enrollment, "weighted_random")

  defp assignment(assignment_scope, algorithm) do
    intervention_id = if assignment_scope == :intervention, do: 601

    %Assignment{
      id: 404,
      experiment_id: 101,
      intervention_id: intervention_id,
      condition_id: 303,
      section_id: 2001,
      enrollment_id: 501,
      user_id: 123,
      assignment_scope: assignment_scope,
      assigned_by_policy: algorithm,
      policy_version:
        if(algorithm == "thompson_sampling", do: "thompson_sampling:v2", else: algorithm),
      assignment_key: "v2:#{assignment_scope}:101:601:501",
      experiment: %ExperimentDefinition{
        id: 101,
        uuid: "11111111-2222-3333-4444-555555555555"
      },
      condition: %Condition{id: 303, condition_code: "condition-a"}
    }
  end

  defp scope do
    %Scope{
      institution_id: 1,
      project_id: 1001,
      publication_id: 3001,
      section_id: 2001,
      user_id: 123,
      enrollment_id: 501
    }
  end
end
