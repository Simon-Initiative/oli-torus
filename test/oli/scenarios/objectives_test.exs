defmodule Oli.Scenarios.ObjectivesTest do
  use Oli.DataCase

  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.DirectiveParser
  alias Oli.Publishing.AuthoringResolver

  describe "objectives creation" do
    test "can create a project with objectives" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
          objectives:
            - Learning Objective 1:
              - "Sub-objective 1.1"
              - "Sub-objective 1.2"
            - Learning Objective 2:
              - "Sub-objective 2.1"

      - assert:
          structure:
            to: "test_proj"
            root:
              children:
                - page: "Page 1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      assert length(result.verifications) == 1
      assert hd(result.verifications).passed == true

      # Verify objectives were created
      project = result.state.projects["test_proj"]
      assert project.objectives_by_title != nil

      # Check parent objectives exist
      assert Map.has_key?(project.objectives_by_title, "Learning Objective 1")
      assert Map.has_key?(project.objectives_by_title, "Learning Objective 2")

      # Check sub-objectives exist
      assert Map.has_key?(project.objectives_by_title, "Sub-objective 1.1")
      assert Map.has_key?(project.objectives_by_title, "Sub-objective 1.2")
      assert Map.has_key?(project.objectives_by_title, "Sub-objective 2.1")

      # Verify parent-child relationships
      lo1 = project.objectives_by_title["Learning Objective 1"]
      sub1_1 = project.objectives_by_title["Sub-objective 1.1"]
      sub1_2 = project.objectives_by_title["Sub-objective 1.2"]

      # Get the latest revision to see the children
      lo1_current = AuthoringResolver.from_resource_id(project.project.slug, lo1.resource_id)
      assert sub1_1.resource_id in lo1_current.children
      assert sub1_2.resource_id in lo1_current.children
    end

    test "can create a project with flat objectives list" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
          objectives:
            - "Objective 1"
            - "Objective 2"
            - "Objective 3"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      project = result.state.projects["test_proj"]
      assert Map.has_key?(project.objectives_by_title, "Objective 1")
      assert Map.has_key?(project.objectives_by_title, "Objective 2")
      assert Map.has_key?(project.objectives_by_title, "Objective 3")

      # Verify these are parent objectives with no children
      obj1 = project.objectives_by_title["Objective 1"]
      obj1_current = AuthoringResolver.from_resource_id(project.project.slug, obj1.resource_id)
      assert obj1_current.children == []
    end

    test "can create a project without objectives" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      project = result.state.projects["test_proj"]
      assert project.objectives_by_title == %{}
    end
  end
end
