defmodule Oli.Scenarios.ProductCustomizeTest do
  use Oli.DataCase

  alias Oli.Scenarios.TestHelpers
  alias Oli.Scenarios.DirectiveTypes.ExecutionResult

  describe "customize directive with products" do
    test "can customize a product by removing content" do
      yaml = """
      - project:
          name: "base_project"
          title: "Base Project"
          root:
            children:
              - page: "Welcome"
              - container: "Module 1"
                children:
                  - page: "Lesson 1"
                  - page: "Quiz"
              - page: "Final"

      - product:
          name: "template"
          title: "Product Template"
          from: "base_project"

      # Verify initial product structure
      - assert:
          structure:
            to: "template"
            root:
              children:
                - page: "Welcome"
                - container: "Module 1"
                  children:
                    - page: "Lesson 1"
                    - page: "Quiz"
                - page: "Final"

      # Customize the product by removing the quiz
      - customize:
          to: "template"
          ops:
            - remove:
                from: "Quiz"

      # Verify the quiz was removed from the product
      - assert:
          structure:
            to: "template"
            root:
              children:
                - page: "Welcome"
                - container: "Module 1"
                  children:
                    - page: "Lesson 1"
                - page: "Final"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: verifications} = result
      assert length(verifications) == 2
      assert Enum.all?(verifications, & &1.passed)
    end

    test "can customize a product by reordering content" do
      yaml = """
      - project:
          name: "base"
          title: "Base"
          root:
            children:
              - page: "Page A"
              - page: "Page B"
              - page: "Page C"

      - product:
          name: "template"
          title: "Template"
          from: "base"

      # Reorder pages in the product
      - customize:
          to: "template"
          ops:
            - reorder:
                from: "Page C"
                before: "Page A"

      # Verify the new order
      - assert:
          structure:
            to: "template"
            root:
              children:
                - page: "Page C"
                - page: "Page A"
                - page: "Page B"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end

    test "sections created from customized products inherit the customizations" do
      yaml = """
      - project:
          name: "base"
          title: "Base"
          root:
            children:
              - page: "Original Page 1"
              - page: "Original Page 2"
              - page: "Original Page 3"

      - product:
          name: "template"
          title: "Template"
          from: "base"

      # Customize the product
      - customize:
          to: "template"
          ops:
            - remove:
                from: "Original Page 2"

      # Create a section from the customized product
      - section:
          name: "derived_section"
          title: "Derived Section"
          from: "template"

      # Verify the section has the customized structure
      - assert:
          structure:
            to: "derived_section"
            root:
              children:
                - page: "Original Page 1"
                - page: "Original Page 3"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end
  end
end
