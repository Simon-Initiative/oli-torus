defmodule Oli.Analytics.XAPI.Events.Experiment.ExperimentConditionAssignedTest do
  use ExUnit.Case, async: true

  alias Oli.Analytics.XAPI.Events.Experiment.ExperimentConditionAssigned
  alias Oli.Analytics.XAPI.SchemaValidator
  alias Oli.Experiments.{AssignmentDecision, Scope}
  alias Oli.Experiments.Schemas.{Assignment, ExperimentDefinition}

  test "builds a bounded assignment statement from persisted assignment state" do
    assigned_at = ~U[2026-08-20 15:04:05Z]

    assignment = %Assignment{
      id: 40,
      experiment_id: 10,
      condition_id: 30,
      intervention_id: 60,
      section_id: 300,
      enrollment_id: 500,
      user_id: 400,
      assigned_by_policy: "weighted_random",
      policy_version: "weighted_random:v1",
      assignment_scope: :intervention,
      assignment_key: "v2:intervention:10:60:500",
      assigned_at: assigned_at
    }

    experiment = %ExperimentDefinition{
      id: 10,
      uuid: "11111111-2222-3333-4444-555555555555"
    }

    decision = %AssignmentDecision{
      status: :assigned,
      experiment_id: 10,
      condition_id: 30,
      condition_code: "a",
      assignment_id: 40,
      reused?: false
    }

    scope = %Scope{project_id: 100, publication_id: 200, section_id: 300, enrollment_id: 500}

    statement = ExperimentConditionAssigned.new(assignment, experiment, decision, scope)
    extensions = get_in(statement, ["context", "extensions"])
    assert [attribution] = extensions["http://oli.cmu.edu/extensions/experiment_attributions"]

    assert statement["verb"] == %{
             "id" => "http://oli.cmu.edu/extensions/verbs/experiment_condition_assigned",
             "display" => %{"en-US" => "experiment condition assigned"}
           }

    assert statement["timestamp"] == "2026-08-20T15:04:05Z"
    assert get_in(statement, ["actor", "account", "name"]) == "400"
    assert attribution["role"] == "assignment"
    assert attribution["attribution_type"] == "assignment"
    assert attribution["assigned_at"] == statement["timestamp"]
    assert attribution["experiment_uuid"] == experiment.uuid
    assert attribution["assignment_scope"] == "intervention"
    assert attribution["intervention_id"] == 60
    assert attribution["section_id"] == 300
    assert attribution["project_id"] == 100
    assert attribution["enrollment_id"] == 500
    refute Jason.encode!(statement) =~ "user_id"

    path = Path.join(System.tmp_dir!(), "condition-assigned-#{System.unique_integer()}.jsonl")
    File.write!(path, Jason.encode!(statement))
    on_exit(fn -> File.rm(path) end)

    assert {:ok, %{error_count: 0, valid_lines: 1}} = SchemaValidator.validate_paths([path])
  end

  test "omits intervention identity for a section-enrollment assignment" do
    assignment = %Assignment{
      id: 41,
      experiment_id: 10,
      condition_id: 30,
      intervention_id: nil,
      section_id: 300,
      enrollment_id: 500,
      assigned_by_policy: "weighted_random",
      policy_version: "weighted_random:v1",
      assignment_scope: :section_enrollment,
      assignment_key: "v2:section_enrollment:10:300:500",
      assigned_at: ~U[2026-08-20 15:04:05Z]
    }

    experiment = %ExperimentDefinition{
      id: 10,
      uuid: "11111111-2222-3333-4444-555555555555"
    }

    decision = %AssignmentDecision{
      status: :assigned,
      experiment_id: 10,
      condition_id: 30,
      condition_code: "a",
      assignment_id: 41,
      reused?: false
    }

    statement =
      ExperimentConditionAssigned.new(
        assignment,
        experiment,
        decision,
        %Scope{project_id: 100, publication_id: 200, section_id: 300, enrollment_id: 500}
      )

    [attribution] =
      get_in(statement, [
        "context",
        "extensions",
        "http://oli.cmu.edu/extensions/experiment_attributions"
      ])

    assert attribution["assignment_scope"] == "section_enrollment"
    refute Map.has_key?(attribution, "intervention_id")
  end
end
