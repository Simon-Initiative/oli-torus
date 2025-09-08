defmodule Oli.Scenarios.Validation.InvalidAttributesTest do
  use ExUnit.Case, async: true

  alias Oli.Scenarios.DirectiveParser

  describe "directive attribute validation" do
    test "project directive with unknown attribute fails" do
      yaml = """
      - project:
          name: "test"
          title: "Test Project"
          description: "This should fail"
          root:
            children:
              - page: "Page 1"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'project' directive: \["description"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "section directive with typo in attribute name fails" do
      yaml = """
      - section:
          name: "test_section"
          tittle: "Test Section"
          from: "project1"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'section' directive: \["tittle"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "clone directive with extra attributes fails" do
      yaml = """
      - clone:
          from: "original"
          name: "cloned"
          title: "Cloned Project"
          description: "Extra field"
          author: "Someone"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'clone' directive: \["author", "description"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "user directive with misspelled attribute fails" do
      yaml = """
      - user:
          name: "testuser"
          type: "student"
          e_mail: "test@example.com"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'user' directive: \["e_mail"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "enroll directive with wrong attribute fails" do
      yaml = """
      - enroll:
          user: "student1"
          section: "section1"
          role: "student"
          permissions: "read"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'enroll' directive: \["permissions"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "publish directive with unknown attribute fails" do
      yaml = """
      - publish:
          to: "project1"
          description: "Publishing"
          version: "1.0"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'publish' directive: \["version"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "assert directive with structure validation - unknown attributes fail" do
      yaml = """
      - assert:
          structure:
            to: "project1"
            root:
              children:
                - page: "Page 1"
            extra_field: "should fail"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'structure assertion' directive: \["extra_field"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "assert directive with progress validation - unknown attributes fail" do
      yaml = """
      - assert:
          progress:
            section: "section1"
            progress: 0.5
            student: "student1"
            score: 85
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'progress assertion' directive: \["score"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "create_activity directive with typo fails" do
      yaml = """
      - create_activity:
          project: "project1"
          title: "Activity 1"
          type: "oli_multiple_choice"
          conent: "activity content"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'create_activity' directive: \["conent"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "node with unknown structure fails" do
      yaml = """
      - project:
          name: "test"
          title: "Test Project"
          root:
            children:
              - pages: "Page 1"
      """

      assert_raise RuntimeError, ~r/Invalid node structure/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "container node with extra attributes fails" do
      yaml = """
      - project:
          name: "test"
          title: "Test Project"
          root:
            children:
              - container: "Module 1"
                children: []
                description: "This should fail"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'container node' directive: \["description"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "valid directives with all allowed attributes succeed" do
      yaml = """
      - project:
          name: "test"
          title: "Test Project"
          root:
            children:
              - page: "Page 1"
          objectives:
            - "Objective 1"
          tags:
            - "Tag 1"
      
      - section:
          name: "test_section"
          title: "Test Section"
          from: "test"
          type: "enrollable"
          registration_open: true
      
      - user:
          name: "testuser"
          type: "student"
          email: "test@example.com"
          given_name: "Test"
          family_name: "User"
      """

      # This should not raise
      directives = DirectiveParser.parse_yaml!(yaml)
      assert length(directives) == 3
    end

    test "manipulate directive with unknown operation attribute fails" do
      yaml = """
      - manipulate:
          to: "project1"
          ops:
            - revise:
                target: "Page 1"
          extra: "field"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'manipulate' directive: \["extra"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "remix directive with misspelled attribute fails" do
      yaml = """
      - remix:
          from: "source_project"
          resources: "Page 1"
          section: "target_section"
          to: "Module 1"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'remix' directive: \["resources"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "product directive with unknown attribute fails" do
      yaml = """
      - product:
          name: "product1"
          title: "Product 1"
          from: "project1"
          price: 99.99
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'product' directive: \["price"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "institution directive with typo fails" do
      yaml = """
      - institution:
          name: "Test University"
          country_code: "US"
          institution_email: "admin@test.edu"
          institution_url: "http://test.edu"
          intitution_id: "12345"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'institution' directive: \["intitution_id"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "customize directive with wrong attribute fails" do
      yaml = """
      - customize:
          to: "section1"
          ops: []
          options: "some options"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'customize' directive: \["options"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "update directive with extra field fails" do
      yaml = """
      - update:
          from: "project1"
          to: "section1"
          force: true
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'update' directive: \["force"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "edit_page directive with typo fails" do
      yaml = """
      - edit_page:
          project: "project1"
          pages: "Page 1"
          content: "content"
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'edit_page' directive: \["pages"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "view_practice_page directive with extra attribute fails" do
      yaml = """
      - view_practice_page:
          student: "student1"
          section: "section1"
          page: "Page 1"
          duration: 60
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'view_practice_page' directive: \["duration"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "answer_question directive with wrong field fails" do
      yaml = """
      - answer_question:
          student: "student1"
          section: "section1"
          page: "Page 1"
          activity_virtual_id: "q1"
          response: "a"
          correct: true
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'answer_question' directive: \["correct"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "use directive with extra attributes fails" do
      yaml = """
      - use:
          file: "other.yaml"
          recursive: true
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'use' directive: \["recursive"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "proficiency assertion with unknown field fails" do
      yaml = """
      - assert:
          proficiency:
            section: "section1"
            objective: "Objective 1"
            bucket: "practiced"
            value: 0.8
            threshold: 0.7
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'proficiency assertion' directive: \["threshold"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "resource assertion with typo fails" do
      yaml = """
      - assert:
          resource:
            to: "project1"
            target: "Page 1"
            resources: {}
      """

      assert_raise RuntimeError, ~r/Unknown attributes in 'resource assertion' directive: \["resources"\]/, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end
    end

    test "multiple unknown attributes are all reported" do
      yaml = """
      - project:
          name: "test"
          title: "Test Project"
          description: "Extra 1"
          author: "Extra 2"
          version: "Extra 3"
          root:
            children:
              - page: "Page 1"
      """

      error = assert_raise RuntimeError, fn ->
        DirectiveParser.parse_yaml!(yaml)
      end

      # Check that all unknown attributes are listed
      assert error.message =~ "author"
      assert error.message =~ "description"
      assert error.message =~ "version"
      assert error.message =~ ~r/Unknown attributes in 'project' directive:/
    end
  end
end