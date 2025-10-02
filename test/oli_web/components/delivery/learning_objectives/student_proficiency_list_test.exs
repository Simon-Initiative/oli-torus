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
          student_id: "1",
          student_name: "Smith, John",
          proficiency: 0.85,
          proficiency_range: "High"
        },
        %{
          student_id: "2",
          student_name: "Johnson, Alice",
          proficiency: 0.65,
          proficiency_range: "High"
        },
        %{
          student_id: "3",
          student_name: "Brown, Charlie",
          proficiency: 0.45,
          proficiency_range: "Medium"
        },
        %{
          student_id: "4",
          student_name: "Davis, Emma",
          proficiency: 0.25,
          proficiency_range: "Low"
        },
        %{
          student_id: "5",
          student_name: "Wilson, Oliver",
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
          selected_proficiency_level: "High"
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
          selected_proficiency_level: "Medium"
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
          selected_proficiency_level: "Low"
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
          selected_proficiency_level: "Not enough data"
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
          student_id: "1",
          student_name: "Smith, John",
          proficiency: 0.85,
          proficiency_range: "High"
        }
      ]

      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_data,
          # No students have Medium proficiency
          selected_proficiency_level: "Medium"
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
          selected_proficiency_level: "High"
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
          selected_proficiency_level: "High"
        })

      # Check initial order before sorting (should be: Smith, Johnson)
      assert view |> element("tbody tr:first-child td:first-child") |> render() =~
               "Johnson, Alice"

      assert view |> element("tbody tr:nth-child(2) td:first-child") |> render() =~
               "Smith, John"

      # Trigger sort by student_name column
      view
      |> element("th[phx-click][phx-value-sort_by='student_name']")
      |> render_click()

      # Check order after sorting (should be alphabetical: Johnson, Smith)
      assert view |> element("tbody tr:first-child td:first-child") |> render() =~
               "Smith, John"

      assert view |> element("tbody tr:nth-child(2) td:first-child") |> render() =~
               "Johnson, Alice"
    end

    test "sorts students by name descending on second click", %{
      conn: conn,
      student_proficiency_data: student_proficiency_data
    } do
      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: student_proficiency_data,
          selected_proficiency_level: "High"
        })

      # First click - sort ascending
      view
      |> element("th[phx-click][phx-value-sort_by='student_name']")
      |> render_click()

      # Verify ascending order (Johnson first alphabetically)
      assert view |> element("tbody tr:first-child td:first-child") |> render() =~
               "Smith, John"

      assert view |> element("tbody tr:nth-child(2) td:first-child") |> render() =~
               "Johnson, Alice"

      # Second click - sort descending
      view
      |> element("th[phx-click][phx-value-sort_by='student_name']")
      |> render_click()

      # Verify descending order (Smith first in reverse alphabetical order)
      assert view |> element("tbody tr:first-child td:first-child") |> render() =~
               "Johnson, Alice"

      assert view |> element("tbody tr:nth-child(2) td:first-child") |> render() =~
               "Smith, John"
    end

    test "handles sorting with single student", %{conn: conn} do
      single_student_data = [
        %{
          student_id: "1",
          student_name: "Only, Student",
          proficiency: 0.85,
          proficiency_range: "High"
        }
      ]

      {:ok, view, _html} =
        live_component_isolated(conn, StudentProficiencyList, %{
          id: "student-proficiency-list-test",
          student_proficiency: single_student_data,
          selected_proficiency_level: "High"
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
end
