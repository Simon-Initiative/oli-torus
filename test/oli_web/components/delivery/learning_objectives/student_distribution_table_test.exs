defmodule OliWeb.Components.Delivery.LearningObjectives.StudentDistributionTableTest do
  use OliWeb.ConnCase, async: true

  import LiveComponentTests
  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.LearningObjectives.StudentDistributionTable

  describe "StudentDistributionTable" do
    test "renders the group title, student count, and guidance copy for each group", %{
      conn: conn
    } do
      for {group, expected_title} <- [
            {:needs_support, "Needs Support"},
            {:excelling, "Excelling"},
            {:limited_activity, "Limited Activity"}
          ] do
        students = one_of_each_proficiency(group)

        {:ok, view, _html} =
          render_table(conn, %{
            id: "student-distribution-table",
            students: students,
            selected_group: group,
            parent_target: nil
          })

        assert has_element?(view, "h4", expected_title)
        assert has_element?(view, "span[aria-label='#{length(students)} students']")
        assert render(view) =~ guidance_snippet(group)
      end
    end

    test "filters rows to only the selected group", %{conn: conn} do
      students =
        one_of_each_proficiency(:limited_activity) ++
          [student("Excelling Student", :excelling, "High")]

      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: students,
          selected_group: :limited_activity,
          parent_target: nil
        })

      refute has_element?(view, "td", "Excelling Student")
      assert has_element?(view, "span[aria-label='4 students']")
    end

    test "defaults to low-proficiency-first sort for Needs Support", %{conn: conn} do
      assert_default_sort_order(conn, :needs_support, [
        "Low Student",
        "Medium Student",
        "High Student",
        "Not Enough Student"
      ])
    end

    test "defaults to medium-proficiency-first sort for Excelling", %{conn: conn} do
      assert_default_sort_order(conn, :excelling, [
        "Medium Student",
        "High Student",
        "Low Student",
        "Not Enough Student"
      ])
    end

    test "defaults to Not Enough Info, Low, Medium, High order for Limited Activity", %{
      conn: conn
    } do
      assert_default_sort_order(conn, :limited_activity, [
        "Not Enough Student",
        "Low Student",
        "Medium Student",
        "High Student"
      ])
    end

    test "the proficiency filter narrows the visible rows", %{conn: conn} do
      students = one_of_each_proficiency(:limited_activity)

      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: students,
          selected_group: :limited_activity,
          parent_target: nil
        })

      assert has_element?(view, "td", "Not Enough Student")
      assert has_element?(view, "td", "Low Student")

      # Goes through the real `<form>`-based serialization path (not an explicit params
      # override), regression coverage for the filter having previously lived on a bare
      # `<select phx-change=...>` outside any `<form>`, which never actually fired.
      view
      |> form("form", %{"proficiency" => "low"})
      |> render_change()

      assert has_element?(view, "td", "Low Student")
      refute has_element?(view, "td", "Not Enough Student")
      refute has_element?(view, "td", "Medium Student")
      refute has_element?(view, "td", "High Student")
    end

    test "an empty proficiency-filtered result shows an empty-state message, not an empty table",
         %{conn: conn} do
      students = [student("Low Student", :limited_activity, "Low")]

      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: students,
          selected_group: :limited_activity,
          parent_target: nil
        })

      view
      |> form("form", %{"proficiency" => "high"})
      |> render_change()

      refute has_element?(view, "table")
      assert has_element?(view, "[data-role='empty-group-message']")
    end

    test "a group with zero students shows an empty-state message instead of an empty table",
         %{conn: conn} do
      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: [student("Excelling Student", :excelling, "High")],
          selected_group: :limited_activity,
          parent_target: nil
        })

      refute has_element?(view, "table")
      assert has_element?(view, "[data-role='empty-group-message']")
      assert has_element?(view, "span[aria-label='0 students']")
      # No proficiency filter is offered for a group with nothing to filter.
      refute has_element?(view, "select")
    end

    test "switching groups resets in-flight sort, filter, and pagination state", %{conn: conn} do
      students = one_of_each_proficiency(:needs_support) ++ one_of_each_proficiency(:excelling)

      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: students,
          selected_group: :needs_support,
          parent_target: nil
        })

      # Re-sort by Student Name (not the default proficiency sort) and narrow the filter to
      # "Low", both local state on the currently-selected group.
      view
      |> element("button[phx-value-sort_by='student_name']")
      |> render_click()

      view
      |> form("form", %{"proficiency" => "low"})
      |> render_change()

      assert has_element?(view, "td", "Low Student")
      refute has_element?(view, "td", "Medium Student")

      # Switching to a different group (simulating the parent re-selecting a group) must not
      # carry over the previous group's sort column, sort order, or proficiency filter.
      LiveComponentTests.Driver.run(view, fn socket ->
        {:reply, :ok,
         Phoenix.Component.assign(socket,
           lc_attrs: %{
             id: "student-distribution-table",
             students: students,
             selected_group: :excelling,
             parent_target: nil
           }
         )}
      end)

      # The proficiency filter reset to its default (no filter): every label is visible again,
      # not just "Low".
      assert has_element?(view, "td", "Medium Student")
      assert has_element?(view, "td", "High Student")
      assert has_element?(view, "td", "Not Enough Student")

      # The new group's own default sort (medium-first for Excelling) applies, not the
      # leftover "Student Name" sort from before the switch.
      assert List.first(rendered_row_names(view)) == "Medium Student"
    end

    test "Load More appends rows without dropping or duplicating previously loaded ones", %{
      conn: conn
    } do
      students = many_limited_activity_students(25)

      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: students,
          selected_group: :limited_activity,
          parent_target: nil
        })

      assert has_element?(view, "[data-role='load-more']", "Load 5 more (5 remaining)")
      assert length(rendered_row_names(view)) == 20

      view
      |> element("[data-role='load-more']")
      |> render_click()

      refute has_element?(view, "[data-role='load-more']")
      row_names = rendered_row_names(view)
      assert length(row_names) == 25
      assert length(Enum.uniq(row_names)) == 25
    end

    test "rows alternate between the two striping tokens instead of sharing one color", %{
      conn: conn
    } do
      students = many_limited_activity_students(4)

      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: students,
          selected_group: :limited_activity,
          parent_target: nil
        })

      row_classes =
        view
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("table tbody tr")
        |> Enum.map(&(Floki.attribute(&1, "class") |> List.first()))

      assert Enum.at(row_classes, 0) =~ "bg-Table-table-row-1"
      assert Enum.at(row_classes, 1) =~ "bg-Table-table-row-2"
      assert Enum.at(row_classes, 2) =~ "bg-Table-table-row-1"
      assert Enum.at(row_classes, 3) =~ "bg-Table-table-row-2"
    end

    test "clicking the Student Name header actually reorders rows by name", %{conn: conn} do
      students = [
        student("Charlie", :limited_activity, "Low"),
        student("Alice", :limited_activity, "Low"),
        student("Bob", :limited_activity, "Low")
      ]

      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: students,
          selected_group: :limited_activity,
          parent_target: nil
        })

      view
      |> element("button[phx-value-sort_by='student_name']")
      |> render_click()

      assert rendered_row_names(view) == ["Alice", "Bob", "Charlie"]

      # Clicking the same header again reverses the order.
      view
      |> element("button[phx-value-sort_by='student_name']")
      |> render_click()

      assert rendered_row_names(view) == ["Charlie", "Bob", "Alice"]
    end

    test "row checkboxes toggle individual selection, independent of other rows", %{conn: conn} do
      students = one_of_each_proficiency(:limited_activity)

      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: students,
          selected_group: :limited_activity,
          parent_target: nil
        })

      [low_student] = Enum.filter(students, &(&1.full_name == "Low Student"))

      refute has_element?(view, "input[type='checkbox'][checked]")

      view
      |> element("input[phx-value-student_id='#{low_student.id}']")
      |> render_click()

      assert view
             |> element("input[phx-value-student_id='#{low_student.id}']")
             |> render() =~ "checked"

      # Unrelated rows remain unchecked.
      [medium_student] = Enum.filter(students, &(&1.full_name == "Medium Student"))

      refute view
             |> element("input[phx-value-student_id='#{medium_student.id}']")
             |> render() =~ "checked"

      # Clicking again deselects it.
      view
      |> element("input[phx-value-student_id='#{low_student.id}']")
      |> render_click()

      refute view
             |> element("input[phx-value-student_id='#{low_student.id}']")
             |> render() =~ "checked"
    end

    test "select-all selects every filtered student, and toggles all off when already fully selected",
         %{conn: conn} do
      students = one_of_each_proficiency(:limited_activity)

      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: students,
          selected_group: :limited_activity,
          parent_target: nil
        })

      select_all = element(view, "th input[type='checkbox']")

      render_click(select_all)

      Enum.each(students, fn s ->
        assert view
               |> element("input[phx-value-student_id='#{s.id}']")
               |> render() =~ "checked"
      end)

      render_click(select_all)

      Enum.each(students, fn s ->
        refute view
               |> element("input[phx-value-student_id='#{s.id}']")
               |> render() =~ "checked"
      end)
    end

    test "renders a per-group left accent border and a matching header count badge color", %{
      conn: conn
    } do
      for {group, accent_border_class, badge_bg_class, badge_text_class} <- [
            {:needs_support, "border-l-Border-border-danger", "bg-Fill-fill-danger",
             "text-Text-text-danger"},
            {:excelling, "border-l-Text-text-accent-green", "bg-Fill-Chip-Green",
             "text-Text-text-accent-green"},
            {:limited_activity, "border-l-Text-text-high", "bg-Fill-Chip-Gray",
             "text-Text-Chip-Gray"}
          ] do
        {:ok, view, _html} =
          render_table(conn, %{
            id: "student-distribution-table",
            students: one_of_each_proficiency(group),
            selected_group: group,
            parent_target: nil
          })

        html = render(view)
        assert html =~ accent_border_class
        assert html =~ badge_bg_class
        assert html =~ badge_text_class
      end
    end

    test "renders the Student Name / Proficiency / Activities column headers and the activities cell as '<attempted> of <total> (<pct>%)'",
         %{conn: conn} do
      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: [student("Low Student", :limited_activity, "Low")],
          selected_group: :limited_activity,
          parent_target: nil
        })

      assert has_element?(view, "th", "Student Name")
      assert has_element?(view, "th", "Proficiency")
      assert has_element?(view, "th", "Activities")
      refute has_element?(view, "th", "Learning Proficiency")
      refute has_element?(view, "th", "Activity Completion")

      assert has_element?(view, "td", "1 of 9 (11%)")
    end

    test "Proficiency and Activities headers carry an info tooltip; Student Name does not", %{
      conn: conn
    } do
      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: [student("Low Student", :limited_activity, "Low")],
          selected_group: :limited_activity,
          parent_target: nil
        })

      html = render(view)

      assert html =~
               "Proficiency is based on the percentage of correct answers on first attempts"

      assert html =~ "The number of activities linked to this learning objective"

      student_name_th =
        view
        |> element("th", "Student Name")
        |> render()

      refute student_name_th =~ "role=\"tooltip\""
    end

    test "the header tooltip trigger is a focusable button whose aria-describedby points to a real tooltip element",
         %{conn: conn} do
      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: [student("Low Student", :limited_activity, "Low")],
          selected_group: :limited_activity,
          parent_target: nil
        })

      proficiency_th =
        view
        |> element("th", "Proficiency")
        |> render()
        |> Floki.parse_fragment!()

      [button] = Floki.find(proficiency_th, "button[aria-describedby]")
      [tooltip_id] = Floki.attribute(button, "aria-describedby")

      assert has_element?(view, "##{tooltip_id}[role='tooltip']")
    end

    test "the proficiency filter dropdown's default option reads 'Proficiency'", %{conn: conn} do
      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: one_of_each_proficiency(:limited_activity),
          selected_group: :limited_activity,
          parent_target: nil
        })

      assert has_element?(view, "option[value='all']", "Proficiency")
      refute has_element?(view, "option", "All")
    end

    test "the close control targets the parent component, not this component's own myself", %{
      conn: conn
    } do
      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: one_of_each_proficiency(:needs_support),
          selected_group: :needs_support,
          parent_target: "parent-target-placeholder"
        })

      assert view
             |> element("button[aria-label='Close Needs Support student list']")
             |> render()
             |> Floki.parse_fragment!()
             |> Floki.attribute("phx-target") == ["parent-target-placeholder"]
    end

    test "the Email button is disabled until a student is selected", %{conn: conn} do
      students = one_of_each_proficiency(:needs_support)

      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: students,
          selected_group: :needs_support,
          parent_target: nil
        })

      assert has_element?(view, "button[disabled]", "Email")

      [student | _] = students

      view
      |> element("input[phx-value-student_id='#{student.id}']")
      |> render_click()

      refute has_element?(view, "button[disabled]", "Email")
    end

    test "the Copy email addresses action carries the comma-separated emails of the selected students",
         %{conn: conn} do
      students = [
        student_with_email("Low Student", :needs_support, "Low", "low@example.com"),
        student_with_email("Medium Student", :needs_support, "Medium", "medium@example.com")
      ]

      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: students,
          selected_group: :needs_support,
          parent_target: nil
        })

      Enum.each(students, fn s ->
        view
        |> element("input[phx-value-student_id='#{s.id}']")
        |> render_click()
      end)

      assert view
             |> element("button[data-copy-text]")
             |> render() =~ "low@example.com, medium@example.com"
    end

    test "the Email button opens the modal with a payload matching the selected group, objective, and selection",
         %{conn: conn} do
      students = [
        student_with_email("Low Student", :needs_support, "Low", "low@example.com"),
        student("No Email Student", :needs_support, "Medium")
      ]

      {:ok, view, _html} =
        render_table(conn, %{
          id: "student-distribution-table",
          students: students,
          selected_group: :needs_support,
          parent_target: nil,
          section_id: 123,
          section_slug: "sec-slug",
          section_title: "Course 1",
          objective_title: "Objective A",
          instructor_email: "instructor@example.com",
          instructor_name: "Ms. Instructor"
        })

      Enum.each(students, fn s ->
        view
        |> element("input[phx-value-student_id='#{s.id}']")
        |> render_click()
      end)

      test_pid = self()

      LiveComponentTests.live_component_intercept(view, fn
        {:show_email_modal, caller_assigns}, socket ->
          send(test_pid, {:captured_payload, caller_assigns.email_modal_payload})
          {:halt, socket}

        _other, socket ->
          {:cont, socket}
      end)

      view
      |> element("button", "Send email")
      |> render_click()

      assert_receive {:captured_payload, payload}

      assert payload.section_id == 123
      assert payload.section_slug == "sec-slug"
      assert payload.section_title == "Course 1"
      assert payload.instructor_email == "instructor@example.com"
      assert payload.instructor_name == "Ms. Instructor"
      assert payload.situation_key == :struggling_students
      assert payload.scope_label == "Needs Support"
      assert payload.objective == %{title: "Objective A", proficiency_label: "Needs Support"}

      assert Enum.map(payload.students, & &1.display_name) |> Enum.sort() ==
               ["Low Student", "No Email Student"]
    end
  end

  defp assert_default_sort_order(conn, group, expected_names) do
    students = one_of_each_proficiency(group)

    {:ok, view, _html} =
      render_table(conn, %{
        id: "student-distribution-table",
        students: students,
        selected_group: group,
        parent_target: nil
      })

    assert rendered_row_names(view) == expected_names
  end

  # `StudentDistributionTable` requires the email-related assigns; most tests here don't
  # exercise that flow, so this centralizes innocuous defaults instead of repeating them
  # at every call site. Tests that do exercise the email flow override what they need.
  defp render_table(conn, attrs) do
    live_component_isolated(conn, StudentDistributionTable, Map.merge(email_defaults(), attrs))
  end

  defp email_defaults do
    %{
      section_id: 1,
      section_slug: "sec",
      section_title: "Section",
      objective_title: "Objective",
      instructor_email: "instructor@example.edu",
      instructor_name: "Instructor"
    }
  end

  defp rendered_row_names(view) do
    view
    |> render()
    |> Floki.parse_fragment!()
    # The name cell also renders an avatar (initials fallback); scope to the name `<span>`
    # itself rather than the whole cell so avatar initials text doesn't leak into the result.
    |> Floki.find("table tbody tr td:nth-child(2) span")
    |> Enum.map(&(Floki.text(&1) |> String.trim()))
  end

  defp one_of_each_proficiency(group) do
    [
      student("Not Enough Student", group, "Not enough data"),
      student("Low Student", group, "Low"),
      student("Medium Student", group, "Medium"),
      student("High Student", group, "High")
    ]
  end

  defp many_limited_activity_students(count) do
    Enum.map(1..count, fn i ->
      student("Student #{i}", :limited_activity, "Low", i)
    end)
  end

  defp student(full_name, group, proficiency_range, id \\ System.unique_integer([:positive])) do
    %{
      id: id,
      full_name: full_name,
      proficiency_range: proficiency_range,
      proficiency: 0.1,
      activity_completion: 1 / 9,
      activities_attempted_count: 1,
      total_related_activities: 9,
      distribution_group: group
    }
  end

  defp student_with_email(full_name, group, proficiency_range, email) do
    student(full_name, group, proficiency_range)
    |> Map.put(:email, email)
  end

  defp guidance_snippet(:needs_support), do: "reach out to students to offer support"
  defp guidance_snippet(:excelling), do: "likely to apply this objective"
  defp guidance_snippet(:limited_activity), do: "fewer activities related to this learning"
end
