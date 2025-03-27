defmodule OliWeb.NewCourse.CourseDetailsTest do
  use ExUnit.Case, async: true
  alias Oli.Delivery.Sections
  use OliWeb.ConnCase

  import Ecto.Query, warn: false
  import Phoenix.LiveViewTest

  @live_view_admin_route Routes.select_source_path(OliWeb.Endpoint, :admin)
  @live_view_independent_learner_route Routes.select_source_path(
                                         OliWeb.Endpoint,
                                         :independent_learner
                                       )
  @live_view_lms_instructor_route Routes.select_source_path(OliWeb.Endpoint, :lms_instructor)

  describe "Admin - Course Details" do
    setup [:admin_conn]

    @tag :skip
    test "renders the \"course details\" form", %{conn: conn} = context do
      %{section: section} = create_source(context)
      {:ok, view, _html} = live(conn, @live_view_admin_route)

      select_source(:admin, view, section)
      complete_course_name_form(view)

      assert has_element?(view, "h2", "Course details")
      assert has_element?(view, "input[type=\"checkbox\"]#sunday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#monday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#tuesday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#wednesday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#thursday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#friday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#saturday_radio_button")
      assert has_element?(view, "input[type=\"datetime-local\"]#section_start_date")
      assert has_element?(view, "input[type=\"datetime-local\"]#section_end_date")
      assert has_element?(view, "input[type=\"time\"]#section_preferred_scheduling_time")
    end

    @tag :skip
    test "doesn't render the class days if class never meets", %{conn: conn} = context do
      %{section: section} = create_source(context)
      {:ok, view, _html} = live(conn, @live_view_admin_route)

      select_source(:admin, view, section)
      complete_course_name_form(view, %{class_modality: :never})

      assert has_element?(view, "h2", "Course details")
      refute has_element?(view, "input[type=\"checkbox\"]#sunday_radio_button")
      refute has_element?(view, "input[type=\"checkbox\"]#monday_radio_button")
      refute has_element?(view, "input[type=\"checkbox\"]#tuesday_radio_button")
      refute has_element?(view, "input[type=\"checkbox\"]#wednesday_radio_button")
      refute has_element?(view, "input[type=\"checkbox\"]#thursday_radio_button")
      refute has_element?(view, "input[type=\"checkbox\"]#friday_radio_button")
      refute has_element?(view, "input[type=\"checkbox\"]#saturday_radio_button")
      assert has_element?(view, "input[type=\"datetime-local\"]#section_start_date")
      assert has_element?(view, "input[type=\"datetime-local\"]#section_end_date")
      assert has_element?(view, "input[type=\"time\"]#section_preferred_scheduling_time")
    end

    @tag :skip
    test "can't go to next step unless all required fields are filled and valid",
         %{conn: conn} = context do
      %{section: section} = create_source(context)
      {:ok, view, _html} = live(conn, @live_view_admin_route)

      select_source(:admin, view, section)
      complete_course_name_form(view)

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{"section" => %{}, "current_step" => 3})

      assert has_element?(view, ".alert-danger", "Some fields require your attention")

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{
        "section" => %{
          class_days: [:monday, :friday],
          start_date: DateTime.add(DateTime.utc_now(), 4, :day),
          end_date: DateTime.add(DateTime.utc_now(), 2, :day),
          preferred_scheduling_time: ~T[23:59:59]
        },
        "current_step" => 3
      })

      assert has_element?(
               view,
               ".alert-danger",
               "The course's start date must be earlier than its end date"
             )
    end

    @tag :skip
    test "successfully creates a section from a project publication", %{conn: conn} = context do
      %{publication: publication} = create_source(context, %{type: :enrollable})
      {:ok, view, _html} = live(conn, @live_view_admin_route)

      select_source(:admin, view, publication)
      complete_course_name_form(view, %{title: "New admin course"})

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{
        "section" => %{
          class_days: [:monday, :friday],
          start_date: "2024-09-10T18:19",
          end_date: "2024-09-18T18:19",
          preferred_scheduling_time: "23:59:59"
        },
        "current_step" => 3
      })

      wait_for_completion()

      assert %{"info" => "Section successfully created."} ==
               assert_redirect(view, ~p"/sections/new_admin_course")
    end

    @tag :skip
    test "successfully creates a section from a product", %{conn: conn} = context do
      %{section: section} = create_source(context, %{type: :blueprint})
      {:ok, view, _html} = live(conn, @live_view_admin_route)

      select_source(:admin, view, section)
      complete_course_name_form(view, %{title: "New admin course"})

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{
        "section" => %{
          class_days: [:monday, :friday],
          start_date: "2024-09-10T18:19",
          end_date: "2024-09-18T18:19",
          preferred_scheduling_time: "23:59:59"
        },
        "current_step" => 3
      })

      wait_for_completion()

      assert %{"info" => "Section successfully created."} ==
               assert_redirect(view, ~p"/sections/new_admin_course")
    end
  end

  describe "Instructor - Course Details" do
    setup [:instructor_conn]

    @tag :skip
    test "renders the \"course details\" form", %{conn: conn} = context do
      %{section: section} = create_source(context)
      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      select_source(:instructor, view, section)
      complete_course_name_form(view)

      assert has_element?(view, "h2", "Course details")
      assert has_element?(view, "input[type=\"checkbox\"]#sunday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#monday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#tuesday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#wednesday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#thursday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#friday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#saturday_radio_button")
      assert has_element?(view, "input[type=\"datetime-local\"]#section_start_date")
      assert has_element?(view, "input[type=\"datetime-local\"]#section_end_date")
      assert has_element?(view, "input[type=\"time\"]#section_preferred_scheduling_time")
    end

    test "can't go to next step unless all required fields are filled", %{conn: conn} = context do
      %{section: section} = create_source(context)
      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      select_source(:instructor, view, section)
      complete_course_name_form(view)

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{"section" => %{}, "current_step" => 3})

      assert has_element?(view, ".alert-danger", "Some fields require your attention")
    end

    @tag :skip
    test "successfully creates a section from a project publication", %{conn: conn} = context do
      %{publication: publication} = create_source(context, %{type: :enrollable})
      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      select_source(:instructor, view, publication)
      complete_course_name_form(view, %{title: "New instructor course"})

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{
        "section" => %{
          class_days: [:monday, :friday],
          start_date: "2024-09-10T18:19",
          end_date: "2024-09-18T18:19",
          preferred_scheduling_time: "23:59:59"
        },
        "current_step" => 3
      })

      wait_for_completion()

      assert %{"info" => "Section successfully created."} ==
               assert_redirect(view, ~p"/sections/new_instructor_course")
    end

    @tag :skip
    test "successfully creates a section from a product", %{conn: conn} = context do
      %{section: section} = create_source(context, %{type: :blueprint})
      {:ok, view, _html} = live(conn, @live_view_independent_learner_route)

      select_source(:instructor, view, section)
      complete_course_name_form(view, %{title: "New instructor course"})

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{
        "section" => %{
          class_days: [:monday, :friday],
          start_date: "2024-09-10T18:19",
          end_date: "2024-09-18T18:19",
          preferred_scheduling_time: "23:59:59"
        },
        "current_step" => 3
      })

      wait_for_completion()

      assert %{"info" => "Section successfully created."} ==
               assert_redirect(view, ~p"/sections/new_instructor_course")
    end
  end

  describe "LMS - Course Details" do
    setup [:lms_instructor_conn]

    @tag :skip
    test "renders the \"course details\" form", %{conn: conn} = context do
      %{section: section} = create_source(context)
      {:ok, view, _html} = live(conn, @live_view_lms_instructor_route)

      select_source(:instructor, view, section)
      complete_course_name_form(view)

      assert has_element?(view, "h2", "Course details")
      assert has_element?(view, "input[type=\"checkbox\"]#sunday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#monday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#tuesday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#wednesday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#thursday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#friday_radio_button")
      assert has_element?(view, "input[type=\"checkbox\"]#saturday_radio_button")
      assert has_element?(view, "input[type=\"datetime-local\"]#section_start_date")
      assert has_element?(view, "input[type=\"datetime-local\"]#section_end_date")
      assert has_element?(view, "input[type=\"time\"]#section_preferred_scheduling_time")
    end

    @tag :skip
    test "can't go to next step unless all required fields are filled", %{conn: conn} = context do
      %{section: section} = create_source(context)
      {:ok, view, _html} = live(conn, @live_view_lms_instructor_route)

      select_source(:instructor, view, section)
      complete_course_name_form(view)

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{"section" => %{}, "current_step" => 3})

      assert has_element?(view, ".alert-danger", "Some fields require your attention")
    end

    @tag :skip
    test "successfully creates a section from a project publication", %{conn: conn} = context do
      %{publication: publication} = create_source(context, %{type: :enrollable})
      {:ok, view, _html} = live(conn, @live_view_lms_instructor_route)

      select_source(:lms_instructor, view, publication)
      complete_course_name_form(view, %{title: "New LMS course"})

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{
        "section" => %{
          class_days: [:monday, :friday],
          start_date: DateTime.add(DateTime.utc_now(), 2, :day),
          end_date: DateTime.add(DateTime.utc_now(), 62, :day)
        },
        "current_step" => 3
      })

      wait_for_completion()

      assert %{"info" => "Section successfully created."} == assert_redirect(view, ~p"/sections")
    end

    @tag :skip
    test "successfully creates a section from a product", %{conn: conn} = context do
      %{section: section} =
        create_source(context, %{type: :blueprint, contains_explorations: true})

      {:ok, view, _html} = live(conn, @live_view_lms_instructor_route)

      select_source(:instructor, view, section)
      complete_course_name_form(view, %{title: "New LMS course"})

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{
        "section" => %{
          class_days: [:monday, :friday],
          start_date: "2024-09-10T18:19",
          end_date: "2024-09-18T18:19",
          preferred_scheduling_time: "23:59:59"
        },
        "current_step" => 3
      })

      blueprint_section =
        Oli.Delivery.Sections.Section
        |> where([s], s.blueprint_id == ^section.id)
        |> Oli.Repo.one()

      wait_for_completion()

      assert blueprint_section.contains_explorations == true

      assert %{"info" => "Section successfully created."} == assert_redirect(view, ~p"/sections")
    end

    @tag :skip
    test "creates a section with analytics_version :v2 ", %{conn: conn} = context do
      # Factory has a default analytics_version ==  :v1
      %{section: section} = create_source(context)

      {:ok, view, _html} = live(conn, @live_view_lms_instructor_route)

      {:ok, section} = Sections.update_section(section, %{type: :blueprint})

      select_source(:lms_instructor_conn, view, section)

      complete_course_name_form(view)

      view
      |> element("#open_and_free_form")
      |> render_hook("js_form_data_response", %{
        "section" => %{
          class_days: [:monday, :friday],
          start_date: "2024-09-10T18:19",
          end_date: "2024-09-18T18:19",
          preferred_scheduling_time: "23:59:59"
        },
        "current_step" => 3
      })

      # Wait until TaskSupervisor completes to create section
      wait_for_completion()

      assert [:v2] ==
               Oli.Repo.all(Sections.Section)
               |> Enum.filter(&(&1.id != section.id))
               |> Enum.map(& &1.analytics_version)
    end
  end

  defp select_source(:admin, view, source) do
    view
    |> element("tr:first-child button[phx-click=\"source_selection\"]")
    |> render_click(%{
      id:
        "#{if Map.get(source, :type) == :blueprint, do: "product", else: "publication"}:#{Map.get(source, :id) || Map.get(source, :publication_id)}"
    })

    view
    |> Phoenix.LiveViewTest.element("button", "Next step")
    |> Phoenix.LiveViewTest.render_click()
  end

  defp select_source(_, view, source) do
    view
    |> Phoenix.LiveViewTest.element(".card-deck a:first-child")
    |> render_click(%{
      id:
        "#{if Map.get(source, :type) == :blueprint, do: "product", else: "publication"}:#{Map.get(source, :id) || Map.get(source, :publication_id)}"
    })

    view
    |> Phoenix.LiveViewTest.element("button", "Next step")
    |> Phoenix.LiveViewTest.render_click()
  end

  defp complete_course_name_form(view, attrs \\ %{}) do
    view
    |> Phoenix.LiveViewTest.element("#open_and_free_form")
    |> Phoenix.LiveViewTest.render_hook("js_form_data_response", %{
      "section" =>
        Map.merge(
          %{
            title: "New Course",
            course_section_number: "1234",
            class_modality: :online
          },
          attrs
        ),
      "current_step" => 2
    })
  end

  defp create_source(type, attrs \\ %{})

  defp create_source(%{admin: _admin}, attrs),
    do: basic_section(nil, Map.merge(%{open_and_free: true}, attrs))

  defp create_source(_, attrs) do
    basic_section(nil, attrs)
  end
end
