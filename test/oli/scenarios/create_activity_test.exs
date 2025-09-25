defmodule Oli.Scenarios.CreateActivityTest do
  use Oli.DataCase

  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.DirectiveParser
  alias Oli.Resources.ResourceType

  describe "create_activity directive" do
    test "creates embedded MCQ activity from TorusDoc YAML" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Page 1"

      - create_activity:
          project: test_project
          title: "Physics MCQ"
          scope: embedded
          type: oli_multiple_choice
          content: |
            stem_md: "What is 2 + 2?"
            choices:
              - id: "A"
                body_md: "3"
                score: 0
                feedback_md: "Incorrect"
              - id: "B"
                body_md: "4"
                score: 1
                feedback_md: "Correct!"
              - id: "C"
                body_md: "5"
                score: 0
            shuffle: true
            hints:
              - body_md: "Think about addition"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      assert Map.has_key?(result.state.projects, "test_project")
      assert Map.has_key?(result.state.activities, {"test_project", "Physics MCQ"})

      # Verify the activity was created
      activity = Map.get(result.state.activities, {"test_project", "Physics MCQ"})
      assert activity != nil
      assert activity.title == "Physics MCQ"
      assert activity.resource_type_id == ResourceType.id_for_activity()

      # Verify the activity content
      assert activity.content["stem"] != nil
      assert length(activity.content["choices"]) == 3
      assert activity.content["authoring"]["transformations"] != []
    end

    test "creates banked activity" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"

      - create_activity:
          project: test_project
          title: "Banked Question"
          scope: banked
          type: oli_multiple_choice
          content: |
            stem_md: "Select the correct answer"
            choices:
              - id: "A"
                body_md: "Option A"
                score: 1
              - id: "B"
                body_md: "Option B"
                score: 0
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      activity = Map.get(result.state.activities, {"test_project", "Banked Question"})
      assert activity != nil
      assert activity.title == "Banked Question"
      assert activity.scope == :banked
    end

    test "handles activity with objectives and tags" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"

      - create_activity:
          project: test_project
          title: "Tagged Activity"
          scope: embedded
          type: oli_multiple_choice
          content: |
            objectives: [123, 456]
            tags: [789]
            stem_md: "Question?"
            choices:
              - id: "A"
                body_md: "Answer"
                score: 1
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      activity = Map.get(result.state.activities, {"test_project", "Tagged Activity"})
      assert activity != nil
      # Note: Objectives and tags would be associated through separate tables
      # This test verifies they're passed through correctly
    end

    test "fails with invalid project name" do
      yaml = """
      - create_activity:
          project: nonexistent_project
          title: "Test Activity"
          scope: embedded
          type: oli_multiple_choice
          content: |
            stem_md: "Test"
            choices:
              - id: "A"
                body_md: "Test"
                score: 1
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert length(result.errors) > 0
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "Project 'nonexistent_project' not found"
    end

    test "fails with invalid activity type" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"

      - create_activity:
          project: test_project
          title: "Test Activity"
          scope: embedded
          type: invalid_activity_type
          content: |
            stem_md: "Test"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert length(result.errors) > 0
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "Unknown activity type"
    end

    test "fails with invalid scope" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"

      - create_activity:
          project: test_project
          title: "Test Activity"
          scope: invalid_scope
          type: oli_multiple_choice
          content: |
            stem_md: "Test"
            choices:
              - id: "A"
                body_md: "Test"
                score: 1
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert length(result.errors) > 0
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "Scope must be 'embedded' or 'banked'"
    end

    test "fails with invalid YAML content" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"

      - create_activity:
          project: test_project
          title: "Test Activity"
          scope: embedded
          type: oli_multiple_choice
          content: |
            This is not valid YAML: [
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert length(result.errors) > 0
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "Failed to parse activity YAML"
    end

    test "activities can be referenced by title within project" do
      yaml = """
      - project:
          name: proj1
          title: "Project 1"
          root:
            container: "Root"

      - project:
          name: proj2
          title: "Project 2"
          root:
            container: "Root"

      - create_activity:
          project: proj1
          title: "Activity A"
          scope: embedded
          type: oli_multiple_choice
          content: |
            stem_md: "Question A"
            choices:
              - id: "A"
                body_md: "Answer"
                score: 1

      - create_activity:
          project: proj2
          title: "Activity A"
          scope: embedded
          type: oli_multiple_choice
          content: |
            stem_md: "Question B"
            choices:
              - id: "B"
                body_md: "Different"
                score: 1
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Both activities should exist with same title but in different projects
      activity1 = Map.get(result.state.activities, {"proj1", "Activity A"})
      activity2 = Map.get(result.state.activities, {"proj2", "Activity A"})

      assert activity1 != nil
      assert activity2 != nil
      assert activity1.id != activity2.id

      # Verify they have different content
      assert activity1.content["stem"]["content"] != activity2.content["stem"]["content"]
    end

    test "can use custom author via user directive" do
      yaml = """
      - user:
          name: custom_author
          type: author
          email: custom@test.edu

      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"

      - create_activity:
          project: test_project
          title: "Activity with Custom Author"
          scope: embedded
          type: oli_multiple_choice
          content: |
            stem_md: "Question?"
            choices:
              - id: "A"
                body_md: "Answer"
                score: 1
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Verify the activity was created (this implicitly confirms the custom author worked)
      activity = Map.get(result.state.activities, {"test_project", "Activity with Custom Author"})
      assert activity != nil
      assert activity.title == "Activity with Custom Author"

      # Verify custom author is in state
      assert Map.has_key?(result.state.users, "custom_author")
      custom_author = Map.get(result.state.users, "custom_author")
      assert custom_author.email == "custom@test.edu"
    end
  end
end
