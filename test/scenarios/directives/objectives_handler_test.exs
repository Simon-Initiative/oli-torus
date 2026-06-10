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
