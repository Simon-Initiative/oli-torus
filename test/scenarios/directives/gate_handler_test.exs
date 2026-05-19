defmodule Oli.Scenarios.Directives.GateHandlerTest do
  use Oli.DataCase

  alias Oli.DateTime, as: OliDateTime
  alias Oli.Delivery.Gating
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Scenarios.DirectiveParser
  alias Oli.Scenarios.Engine

  setup do
    on_exit(fn -> OliDateTime.set_override(nil) end)
  end

  test "time and gate directives create a schedule gate with deterministic evaluation" do
    yaml = """
    - project:
        name: "gating_course"
        title: "Gating Course"
        root:
          children:
            - page: "Warmup Page"
            - page: "Locked Page"

    - section:
        name: "gating_section"
        title: "Gating Section"
        from: "gating_course"

    - user:
        name: "alice"
        type: "student"

    - enroll:
        user: "alice"
        section: "gating_section"
        role: "student"

    - time:
        at: "2026-01-10T12:00:00Z"

    - gate:
        name: "schedule_gate"
        section: "gating_section"
        target: "Locked Page"
        type: "schedule"
        start: "2026-01-11T12:00:00Z"
        end: "2026-01-12T12:00:00Z"
    """

    result =
      yaml
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute()

    assert result.errors == []
    assert result.state.scenario_time == ~U[2026-01-10 12:00:00Z]

    gate = Engine.get_gate(result.state, "schedule_gate")
    section = Engine.get_section(result.state, "gating_section")
    alice = Engine.get_user(result.state, "alice")

    assert gate.type == :schedule
    assert gate.data.start_datetime == ~U[2026-01-11 12:00:00Z]
    assert gate.data.end_datetime == ~U[2026-01-12 12:00:00Z]

    locked_page = published_revision(section, result.state, "gating_course", "Locked Page")

    OliDateTime.set_override(result.state.scenario_time)
    assert Gating.blocked_by(section, alice, locked_page.resource_id) != []

    OliDateTime.set_override(~U[2026-01-11 18:00:00Z])
    assert Gating.blocked_by(section, alice, locked_page.resource_id) == []

    OliDateTime.set_override(~U[2026-01-12 18:00:00Z])
    assert Gating.blocked_by(section, alice, locked_page.resource_id) != []
  end

  test "gate directive can create a student-specific exception linked to a parent gate" do
    yaml = """
    - project:
        name: "exception_course"
        title: "Exception Course"
        root:
          children:
            - page: "Warmup Page"
            - page: "Locked Page"

    - section:
        name: "exception_section"
        title: "Exception Section"
        from: "exception_course"

    - user:
        name: "alice"
        type: "student"

    - user:
        name: "bob"
        type: "student"

    - enroll:
        user: "alice"
        section: "exception_section"
        role: "student"

    - enroll:
        user: "bob"
        section: "exception_section"
        role: "student"

    - gate:
        name: "base_gate"
        section: "exception_section"
        target: "Locked Page"
        type: "started"
        source: "Warmup Page"

    - gate:
        name: "alice_exception"
        section: "exception_section"
        parent: "base_gate"
        student: "alice"
        type: "always_open"
    """

    result =
      yaml
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute()

    assert result.errors == []

    base_gate = Engine.get_gate(result.state, "base_gate")
    alice_exception = Engine.get_gate(result.state, "alice_exception")
    section = Engine.get_section(result.state, "exception_section")
    alice = Engine.get_user(result.state, "alice")
    bob = Engine.get_user(result.state, "bob")
    locked_page = published_revision(section, result.state, "exception_course", "Locked Page")

    assert base_gate.type == :started
    assert alice_exception.type == :always_open
    assert alice_exception.parent_id == base_gate.id
    assert alice_exception.user_id == alice.id

    assert Gating.blocked_by(section, alice, locked_page.resource_id) == []
    assert Gating.blocked_by(section, bob, locked_page.resource_id) != []
  end

  defp published_revision(section, state, project_name, page_title) do
    project = Engine.get_project(state, project_name)
    revision = project.rev_by_title[page_title]
    DeliveryResolver.from_revision_slug(section.slug, revision.slug)
  end
end
