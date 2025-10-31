defmodule OliWeb.Components.Delivery.LearningObjectives.StudentProficiencyListTest do
  use OliWeb.ConnCase, async: true

  import LiveComponentTests
  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.LearningObjectives.StudentProficiencyList

  describe "StudentProficiencyList component" do
    setup %{conn: conn} do
      # Create test data with student proficiency data similar to real component structure
      student_proficiency_data = [
        %{
          id: 1,
          full_name: "Smith, John",
          proficiency: 0.85,
          proficiency_range: "High"
        },
        %{
          id: 2,
          full_name: "Johnson, Alice",
          proficiency: 0.65,
          proficiency_range: "High"
        },
        %{
          id: 3,
          full_name: "Brown, Charlie",
          proficiency: 0.45,
          proficiency_range: "Medium"
        },
        %{
          id: 4,
          full_name: "Davis, Emma",
          proficiency: 0.25,
          proficiency_range: "Low"
        },
        %{
          id: 5,
          full_name: "Wilson, Oliver",
          proficiency: 0.0,
          proficiency_range: "Not enough data"
        }
      ]

      %{
        conn: conn,
        student_proficiency_data: student_proficiency_data
      }
    end

    test "renders correctly with High proficiency students", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Check that the component renders
      assert has_element?(view, "div.w-full")
      assert has_element?(view, "h4", "Students with High Estimated Proficiency")

      # Check that the table is rendered
      assert has_element?(view, "table")
      assert has_element?(view, "tbody tr")

      # Check that only High proficiency students are displayed
      assert has_element?(view, "td", "Smith, John")
      assert has_element?(view, "td", "Johnson, Alice")

      # Check that students with other proficiency levels are not displayed
      # Medium
      refute has_element?(view, "td", "Brown, Charlie")
      # Low
      refute has_element?(view, "td", "Davis, Emma")
      # Not enough data
      refute has_element?(view, "td", "Wilson, Oliver")
    end

    test "renders correctly with Medium proficiency students", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "Medium",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Check header
      assert has_element?(view, "h4", "Students with Medium Estimated Proficiency")

      # Check that only Medium proficiency students are displayed
      assert has_element?(view, "td", "Brown, Charlie")

      # Check that students with other proficiency levels are not displayed
      # High
      refute has_element?(view, "td", "Smith, John")
      # High
      refute has_element?(view, "td", "Johnson, Alice")
      # Low
      refute has_element?(view, "td", "Davis, Emma")
      # Not enough data
      refute has_element?(view, "td", "Wilson, Oliver")
    end

    test "renders correctly with Low proficiency students", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "Low",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Check header
      assert has_element?(view, "h4", "Students with Low Estimated Proficiency")

      # Check that only Low proficiency students are displayed
      assert has_element?(view, "td", "Davis, Emma")

      # Check that students with other proficiency levels are not displayed
      # High
      refute has_element?(view, "td", "Smith, John")
      # High
      refute has_element?(view, "td", "Johnson, Alice")
      # Medium
      refute has_element?(view, "td", "Brown, Charlie")
      # Not enough data
      refute has_element?(view, "td", "Wilson, Oliver")
    end

    test "renders correctly with 'Not enough data' proficiency students", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "Not enough data",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Check header (should capitalize properly)
      assert has_element?(view, "h4", "Students with Not Enough Data Estimated Proficiency")

      # Check that only "Not enough data" proficiency students are displayed
      assert has_element?(view, "td", "Wilson, Oliver")

      # Check that students with other proficiency levels are not displayed
      # High
      refute has_element?(view, "td", "Smith, John")
      # High
      refute has_element?(view, "td", "Johnson, Alice")
      # Medium
      refute has_element?(view, "td", "Brown, Charlie")
      # Low
      refute has_element?(view, "td", "Davis, Emma")
    end

    test "handles empty filtered student data", %{conn: conn} do
      student_data = [
        %{
          id: 1,
          full_name: "Smith, John",
          proficiency: 0.85,
          proficiency_range: "High"
        }
      ]

      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_data,
          # No students have Medium proficiency
          selected_proficiency_level: "Medium",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Should still render table structure
      assert has_element?(view, "table")
      assert has_element?(view, "h4", "Students with Medium Estimated Proficiency")

      # Should not have any data rows
      refute has_element?(view, "tbody tr")
    end

    test "handles completely empty student data", %{conn: conn} do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: [],
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Should still render table structure but with no data rows
      assert has_element?(view, "table")
      assert has_element?(view, "h4", "Students with High Estimated Proficiency")
      refute has_element?(view, "tbody tr")
    end

    test "sorts students by name ascending", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          # Will show Smith, John and Johnson, Alice
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Check initial order before sorting (appears to be sorted by insertion order)
      # Note: td:nth-child(2) because first column is now the checkbox
      assert view |> element("tbody tr:first-child td:nth-child(2)") |> render() =~
               "Smith, John"

      assert view |> element("tbody tr:nth-child(2) td:nth-child(2)") |> render() =~
               "Johnson, Alice"

      # Trigger sort by student_name column - first click sorts ascending
      view
      |> element("th[phx-click][phx-value-sort_by='student_name']")
      |> render_click()

      # Check order after sorting ascending (Johnson should come before Smith alphabetically)
      assert view |> element("tbody tr:first-child td:nth-child(2)") |> render() =~
               "Johnson, Alice"

      assert view |> element("tbody tr:nth-child(2) td:nth-child(2)") |> render() =~
               "Smith, John"
    end

    test "sorts students by name descending on second click", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # First click - sort ascending
      view
      |> element("th[phx-click][phx-value-sort_by='student_name']")
      |> render_click()

      # Verify ascending order (Johnson first alphabetically)
      # Note: td:nth-child(2) because first column is now the checkbox
      assert view |> element("tbody tr:first-child td:nth-child(2)") |> render() =~
               "Johnson, Alice"

      assert view |> element("tbody tr:nth-child(2) td:nth-child(2)") |> render() =~
               "Smith, John"

      # Second click - sort descending
      view
      |> element("th[phx-click][phx-value-sort_by='student_name']")
      |> render_click()

      # Verify descending order (Smith first in reverse alphabetical order)
      assert view |> element("tbody tr:first-child td:nth-child(2)") |> render() =~
               "Smith, John"

      assert view |> element("tbody tr:nth-child(2) td:nth-child(2)") |> render() =~
               "Johnson, Alice"
    end

    test "handles sorting with single student", %{conn: conn} do
      single_student_data = [
        %{
          id: 1,
          full_name: "Only, Student",
          proficiency: 0.85,
          proficiency_range: "High"
        }
      ]

      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: single_student_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Should render the single student
      assert has_element?(view, "td", "Only, Student")

      # Sorting should not crash with single student
      view
      |> element("th[phx-click][phx-value-sort_by='student_name']")
      |> render_click()

      # Should still render the same student
      assert has_element?(view, "td", "Only, Student")
    end
  end

  describe "Row Selection - Individual Checkboxes" do
    setup %{conn: conn} do
      student_proficiency_data = [
        %{
          id: 1,
          full_name: "Smith, John",
          proficiency: 0.85,
          proficiency_range: "High"
        },
        %{
          id: 2,
          full_name: "Johnson, Alice",
          proficiency: 0.65,
          proficiency_range: "High"
        },
        %{
          id: 3,
          full_name: "Brown, Charlie",
          proficiency: 0.45,
          proficiency_range: "High"
        }
      ]

      %{
        conn: conn,
        student_proficiency_data: student_proficiency_data
      }
    end

    test "selects a single student by clicking checkbox", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Initially no students are selected
      refute view
             |> element("tbody tr:first-child input[type='checkbox']")
             |> render() =~ "checked"

      # Click checkbox of first student
      view
      |> element("tbody tr:first-child input[type='checkbox']")
      |> render_click()

      # Verify checkbox is now checked
      assert view
             |> element("tbody tr:first-child input[type='checkbox']")
             |> render() =~ "checked"
    end

    test "deselects a previously selected student", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Select first student
      view
      |> element("tbody tr:first-child input[type='checkbox']")
      |> render_click()

      # Verify it's selected
      assert view
             |> element("tbody tr:first-child input[type='checkbox']")
             |> render() =~ "checked"

      # Deselect the same student
      view
      |> element("tbody tr:first-child input[type='checkbox']")
      |> render_click()

      # Verify it's no longer selected
      refute view
             |> element("tbody tr:first-child input[type='checkbox']")
             |> render() =~ "checked"
    end

    test "selects multiple students independently", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Select first student
      view
      |> element("tbody tr:first-child input[type='checkbox']")
      |> render_click()

      # Select third student
      view
      |> element("tbody tr:nth-child(3) input[type='checkbox']")
      |> render_click()

      # Verify both are selected
      assert view
             |> element("tbody tr:first-child input[type='checkbox']")
             |> render() =~ "checked"

      assert view
             |> element("tbody tr:nth-child(3) input[type='checkbox']")
             |> render() =~ "checked"

      # Verify second student is not selected
      refute view
             |> element("tbody tr:nth-child(2) input[type='checkbox']")
             |> render() =~ "checked"
    end

    test "maintains selection state after sorting", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Select first student (Smith, John) and third student (Brown, Charlie)
      view
      |> element("tbody tr:first-child input[type='checkbox']")
      |> render_click()

      view
      |> element("tbody tr:nth-child(3) input[type='checkbox']")
      |> render_click()

      # Trigger sort by name (ascending)
      view
      |> element("th[phx-click][phx-value-sort_by='student_name']")
      |> render_click()

      # After sorting, order is: Brown, Johnson, Smith
      # Verify that Brown and Smith are still selected
      # Brown is now first
      assert view
             |> element("tbody tr:first-child td:nth-child(2)")
             |> render() =~ "Brown, Charlie"

      assert view
             |> element("tbody tr:first-child input[type='checkbox']")
             |> render() =~ "checked"

      # Johnson is second and not selected
      assert view
             |> element("tbody tr:nth-child(2) td:nth-child(2)")
             |> render() =~ "Johnson, Alice"

      refute view
             |> element("tbody tr:nth-child(2) input[type='checkbox']")
             |> render() =~ "checked"

      # Smith is third and selected
      assert view
             |> element("tbody tr:nth-child(3) td:nth-child(2)")
             |> render() =~ "Smith, John"

      assert view
             |> element("tbody tr:nth-child(3) input[type='checkbox']")
             |> render() =~ "checked"
    end
  end

  describe "Select All Functionality" do
    setup %{conn: conn} do
      student_proficiency_data = [
        %{id: 1, full_name: "Student 1", proficiency: 0.85, proficiency_range: "High"},
        %{id: 2, full_name: "Student 2", proficiency: 0.75, proficiency_range: "High"},
        %{id: 3, full_name: "Student 3", proficiency: 0.65, proficiency_range: "High"},
        %{id: 4, full_name: "Student 4", proficiency: 0.55, proficiency_range: "High"},
        %{id: 5, full_name: "Student 5", proficiency: 0.45, proficiency_range: "High"}
      ]

      %{
        conn: conn,
        student_proficiency_data: student_proficiency_data
      }
    end

    test "selects all students when clicking select all checkbox", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Click select all checkbox in header
      view
      |> element("thead input[type='checkbox']")
      |> render_click()

      # Verify all checkboxes are now checked
      Enum.each(1..5, fn index ->
        assert view
               |> element("tbody tr:nth-child(#{index}) input[type='checkbox']")
               |> render() =~ "checked"
      end)
    end

    test "deselects all students when all are selected and clicking select all", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # First select all
      view
      |> element("thead input[type='checkbox']")
      |> render_click()

      # Verify all are selected
      assert view
             |> element("tbody tr:first-child input[type='checkbox']")
             |> render() =~ "checked"

      # Click select all again to deselect
      view
      |> element("thead input[type='checkbox']")
      |> render_click()

      # Verify all checkboxes are now unchecked
      Enum.each(1..5, fn index ->
        refute view
               |> element("tbody tr:nth-child(#{index}) input[type='checkbox']")
               |> render() =~ "checked"
      end)
    end

    test "selects all when some (but not all) are selected", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Select only 2 students individually
      view
      |> element("tbody tr:first-child input[type='checkbox']")
      |> render_click()

      view
      |> element("tbody tr:nth-child(3) input[type='checkbox']")
      |> render_click()

      # Verify only 2 are selected
      assert view
             |> element("tbody tr:first-child input[type='checkbox']")
             |> render() =~ "checked"

      refute view
             |> element("tbody tr:nth-child(2) input[type='checkbox']")
             |> render() =~ "checked"

      # Click select all
      view
      |> element("thead input[type='checkbox']")
      |> render_click()

      # Verify all 5 are now selected
      Enum.each(1..5, fn index ->
        assert view
               |> element("tbody tr:nth-child(#{index}) input[type='checkbox']")
               |> render() =~ "checked"
      end)
    end
  end

  describe "EmailButton Integration" do
    setup %{conn: conn} do
      student_proficiency_data = [
        %{id: 1, full_name: "Smith, John", proficiency: 0.85, proficiency_range: "High"},
        %{id: 2, full_name: "Johnson, Alice", proficiency: 0.65, proficiency_range: "High"}
      ]

      %{
        conn: conn,
        student_proficiency_data: student_proficiency_data
      }
    end

    test "email button is disabled when no students selected", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Verify email button has disabled styling
      email_button_html =
        view
        |> element("#email_button_wrapper > button")
        |> render()

      assert email_button_html =~ "cursor-not-allowed"
      assert email_button_html =~ "disabled"
    end

    test "email button is enabled when students are selected", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Select a student
      view
      |> element("tbody tr:first-child input[type='checkbox']")
      |> render_click()

      # Verify email button is now enabled (has primary styling)
      email_button_html =
        view
        |> element("#email_button_wrapper > button")
        |> render()

      assert email_button_html =~ "bg-Fill-Buttons-fill-primary"
      refute email_button_html =~ "cursor-not-allowed"
    end

    test "email button has dropdown with correct options", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Select a student
      view
      |> element("tbody tr:first-child input[type='checkbox']")
      |> render_click()

      # Verify dropdown structure exists with correct content
      dropdown_html =
        view
        |> element("#email-dropdown-email_button_proficiency_component")
        |> render()

      assert dropdown_html =~ "Copy email addresses"
      assert dropdown_html =~ "Send email"

      # Verify it has the toggle behavior configured (uses JS.toggle)
      button_html =
        view
        |> element("#email_button_wrapper > button")
        |> render()

      assert button_html =~ "phx-click"
      assert button_html =~ "#email-dropdown-email_button_proficiency_component"
    end
  end

  describe "Email Modal Integration" do
    setup %{conn: conn} do
      student_proficiency_data = [
        %{
          id: 1,
          full_name: "Smith, John",
          proficiency: 0.85,
          proficiency_range: "High",
          email: "john@test.com"
        },
        %{
          id: 2,
          full_name: "Johnson, Alice",
          proficiency: 0.65,
          proficiency_range: "High",
          email: "alice@test.com"
        }
      ]

      %{
        conn: conn,
        student_proficiency_data: student_proficiency_data
      }
    end

    test "email modal component is conditionally rendered", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Select students
      view
      |> element("tbody tr:first-child input[type='checkbox']")
      |> render_click()

      # Initially modal should not be rendered (show_email_modal defaults to false)
      refute has_element?(view, "#email_modal_proficiency")

      # Verify dropdown has "Send email" button with correct event
      send_email_button_html =
        view
        |> element("#email-dropdown-email_button_proficiency_component button", "Send email")
        |> render()

      assert send_email_button_html =~ "phx-click"
      assert send_email_button_html =~ "show_email_modal"
    end
  end

  describe "Edge Cases" do
    test "handles empty filtered data gracefully", %{conn: conn} do
      student_data = [
        %{
          id: 1,
          full_name: "Smith, John",
          proficiency: 0.85,
          proficiency_range: "High"
        }
      ]

      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_data,
          selected_proficiency_level: "Medium",
          section_slug: "test-section",
          section_title: "Test Section",
          instructor_email: "instructor@test.com"
        })

      # Should render table structure but no select all checkbox since there are no students
      assert has_element?(view, "table")
      refute has_element?(view, "tbody tr")

      # Verify select all checkbox is not shown when there are no students
      refute has_element?(view, "thead input[type='checkbox']")
    end
  end
end
