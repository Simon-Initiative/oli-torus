defmodule Oli.Scenarios.ProductTest do
  use Oli.DataCase

  alias Oli.Scenarios.TestHelpers
  alias Oli.Scenarios.DirectiveTypes.ExecutionResult

  describe "product directive" do
    test "can create a product from a project" do
      yaml = """
      - project:
          name: "source_project"
          title: "Source Project"
          root:
            children:
              - page: "Page 1"
              - container: "Module 1"
                children:
                  - page: "Lesson 1"
                  - page: "Lesson 2"

      - product:
          name: "my_product"
          title: "My Product Template"
          from: "source_project"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: []} = result
      assert product = TestHelpers.get_product(result, "my_product")
      assert product.title == "My Product Template"
    end

    test "can create section from a product" do
      yaml = """
      - project:
          name: "source_project"
          title: "Source Project"
          root:
            children:
              - page: "Welcome"
              - container: "Unit 1"
                children:
                  - page: "Intro"

      - product:
          name: "product_template"
          title: "Product Template"
          from: "source_project"

      - section:
          name: "section_from_product"
          title: "Section from Product"
          from: "product_template"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: []} = result
      assert _product = TestHelpers.get_product(result, "product_template")
      assert section = TestHelpers.get_section(result, "section_from_product")
      assert section.title == "Section from Product"
    end

    test "fails when source project doesn't exist" do
      yaml = """
      - product:
          name: "my_product"
          title: "My Product"
          from: "nonexistent_project"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: errors} = result
      assert length(errors) > 0
      assert {_directive, reason} = hd(errors)
      assert reason =~ "Project 'nonexistent_project' not found"
    end

    test "can create multiple products from same project" do
      yaml = """
      - project:
          name: "base_project"
          title: "Base Project"
          root:
            children:
              - page: "Content"

      - product:
          name: "product1"
          title: "Product Version 1"
          from: "base_project"

      - product:
          name: "product2"
          title: "Product Version 2"
          from: "base_project"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: []} = result
      assert product1 = TestHelpers.get_product(result, "product1")
      assert product2 = TestHelpers.get_product(result, "product2")
      assert product1.title == "Product Version 1"
      assert product2.title == "Product Version 2"
    end
  end
end
