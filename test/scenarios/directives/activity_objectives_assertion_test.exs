defmodule Oli.Scenarios.Directives.Assert.ActivityObjectivesAssertionTest do
  use Oli.DataCase

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
end
