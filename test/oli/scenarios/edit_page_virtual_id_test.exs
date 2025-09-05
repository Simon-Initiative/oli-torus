defmodule Oli.Scenarios.EditPageVirtualIdTest do
  use Oli.DataCase

  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.DirectiveParser

  describe "edit_page with virtual_id for inline activities" do
    test "creates inline activity with virtual_id on first edit" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Page 1"

      - edit_page:
          project: test_project
          page: "Page 1"
          content: |
            title: "Page with Activity"
            blocks:
              - type: prose
                body_md: "Introduction"
              - type: activity
                virtual_id: "quiz_1"
                activity:
                  type: oli_multiple_choice
                  stem_md: "What is 2+2?"
                  choices:
                    - id: "a"
                      body_md: "3"
                      score: 0
                    - id: "b"
                      body_md: "4"
                      score: 1
              - type: prose
                body_md: "Conclusion"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Verify the activity was created and stored by virtual_id
      assert Map.has_key?(result.state.activity_virtual_ids, {"test_project", "quiz_1"})
      
      # Get the project and page
      project = Map.get(result.state.projects, "test_project")
      page_revision = Map.get(project.rev_by_title, "Page with Activity")
      
      assert page_revision != nil
      assert page_revision.title == "Page with Activity"
      
      # The content should have activity-reference blocks
      model = page_revision.content["model"]
      assert length(model) == 3
      
      [_prose1, activity_ref, _prose2] = model
      assert activity_ref["type"] == "activity-reference"
      assert activity_ref["activitySlug"] != nil
    end

    test "reuses existing activity when editing page again with same virtual_id" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Page 1"

      # First edit - creates activity
      - edit_page:
          project: test_project
          page: "Page 1"
          content: |
            title: "Version 1"
            blocks:
              - type: activity
                virtual_id: "reusable_quiz"
                activity:
                  type: oli_multiple_choice
                  stem_md: "Original question?"
                  choices:
                    - id: "a"
                      body_md: "Answer A"
                      score: 1

      # Second edit - reuses the same activity
      - edit_page:
          project: test_project
          page: "Page 1"
          content: |
            title: "Version 2"
            blocks:
              - type: prose
                body_md: "New introduction"
              - type: activity
                virtual_id: "reusable_quiz"
                activity:
                  type: oli_multiple_choice
                  stem_md: "This should be ignored"
                  choices:
                    - id: "x"
                      body_md: "Different"
                      score: 0
              - type: prose
                body_md: "New conclusion"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Get the activity from state
      activity_revision = Map.get(result.state.activity_virtual_ids, {"test_project", "reusable_quiz"})
      assert activity_revision != nil
      
      # Get the project and page after second edit
      project = Map.get(result.state.projects, "test_project")
      page_revision = Map.get(project.rev_by_title, "Version 2")
      
      assert page_revision != nil
      assert page_revision.title == "Version 2"
      
      # The content should reference the same activity
      model = page_revision.content["model"]
      assert length(model) == 3
      
      [_prose1, activity_ref, _prose2] = model
      assert activity_ref["type"] == "activity-reference"
      assert activity_ref["activitySlug"] == activity_revision.resource_id
    end

    test "supports activity_reference with virtual_id" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Page 1"
              - page: "Page 2"

      # Create activity in first page
      - edit_page:
          project: test_project
          page: "Page 1"
          content: |
            title: "Page 1 with Activity"
            blocks:
              - type: activity
                virtual_id: "shared_activity"
                activity:
                  type: oli_short_answer
                  stem_md: "Explain your answer"
                  input_type: "text"

      # Reference the activity in second page
      - edit_page:
          project: test_project
          page: "Page 2"
          content: |
            title: "Page 2 References Activity"
            blocks:
              - type: prose
                body_md: "Please complete the following activity:"
              - type: activity_reference
                virtual_id: "shared_activity"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Get the activity from state
      activity_revision = Map.get(result.state.activity_virtual_ids, {"test_project", "shared_activity"})
      assert activity_revision != nil
      
      # Get the second page
      project = Map.get(result.state.projects, "test_project")
      page2_revision = Map.get(project.rev_by_title, "Page 2 References Activity")
      
      assert page2_revision != nil
      
      # The content should reference the activity created in page 1
      model = page2_revision.content["model"]
      assert length(model) == 2
      
      [_prose, activity_ref] = model
      assert activity_ref["type"] == "activity-reference"
      assert activity_ref["activitySlug"] == activity_revision.resource_id
    end

    test "handles activities in nested groups" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Complex Page"

      - edit_page:
          project: test_project
          page: "Complex Page"
          content: |
            title: "Page with Nested Activities"
            blocks:
              - type: group
                purpose: "quiz"
                blocks:
                  - type: prose
                    body_md: "Group introduction"
                  - type: activity
                    virtual_id: "group_activity_1"
                    activity:
                      type: oli_multiple_choice
                      stem_md: "Question in group?"
                      choices:
                        - id: "a"
                          body_md: "Yes"
                          score: 1
                  - type: activity_reference
                    virtual_id: "group_activity_1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Verify the activity was created
      activity_revision = Map.get(result.state.activity_virtual_ids, {"test_project", "group_activity_1"})
      assert activity_revision != nil
      
      # Get the page
      project = Map.get(result.state.projects, "test_project")
      page_revision = Map.get(project.rev_by_title, "Page with Nested Activities")
      
      assert page_revision != nil
      
      # Check the group structure
      model = page_revision.content["model"]
      assert length(model) == 1
      
      [group] = model
      assert group["type"] == "group"
      assert group["purpose"] == "quiz"
      
      # Check activities within the group
      group_children = group["children"]
      assert length(group_children) == 3
      
      [_prose, activity1, activity2] = group_children
      assert activity1["type"] == "activity-reference"
      assert activity2["type"] == "activity-reference"
      # Both should reference the same activity
      assert activity1["activitySlug"] == activity_revision.resource_id
      assert activity2["activitySlug"] == activity_revision.resource_id
    end

    test "handles activities in surveys" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Survey Page"

      - edit_page:
          project: test_project
          page: "Survey Page"
          content: |
            title: "Page with Survey"
            blocks:
              - type: survey
                blocks:
                  - type: prose
                    body_md: "Please answer:"
                  - type: activity
                    virtual_id: "survey_q1"
                    activity:
                      type: oli_short_answer
                      stem_md: "What did you learn?"
                      input_type: "text"
                  - type: activity
                    virtual_id: "survey_q2"
                    activity:
                      type: oli_multiple_choice
                      stem_md: "Rate this course"
                      choices:
                        - id: "1"
                          body_md: "Excellent"
                          score: 1
                        - id: "2"
                          body_md: "Good"
                          score: 1
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Verify both activities were created
      assert Map.has_key?(result.state.activity_virtual_ids, {"test_project", "survey_q1"})
      assert Map.has_key?(result.state.activity_virtual_ids, {"test_project", "survey_q2"})
      
      # Get the page
      project = Map.get(result.state.projects, "test_project")
      page_revision = Map.get(project.rev_by_title, "Page with Survey")
      
      assert page_revision != nil
      
      # Check the survey structure
      model = page_revision.content["model"]
      assert length(model) == 1
      
      [survey] = model
      assert survey["type"] == "survey"
      
      # Check activities within the survey
      survey_children = survey["children"]
      assert length(survey_children) == 3
      
      [_prose, activity1, activity2] = survey_children
      assert activity1["type"] == "activity-reference"
      assert activity2["type"] == "activity-reference"
    end

    test "errors when referencing non-existent virtual_id" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Error Page"

      - edit_page:
          project: test_project
          page: "Error Page"
          content: |
            title: "Page with Bad Reference"
            blocks:
              - type: activity_reference
                virtual_id: "non_existent_activity"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      # This should produce an error
      assert length(result.errors) > 0
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "non_existent_activity"
    end

    test "can use both create_activity and inline activities with virtual_ids" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Mixed Page"

      # Create an activity explicitly
      - create_activity:
          project: test_project
          title: "Explicit Activity"
          virtual_id: "explicit_q1"
          type: oli_multiple_choice
          content: |
            stem_md: "Explicitly created question"
            mcq_attributes:
              shuffle: true
              choices:
                - id: "a"
                  body_md: "Option 1"
                  score: 1

      # Edit page with both inline and reference
      - edit_page:
          project: test_project
          page: "Mixed Page"
          content: |
            title: "Mixed Activities"
            blocks:
              - type: activity_reference
                virtual_id: "explicit_q1"
              - type: activity
                virtual_id: "inline_q1"
                activity:
                  type: oli_short_answer
                  stem_md: "Inline question"
                  input_type: "text"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Both activities should be in state
      assert Map.has_key?(result.state.activity_virtual_ids, {"test_project", "explicit_q1"})
      assert Map.has_key?(result.state.activity_virtual_ids, {"test_project", "inline_q1"})
      
      # Get the page
      project = Map.get(result.state.projects, "test_project")
      page_revision = Map.get(project.rev_by_title, "Mixed Activities")
      
      assert page_revision != nil
      
      # Both should be activity references
      model = page_revision.content["model"]
      assert length(model) == 2
      
      [activity1, activity2] = model
      assert activity1["type"] == "activity-reference"
      assert activity2["type"] == "activity-reference"
    end
  end
end