defmodule Oli.Scenarios.ProductRemixTest do
  use Oli.DataCase

  alias Oli.Scenarios.TestHelpers
  alias Oli.Scenarios.DirectiveTypes.ExecutionResult

  describe "remix directive with products" do
    test "can remix content into a product" do
      yaml = """
      - project:
          name: "source"
          title: "Source Project"
          root:
            children:
              - page: "Shared Content"
              - container: "Shared Module"
                children:
                  - page: "Shared Lesson"

      - project:
          name: "base"
          title: "Base Project"
          root:
            children:
              - container: "Module 1"
                children:
                  - page: "Original Content"

      - product:
          name: "template"
          title: "Product Template"
          from: "base"

      # Remix content into the product
      - remix:
          from: "source"
          resource: "Shared Content"
          section: "template"
          to: "Module 1"

      # Verify the content was added to the product
      - verify:
          to: "template"
          structure:
            root:
              children:
                - container: "Module 1"
                  children:
                    - page: "Original Content"
                    - page: "Shared Content"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end

    test "can remix a container into a product" do
      yaml = """
      - project:
          name: "library"
          title: "Content Library"
          root:
            children:
              - container: "Reusable Module"
                children:
                  - page: "Topic 1"
                  - page: "Topic 2"

      - project:
          name: "base"
          title: "Base"
          root:
            children:
              - page: "Welcome"

      - product:
          name: "template"
          title: "Template"
          from: "base"

      # Remix container into product root
      - remix:
          from: "library"
          resource: "Reusable Module"
          section: "template"
          to: "root"

      # Verify the container was added
      - verify:
          to: "template"
          structure:
            root:
              children:
                - page: "Welcome"
                - container: "Reusable Module"
                  children:
                    - page: "Topic 1"
                    - page: "Topic 2"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end

    test "sections created from remixed products include the remixed content" do
      yaml = """
      - project:
          name: "library"
          title: "Library"
          root:
            children:
              - page: "Bonus Content"

      - project:
          name: "base"
          title: "Base"
          root:
            children:
              - container: "Main Module"
                children:
                  - page: "Core Content"

      - product:
          name: "enhanced_template"
          title: "Enhanced Template"
          from: "base"

      # Remix content into the product
      - remix:
          from: "library"
          resource: "Bonus Content"
          section: "enhanced_template"
          to: "Main Module"

      # Create a section from the enhanced product
      - section:
          name: "enhanced_section"
          title: "Enhanced Section"
          from: "enhanced_template"

      # Verify the section includes the remixed content
      - verify:
          to: "enhanced_section"
          structure:
            root:
              children:
                - container: "Main Module"
                  children:
                    - page: "Core Content"
                    - page: "Bonus Content"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end

    test "can combine remix and customize operations on products" do
      yaml = """
      - project:
          name: "library"
          title: "Library"
          root:
            children:
              - page: "Extra Page"

      - project:
          name: "base"
          title: "Base"
          root:
            children:
              - page: "Page 1"
              - page: "Page 2"
              - page: "Page 3"

      - product:
          name: "custom_template"
          title: "Custom Template"
          from: "base"

      # Remix content into the product
      - remix:
          from: "library"
          resource: "Extra Page"
          section: "custom_template"
          to: "root"

      # Customize by removing and reordering
      - customize:
          to: "custom_template"
          ops:
            - remove:
                from: "Page 2"
            - reorder:
                from: "Extra Page"
                before: "Page 1"

      # Verify final structure
      - verify:
          to: "custom_template"
          structure:
            root:
              children:
                - page: "Extra Page"
                - page: "Page 1"
                - page: "Page 3"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: [], verifications: [verification]} = result
      assert verification.passed
    end
  end
end