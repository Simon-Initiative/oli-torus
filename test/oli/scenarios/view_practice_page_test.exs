defmodule Oli.Scenarios.ViewPracticePageTest do
  use Oli.DataCase

  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.DirectiveParser

  describe "view_practice_page directive" do
    test "student views a practice page for the first time" do
      yaml = """
      # Create a project with a practice page
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Practice Page 1"

      # Edit the page to add content (graded: false for practice)
      - edit_page:
          project: test_project
          page: "Practice Page 1"
          content: |
            title: "Practice Page 1"
            graded: false
            blocks:
              - type: prose
                body_md: "This is a practice page"
              - type: activity
                virtual_id: "practice_q1"
                activity:
                  type: oli_multiple_choice
                  stem_md: "What is 2 + 2?"
                  choices:
                    - id: "a"
                      body_md: "3"
                      score: 0
                    - id: "b"
                      body_md: "4"
                      score: 1

      # Create a section from the project
      - section:
          name: test_section
          title: "Test Section"
          from: test_project
          type: enrollable
          registration_open: true

      # Create a student user
      - user:
          name: student1
          type: student
          email: "student1@example.com"

      # Enroll the student
      - enroll:
          user: student1
          section: test_section
          role: student

      # Student views the practice page
      - view_practice_page:
          student: student1
          section: test_section
          page: "Practice Page 1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Check that the page attempt was stored
      key = {"student1", "test_section", "Practice Page 1"}
      assert Map.has_key?(result.state.page_attempts, key)

      attempt_result = Map.get(result.state.page_attempts, key)
      assert attempt_result != nil

      # The result should be either {:not_started, _} or {:in_progress, _}
      # For a first visit to a practice page, it typically starts an attempt
      assert is_tuple(attempt_result)
      {status, _data} = attempt_result
      assert status in [:not_started, :in_progress, :revised]
    end

    test "student views a practice page twice (resuming attempt)" do
      yaml = """
      # Create project, section, and page
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Practice Page"

      - edit_page:
          project: test_project
          page: "Practice Page"
          content: |
            title: "Practice Page"
            graded: false
            blocks:
              - type: prose
                body_md: "Practice content"

      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      # Create and enroll student
      - user:
          name: student1
          type: student
          email: "student1@example.com"

      - enroll:
          user: student1
          section: test_section
          role: student

      # First view
      - view_practice_page:
          student: student1
          section: test_section
          page: "Practice Page"

      # Second view (should resume)
      - view_practice_page:
          student: student1
          section: test_section
          page: "Practice Page"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Both views should succeed and store attempts
      key = {"student1", "test_section", "Practice Page"}
      assert Map.has_key?(result.state.page_attempts, key)
    end

    test "multiple students view the same practice page" do
      yaml = """
      # Create project and section
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Shared Practice Page"

      - edit_page:
          project: test_project
          page: "Shared Practice Page"
          content: |
            title: "Shared Practice Page"
            graded: false
            blocks:
              - type: prose
                body_md: "Practice content for all students"

      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      # Create multiple students
      - user:
          name: student1
          type: student
          email: "alice@example.com"

      - user:
          name: student2
          type: student
          email: "bob@example.com"

      # Enroll both students
      - enroll:
          user: student1
          section: test_section
          role: student

      - enroll:
          user: student2
          section: test_section
          role: student

      # Both students view the page
      - view_practice_page:
          student: student1
          section: test_section
          page: "Shared Practice Page"

      - view_practice_page:
          student: student2
          section: test_section
          page: "Shared Practice Page"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []

      # Check that both students have separate attempts
      key1 = {"student1", "test_section", "Shared Practice Page"}
      key2 = {"student2", "test_section", "Shared Practice Page"}

      assert Map.has_key?(result.state.page_attempts, key1)
      assert Map.has_key?(result.state.page_attempts, key2)

      # Each student should have their own attempt state
      attempt1 = Map.get(result.state.page_attempts, key1)
      attempt2 = Map.get(result.state.page_attempts, key2)

      assert attempt1 != nil
      assert attempt2 != nil
    end

    test "error when student not found" do
      yaml = """
      # Create project and section
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Page 1"

      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      # Try to view page with non-existent student
      - view_practice_page:
          student: nonexistent_student
          section: test_section
          page: "Page 1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      # Should have an error for missing student
      assert length(result.errors) > 0
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "User 'nonexistent_student' not found"
    end

    test "error when section not found" do
      yaml = """
      # Create user but no section
      - user:
          name: student1
          type: student
          email: "student1@example.com"

      # Try to view page in non-existent section
      - view_practice_page:
          student: student1
          section: nonexistent_section
          page: "Page 1"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      # Should have an error for missing section
      assert length(result.errors) > 0
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "Section 'nonexistent_section' not found"
    end

    test "error when page not found in project" do
      yaml = """
      # Create project, section, and user
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Existing Page"

      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      - user:
          name: student1
          type: student
          email: "student1@example.com"

      - enroll:
          user: student1
          section: test_section
          role: student

      # Try to view non-existent page
      - view_practice_page:
          student: student1
          section: test_section
          page: "Nonexistent Page"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      # Should have an error for missing page
      assert length(result.errors) > 0
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "Page 'Nonexistent Page' not found"
    end

    test "student is automatically enrolled if not already enrolled" do
      yaml = """
      # Create project and section
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Practice Page"

      - edit_page:
          project: test_project
          page: "Practice Page"
          content: |
            title: "Practice Page"
            graded: false
            blocks:
              - type: prose
                body_md: "Auto-enrollment test"

      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      # Create student but don't explicitly enroll
      - user:
          name: student1
          type: student
          email: "student1@example.com"

      # View page (should auto-enroll)
      - view_practice_page:
          student: student1
          section: test_section
          page: "Practice Page"
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      # Should succeed with auto-enrollment
      assert result.errors == []

      key = {"student1", "test_section", "Practice Page"}
      assert Map.has_key?(result.state.page_attempts, key)
    end
  end
end
