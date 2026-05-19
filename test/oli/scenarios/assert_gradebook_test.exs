defmodule Oli.Scenarios.AssertGradebookTest do
  use Oli.DataCase

  alias Oli.Scenarios.DirectiveTypes.ExecutionResult
  alias Oli.Scenarios.TestHelpers

  describe "assert.gradebook" do
    test "asserts instructor-visible gradebook state from the shared grading boundary" do
      yaml = """
      - project:
          name: "source_project"
          title: "Source Project"
          root:
            children:
              - page: "Quiz Page"

      - edit_page:
          project: "source_project"
          page: "Quiz Page"
          content: |
            title: "Quiz Page"
            graded: true
            blocks:
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

      - section:
          name: "test_section"
          from: "source_project"
          title: "Test Section"

      - user:
          name: "instructor_1"
          type: "instructor"

      - user:
          name: "student_1"
          type: "student"

      - manipulate:
          to: "test_section"
          ops:
            - revise:
                target: "Quiz Page"
                set:
                  start_date: "2024-12-22T21:00:00Z"
                  end_date: "2024-12-23T21:00:00Z"
                  max_attempts: 7
                  time_limit: 0
                  late_policy: "@atom(allow_late_start_and_late_submit)"

      - visit_page:
          student: "student_1"
          section: "test_section"
          page: "Quiz Page"

      - answer_question:
          student: "student_1"
          section: "test_section"
          page: "Quiz Page"
          activity_virtual_id: "quiz_q1"
          response: "b"

      - finalize_attempt:
          student: "student_1"
          section: "test_section"
          page: "Quiz Page"

      - assert:
          gradebook:
            instructor: "instructor_1"
            section: "test_section"
            student: "student_1"
            page: "Quiz Page"
            score: 1.0
            out_of: 1.0
            was_late: true
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end
  end
end
