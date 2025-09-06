defmodule Oli.Scenarios.ResourceVerifyTest do
  use Oli.DataCase

  alias Oli.Scenarios.TestHelpers
  alias Oli.Scenarios.DirectiveTypes.ExecutionResult

  describe "verify resource directive" do
    test "can verify resource properties in a project" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Practice Page"
              - container: "Module 1"
                children:
                  - page: "Quiz Page"

      # Revise pages to have specific properties
      - manipulate:
          to: "test_project"
          ops:
            - revise:
                target: "Practice Page"
                set:
                  purpose: "@atom(deliberate_practice)"
                  graded: false
                  max_attempts: 0
            - revise:
                target: "Quiz Page"
                set:
                  graded: true
                  max_attempts: 3

      # Verify the properties were set correctly
      - assert:
          resource:
            to: "test_project"
            target: "Practice Page"
            resource:
              purpose: "@atom(deliberate_practice)"
              graded: false
              max_attempts: 0

      - assert:
          resource:
            to: "test_project"
            target: "Quiz Page"
            resource:
              graded: true
              max_attempts: 3
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: verifications} = result
      assert length(verifications) == 2
      assert Enum.all?(verifications, & &1.passed)
    end

    test "can verify resource properties in a section" do
      yaml = """
      - project:
          name: "source_project"
          title: "Source Project"
          root:
            children:
              - page: "Lesson 1"
              - page: "Lesson 2"

      # Create a section from the project
      - section:
          name: "test_section"
          from: "source_project"

      # Revise section resources in the section
      - manipulate:
          to: "test_section"
          ops:
            - revise:
                target: "Lesson 1"
                set:
                  purpose: "@atom(foundation)"
                  graded: false
            - revise:
                target: "Lesson 2"
                set:
                  purpose: "@atom(application)"
                  graded: true
                  max_attempts: 2

      # Verify resource properties in the section
      - assert:
          resource:
            to: "test_section"
            target: "Lesson 1"
            resource:
              purpose: "@atom(foundation)"
              graded: false

      - assert:
          resource:
            to: "test_section"
            target: "Lesson 2"
            resource:
              purpose: "@atom(application)"
              graded: true
              max_attempts: 2
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: verifications} = result
      assert length(verifications) == 2
      assert Enum.all?(verifications, & &1.passed)
    end

    test "can verify resource properties in a product" do
      yaml = """
      - project:
          name: "base_project"
          title: "Base Project"
          root:
            children:
              - page: "Page 1"
              - page: "Page 2"

      # Create a product from the project
      - product:
          name: "test_product"
          from: "base_project"

      # Revise section resources in the product
      - manipulate:
          to: "test_product"
          ops:
            - revise:
                target: "Page 1"
                set:
                  graded: true
                  max_attempts: 5

      # Verify resource properties in the product
      - assert:
          resource:
            to: "test_product"
            target: "Page 1"
            resource:
              graded: true
              max_attempts: 5
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end

    test "resource verification fails when properties don't match" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Test Page"

      # Set page properties
      - manipulate:
          to: "test_project"
          ops:
            - revise:
                target: "Test Page"
                set:
                  graded: true
                  max_attempts: 3

      # Verify with wrong expected values
      - assert:
          resource:
            to: "test_project"
            target: "Test Page"
            resource:
              graded: false  # Wrong value
              max_attempts: 5  # Wrong value
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed == false
      assert verification.message =~ "mismatch"
    end

    test "resource verification fails when resource not found" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Existing Page"

      # Try to verify non-existent resource
      - assert:
          resource:
            to: "test_project"
            target: "Non-existent Page"
            resource:
              graded: true
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed == false
      assert verification.message =~ "not found"
    end

    test "can combine structure and resource verification" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
              - container: "Module 1"
                children:
                  - page: "Page 2"

      # Revise a page
      - manipulate:
          to: "test_project"
          ops:
            - revise:
                target: "Page 2"
                set:
                  purpose: "@atom(deliberate_practice)"
                  graded: false

      # Verify structure
      - assert:
          structure:
            to: "test_project"
            root:
              children:
                - page: "Page 1"
                - container: "Module 1"
                  children:
                    - page: "Page 2"

      # Verify resource properties
      - assert:
          resource:
            to: "test_project"
            target: "Page 2"
            resource:
              purpose: "@atom(deliberate_practice)"
              graded: false
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: verifications} = result
      assert length(verifications) == 2
      assert Enum.all?(verifications, & &1.passed)
    end
  end
end
