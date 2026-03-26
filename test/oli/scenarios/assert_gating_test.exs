defmodule Oli.Scenarios.AssertGatingTest do
  use Oli.DataCase

  alias Oli.Scenarios.DirectiveTypes.ExecutionResult
  alias Oli.Scenarios.TestHelpers

  describe "assert.gating" do
    test "verifies schedule gate configuration and access across scenario time" do
      yaml = """
      - project:
          name: "schedule_project"
          title: "Schedule Project"
          root:
            children:
              - page: "Warmup Page"
              - page: "Locked Page"

      - section:
          name: "schedule_section"
          title: "Schedule Section"
          from: "schedule_project"

      - user:
          name: "alice"
          type: "student"

      - enroll:
          user: "alice"
          section: "schedule_section"
          role: "student"

      - time:
          at: "2026-01-10T12:00:00Z"

      - gate:
          name: "schedule_gate"
          section: "schedule_section"
          target: "Locked Page"
          type: "schedule"
          start: "2026-01-11T12:00:00Z"
          end: "2026-01-12T12:00:00Z"

      - assert:
          gating:
            gate: "schedule_gate"
            type: "schedule"
            target: "Locked Page"
            start: "2026-01-11T12:00:00Z"
            end: "2026-01-12T12:00:00Z"

      - assert:
          gating:
            section: "schedule_section"
            student: "alice"
            resource: "Locked Page"
            accessible: false
            blocking_types: ["schedule"]
            blocking_count: 1

      - time:
          at: "2026-01-11T18:00:00Z"

      - assert:
          gating:
            section: "schedule_section"
            student: "alice"
            resource: "Locked Page"
            accessible: true
            blocking_count: 0

      - time:
          at: "2026-01-12T18:00:00Z"

      - assert:
          gating:
            section: "schedule_section"
            student: "alice"
            resource: "Locked Page"
            accessible: false
            blocking_types: ["schedule"]
            blocking_count: 1
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: verifications} = result
      assert length(verifications) == 4
      assert Enum.all?(verifications, & &1.passed)
      assert Enum.at(verifications, 0).message =~ "Gate assertion passed"
      assert Enum.at(verifications, 1).message =~ "Access assertion passed"
    end

    test "verifies started gates and always-open exceptions" do
      yaml = """
      - project:
          name: "exception_project"
          title: "Exception Project"
          root:
            children:
              - page: "Warmup Page"
              - page: "Locked Page"

      - section:
          name: "exception_section"
          title: "Exception Section"
          from: "exception_project"

      - user:
          name: "alice"
          type: "student"

      - user:
          name: "bob"
          type: "student"

      - enroll:
          user: "alice"
          section: "exception_section"
          role: "student"

      - enroll:
          user: "bob"
          section: "exception_section"
          role: "student"

      - gate:
          name: "base_gate"
          section: "exception_section"
          target: "Locked Page"
          type: "started"
          source: "Warmup Page"

      - gate:
          name: "alice_exception"
          section: "exception_section"
          parent: "base_gate"
          student: "alice"
          type: "always_open"

      - assert:
          gating:
            section: "exception_section"
            type: "started"
            target: "Locked Page"
            source: "Warmup Page"

      - assert:
          gating:
            gate: "alice_exception"
            type: "always_open"
            student: "alice"

      - assert:
          gating:
            section: "exception_section"
            student: "alice"
            resource: "Locked Page"
            accessible: true
            blocking_count: 0

      - assert:
          gating:
            section: "exception_section"
            student: "bob"
            resource: "Locked Page"
            accessible: false
            blocking_types: ["started"]
            blocking_count: 1
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: verifications} = result
      assert length(verifications) == 4
      assert Enum.all?(verifications, & &1.passed)
    end

    test "verifies finished gate minimum percentage and access after completion" do
      yaml = """
      - project:
          name: "finished_project"
          title: "Finished Project"
          root:
            children:
              - page: "Source Quiz"
              - page: "Locked Page"

      - edit_page:
          project: "finished_project"
          page: "Source Quiz"
          content: |
            title: "Source Quiz"
            graded: true
            blocks:
              - type: activity
                virtual_id: "source_q1"
                activity:
                  type: oli_multiple_choice
                  stem_md: "Which choice is correct?"
                  choices:
                    - id: "a"
                      body_md: "Correct"
                      score: 1
                    - id: "b"
                      body_md: "Incorrect"
                      score: 0

      - section:
          name: "finished_section"
          title: "Finished Section"
          from: "finished_project"

      - user:
          name: "alice"
          type: "student"

      - enroll:
          user: "alice"
          section: "finished_section"
          role: "student"

      - gate:
          name: "finished_gate"
          section: "finished_section"
          target: "Locked Page"
          type: "finished"
          source: "Source Quiz"
          minimum_percentage: 0.8

      - assert:
          gating:
            gate: "finished_gate"
            type: "finished"
            target: "Locked Page"
            source: "Source Quiz"
            minimum_percentage: 0.8

      - assert:
          gating:
            section: "finished_section"
            student: "alice"
            resource: "Locked Page"
            accessible: false
            blocking_types: ["finished"]
            blocking_count: 1

      - visit_page:
          student: "alice"
          section: "finished_section"
          page: "Source Quiz"

      - complete_scored_page:
          student: "alice"
          section: "finished_section"
          page: "Source Quiz"
          score: 4
          out_of: 5

      - assert:
          gating:
            section: "finished_section"
            student: "alice"
            resource: "Locked Page"
            accessible: true
            blocking_count: 0
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: verifications} = result
      assert length(verifications) == 3
      assert Enum.all?(verifications, & &1.passed)
    end

    test "reports explicit verification failures for mismatched accessibility expectations" do
      yaml = """
      - project:
          name: "failure_project"
          title: "Failure Project"
          root:
            children:
              - page: "Warmup Page"
              - page: "Locked Page"

      - section:
          name: "failure_section"
          title: "Failure Section"
          from: "failure_project"

      - user:
          name: "alice"
          type: "student"

      - enroll:
          user: "alice"
          section: "failure_section"
          role: "student"

      - gate:
          name: "started_gate"
          section: "failure_section"
          target: "Locked Page"
          type: "started"
          source: "Warmup Page"

      - assert:
          gating:
            section: "failure_section"
            student: "alice"
            resource: "Locked Page"
            accessible: true
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed == false
      assert verification.message =~ "Access assertion failed"
      assert verification.message =~ "expected accessible=true, got false"
    end
  end
end
