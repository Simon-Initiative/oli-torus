defmodule Oli.Scenarios.ProductTest do
  use Oli.DataCase

  alias Oli.Delivery.Paywall
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

    test "can configure product paywall, inherit it into section, and override it at section level" do
      yaml = """
      - institution:
          name: "paid_school"
          country_code: "US"
          institution_email: "admin@paid.edu"
          institution_url: "https://paid.edu"

      - project:
          name: "source_project"
          title: "Source Project"
          root:
            children:
              - page: "Page 1"

      - product:
          name: "paid_product"
          title: "Paid Product"
          from: "source_project"
          requires_payment: true
          payment_options: "direct"
          amount:
            amount: 25
            currency: "USD"
          has_grace_period: false
          grace_period_strategy: "relative_to_student"

      - institution_discount:
          institution: "paid_school"
          product: "paid_product"
          type: "percentage"
          percentage: 15

      - section:
          name: "inherits_product_paywall"
          title: "Inherits Product Paywall"
          from: "paid_product"

      - section:
          name: "overrides_product_paywall"
          title: "Overrides Product Paywall"
          from: "paid_product"
          payment_options: "deferred"
          has_grace_period: true
          grace_period_days: 7
          grace_period_strategy: "relative_to_section"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: []} = result

      assert product = TestHelpers.get_product(result, "paid_product")
      assert product.requires_payment == true
      assert product.payment_options == :direct
      assert product.amount == Money.new(25, "USD")
      assert product.has_grace_period == false
      assert product.grace_period_strategy == :relative_to_student

      assert inherited = TestHelpers.get_section(result, "inherits_product_paywall")
      assert inherited.requires_payment == true
      assert inherited.payment_options == :direct
      assert inherited.amount == Money.new(25, "USD")
      assert inherited.has_grace_period == false
      assert inherited.grace_period_strategy == :relative_to_student

      assert overridden = TestHelpers.get_section(result, "overrides_product_paywall")
      assert overridden.requires_payment == true
      assert overridden.payment_options == :deferred
      assert overridden.amount == Money.new(25, "USD")
      assert overridden.has_grace_period == true
      assert overridden.grace_period_days == 7
      assert overridden.grace_period_strategy == :relative_to_section

      assert discount =
               Paywall.get_discount_by!(
                 section_id: product.id,
                 institution_id: result.state.current_institution.id
               )

      assert discount.type == :percentage
      assert discount.percentage == 15.0
    end
  end
end
