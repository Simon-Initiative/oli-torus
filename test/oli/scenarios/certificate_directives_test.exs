defmodule Oli.Scenarios.CertificateDirectivesTest do
  use Oli.DataCase

  alias Oli.Scenarios.{DirectiveParser, Engine}

  test "certificate directives configure copied section settings and learner certificate state" do
    yaml = """
    - project:
        name: "course"
        title: "Certificate Course"
        root:
          children:
            - page: "Lesson 1"

    - product:
        name: "certificate_product"
        from: "course"
        title: "Certificate Product"

    - certificate:
        target: "certificate_product"
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
          admin_name1: "Admin One"
          admin_title1: "Dean"

    - section:
        name: "certificate_section"
        from: "certificate_product"
        title: "Certificate Section"

    - user:
        name: "instructor_1"
        type: "instructor"
        email: "instructor_1@test.edu"

    - user:
        name: "student_1"
        type: "student"
        email: "student_1@test.edu"

    - assert:
        certificate:
          section: "certificate_section"
          enabled: true
          required_discussion_posts: 1
          required_class_notes: 1
          min_percentage_for_completion: 50
          min_percentage_for_distinction: 90
          requires_instructor_approval: true
          assessments_apply_to: "custom"
          scored_pages:
            - "Lesson 1"
          title: "Completion Certificate"
          description: "Course Subtitle"
          admin_name1: "Admin One"
          admin_title1: "Dean"

    - discussion_post:
        student: "student_1"
        section: "certificate_section"
        body: "This is my discussion post"

    - class_note:
        student: "student_1"
        section: "certificate_section"
        page: "Lesson 1"
        body: "This is my note"

    - assert:
        certificate:
          section: "certificate_section"
          student: "student_1"
          state: "none"
          progress:
            discussion_posts:
              completed: 1
              total: 1
            class_notes:
              completed: 1
              total: 1
            required_assignments:
              completed: 0
              total: 1

    - complete_scored_page:
        student: "student_1"
        section: "certificate_section"
        page: "Lesson 1"
        score: 0.75
        out_of: 1.0

    - assert:
        certificate:
          section: "certificate_section"
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

    - certificate_action:
        instructor: "instructor_1"
        section: "certificate_section"
        student: "student_1"
        action: "approve"

    - assert:
        certificate:
          section: "certificate_section"
          student: "student_1"
          state: "earned"
          with_distinction: false
    """

    result =
      yaml
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute()

    assert result.errors == []
    assert Enum.all?(result.verifications, & &1.passed)
  end
end
