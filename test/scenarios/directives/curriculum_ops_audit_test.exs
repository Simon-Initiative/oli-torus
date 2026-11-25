defmodule Oli.Scenarios.Directives.CurriculumOpsAuditTest do
  use Oli.DataCase

  alias Oli.Scenarios.DirectiveParser
  alias Oli.Scenarios.Engine

  test "scenario curriculum operations record their changes as the scenario author" do
    yaml = """
    - project:
        name: "curriculum_ops"
        title: "Curriculum Ops"
        root:
          children:
            - container: "Module A"
              children:
                - page: "Page 1"
                - page: "Page 2"
            - container: "Module B"
              children:
                - page: "Page 3"

    - manipulate:
        to: "curriculum_ops"
        ops:
          - move:
              from: "Page 2"
              to: "Module B"
          - reorder:
              from: "Page 2"
              before: "Page 3"
          - revise:
              target: "Page 1"
              set:
                max_attempts: 3
          - remove:
              from: "Page 1"
    """

    result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

    assert result.errors == []
    project = Engine.get_project(result.state, "curriculum_ops").project

    filters = [project_id: project.id, actor: result.state.current_author, source: :scenario]

    # The move records both modules, the reorder Module B, and the removal Module A
    assert length(audit_events(:curriculum_changed, filters)) == 4

    settings = audit_events(:authoring_settings_changed, filters)
    assert Enum.any?(settings, &(&1.changes["max_attempts"]["after"] == 3))
    # The builder sets the root container's title from the spec
    assert Enum.any?(settings, &(&1.entity_type == :container))
  end
end
