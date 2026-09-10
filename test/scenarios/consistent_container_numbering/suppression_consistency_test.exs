defmodule Oli.Scenarios.ConsistentContainerNumbering.SuppressionConsistencyTest do
  @moduledoc """
  End-to-end regression for MER-5871: authors a course through the real
  author -> publish -> create-section workflow (via `Oli.Scenarios`, not hand-built
  fixtures), suppresses a top-level unit, and confirms several independent delivery and
  instructor-facing surfaces all agree on the resulting numbers for the same containers.
  """

  use OliWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Oli.Delivery.Sections
  alias Oli.Scenarios.DirectiveParser
  alias Oli.Scenarios.Engine

  @yaml """
  - project:
      name: "numbering_course"
      title: "Numbering Course"
      root:
        children:
          - container: "Foundations"
            children:
              - page: "Foundations Assessment"
          - container: "Data Analysis"
            children:
              - page: "Data Analysis Reading"

  - manipulate:
      to: "numbering_course"
      ops:
        - revise:
            target: "Foundations Assessment"
            set:
              graded: true

  - section:
      name: "numbering_section"
      title: "Numbering Section"
      from: "numbering_course"

  - user:
      name: "instructor_1"
      type: instructor

  - enroll:
      user: "instructor_1"
      section: "numbering_section"
      role: instructor
  """

  test "a suppressed top-level unit reports the same number across Learn, Assessment Settings, and the Instructor Dashboard" do
    directives = DirectiveParser.parse_yaml!(@yaml)
    result = Engine.execute(directives)

    assert result.errors == []

    project = Engine.get_project(result.state, "numbering_course")
    section = Engine.get_section(result.state, "numbering_section")
    instructor = Engine.get_user(result.state, "instructor_1")

    foundations_id = project.id_by_title["Foundations"]
    data_analysis_id = project.id_by_title["Data Analysis"]

    {:ok, section} = Sections.update_section(section, %{unnumbered_unit_ids: [foundations_id]})

    # Learn: "Foundations" is suppressed (absent from the map); "Data Analysis" is
    # renumbered to display index 1, since "Foundations" no longer consumes a slot.
    numbering_map = Sections.decorated_numbering_map(section)
    refute Map.has_key?(numbering_map, foundations_id)
    assert numbering_map[data_analysis_id].index == 1

    conn = build_conn() |> log_in_user(instructor)

    # Assessment Settings: the bulk-apply selector shows "Foundations Assessment" with no
    # container-number prefix, since its parent unit is suppressed.
    {:ok, assessment_settings_view, _html} =
      live(
        conn,
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Sections.AssessmentSettings.SettingsLive,
          section.slug,
          "all"
        )
      )

    select_html =
      assessment_settings_view |> element(~s{select#assessment_select}) |> render()

    assert select_html =~ "Foundations Assessment"
    refute select_html =~ "Foundations: Foundations Assessment"

    # Instructor Dashboard Content tab: "Data Analysis" shows the same renumbered
    # display index (1) that Learn and decorated_numbering_map/1 already agreed on.
    {:ok, content_view, _html} =
      live(
        conn,
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
          section.slug,
          :insights,
          :content,
          %{container_filter_by: :units}
        )
      )

    rows =
      content_view
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.find(~s{.instructor_dashboard_table tbody tr})

    order_and_name =
      Enum.map(rows, fn row ->
        order = row |> Floki.find("td:first-child") |> Floki.text() |> String.trim()
        name = row |> Floki.find("td a") |> Floki.text() |> String.trim()
        {order, name}
      end)

    assert {"", "Foundations"} in order_and_name
    assert {"1", "Data Analysis"} in order_and_name
  end
end
