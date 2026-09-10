defmodule OliWeb.Delivery.InstructorDashboard.Insights.LoAggregationUiTest do
  @moduledoc """
  Verifies parent Learning Objective proficiency aggregation end to end,
  through the real Instructor Dashboard Learning Objectives tab, the
  per-student instructor view, and the CSV export -- not just the Metrics
  functions in isolation.

  The course, section, enrollments, and student attempts are all seeded by
  `Oli.Scenarios` (see the scenario file below), which exercises the real
  attempt-submission pipeline rather than inserting ResourceSummary rows
  directly.
  """

  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Oli.Scenarios
  alias Oli.Scenarios.TestSupport

  @scenario_path Path.join(
                   File.cwd!(),
                   "test/scenarios/instructor_dashboard/lo_aggregation_weighted_and_combined.scenario.yaml"
                 )

  defp learning_objectives_route(section_slug, params \\ %{}) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      section_slug,
      :insights,
      :learning_objectives,
      params
    )
  end

  defp student_dashboard_route(section_slug, student_id, tab, params \\ %{}) do
    Routes.live_path(
      OliWeb.Endpoint,
      OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
      section_slug,
      student_id,
      tab,
      params
    )
  end

  setup %{conn: conn} do
    result = TestSupport.execute_file_with_fixtures(@scenario_path)

    assert result.errors == []
    assert Enum.all?(result.verifications, & &1.passed)

    section = Scenarios.get_section(result, "lo_aggregation_ui_section")
    instructor = Scenarios.get_user(result, "lo_ui_instructor")
    student = Scenarios.get_user(result, "lo_ui_student")
    project = Scenarios.get_project(result, "lo_aggregation_ui_project")

    %{
      conn: log_in_user(conn, instructor),
      section: section,
      student: student,
      weighted_parent_resource_id: project.objectives_by_title["Weighted Parent"].resource_id,
      combined_parent_resource_id: project.objectives_by_title["Combined Parent"].resource_id
    }
  end

  describe "Instructor Dashboard Learning Objectives tab" do
    test "shows the parent's proficiency as the count-weighted average of its Sub-LOs, with no evidence of its own",
         %{conn: conn, section: section, weighted_parent_resource_id: weighted_parent_resource_id} do
      {:ok, view, _html} = live(conn, learning_objectives_route(section.slug))

      row =
        view
        |> element("tr[data-row-id='row_#{weighted_parent_resource_id}']")
        |> render()

      assert row =~ "Weighted Parent"
      assert row =~ "High"
    end

    test "shows the parent's proficiency as its own evidence combined with its Sub-LO's evidence",
         %{conn: conn, section: section, combined_parent_resource_id: combined_parent_resource_id} do
      {:ok, view, _html} = live(conn, learning_objectives_route(section.slug))

      row =
        view
        |> element("tr[data-row-id='row_#{combined_parent_resource_id}']")
        |> render()

      assert row =~ "Combined Parent"
      assert row =~ "Medium"
    end
  end

  describe "per-student instructor view Learning Objectives tab" do
    test "shows the same combined proficiency values as the Instructor Dashboard tab", %{
      conn: conn,
      section: section,
      student: student,
      weighted_parent_resource_id: weighted_parent_resource_id,
      combined_parent_resource_id: combined_parent_resource_id
    } do
      {:ok, view, _html} =
        live(conn, student_dashboard_route(section.slug, student.id, :learning_objectives))

      # Unlike the Instructor Dashboard tab (`data-row-id="row_<resource_id>"`,
      # one row per top-level objective), the per-student view flattens one
      # row per (objective, subobjective) pair and uses the bare resource_id
      # as `data-row-id`. The row whose subobjective column is "-" is the
      # objective's own aggregated row (student_proficiency_obj); the other
      # rows show each Sub-LO's own individual proficiency, not the parent's
      # aggregate, so only the "-" row is the one to check here.
      weighted_row =
        view
        |> element("tr[data-row-id='#{weighted_parent_resource_id}']")
        |> render()

      combined_row =
        view
        |> element("tr[data-row-id='#{combined_parent_resource_id}']")
        |> render()

      assert weighted_row =~ "High"
      assert combined_row =~ "Medium"
    end
  end

  describe "Learning Objectives CSV export" do
    test "includes the same combined proficiency values as the Instructor Dashboard tab", %{
      conn: conn,
      section: section
    } do
      conn =
        get(
          conn,
          "/sections/#{section.slug}/instructor_dashboard/downloads/learning_objectives"
        )

      csv = response(conn, 200)

      assert csv =~ "Weighted Parent"
      assert csv =~ "Combined Parent"
      assert csv =~ "High"
      assert csv =~ "Medium"
    end
  end
end
