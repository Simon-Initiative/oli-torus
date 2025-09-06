defmodule Oli.Scenarios.ProductComprehensiveTest do
  use Oli.DataCase

  alias Oli.Scenarios.TestHelpers
  alias Oli.Scenarios.DirectiveTypes.ExecutionResult

  describe "comprehensive product workflow" do
    test "products support full workflow with customize, remix, and section creation" do
      yaml = """
      # Create a library of reusable content
      - project:
          name: "content_library"
          title: "Reusable Content Library"
          root:
            children:
              - page: "Shared Introduction"
              - container: "Shared Resources"
                children:
                  - page: "Resource 1"
                  - page: "Resource 2"

      # Create base course template
      - project:
          name: "base_template"
          title: "Base Course Template"
          root:
            children:
              - page: "Course Welcome"
              - container: "Module 1"
                children:
                  - page: "Lesson 1.1"
                  - page: "Quiz 1"
              - container: "Module 2"
                children:
                  - page: "Lesson 2.1"
                  - page: "Quiz 2"
              - page: "Final Exam"

      # Create a product from the base template
      - product:
          name: "standard_course"
          title: "Standard Course Product"
          from: "base_template"

      # Customize the product by removing quizzes
      - customize:
          to: "standard_course"
          ops:
            - remove:
                from: "Quiz 1"
            - remove:
                from: "Quiz 2"

      # Remix shared content into the product
      - remix:
          from: "content_library"
          resource: "Shared Introduction"
          section: "standard_course"
          to: "Module 1"

      # Verify the customized and remixed product structure
      - assert:
          structure:
            to: "standard_course"
            root:
              children:
                - page: "Course Welcome"
                - container: "Module 1"
                  children:
                    - page: "Lesson 1.1"
                    - page: "Shared Introduction"
                - container: "Module 2"
                  children:
                    - page: "Lesson 2.1"
                - page: "Final Exam"

      # Create multiple sections from the customized product
      - section:
          name: "fall_2024"
          title: "Fall 2024 Section"
          from: "standard_course"

      - section:
          name: "spring_2025"
          title: "Spring 2025 Section"
          from: "standard_course"

      # Verify both sections have the customized structure
      - assert:
          structure:
            to: "fall_2024"
            root:
              children:
                - page: "Course Welcome"
                - container: "Module 1"
                  children:
                    - page: "Lesson 1.1"
                    - page: "Shared Introduction"
                - container: "Module 2"
                  children:
                    - page: "Lesson 2.1"
                - page: "Final Exam"

      - assert:
          structure:
            to: "spring_2025"
            root:
              children:
                - page: "Course Welcome"
                - container: "Module 1"
                  children:
                    - page: "Lesson 1.1"
                    - page: "Shared Introduction"
                - container: "Module 2"
                  children:
                    - page: "Lesson 2.1"
                - page: "Final Exam"

      # Further customize spring section
      - customize:
          to: "spring_2025"
          ops:
            - reorder:
                from: "Final Exam"
                before: "Module 2"

      # Verify spring section has additional customization
      - assert:
          structure:
            to: "spring_2025"
            root:
              children:
                - page: "Course Welcome"
                - container: "Module 1"
                  children:
                    - page: "Lesson 1.1"
                    - page: "Shared Introduction"
                - page: "Final Exam"
                - container: "Module 2"
                  children:
                    - page: "Lesson 2.1"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: verifications} = result
      assert length(verifications) == 4
      assert Enum.all?(verifications, & &1.passed)
    end
  end
end
