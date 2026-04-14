defmodule Oli.Scenarios.CertificateParserTest do
  use ExUnit.Case, async: true

  alias Oli.Scenarios
  alias Oli.Scenarios.DirectiveParser

  test "certificate directive validates unknown nested attributes" do
    yaml = """
    - certificate:
        target: "product_1"
        thresholds:
          bogus: true
    """

    assert_raise RuntimeError, ~r/Unknown attributes in 'certificate thresholds' directive/, fn ->
      DirectiveParser.parse_yaml!(yaml)
    end
  end

  test "certificate assertion validates unknown attributes" do
    yaml = """
    - assert:
        certificate:
          section: "section_1"
          unsupported: true
    """

    assert_raise RuntimeError, ~r/Unknown attributes in 'certificate assertion' directive/, fn ->
      DirectiveParser.parse_yaml!(yaml)
    end
  end

  test "schema accepts certificate workflow directives" do
    yaml = """
    - certificate:
        target: "product_1"
        enabled: true
        thresholds:
          required_discussion_posts: 1
          required_class_notes: 1
          min_percentage_for_completion: 50
          min_percentage_for_distinction: 90
          assessments_apply_to: "custom"
          scored_pages:
            - "Lesson 1"
          requires_instructor_approval: true
        design:
          title: "Completion Certificate"
          description: "Course Subtitle"

    - discussion_post:
        student: "student_1"
        section: "section_1"
        body: "Hello"

    - class_note:
        student: "student_1"
        section: "section_1"
        page: "Lesson 1"
        body: "Note"

    - complete_scored_page:
        student: "student_1"
        section: "section_1"
        page: "Lesson 1"
        score: 0.75
        out_of: 1.0

    - certificate_action:
        instructor: "instructor_1"
        section: "section_1"
        student: "student_1"
        action: "approve"

    - assert:
        certificate:
          section: "section_1"
          student: "student_1"
          state: "pending"
          with_distinction: false
          progress:
            discussion_posts:
              completed: 1
              total: 1
            class_notes:
              completed: 1
              total: 1
            required_assignments:
              completed: 1
              total: 1
    """

    assert :ok = Scenarios.validate_yaml(yaml)
  end
end
