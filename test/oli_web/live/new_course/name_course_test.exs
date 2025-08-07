defmodule OliWeb.NewCourse.NameCourseTest do
  use ExUnit.Case, async: true
  use OliWeb.ConnCase

  alias Oli.Publishing.Publications.Publication

  import Phoenix.LiveViewTest
  import Oli.Factory

  describe "Admin - Name your course" do
    setup [:admin_conn, :create_sources]

    test "renders the \"name your course\" form", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, ~p"/admin/sections/create")

      select_section(:admin, view, section)

      assert has_element?(view, "h2", "Name your course")
      assert has_element?(view, "input#section_title")
      assert has_element?(view, "input#section_course_section_number")
      assert has_element?(view, "input#in_person_radio_button")
      assert has_element?(view, "input#online_radio_button")
      assert has_element?(view, "input#hybrid_radio_button")
      assert has_element?(view, "input#never_radio_button")
      assert has_element?(view, "button", "Cancel")
    end

    test "can't go to next step unless all required fields are filled", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/sections/create")

      select_section(:admin, view, section)

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{"section" => %{}, "current_step" => 2})

      assert has_element?(view, ".alert-danger", "Some fields require your attention")
    end

    test "moves to the next step once all required fields are filled", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/sections/create")

      select_section(:admin, view, section)

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{
        "section" => %{
          title: "Test Title",
          course_section_number: "1234",
          class_modality: :online
        },
        "current_step" => 2
      })

      refute has_element?(view, "h2", "Name your course")
      refute has_element?(view, ".alert-danger", "Some fields require your attention")
      assert has_element?(view, "h2", "Course details")
    end
  end

  describe "Instructor - Name your course" do
    setup [:instructor_conn, :create_sources]

    test "renders the \"name your course\" form", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, ~p"/sections/new")

      select_section(:instructor, view, section)

      assert has_element?(view, "h2", "Name your course")
      assert has_element?(view, "input#section_title")
      assert has_element?(view, "input#section_course_section_number")
      assert has_element?(view, "input#in_person_radio_button")
      assert has_element?(view, "input#online_radio_button")
      assert has_element?(view, "input#hybrid_radio_button")
      assert has_element?(view, "input#never_radio_button")
      assert has_element?(view, "button", "Cancel")
    end

    test "can't go to next step unless all required fields are filled and correct", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, ~p"/sections/new")

      select_section(:instructor, view, section)

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{"section" => %{}, "current_step" => 2})

      assert has_element?(view, ".alert-danger", "Some fields require your attention")

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{
        "section" => %{
          title: "Test Title",
          course_section_number: "  ",
          class_modality: :online
        },
        "current_step" => 2
      })

      assert has_element?(view, ".alert-danger", "Some fields require your attention")
    end

    test "moves to the next step once all required fields are filled", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, ~p"/sections/new")

      select_section(:instructor, view, section)

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{
        "section" => %{
          title: "Test Title",
          course_section_number: "1234",
          class_modality: :online
        },
        "current_step" => 2
      })

      refute has_element?(view, "h2", "Name your course")
      refute has_element?(view, ".alert-danger", "Some fields require your attention")
      assert has_element?(view, "h2", "Course details")
    end
  end

  describe "LMS - Name your course" do
    setup [:lms_instructor_conn, :create_sources]

    test "renders the \"name your course\" form", %{conn: conn, section: section} do
      {:ok, view, _html} = live(conn, ~p"/sections/new")

      select_section(:lms, view, section)

      assert has_element?(view, "h2", "Name your course")
      assert has_element?(view, "input#section_title")
      assert has_element?(view, "input#section_course_section_number")
      assert has_element?(view, "input#in_person_radio_button")
      assert has_element?(view, "input#online_radio_button")
      assert has_element?(view, "input#hybrid_radio_button")
      assert has_element?(view, "input#never_radio_button")
      assert has_element?(view, "button", "Cancel")
    end

    test "can't go to next step unless all required fields are filled", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, ~p"/sections/new")

      select_section(:lms, view, section)

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{"section" => %{}, "current_step" => 2})

      assert has_element?(view, ".alert-danger", "Some fields require your attention")
    end

    test "moves to the next step once all required fields are filled", %{
      conn: conn,
      section: section
    } do
      {:ok, view, _html} = live(conn, ~p"/sections/new")

      select_section(:lms, view, section)

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{
        "section" => %{
          title: "Test Title",
          course_section_number: "1234",
          class_modality: :online
        },
        "current_step" => 2
      })

      refute has_element?(view, "h2", "Name your course")
      refute has_element?(view, ".alert-danger", "Some fields require your attention")
      assert has_element?(view, "h2", "Course details")
    end
  end

  defp select_section(:admin, view, section) do
    view
    |> element("tr:first-child button[phx-click=\"source_selection\"]")
    |> render_click(%{id: "publication:#{section.id}"})

    view
    |> Phoenix.LiveViewTest.element("button", "Next step")
    |> Phoenix.LiveViewTest.render_click()
  end

  defp select_section(_, view, section) do
    view
    |> Phoenix.LiveViewTest.element(".card-deck a:first-child")
    |> Phoenix.LiveViewTest.render_click(id: "publication:#{section.id}")

    view
    |> Phoenix.LiveViewTest.element("button", "Next step")
    |> Phoenix.LiveViewTest.render_click()
  end

  defp create_sources(_) do
    %Publication{project: project} = insert(:publication)
    section = insert(:section, base_project: project, open_and_free: true)

    {:ok, project: project, section: section}
  end
end
