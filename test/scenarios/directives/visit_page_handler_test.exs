defmodule Oli.Scenarios.Directives.VisitPageHandlerTest do
  use Oli.DataCase

  alias Oli.Delivery.Gating
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Scenarios.DirectiveParser
  alias Oli.Scenarios.Engine

  test "visit_page can start a graded source page and unblock a started gate" do
    setup_yaml = """
    - project:
        name: "visit_course"
        title: "Visit Course"
        root:
          children:
            - page: "Source Quiz"
            - page: "Locked Page"

    - edit_page:
        project: "visit_course"
        page: "Source Quiz"
        content: |
          title: "Source Quiz"
          graded: true
          blocks:
            - type: prose
              body_md: "Start this quiz."

            - type: activity
              virtual_id: "source_q1"
              activity:
                type: oli_multiple_choice
                stem_md: "Which number is correct?"
                choices:
                  - id: "a"
                    body_md: "1"
                    score: 1
                  - id: "b"
                    body_md: "2"
                    score: 0

    - section:
        name: "visit_section"
        title: "Visit Section"
        from: "visit_course"

    - user:
        name: "alice"
        type: "student"

    - enroll:
        user: "alice"
        section: "visit_section"
        role: "student"

    - gate:
        name: "started_gate"
        section: "visit_section"
        target: "Locked Page"
        type: "started"
        source: "Source Quiz"
    """

    initial_result =
      setup_yaml
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute()

    assert initial_result.errors == []

    section = Engine.get_section(initial_result.state, "visit_section")
    alice = Engine.get_user(initial_result.state, "alice")
    locked_page = published_revision(section, initial_result.state, "visit_course", "Locked Page")

    assert Gating.blocked_by(section, alice, locked_page.resource_id) != []

    visit_result =
      """
      - visit_page:
          student: "alice"
          section: "visit_section"
          page: "Source Quiz"
      """
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute(state: initial_result.state)

    assert visit_result.errors == []

    section = Engine.get_section(visit_result.state, "visit_section")
    assert Gating.blocked_by(section, alice, locked_page.resource_id) == []
  end

  defp published_revision(section, state, project_name, page_title) do
    project = Engine.get_project(state, project_name)
    revision = project.rev_by_title[page_title]
    DeliveryResolver.from_revision_slug(section.slug, revision.slug)
  end
end
