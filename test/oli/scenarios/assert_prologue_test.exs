defmodule Oli.Scenarios.AssertPrologueTest do
  use Oli.DataCase

  alias Oli.Scenarios.DirectiveTypes.ExecutionResult
  alias Oli.Scenarios.TestHelpers

  describe "assert.prologue" do
    test "asserts prologue state for a past-due assessment that still allows starting" do
      yaml = """
      - project:
          name: "source_project"
          title: "Source Project"
          root:
            children:
              - page: "Adaptive Page"

      - manipulate:
          to: "source_project"
          ops:
            - revise:
                target: "Adaptive Page"
                set:
                  graded: true

      - section:
          name: "test_section"
          from: "source_project"
          title: "Test Section"

      - user:
          name: "student_1"
          type: "student"

      - enroll:
          user: "student_1"
          section: "test_section"
          role: "student"

      - manipulate:
          to: "test_section"
          ops:
            - revise:
                target: "Adaptive Page"
                set:
                  start_date: "2024-12-22T21:00:00Z"
                  end_date: "2024-12-23T21:00:00Z"
                  max_attempts: 7
                  time_limit: 0
                  late_policy: "@atom(allow_late_start_and_late_submit)"

      - assert:
          prologue:
            section: "test_section"
            student: "student_1"
            page: "Adaptive Page"
            allow_attempt: true
            show_blocking_gates: false
            attempts_taken: 0
            max_attempts: 7
            attempts_summary: "Attempts 0/7"
            next_attempt_ordinal: "1st"
            attempt_message: "You have 7 attempts remaining out of 7 total attempts."
            terms:
              page_due_terms: "This assignment was available on Sun Dec 22, 2024 at 9:00pm. and was due on Mon Dec 23, 2024 by 9:00pm."
              page_scoring_terms: "For this assignment, your score will be determined by your best attempt."
              page_submit_term: "If you submit after the due date, it will be marked late."
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end
  end
end
