defmodule Oli.Scenarios.TagsTest do
  use Oli.DataCase

  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.DirectiveParser

  describe "tags creation" do
    test "can create a project with tags" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
          tags:
            - "Beginner"
            - "Math"
            - "Algebra"

      - verify:
          to: "test_proj"
          structure:
            root:
              children:
                - page: "Page 1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      assert length(result.verifications) == 1
      assert hd(result.verifications).passed == true

      # Verify tags were created
      project = result.state.projects["test_proj"]
      assert project.tags_by_title != nil

      # Check tags exist
      assert Map.has_key?(project.tags_by_title, "Beginner")
      assert Map.has_key?(project.tags_by_title, "Math")
      assert Map.has_key?(project.tags_by_title, "Algebra")

      # Verify tags are revisions with resource_ids
      beginner_tag = project.tags_by_title["Beginner"]
      assert beginner_tag.resource_id != nil
      assert beginner_tag.title == "Beginner"
    end

    test "can create a project without tags" do
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
      assert project.tags_by_title == %{}
    end

    test "can create standalone activity with tags" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
          tags:
            - "Easy"
            - "Practice"

      - create_activity:
          project: "test_proj"
          title: "Test Activity"
          type: "oli_multiple_choice"
          tags:
            - "Easy"
            - "Practice"
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

      # Verify the activity was created with tags
      project = result.state.projects["test_proj"]
      activity_revision = result.state.activities[{"test_proj", "Test Activity"}]
      
      assert activity_revision != nil
      
      # Get tag resource IDs
      easy_tag = project.tags_by_title["Easy"]
      practice_tag = project.tags_by_title["Practice"]
      
      assert easy_tag != nil
      assert practice_tag != nil
      
      # Check that tags are attached to the activity
      assert easy_tag.resource_id in activity_revision.tags
      assert practice_tag.resource_id in activity_revision.tags
    end

    test "can create inline activity with tags in edit_page" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Practice Page"
          tags:
            - "Intermediate"
            - "Quiz"

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
                  tags:
                    - "Intermediate"
                    - "Quiz"
                  stem_md: "What is the capital of France?"
                  choices:
                    - id: a
                      body_md: "London"
                    - id: b
                      body_md: "Paris"
                      correct: true
                    - id: c
                      body_md: "Berlin"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Verify the inline activity has tags
      project = result.state.projects["test_proj"]
      activity_revision = result.state.activity_virtual_ids[{"test_proj", "practice_q1"}]
      
      assert activity_revision != nil
      
      intermediate_tag = project.tags_by_title["Intermediate"]
      quiz_tag = project.tags_by_title["Quiz"]
      
      assert intermediate_tag != nil
      assert quiz_tag != nil
      
      # Check tags are attached
      assert intermediate_tag.resource_id in activity_revision.tags
      assert quiz_tag.resource_id in activity_revision.tags
    end

    test "activity creation fails with non-existent tag" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
          tags:
            - "ValidTag"

      - create_activity:
          project: "test_proj"
          title: "Test Activity"
          type: "oli_multiple_choice"
          tags:
            - "ValidTag"
            - "NonExistentTag"
          content: |
            stem_md: "Test question"
            choices:
              - id: a
                body_md: "Answer"
                score: 1
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert length(result.errors) > 0
      assert Enum.any?(result.errors, fn 
        {_directive, message} when is_binary(message) ->
          String.contains?(message, "NonExistentTag") and String.contains?(message, "not found")
        _ ->
          false
      end)
    end

    test "tags specified in directive override YAML content tags" do
      yaml = """
      - project:
          name: "test_proj"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
          tags:
            - "Tag A"
            - "Tag B"

      - create_activity:
          project: "test_proj"
          title: "Test Activity"
          type: "oli_multiple_choice"
          tags:
            - "Tag A"
          content: |
            stem_md: "Test question"
            tags:
              - "Tag B"
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
      
      tag_a = project.tags_by_title["Tag A"]
      tag_b = project.tags_by_title["Tag B"]
      
      # Directive tags should override YAML tags
      assert tag_a.resource_id in activity_revision.tags
      assert tag_b.resource_id not in activity_revision.tags
    end
  end
end