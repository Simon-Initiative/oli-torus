defmodule Oli.Scenarios.ReviseOperationTest do
  use Oli.DataCase

  alias Oli.Scenarios.TestHelpers
  alias Oli.Scenarios.DirectiveTypes.ExecutionResult

  describe "revise operation" do
    test "can revise page properties" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Practice Page"
              - container: "Module 1"
                children:
                  - page: "Lesson 1"
                  - page: "Quiz 1"

      # Revise the Practice Page to be a practice page
      - manipulate:
          to: "test_project"
          ops:
            - revise:
                target: "Practice Page"
                set:
                  purpose: "@atom(deliberate_practice)"
                  graded: false
                  max_attempts: 0

      # Revise Quiz 1 to be graded
      - manipulate:
          to: "test_project"
          ops:
            - revise:
                target: "Quiz 1"
                set:
                  graded: true
                  max_attempts: 3

      # Verify we can read back the revised properties
      - section:
          name: "test_section"
          from: "test_project"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: []} = result

      # Get the project to verify the revisions
      project = TestHelpers.get_project(result, "test_project")

      # Check that Practice Page has the deliberate_practice purpose
      practice_page = project.rev_by_title["Practice Page"]
      assert practice_page.purpose == :deliberate_practice
      assert practice_page.graded == false
      assert practice_page.max_attempts == 0

      # Check that Quiz 1 is graded
      quiz = project.rev_by_title["Quiz 1"]
      assert quiz.graded == true
      assert quiz.max_attempts == 3
    end

    test "can revise container properties" do
      yaml = """
      - project:
          name: "container_project"
          title: "Container Project"
          root:
            children:
              - container: "Practice Module"
                children:
                  - page: "Exercise 1"
                  - page: "Exercise 2"

      # Revise the container to be practice-focused
      - manipulate:
          to: "container_project"
          ops:
            - revise:
                target: "Practice Module"
                set:
                  purpose: "@atom(application)"
                  graded: false

      - section:
          name: "test_section"
          from: "container_project"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: []} = result

      project = TestHelpers.get_project(result, "container_project")

      # Check that Practice Module has the application purpose
      module = project.rev_by_title["Practice Module"]
      assert module.purpose == :application
      assert module.graded == false
    end

    test "multiple revise operations in sequence" do
      yaml = """
      - project:
          name: "multi_revise"
          title: "Multi Revise Project"
          root:
            children:
              - page: "Page 1"
              - page: "Page 2"
              - page: "Page 3"

      # Apply multiple revisions in one manipulate directive
      - manipulate:
          to: "multi_revise"
          ops:
            - revise:
                target: "Page 1"
                set:
                  purpose: "@atom(foundation)"
                  graded: false
            - revise:
                target: "Page 2"
                set:
                  purpose: "@atom(application)"
                  graded: true
                  max_attempts: 2
            - revise:
                target: "Page 3"
                set:
                  purpose: "@atom(deliberate_practice)"
                  graded: false
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: []} = result

      project = TestHelpers.get_project(result, "multi_revise")

      # Verify all three pages have different purposes
      page1 = project.rev_by_title["Page 1"]
      assert page1.purpose == :foundation
      assert page1.graded == false

      page2 = project.rev_by_title["Page 2"]
      assert page2.purpose == :application
      assert page2.graded == true
      assert page2.max_attempts == 2

      page3 = project.rev_by_title["Page 3"]
      assert page3.purpose == :deliberate_practice
      assert page3.graded == false
    end

    test "revise operation with invalid target fails with error" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Existing Page"

      # Try to revise a non-existent page
      - manipulate:
          to: "test_project"
          ops:
            - revise:
                target: "Non-existent Page"
                set:
                  graded: true
      """

      result = TestHelpers.execute_yaml(yaml)

      # The operation should now fail with an error
      assert %ExecutionResult{errors: errors} = result
      assert length(errors) > 0

      # Check that the error message mentions the missing target
      {_directive, error_msg} = List.first(errors)
      assert error_msg =~ "Non-existent Page"
      assert error_msg =~ "not found"
    end

    test "revision tracking is properly updated after revise operation" do
      yaml = """
      - project:
          name: "tracking_test"
          title: "Tracking Test"
          root:
            children:
              - page: "Test Page"
              - container: "Module 1"
                children:
                  - page: "Inner Page"

      # First revise the page
      - manipulate:
          to: "tracking_test"
          ops:
            - revise:
                target: "Test Page"
                set:
                  purpose: "@atom(application)"
                  graded: true

      # Then perform another operation that depends on finding the revised page
      - manipulate:
          to: "tracking_test"
          ops:
            - move:
                from: "Test Page"
                to: "Module 1"

      # And edit its title
      - manipulate:
          to: "tracking_test"
          ops:
            - edit_page_title:
                title: "Test Page"
                new_title: "Revised Test Page"

      # Finally revise it again with the new title
      - manipulate:
          to: "tracking_test"
          ops:
            - revise:
                target: "Revised Test Page"
                set:
                  max_attempts: 5
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: []} = result

      project = TestHelpers.get_project(result, "tracking_test")

      # Verify the page has all the revisions applied
      revised_page = project.rev_by_title["Revised Test Page"]
      assert revised_page != nil
      assert revised_page.purpose == :application
      assert revised_page.graded == true
      assert revised_page.max_attempts == 5

      # Verify it's in Module 1
      module1 = project.rev_by_title["Module 1"]
      assert revised_page.resource_id in module1.children
    end
  end
end
