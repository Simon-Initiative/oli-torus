defmodule Oli.Scenarios.Directives.Assert.ActivityObjectivesAssertionTest do
  use Oli.DataCase

  alias Oli.Resources
  alias Oli.Scenarios.{DirectiveParser, Engine}
  alias Oli.Scenarios.DirectiveTypes.{AssertDirective, ExecutionState}
  alias Oli.Scenarios.Directives.Assert.ActivityObjectivesAssertion

  test "returns a failed verification when the activity revision cannot be resolved" do
    directive = %AssertDirective{
      activity_objectives: %{
        project: "objective_course",
        activity_virtual_id: "missing_activity",
        expected: ["Understand Systems"]
      }
    }

    state = %ExecutionState{
      projects: %{
        "objective_course" => %{
          project: %{slug: "objective_course"},
          objectives_by_title: %{}
        }
      },
      activity_virtual_ids: %{
        {"objective_course", "missing_activity"} => %{resource_id: -1}
      }
    }

    assert {:ok, ^state, verification} = ActivityObjectivesAssertion.assert(directive, state)
    refute verification.passed
    assert verification.message =~ "Activity revision '-1' not found"
    assert verification.expected == ["Understand Systems"]
    assert verification.actual == nil
  end

  test "returns a failed verification when attached objective ids cannot be resolved" do
    yaml = """
    - project:
        name: "objective_course"
        title: "Objective Course"
        root:
          children:
            - page: "Practice"

    - edit_page:
        project: "objective_course"
        page: "Practice"
        content: |
          title: "Practice"
          graded: false
          blocks:
            - type: activity
              virtual_id: "practice_activity"
              activity:
                type: oli_multiple_choice
                stem_md: "Question?"
                choices:
                  - id: "a"
                    body_md: "Answer"
                    score: 1
    """

    result =
      yaml
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute()

    assert result.errors == []

    activity_revision =
      result.state.activity_virtual_ids[{"objective_course", "practice_activity"}]

    assert {:ok, _revision} =
             Resources.update_revision(activity_revision, %{objectives: %{"attached" => [-1]}})

    directive = %AssertDirective{
      activity_objectives: %{
        project: "objective_course",
        activity_virtual_id: "practice_activity",
        expected: []
      }
    }

    assert {:ok, _state, verification} =
             ActivityObjectivesAssertion.assert(directive, result.state)

    refute verification.passed
    assert verification.message =~ "Unresolved objective resource ids: [-1]"
    assert verification.actual == nil
  end
end
