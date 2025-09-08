defmodule Oli.Scenarios.ActivityObjectivesTest do
  use Oli.DataCase

  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.DirectiveParser

  describe "activity objectives attachment" do
    test "can create standalone activity with objectives" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
          objectives:
            - "Learning Objective 1"
            - "Learning Objective 2"

      - create_activity:
          project: "test_proj"
          title: "Test Activity"
          type: "oli_multiple_choice"
          objectives:
            - "Learning Objective 1"
            - "Learning Objective 2"
          content: |
            stem_md: "What is 2 + 2?"
            choices:
              - id: a
                body_md: "3"
              - id: b
                body_md: "4"
                correct: true
              - id: c
                body_md: "5"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Verify the activity was created with objectives
      project = result.state.projects["test_proj"]
      activity_revision = result.state.activities[{"test_proj", "Test Activity"}]

      assert activity_revision != nil

      # Get objective resource IDs
      obj1 = project.objectives_by_title["Learning Objective 1"]
      obj2 = project.objectives_by_title["Learning Objective 2"]

      # Check that objectives are attached to the activity
      # Objectives are attached to parts, not directly to the activity
      # Get the first part's objectives (all parts should have the same objectives)
      part_objectives = activity_revision.objectives |> Map.values() |> List.first() || []
      assert obj1.resource_id in part_objectives
      assert obj2.resource_id in part_objectives
    end

    test "can create inline activity with objectives in edit_page" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Practice Page"
          objectives:
            - Understand concepts:
              - "Define terms"
              - "Apply knowledge"

      - edit_page:
          project: "test_proj"
          page: "Practice Page"
          content: |
            type: page
            title: "Practice Page"
            blocks:
              - type: activity
                virtual_id: "practice_q1"
                activity:
                  type: "oli_multiple_choice"
                  objectives:
                    - "Define terms"
                  stem_md: "What is the definition?"
                  choices:
                    - id: a
                      body_md: "Option A"
                      correct: true
                    - id: b
                      body_md: "Option B"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Verify the inline activity was created with objectives
      project = result.state.projects["test_proj"]
      activity_revision = result.state.activity_virtual_ids[{"test_proj", "practice_q1"}]

      assert activity_revision != nil

      # Get objective resource ID
      obj = project.objectives_by_title["Define terms"]

      # Check that objective is attached to the activity
      # Objectives are attached to parts, not directly to the activity
      part_objectives = activity_revision.objectives |> Map.values() |> List.first() || []
      assert obj.resource_id in part_objectives
    end

    test "activity creation fails with non-existent objective" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
          objectives:
            - "Learning Objective 1"

      - create_activity:
          project: "test_proj"
          title: "Test Activity"
          type: "oli_multiple_choice"
          objectives:
            - "Learning Objective 1"
            - "Non-existent Objective"
          content: |
            stem_md: "Question?"
            choices:
              - id: a
                body_md: "Answer"
                correct: true
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      # Should have an error about the non-existent objective
      assert length(result.errors) > 0
      {_directive, error_message} = hd(result.errors)
      assert String.contains?(error_message, "Non-existent Objective")
    end

    test "can create activity without objectives" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"

      - create_activity:
          project: "test_proj"
          title: "Test Activity"
          type: "oli_multiple_choice"
          content: |
            stem_md: "What is 2 + 2?"
            choices:
              - id: a
                body_md: "3"
              - id: b
                body_md: "4"
                correct: true
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Verify the activity was created without objectives
      activity_revision = result.state.activities[{"test_proj", "Test Activity"}]
      assert activity_revision != nil

      # Verify no objectives are attached to any parts
      all_objectives = activity_revision.objectives |> Map.values() |> List.flatten()
      assert all_objectives == []
    end

    test "objectives specified in directive override YAML content objectives" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
          objectives:
            - "Objective A"
            - "Objective B"

      - create_activity:
          project: "test_proj"
          title: "Test Activity"
          type: "oli_multiple_choice"
          objectives:
            - "Objective A"
          content: |
            stem_md: "Question?"
            objectives:
              - "Objective B"
            choices:
              - id: a
                body_md: "Answer"
                correct: true
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Verify the directive objectives override the YAML content objectives
      project = result.state.projects["test_proj"]
      activity_revision = result.state.activities[{"test_proj", "Test Activity"}]

      obj_a = project.objectives_by_title["Objective A"]
      obj_b = project.objectives_by_title["Objective B"]

      # Objectives are attached to parts
      part_objectives = activity_revision.objectives |> Map.values() |> List.first() || []

      # Should have Objective A (from directive), not Objective B (from YAML content)
      assert obj_a.resource_id in part_objectives
      assert obj_b.resource_id not in part_objectives
    end
  end
end
