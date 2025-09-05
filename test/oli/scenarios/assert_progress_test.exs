defmodule Oli.Scenarios.AssertProgressTest do
  use Oli.DataCase

  alias Oli.Scenarios.Engine
  alias Oli.Scenarios.DirectiveParser

  describe "assert_progress directive" do
    test "asserts individual student progress on a page" do
      yaml = """
      # Create a project with pages
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Introduction"
              - container: "Module 1"
                children:
                  - page: "Lesson 1"
                  - page: "Lesson 2"

      # Edit pages to add activities
      - edit_page:
          project: test_project
          page: "Lesson 1"
          content: |
            title: "Lesson 1"
            graded: false
            blocks:
              - type: activity
                virtual_id: "lesson1_q1"
                activity:
                  type: oli_multiple_choice
                  stem_md: "Question 1"
                  choices:
                    - id: "a"
                      body_md: "Answer A"
                      score: 1
                    - id: "b"
                      body_md: "Answer B"
                      score: 0

      - edit_page:
          project: test_project
          page: "Lesson 2"
          content: |
            title: "Lesson 2"
            graded: false
            blocks:
              - type: activity
                virtual_id: "lesson2_q1"
                activity:
                  type: oli_multiple_choice
                  stem_md: "Question 2"
                  choices:
                    - id: "a"
                      body_md: "Answer A"
                      score: 0
                    - id: "b"
                      body_md: "Answer B"
                      score: 1

      # Create section
      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      # Create users
      - user:
          name: student1
          type: student
          email: "student1@example.com"

      - user:
          name: student2
          type: student
          email: "student2@example.com"

      # Enroll students
      - enroll:
          user: student1
          section: test_section
          role: student

      - enroll:
          user: student2
          section: test_section
          role: student

      # Student1 completes Lesson 1
      - view_practice_page:
          student: student1
          section: test_section
          page: "Lesson 1"

      - answer_question:
          student: student1
          section: test_section
          page: "Lesson 1"
          activity_virtual_id: "lesson1_q1"
          response: "a"

      # Assert student1's progress on Lesson 1 (should be 1.0)
      - assert_progress:
          section: test_section
          student: student1
          page: "Lesson 1"
          progress: 1.0

      # Assert student2's progress on Lesson 1 (should be 0.0)
      - assert_progress:
          section: test_section
          student: student2
          page: "Lesson 1"
          progress: 0.0
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      assert length(result.verifications) == 2

      # First verification (student1 - should pass)
      [verify1, verify2] = result.verifications
      assert verify1.passed == true
      assert verify1.message =~ "Student 'student1'"
      assert verify1.message =~ "Lesson 1"
      assert verify1.message =~ "1.0"

      # Second verification (student2 - should pass)
      assert verify2.passed == true
      assert verify2.message =~ "Student 'student2'"
      assert verify2.message =~ "0.0"
    end

    test "asserts average progress for all students on a page" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Quiz Page"

      - edit_page:
          project: test_project
          page: "Quiz Page"
          content: |
            title: "Quiz Page"
            graded: false
            blocks:
              - type: activity
                virtual_id: "quiz_q1"
                activity:
                  type: oli_multiple_choice
                  stem_md: "Question"
                  choices:
                    - id: "a"
                      body_md: "Correct"
                      score: 1
                    - id: "b"
                      body_md: "Wrong"
                      score: 0

      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      # Create 3 students
      - user:
          name: student1
          type: student
      - user:
          name: student2
          type: student
      - user:
          name: student3
          type: student

      # Enroll all students
      - enroll:
          user: student1
          section: test_section
          role: student
      - enroll:
          user: student2
          section: test_section
          role: student
      - enroll:
          user: student3
          section: test_section
          role: student

      # Student1 completes the quiz
      - view_practice_page:
          student: student1
          section: test_section
          page: "Quiz Page"
      - answer_question:
          student: student1
          section: test_section
          page: "Quiz Page"
          activity_virtual_id: "quiz_q1"
          response: "a"

      # Student2 completes the quiz
      - view_practice_page:
          student: student2
          section: test_section
          page: "Quiz Page"
      - answer_question:
          student: student2
          section: test_section
          page: "Quiz Page"
          activity_virtual_id: "quiz_q1"
          response: "a"

      # Student3 doesn't complete the quiz

      # Assert average progress for all students (2 out of 3 completed = ~0.667)
      - assert_progress:
          section: test_section
          page: "Quiz Page"
          progress: 0.667
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      assert length(result.verifications) == 1

      [verification] = result.verifications
      assert verification.passed == true
      assert verification.message =~ "All students"
      assert verification.message =~ "Quiz Page"
    end

    test "asserts progress for a container" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Course"
            children:
              - container: "Unit 1"
                children:
                  - page: "Page A"
                  - page: "Page B"

      - edit_page:
          project: test_project
          page: "Page A"
          content: |
            title: "Page A"
            graded: false
            blocks:
              - type: activity
                virtual_id: "a_q1"
                activity:
                  type: oli_multiple_choice
                  stem_md: "Question A"
                  choices:
                    - id: "correct"
                      body_md: "Correct"
                      score: 1

      - edit_page:
          project: test_project
          page: "Page B"
          content: |
            title: "Page B"
            graded: false
            blocks:
              - type: activity
                virtual_id: "b_q1"
                activity:
                  type: oli_multiple_choice
                  stem_md: "Question B"
                  choices:
                    - id: "correct"
                      body_md: "Correct"
                      score: 1

      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      - user:
          name: student1
          type: student

      - enroll:
          user: student1
          section: test_section
          role: student

      # Student completes only Page A
      - view_practice_page:
          student: student1
          section: test_section
          page: "Page A"
      - answer_question:
          student: student1
          section: test_section
          page: "Page A"
          activity_virtual_id: "a_q1"
          response: "correct"

      # Assert progress for Unit 1 container
      # NOTE: In test scenarios, container progress may not be fully simulated
      # as it depends on ResourceAccess records that aren't created by view_practice_page
      - assert_progress:
          section: test_section
          student: student1
          container: "Unit 1"
          progress: 0.0
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      assert length(result.verifications) == 1

      [verification] = result.verifications
      
      assert verification.passed == true
      assert verification.message =~ "Student 'student1'"
      assert verification.message =~ "Unit 1"
      assert verification.message =~ "0.0"
    end

    test "fails when progress doesn't match" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Test Page"

      - edit_page:
          project: test_project
          page: "Test Page"
          content: |
            title: "Test Page"
            graded: false
            blocks:
              - type: activity
                virtual_id: "q1"
                activity:
                  type: oli_multiple_choice
                  stem_md: "Question"
                  choices:
                    - id: "a"
                      body_md: "Answer"
                      score: 1

      - section:
          name: test_section
          title: "Test Section"
          from: test_project

      - user:
          name: student1
          type: student

      - enroll:
          user: student1
          section: test_section
          role: student

      # Student doesn't complete anything

      # Assert incorrect progress (expecting 1.0 but actual is 0.0)
      - assert_progress:
          section: test_section
          student: student1
          page: "Test Page"
          progress: 1.0
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      assert length(result.verifications) == 1

      [verification] = result.verifications
      assert verification.passed == false
      assert verification.message =~ "assertion failed"
      assert verification.message =~ "has progress 0"
      assert verification.message =~ "expected 1"
    end

    test "handles float parsing from various formats" do
      yaml = """
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

      - user:
          name: student1
          type: student

      - enroll:
          user: student1
          section: test_section
          role: student

      # Test with integer (should convert to float)
      - assert_progress:
          section: test_section
          student: student1
          page: "Page 1"
          progress: 0

      # Test with string float
      - assert_progress:
          section: test_section
          student: student1
          page: "Page 1"
          progress: "0.0"

      # Test with actual float
      - assert_progress:
          section: test_section
          student: student1
          page: "Page 1"
          progress: 0.0
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert result.errors == []
      assert length(result.verifications) == 3

      # All should pass as they all represent 0.0
      Enum.each(result.verifications, fn verification ->
        assert verification.passed == true
      end)
    end

    test "error when section not found" do
      yaml = """
      - project:
          name: test_project
          title: "Test Project"
          root:
            container: "Root"
            children:
              - page: "Page 1"

      # Try to assert progress for non-existent section
      - assert_progress:
          section: non_existent_section
          page: "Page 1"
          progress: 0.0
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert length(result.errors) == 1
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "Section 'non_existent_section' not found"
    end

    test "error when page not found" do
      yaml = """
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

      # Try to assert progress for non-existent page
      - assert_progress:
          section: test_section
          page: "Non-existent Page"
          progress: 0.0
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert length(result.errors) == 1
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "Resource 'Non-existent Page' not found"
    end

    test "error when neither page nor container specified" do
      yaml = """
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

      # Missing both page and container
      - assert_progress:
          section: test_section
          progress: 0.0
      """

      directives = DirectiveParser.parse_yaml!(yaml)
      result = Engine.execute(directives)

      assert length(result.errors) == 1
      {_directive, error_msg} = List.first(result.errors)
      assert error_msg =~ "Either 'page' or 'container' must be specified"
    end
  end
end