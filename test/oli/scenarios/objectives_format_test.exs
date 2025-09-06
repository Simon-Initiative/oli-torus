defmodule Oli.Scenarios.ObjectivesFormatTest do
  use Oli.DataCase

  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.DirectiveParser
  alias Oli.Publishing.AuthoringResolver

  describe "objectives format variations" do
    test "supports simple format with title as key" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
          objectives:
            - Mechanics
            - Kinematics
            - This is a very long objective to test wrapping in the UI:
              - Short Answer
              - Ordering
            - Extensions:
              - Worked Examples
              - Practice Problems
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      project = result.state.projects["test_proj"]
      assert project.objectives_by_title != nil

      # Check parent objectives exist
      assert Map.has_key?(project.objectives_by_title, "Mechanics")
      assert Map.has_key?(project.objectives_by_title, "Kinematics")
      assert Map.has_key?(project.objectives_by_title, "This is a very long objective to test wrapping in the UI")
      assert Map.has_key?(project.objectives_by_title, "Extensions")

      # Check sub-objectives exist
      assert Map.has_key?(project.objectives_by_title, "Short Answer")
      assert Map.has_key?(project.objectives_by_title, "Ordering")
      assert Map.has_key?(project.objectives_by_title, "Worked Examples")
      assert Map.has_key?(project.objectives_by_title, "Practice Problems")

      # Verify parent-child relationships
      long_obj = project.objectives_by_title["This is a very long objective to test wrapping in the UI"]
      short_answer = project.objectives_by_title["Short Answer"]
      ordering = project.objectives_by_title["Ordering"]

      # Get the latest revision to see the children
      long_obj_current = AuthoringResolver.from_resource_id(project.project.slug, long_obj.resource_id)
      assert short_answer.resource_id in long_obj_current.children
      assert ordering.resource_id in long_obj_current.children

      extensions = project.objectives_by_title["Extensions"]
      worked = project.objectives_by_title["Worked Examples"]
      practice = project.objectives_by_title["Practice Problems"]

      extensions_current = AuthoringResolver.from_resource_id(project.project.slug, extensions.resource_id)
      assert worked.resource_id in extensions_current.children
      assert practice.resource_id in extensions_current.children

      # Verify simple objectives have no children
      mechanics = project.objectives_by_title["Mechanics"]
      mechanics_current = AuthoringResolver.from_resource_id(project.project.slug, mechanics.resource_id)
      assert mechanics_current.children == []
    end

    test "rejects old format with title and children keys" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
          objectives:
            - Simple Objective 1
            - title: "Old Format Parent"
              children:
                - "Old Format Child 1"
                - "Old Format Child 2"
      """

      assert_raise RuntimeError, ~r/Invalid objective format/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "activities can reference objectives created with simple format" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
          objectives:
            - Basic Concepts:
              - "Variables"
              - "Functions"
            - Advanced Topics

      - create_activity:
          project: "test_proj"
          title: "Test Activity"
          type: "oli_multiple_choice"
          objectives:
            - "Variables"
            - "Advanced Topics"
          content: |
            stem_md: "Test question"
            choices:
              - id: a
                body_md: "Answer"
                score: 1
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      project = result.state.projects["test_proj"]
      activity_revision = result.state.activities[{"test_proj", "Test Activity"}]
      
      variables_obj = project.objectives_by_title["Variables"]
      advanced_obj = project.objectives_by_title["Advanced Topics"]
      
      # Check that objectives are attached to the activity parts
      part_objectives = activity_revision.objectives |> Map.values() |> List.first() || []
      assert variables_obj.resource_id in part_objectives
      assert advanced_obj.resource_id in part_objectives
    end
  end
end