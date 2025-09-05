defmodule Oli.Scenarios.AnswerQuestionTest do
  use Oli.DataCase

  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.DirectiveParser

  describe "answer_question directive" do
    test "student answers multiple choice question correctly" do
      yaml = """
      # Create a project with a practice page containing a multiple choice question
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Quiz Page"

      # Edit the page to add a multiple choice question
      - edit_page:
          project: test_project
          page: "Quiz Page"
          content: |
            title: "Quiz Page"
            graded: false
            blocks:
              - type: prose
                body_md: "Answer the following question:"
              - type: activity
                virtual_id: "quiz_q1"
                activity:
                  type: oli_multiple_choice
                  stem_md: "What is 2 + 2?"
                  choices:
                    - id: "a"
                      body_md: "3"
                      score: 0
                    - id: "b"
                      body_md: "4"
                      score: 1
                    - id: "c"
                      body_md: "5"
                      score: 0

      # Create section (which publishes the project)
      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      # Create student
      - user:
          name: student1
          type: student
          email: "student1@example.com"

      # Student views the page
      - view_practice_page:
          student: student1
          section: test_section
          page: "Quiz Page"

      # Student answers correctly (choice "b")
      - answer_question:
          student: student1
          section: test_section
          page: "Quiz Page"
          activity_virtual_id: "quiz_q1"
          response: "b"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Check that the evaluation was stored
      key = {"student1", "test_section", "Quiz Page", "quiz_q1"}
      assert Map.has_key?(result.state.activity_evaluations, key)

      evaluation = Map.get(result.state.activity_evaluations, key)
      assert evaluation != nil

      # The evaluation should be a list of actions
      assert is_list(evaluation)
      assert length(evaluation) > 0

      # Check that we got a FeedbackAction
      [action | _] = evaluation
      assert action.type == "FeedbackAction"
      # For now, just verify it was evaluated
      assert action.out_of == 1.0
      assert action.score == 1.0
    end

    test "student answers multiple choice question incorrectly" do
      yaml = """
      # Create a project with a practice page
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Quiz Page"

      - edit_page:
          project: test_project
          page: "Quiz Page"
          content: |
            title: "Quiz Page"
            graded: false
            blocks:
              - type: activity
                virtual_id: "math_q1"
                activity:
                  type: oli_multiple_choice
                  stem_md: "What is 10 / 2?"
                  choices:
                    - id: "a"
                      body_md: "3"
                      score: 0
                    - id: "b"
                      body_md: "5"
                      score: 1
                    - id: "c"
                      body_md: "7"
                      score: 0

      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      - user:
          name: student1
          type: student
          email: "student1@example.com"

      - view_practice_page:
          student: student1
          section: test_section
          page: "Quiz Page"

      # Student answers incorrectly (choice "a" instead of "b")
      - answer_question:
          student: student1
          section: test_section
          page: "Quiz Page"
          activity_virtual_id: "math_q1"
          response: "a"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Check evaluation exists
      key = {"student1", "test_section", "Quiz Page", "math_q1"}
      assert Map.has_key?(result.state.activity_evaluations, key)
      
      evaluation = Map.get(result.state.activity_evaluations, key)
      assert evaluation != nil
      
      # The evaluation should be a list of actions
      assert is_list(evaluation)
      assert length(evaluation) > 0
      
      # Check that we got a FeedbackAction with incorrect score
      [action | _] = evaluation
      assert action.type == "FeedbackAction"
      assert action.score == 0  # Incorrect answer should score 0
      assert action.out_of == 1.0
    end

    test "student answers multiple questions on same page" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Multi Question Page"

      - edit_page:
          project: test_project
          page: "Multi Question Page"
          content: |
            title: "Multi Question Page"
            graded: false
            blocks:
              - type: activity
                virtual_id: "q1"
                activity:
                  type: oli_multiple_choice
                  stem_md: "Question 1: What is 1 + 1?"
                  choices:
                    - id: "a"
                      body_md: "1"
                      score: 0
                    - id: "b"
                      body_md: "2"
                      score: 1
              - type: activity
                virtual_id: "q2"
                activity:
                  type: oli_multiple_choice
                  stem_md: "Question 2: What is 3 + 3?"
                  choices:
                    - id: "a"
                      body_md: "5"
                      score: 0
                    - id: "b"
                      body_md: "6"
                      score: 1

      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      - user:
          name: student1
          type: student
          email: "student1@example.com"

      - view_practice_page:
          student: student1
          section: test_section
          page: "Multi Question Page"

      # Answer first question
      - answer_question:
          student: student1
          section: test_section
          page: "Multi Question Page"
          activity_virtual_id: "q1"
          response: "b"

      # Answer second question
      - answer_question:
          student: student1
          section: test_section
          page: "Multi Question Page"
          activity_virtual_id: "q2"
          response: "b"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Check both evaluations exist
      key1 = {"student1", "test_section", "Multi Question Page", "q1"}
      key2 = {"student1", "test_section", "Multi Question Page", "q2"}

      assert Map.has_key?(result.state.activity_evaluations, key1)
      assert Map.has_key?(result.state.activity_evaluations, key2)
      
      # Check first question evaluation (correct answer)
      evaluation1 = Map.get(result.state.activity_evaluations, key1)
      assert is_list(evaluation1)
      [action1 | _] = evaluation1
      assert action1.type == "FeedbackAction"
      assert action1.score == 1.0  # Correct answer should score 1
      assert action1.out_of == 1.0
      
      # Check second question evaluation (correct answer)
      evaluation2 = Map.get(result.state.activity_evaluations, key2)
      assert is_list(evaluation2)
      [action2 | _] = evaluation2
      assert action2.type == "FeedbackAction"
      assert action2.score == 1.0  # Correct answer should score 1
      assert action2.out_of == 1.0
    end

    test "error when student hasn't viewed page first" do
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
            title: "Page 1"
            blocks:
              - type: activity
                virtual_id: "q1"
                activity:
                  type: oli_multiple_choice
                  stem_md: "Test question"
                  choices:
                    - id: "a"
                      body_md: "Answer"
                      score: 1

      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      - user:
          name: student1
          type: student
          email: "student1@example.com"

      # Try to answer without viewing page first
      - answer_question:
          student: student1
          section: test_section
          page: "Page 1"
          activity_virtual_id: "q1"
          response: "a"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      # Should have an error
      assert length(result.errors) > 0
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "No attempt found" or error_msg =~ "must view page first"
    end

    test "error when activity virtual_id not found" do
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
            title: "Page 1"
            blocks:
              - type: activity
                virtual_id: "real_question"
                activity:
                  type: oli_multiple_choice
                  stem_md: "Test"
                  choices:
                    - id: "a"
                      body_md: "Answer"
                      score: 1

      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      - user:
          name: student1
          type: student
          email: "student1@example.com"

      - view_practice_page:
          student: student1
          section: test_section
          page: "Page 1"

      # Try to answer non-existent question
      - answer_question:
          student: student1
          section: test_section
          page: "Page 1"
          activity_virtual_id: "non_existent"
          response: "a"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      # Should have an error
      assert length(result.errors) > 0
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "not found"
    end

    test "student answers short answer question" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Short Answer Page"

      - edit_page:
          project: test_project
          page: "Short Answer Page"
          content: |
            title: "Short Answer Page"
            graded: false
            blocks:
              - type: activity
                virtual_id: "short_q1"
                activity:
                  type: oli_short_answer
                  stem_md: "What is your name?"
                  input_type: "text"

      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      - user:
          name: student1
          type: student
          email: "student1@example.com"

      - view_practice_page:
          student: student1
          section: test_section
          page: "Short Answer Page"

      # Answer short answer question
      - answer_question:
          student: student1
          section: test_section
          page: "Short Answer Page"
          activity_virtual_id: "short_q1"
          response: "My name is Alice"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Check evaluation exists
      key = {"student1", "test_section", "Short Answer Page", "short_q1"}
      assert Map.has_key?(result.state.activity_evaluations, key)
      
      evaluation = Map.get(result.state.activity_evaluations, key)
      assert evaluation != nil
      
      # The evaluation should be a list of actions
      assert is_list(evaluation)
      assert length(evaluation) > 0
      
      # Check that we got a FeedbackAction
      # Note: Short answer questions may have different scoring logic
      [action | _] = evaluation
      assert action.type == "FeedbackAction"
      # Short answer questions typically need manual grading or specific rules
      # For now, just verify it was evaluated
      assert action.out_of == 1.0
    end
  end
end
