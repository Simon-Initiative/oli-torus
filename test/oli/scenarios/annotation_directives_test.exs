defmodule Oli.Scenarios.AnnotationDirectivesTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  test "rejects a reply whose parent note belongs to another page" do
    yaml = """
    - project:
        name: "annotation_scope_course"
        title: "Annotation Scope Course"
        root:
          children:
            - page: "First Page"
            - page: "Second Page"

    - publish:
        to: "annotation_scope_course"
        description: "Publish annotation scope course"

    - section:
        name: "annotation_scope_section"
        title: "Annotation Scope Section"
        from: "annotation_scope_course"

    - user:
        name: "annotation_student"
        type: "student"
        email: "annotation_scope_student@test.edu"

    - enroll:
        user: "annotation_student"
        section: "annotation_scope_section"
        role: "student"

    - class_note:
        name: "first_page_note"
        student: "annotation_student"
        section: "annotation_scope_section"
        page: "First Page"
        body: "This note belongs to the first page."

    - class_note:
        name: "invalid_reply"
        student: "annotation_student"
        section: "annotation_scope_section"
        page: "Second Page"
        reply_to: "first_page_note"
        body: "This reply must be rejected."
    """

    result = Scenarios.execute_yaml(yaml, RuntimeOpts.build())

    assert [{_directive, error}] = result.errors
    assert error =~ "Parent note does not belong to the requested section and page"
  end
end
