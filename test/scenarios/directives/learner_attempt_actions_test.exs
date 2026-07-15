defmodule Oli.Scenarios.Directives.LearnerAttemptActionsTest do
  use Oli.DataCase

  import Ecto.Query

  alias Oli.Delivery.Attempts.Core.ActivityAttempt
  alias Oli.Scenarios

  alias Oli.Scenarios.DirectiveTypes.{
    ExecutionState,
    RequestHintDirective,
    ResetActivityDirective
  }

  alias Oli.Scenarios.Directives.{
    ActivityAttemptSupport,
    RequestHintHandler,
    ResetActivityHandler
  }

  alias Oli.Scenarios.RuntimeOpts

  @scenario_path Path.join(__DIR__, "learner_attempt_actions.scenario.yaml")

  test "requests a hint and answers a reset activity attempt" do
    assert :ok = Scenarios.validate_file(@scenario_path)

    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())

    assert result.errors == []
    assert Enum.all?(result.verifications, & &1.passed)

    {_status, attempt_state} =
      result.state.page_attempts[
        {"student", "learner_attempt_actions_section", "Hint and Retry Practice"}
      ]

    activity_revision =
      result.state.activity_virtual_ids[
        {"learner_attempt_actions", "hint_and_retry_question"}
      ]

    attempts =
      from(attempt in ActivityAttempt,
        where:
          attempt.resource_attempt_id == ^attempt_state.resource_attempt.id and
            attempt.resource_id == ^activity_revision.resource_id,
        order_by: attempt.attempt_number,
        preload: :part_attempts
      )
      |> Oli.Repo.all()

    assert [first_attempt, second_attempt] = attempts
    assert first_attempt.score == 0.0
    assert second_attempt.score == 1.0
    assert first_attempt.attempt_number == 1
    assert second_attempt.attempt_number == 2

    assert [first_part_attempt] = first_attempt.part_attempts
    assert [second_part_attempt] = second_attempt.part_attempts
    assert first_part_attempt.hints == ["try_again_hint"]
    assert second_part_attempt.hints == ["try_again_hint"]
  end

  test "request_hint requires a visited page" do
    directive = %RequestHintDirective{
      student: "student",
      section: "section",
      page: "Practice",
      activity_virtual_id: "question"
    }

    assert {:error, message} = RequestHintHandler.handle(directive, %ExecutionState{})

    assert message ==
             "Failed to request hint: No attempt found - student must view page first"
  end

  test "reset_activity requires a known student" do
    directive = %ResetActivityDirective{
      student: "student",
      section: "section",
      page: "Practice",
      activity_virtual_id: "question"
    }

    assert {:error, message} = ResetActivityHandler.handle(directive, %ExecutionState{})
    assert message == "Failed to reset activity: User 'student' not found"
  end

  test "activity revisions are scoped to the section's project" do
    first_revision = %{resource_id: 1}
    second_revision = %{resource_id: 2}

    state = %ExecutionState{
      projects: %{
        "first_project" => %{project: %{id: 10}},
        "second_project" => %{project: %{id: 20}}
      },
      sections: %{
        "second_section" => %{base_project_id: 20, slug: "second-section"}
      },
      activity_virtual_ids: %{
        {"first_project", "shared_question"} => first_revision,
        {"second_project", "shared_question"} => second_revision
      }
    }

    assert {:ok, ^second_revision} =
             ActivityAttemptSupport.get_activity_revision(
               state,
               "second_section",
               "shared_question"
             )
  end

  test "activity attempts use resource identity instead of activity type" do
    first_attempt = activity_attempt("first-attempt", 1)
    second_attempt = activity_attempt("second-attempt", 2)

    attempt_state = %{
      attempt_hierarchy: %{
        first: {first_attempt, %{}},
        second: {second_attempt, %{}}
      }
    }

    assert {:ok, %{attempt_guid: "second-attempt"}} =
             ActivityAttemptSupport.find_activity_attempt(attempt_state, %{
               resource_id: 2,
               content: %{"activityType" => "oli_multiple_choice"}
             })

    assert {:error, message} =
             ActivityAttemptSupport.find_activity_attempt(attempt_state, %{
               resource_id: 3,
               content: %{"activityType" => "oli_multiple_choice"}
             })

    assert message == "Could not find activity attempt for resource_id 3"
  end

  defp activity_attempt(attempt_guid, resource_id) do
    %{
      attempt_guid: attempt_guid,
      part_attempts: [],
      revision: %{
        resource_id: resource_id,
        content: %{"activityType" => "oli_multiple_choice"}
      }
    }
  end
end
