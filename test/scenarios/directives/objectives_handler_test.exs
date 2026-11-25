defmodule Oli.Scenarios.Directives.ObjectivesHandlerTest do
  use Oli.DataCase

  alias Oli.Scenarios.DirectiveParser
  alias Oli.Scenarios.Engine

  test "objectives directive creates and removes objective hierarchy entries" do
    yaml = """
    - project:
        name: "objective_course"
        title: "Objective Course"
        root:
          children:
            - page: "Practice"

    - objectives:
        project: "objective_course"
        ops:
          - create:
              title: "Understand Systems"
          - create_sub:
              parent: "Understand Systems"
              title: "Predict Outputs"
          - create_sub:
              parent: "Understand Systems"
              title: "Temporary Skill"
          - remove_sub:
              parent: "Understand Systems"
              title: "Temporary Skill"
    """

    result =
      yaml
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute()

    assert result.errors == []

    built_project = Engine.get_project(result.state, "objective_course")
    objectives = built_project.objectives_by_title

    parent = objectives["Understand Systems"]
    child = objectives["Predict Outputs"]
    removed_child = objectives["Temporary Skill"]

    assert child.resource_id in parent.children
    refute removed_child.resource_id in parent.children
    assert removed_child.deleted

    events =
      audit_events(:learning_objectives_changed,
        project_id: built_project.project.id,
        actor: result.state.current_author,
        source: :scenario
      )

    assert Enum.any?(events, &(&1.resource_id == child.resource_id))

    assert Enum.any?(
             events,
             &(&1.resource_id == removed_child.resource_id and &1.changes["deleted"]["after"])
           )
  end

  test "objectives declared on a scenario project are recorded as created by its author" do
    yaml = """
    - project:
        name: "declared_objectives"
        title: "Declared Objectives"
        objectives:
          - "Objective A"
        root:
          children:
            - page: "Practice"
    """

    result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

    assert result.errors == []
    built_project = Engine.get_project(result.state, "declared_objectives")
    objective = built_project.objectives_by_title["Objective A"]

    event =
      assert_audited(:learning_objectives_changed,
        project_id: built_project.project.id,
        resource_id: objective.resource_id,
        source: :scenario
      )

    assert event.changes["title"]["after"] == "Objective A"
  end

  test "objectives directive reports missing parents" do
    yaml = """
    - project:
        name: "objective_course"
        title: "Objective Course"
        root:
          children:
            - page: "Practice"

    - objectives:
        project: "objective_course"
        ops:
          - create_sub:
              parent: "Missing Parent"
              title: "Predict Outputs"
    """

    result =
      yaml
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute()

    assert [{_, message}] = result.errors
    assert message =~ "Objective 'Missing Parent' not found"
  end

  test "objectives directive limits large objective operation blocks" do
    ops =
      1..26
      |> Enum.map(fn index ->
        """
              - create:
                  title: "Objective #{index}"
        """
      end)
      |> Enum.join("")

    yaml = """
    - project:
        name: "objective_course"
        title: "Objective Course"
        root:
          children:
            - page: "Practice"

    - objectives:
        project: "objective_course"
        ops:
    #{ops}
    """

    result =
      yaml
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute()

    assert [{_, message}] = result.errors
    assert message =~ "objectives supports at most 25 ops per directive"
  end
end
