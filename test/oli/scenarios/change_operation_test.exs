defmodule Oli.Scenarios.ChangeOperationTest do
  use Oli.DataCase

  alias Oli.Scenarios.TestHelpers
  alias Oli.Scenarios.DirectiveTypes.ExecutionResult

  describe "change operation" do
    test "can change project settings" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"

      # Change project settings
      - manipulate:
          to: "test_project"
          ops:
            - change:
                title: "Updated Project Title"
                description: "This is an updated description"
                allow_triggers: true

      # Create a section to verify the project changes
      - section:
          name: "test_section"
          from: "test_project"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: []} = result

      # Verify the project was updated
      project = result.state.projects["test_project"].project
      assert project.title == "Updated Project Title"
      assert project.description == "This is an updated description"
      assert project.allow_triggers == true
    end

    test "can change section settings" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"

      - section:
          name: "test_section"
          from: "test_project"

      # Change section settings
      - manipulate:
          to: "test_section"
          ops:
            - change:
                title: "Updated Section Title"
                apply_major_updates: true
                grace_period_strategy: "@atom(relative_to_student)"
                has_grace_period: true
                grace_period_days: 7

      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: []} = result

      # Verify the section was updated
      section = result.state.sections["test_section"]
      assert section.title == "Updated Section Title"
      assert section.apply_major_updates == true
      assert section.grace_period_strategy == :relative_to_student
      assert section.has_grace_period == true
      assert section.grace_period_days == 7
    end

    test "can change product settings" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"

      - product:
          name: "test_product"
          from: "test_project"
          title: "Test Product"

      # Change product settings
      - manipulate:
          to: "test_product"
          ops:
            - change:
                title: "Updated Product Title"
                apply_major_updates: false
                description: "Updated product description"

      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: []} = result

      # Verify the product was updated
      product = result.state.products["test_product"]
      assert product.title == "Updated Product Title"
      assert product.apply_major_updates == false
      assert product.description == "Updated product description"
    end

    test "supports multiple data types in change operation" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"

      - section:
          name: "test_section"
          from: "test_project"

      # Change with various data types
      - manipulate:
          to: "test_section"
          ops:
            - change:
                title: "String Value"
                apply_major_updates: true
                grace_period_days: 5
                requires_enrollment: false
                course_section_number: "section-123"

      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: []} = result

      section = result.state.sections["test_section"]
      assert section.title == "String Value"
      assert section.apply_major_updates == true
      assert section.grace_period_days == 5
      assert section.requires_enrollment == false
      assert section.course_section_number == "section-123"

      event =
        assert_audited(:section_settings_changed, section_id: section.id, source: :scenario)

      assert Map.keys(event.changes) == ["course_section_number", "title"]

      assert_audited(:publication_update_policy_changed,
        section_id: section.id,
        source: :scenario
      )
    end

    test "rejects fields that no settings form writes" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"

      - section:
          name: "test_section"
          from: "test_project"

      - manipulate:
          to: "test_section"
          ops:
            - change:
                grade_passback_enabled: true

      """

      result = TestHelpers.execute_yaml(yaml)

      assert [{_directive, message}] = result.errors
      assert message =~ "invalid_request"
    end

    test "can combine change with other operations" do
      yaml = """
      - project:
          name: "test_project"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"

      # Multiple operations including change
      - manipulate:
          to: "test_project"
          ops:
            - change:
                title: "Updated Title"
                description: "Updated Description"
            - add_page:
                title: "New Page"
                to: "root"
            - revise:
                target: "Page 1"
                set:
                  graded: true
                  max_attempts: 2

      - section:
          name: "test_section"
          from: "test_project"
      """

      result = TestHelpers.execute_yaml(yaml)

      assert %ExecutionResult{errors: []} = result

      # Verify all operations were applied
      project = result.state.projects["test_project"]
      assert project.project.title == "Updated Title"
      assert project.project.description == "Updated Description"

      # Verify the new page was added
      assert Map.has_key?(project.id_by_title, "New Page")

      # Verify Page 1 was revised
      page1_rev = project.rev_by_title["Page 1"]
      assert page1_rev.graded == true
      assert page1_rev.max_attempts == 2
    end
  end
end
