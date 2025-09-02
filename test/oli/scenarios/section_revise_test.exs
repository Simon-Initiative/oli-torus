defmodule Oli.Scenarios.SectionReviseTest do
  use Oli.DataCase

  alias Oli.Scenarios.TestHelpers
  alias Oli.Scenarios.DirectiveTypes.ExecutionResult

  describe "revise operation on sections" do
    test "can revise section resource properties" do
      yaml = """
      - project:
          name: "source_project"
          title: "Source Project"
          root:
            children:
              - page: "Page 1"
              - page: "Page 2"

      # Create a section
      - section:
          name: "test_section"
          from: "source_project"
          title: "Test Section"

      # Revise section resource properties
      - manipulate:
          to: "test_section"
          ops:
            - revise:
                target: "Page 1"
                set:
                  max_attempts: 5
                  late_submit: "@atom(disallow)"
                  time_limit: 3600

      # Verify the section resource was updated
      - verify:
          to: "test_section"
          resource:
            target: "Page 1"
            resource:
              max_attempts: 5
              late_submit: "@atom(disallow)"
              time_limit: 3600
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end

    test "can revise product resource properties" do
      yaml = """
      - project:
          name: "base_project"
          title: "Base Project"
          root:
            children:
              - page: "Lesson 1"
              - container: "Module 1"
                children:
                  - page: "Quiz 1"

      # Create a product
      - product:
          name: "test_product"
          from: "base_project"
          title: "Test Product"

      # Revise product resource properties (products are sections)
      - manipulate:
          to: "test_product"
          ops:
            - revise:
                target: "Quiz 1"
                set:
                  max_attempts: 3
                  graded: true
                  late_start: "@atom(disallow)"

      # Verify the product resource was updated
      - verify:
          to: "test_product"
          resource:
            target: "Quiz 1"
            resource:
              max_attempts: 3
              late_start: "@atom(disallow)"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end

    test "data-driven type processing works correctly" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Test Page"

      - section:
          name: "test_section"
          from: "test_project"

      # Test various data types
      - manipulate:
          to: "test_section"
          ops:
            - revise:
                target: "Test Page"
                set:
                  max_attempts: "10"           # String to integer
                  time_limit: "3600"           # String to integer
                  late_submit: "@atom(allow)"  # String to atom
                  manually_scheduled: "true"   # String to boolean
                  grace_period: 300            # Native integer
                  hidden: false                # Native boolean

      # Verify all types were correctly processed
      - verify:
          to: "test_section"
          resource:
            target: "Test Page"
            resource:
              max_attempts: 10
              time_limit: 3600
              late_submit: "@atom(allow)"
              manually_scheduled: true
              grace_period: 300
              hidden: false
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end

    test "revise fails with meaningful error for non-existent section resource" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Existing Page"

      - section:
          name: "test_section"
          from: "test_project"

      # Try to revise non-existent resource
      - manipulate:
          to: "test_section"
          ops:
            - revise:
                target: "Non-existent Page"
                set:
                  max_attempts: 5
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: errors} = result
      assert length(errors) > 0

      {_directive, error_msg} = List.first(errors)
      assert error_msg =~ "Non-existent Page"
      assert error_msg =~ "not found"
    end

    test "can combine project and section revisions" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"

      # Revise in the project (affects revision)
      - manipulate:
          to: "test_project"
          ops:
            - revise:
                target: "Page 1"
                set:
                  purpose: "@atom(deliberate_practice)"
                  graded: false

      # Create section from project
      - section:
          name: "test_section"
          from: "test_project"

      # Revise in the section (affects section_resource)
      - manipulate:
          to: "test_section"
          ops:
            - revise:
                target: "Page 1"
                set:
                  max_attempts: 5
                  time_limit: 1800

      # Verify project revision properties
      - verify:
          to: "test_project"
          resource:
            target: "Page 1"
            resource:
              purpose: "@atom(deliberate_practice)"
              graded: false

      # Verify section resource properties
      - verify:
          to: "test_section"
          resource:
            target: "Page 1"
            resource:
              max_attempts: 5
              time_limit: 1800
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: verifications} = result
      assert length(verifications) == 2
      assert Enum.all?(verifications, & &1.passed)
    end
  end
end
