defmodule OliWeb.NewCourse.CourseBuilderTelemetryTest do
  # `async: false`: both tests attach a handler to a global `:telemetry` event bus and assert
  # on what that handler receives (including a `refute_received` for the negative case), which
  # is only safe when no other test running in parallel can emit the same event names.
  use ExUnit.Case, async: false
  use OliWeb.ConnCase

  import Phoenix.LiveViewTest
  import Oli.Factory

  alias Oli.Publishing.Publications.Publication

  describe "telemetry - card activation" do
    setup [:admin_conn]

    test "emits my_course_sections_card_activated only when a My Course Sections source is selected",
         %{conn: conn} do
      handler_id = "my-course-sections-card-telemetry-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:oli, :course_builder, :my_course_sections_card_activated],
        fn event, measurements, metadata, pid ->
          send(pid, {:telemetry_event, event, measurements, metadata})
        end,
        self()
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      %Publication{project: project} = insert(:publication)
      template = insert(:section, base_project: project, title: "Chem Template")
      course = insert(:section, type: :enrollable, base_project: project, title: "Chem Copy")

      {:ok, view, _html} = live(conn, ~p"/admin/sections/create")

      view
      |> element("button[phx-value-id='product:#{template.id}']")
      |> render_click()

      assert has_element?(view, "h2", "Name your course")

      refute_received {:telemetry_event,
                       [:oli, :course_builder, :my_course_sections_card_activated], _, _}

      {:ok, view, _html} = live(conn, ~p"/admin/sections/create")

      view
      |> element("button[phx-value-id='section:#{course.id}']")
      |> render_click()

      assert_received {:telemetry_event,
                       [:oli, :course_builder, :my_course_sections_card_activated], %{count: 1},
                       %{}}
    end
  end

  describe "telemetry - filter selection" do
    setup [:instructor_conn]

    test "emits my_course_sections_filter_selected only when the My Course Sections tab is selected",
         %{conn: conn} do
      handler_id = "my-course-sections-filter-telemetry-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:oli, :course_builder, :my_course_sections_filter_selected],
        fn event, measurements, metadata, pid ->
          send(pid, {:telemetry_event, event, measurements, metadata})
        end,
        self()
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      {:ok, view, _html} = live(conn, ~p"/sections/new")

      view
      |> element("button[aria-pressed]", "Templates")
      |> render_click()

      assert has_element?(view, "button[aria-pressed='true']", "Templates")

      refute_received {:telemetry_event,
                       [:oli, :course_builder, :my_course_sections_filter_selected], _, _}

      view
      |> element("button[aria-pressed]", "My Course Sections")
      |> render_click()

      assert_received {:telemetry_event,
                       [:oli, :course_builder, :my_course_sections_filter_selected], %{count: 1},
                       %{}}
    end
  end
end
