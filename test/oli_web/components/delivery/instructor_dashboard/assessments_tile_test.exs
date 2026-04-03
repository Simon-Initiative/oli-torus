defmodule OliWeb.Components.Delivery.InstructorDashboard.AssessmentsTileTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import LiveComponentTests

  alias OliWeb.Common.SessionContext
  alias OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.AssessmentsTile

  describe "AssessmentsTile" do
    test "renders empty state when there are no rows", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, AssessmentsTile, %{
          id: "assessments_tile",
          ctx: ctx(),
          projection: %{rows: [], total_rows: 0, has_assessments?: false},
          status: "Loading..."
        })

      assert has_element?(
               component,
               "div",
               "No scored assessments were found for the current dashboard scope."
             )
    end

    test "renders the expanded assessment details from assigns", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, AssessmentsTile, %{
          id: "assessments_tile",
          ctx: ctx(),
          projection: projection(),
          status: "Loading...",
          section_slug: "demo-section",
          expanded_assessment_id: 2
        })

      assert has_element?(component, "h3", "Assessments")
      assert has_element?(component, "p", "Quiz 2")
      assert has_element?(component, "button", "Email Students Not Completed")
      assert has_element?(component, "a", "Review Questions")
      assert has_element?(component, "span", "Status: 4/20 Students Completed")
      assert has_element?(component, "button[aria-label='Collapse assessment Quiz 2']")
      assert has_element?(component, "#learning-dashboard-assessment-card-2")

      assert has_element?(
               component,
               "a[href='/sections/demo-section/instructor_dashboard/insights/scored_pages/202']",
               "Review Questions"
             )

      assert has_element?(
               component,
               "[role='img'][aria-label='Score distribution for Quiz 2. 0-10 percent: 1 students, 40-50 percent: 2 students, 50-60 percent: 1 students.']"
             )

      html = render(component)
      assert html =~ "border-Icon-icon-danger bg-Fill-fill-danger"
      assert html =~ "border-Fill-Accent-fill-accent-green-bold bg-Fill-Chip-Green"
    end

    test "renders the assessment scores navigation when section slug is present", %{conn: conn} do
      {:ok, _component, html} =
        live_component_isolated(conn, AssessmentsTile, %{
          id: "assessments_tile",
          ctx: ctx(),
          projection: projection(),
          status: "Loading...",
          section_slug: "demo-section"
        })

      assert html =~ "View Assessment Scores"
      assert html =~ "/sections/demo-section/grades/gradebook"
    end

    test "renders schedule fallbacks as Now and None", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, AssessmentsTile, %{
          id: "assessments_tile",
          ctx: ctx(),
          projection: %{
            has_assessments?: true,
            total_rows: 1,
            rows: [
              %{
                assessment_id: 3,
                review_resource_id: 303,
                title: "Quiz 3",
                context_label: nil,
                available_at: nil,
                due_at: nil,
                completion: %{
                  completed_count: 0,
                  total_students: 20,
                  ratio: 0.0,
                  label: "0 of 20 students completed",
                  status: :bad
                },
                metrics: %{
                  minimum: nil,
                  median: nil,
                  mean: nil,
                  maximum: nil,
                  standard_deviation: nil
                },
                histogram_bins:
                  Enum.map(0..9, fn idx -> %{range: "#{idx * 10}-#{(idx + 1) * 10}", count: 0} end)
              }
            ]
          },
          status: "Loading..."
        })

      assert has_element?(component, "span", "Available: Now")
      assert has_element?(component, "span", "Due: None")
    end

    test "renders the draft email modal when requested even with no recipients", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, AssessmentsTile, %{
          id: "assessments_tile",
          ctx: ctx(),
          projection: projection(),
          status: "Loading...",
          show_email_modal: true,
          email_recipients: [],
          email_assessment: %{assessment_id: 2, title: "Quiz 2"},
          section_title: "Demo section",
          section_slug: "demo-section",
          instructor_email: "instructor@example.com",
          instructor_name: "Instructor"
        })

      assert has_element?(component, "#student_support_email_modal_assessments_tile")

      assert has_element?(
               component,
               "p",
               "No students currently need this message. You can review the draft, but sending stays disabled until at least one recipient is available."
             )
    end

    test "ignores out-of-scope assessment ids when opening the email modal", %{conn: conn} do
      {:ok, component, _html} =
        live_component_isolated(conn, AssessmentsTile, %{
          id: "assessments_tile",
          ctx: ctx(),
          projection: projection(),
          status: "Loading...",
          section_id: 123,
          expanded_assessment_id: 2
        })

      refute has_element?(component, "#student_support_email_modal_assessments_tile")

      component
      |> element("button[phx-click='open_assessment_email_modal'][phx-value-assessment_id='2']")
      |> render_click(%{"assessment_id" => "999"})

      refute has_element?(component, "#student_support_email_modal_assessments_tile")
    end
  end

  defp projection do
    %{
      has_assessments?: true,
      total_rows: 2,
      rows: [
        %{
          assessment_id: 2,
          review_resource_id: 202,
          title: "Quiz 2",
          context_label: "Unit 2",
          available_at: ~U[2026-03-05 12:00:00Z],
          due_at: ~U[2026-03-15 12:00:00Z],
          completion: %{
            completed_count: 4,
            total_students: 20,
            ratio: 0.2,
            label: "4 of 20 students completed",
            status: :bad
          },
          metrics: %{
            minimum: 10.0,
            median: 44.0,
            mean: 48.0,
            maximum: 88.0,
            standard_deviation: 9.2
          },
          histogram_bins: [
            %{range: "0-10", count: 1},
            %{range: "10-20", count: 0},
            %{range: "20-30", count: 0},
            %{range: "30-40", count: 0},
            %{range: "40-50", count: 2},
            %{range: "50-60", count: 1},
            %{range: "60-70", count: 0},
            %{range: "70-80", count: 0},
            %{range: "80-90", count: 0},
            %{range: "90-100", count: 0}
          ]
        },
        %{
          assessment_id: 1,
          review_resource_id: 101,
          title: "Quiz 1",
          context_label: nil,
          available_at: ~U[2026-03-01 12:00:00Z],
          due_at: ~U[2026-03-10 12:00:00Z],
          completion: %{
            completed_count: 12,
            total_students: 20,
            ratio: 0.6,
            label: "12 of 20 students completed",
            status: :good
          },
          metrics: %{
            minimum: 25.0,
            median: 50.0,
            mean: 55.0,
            maximum: 100.0,
            standard_deviation: 12.4
          },
          histogram_bins: [
            %{range: "0-10", count: 1},
            %{range: "10-20", count: 0},
            %{range: "20-30", count: 0},
            %{range: "30-40", count: 0},
            %{range: "40-50", count: 0},
            %{range: "50-60", count: 3},
            %{range: "60-70", count: 2},
            %{range: "70-80", count: 1},
            %{range: "80-90", count: 0},
            %{range: "90-100", count: 5}
          ]
        }
      ]
    }
  end

  defp ctx do
    %SessionContext{
      browser_timezone: "Etc/UTC",
      local_tz: "Etc/UTC",
      is_liveview: true,
      author: nil,
      user: nil
    }
  end
end
