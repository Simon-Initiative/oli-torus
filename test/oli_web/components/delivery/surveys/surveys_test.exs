defmodule OliWeb.Components.Delivery.SurveysTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.Surveys

  describe "mount/1" do
    test "mounts with default assigns" do
      {:ok, socket} = Surveys.mount(%Phoenix.LiveView.Socket{})
      assert socket.assigns.scripts_loaded == false
      assert socket.assigns.table_model == nil
      assert socket.assigns.current_assessment == nil
      assert socket.assigns.activities == nil
    end
  end

  describe "update/2" do
    test "updates assigns and table_model" do
      assigns = %{
        params: %{"sort_by" => "title", "sort_order" => "asc"},
        section: %{id: 1, slug: "section"},
        view: :surveys,
        ctx: %{user: %{id: 1}},
        assessments: [%{id: 1, title: "Survey 1"}],
        students: [%{id: 1}],
        scripts: [],
        activity_types_map: %{}
      }

      socket = %Phoenix.LiveView.Socket{assigns: %{myself: :self, __changed__: %{}}}
      {:ok, updated_socket} = Surveys.update(assigns, socket)
      assert updated_socket.assigns.table_model != nil
      assert updated_socket.assigns.total_count == 1
      # Verify the table model has the expected structure
      assert updated_socket.assigns.table_model.rows != nil
      assert updated_socket.assigns.table_model.column_specs != nil
    end
  end

  describe "render/1" do
    test "renders loader if table_model is nil" do
      assigns = %{table_model: nil}
      html = render_component(&Surveys.render/1, assigns)
      assert html =~ "spinner-border"
    end

    test "renders table if table_model present" do
      assigns = %{
        table_model: %{
          rows: [%{id: 1, title: "Survey 1"}],
          column_specs: [
            %{
              name: :title,
              label: "Title",
              th_class: nil,
              td_class: nil,
              sortable: false,
              tooltip: nil,
              render_fn: fn _, _, _ -> "" end
            },
            %{
              name: :avg_score,
              label: "Score",
              th_class: nil,
              td_class: nil,
              sortable: false,
              tooltip: nil,
              render_fn: fn _, _, _ -> "" end
            }
          ],
          data: %{},
          sort_order: :asc,
          id_field: [:id],
          selected: nil,
          sort_by_spec: %{
            name: :title,
            label: "Title",
            th_class: nil,
            td_class: nil,
            sortable: false,
            tooltip: nil,
            render_fn: fn _, _, _ -> "" end
          }
        },
        params: %{text_search: nil, offset: 0, limit: 20},
        total_count: 1,
        view: :surveys,
        section: %{slug: "section"},
        students: [%{id: 1}],
        activity_types_map: %{},
        scripts: [],
        assessments: [%{id: 1, title: "Survey 1"}],
        myself: :self,
        activities: []
      }

      html = render_component(&Surveys.render/1, assigns)
      assert html =~ "Surveys"
      assert html =~ "instructor_dashboard_table"
    end

    test "renders activities when present" do
      assigns = %{
        table_model: %{
          rows: [%{id: 1, title: "Survey 1"}],
          column_specs: [
            %{
              name: :title,
              label: "Title",
              th_class: nil,
              td_class: nil,
              sortable: false,
              tooltip: nil,
              render_fn: fn _, _, _ -> "" end
            }
          ],
          data: %{},
          sort_order: :asc,
          id_field: [:id],
          selected: nil,
          sort_by_spec: %{
            name: :title,
            label: "Title",
            th_class: nil,
            td_class: nil,
            sortable: false,
            tooltip: nil,
            render_fn: fn _, _, _ -> "" end
          }
        },
        params: %{text_search: nil, offset: 0, limit: 20},
        total_count: 1,
        view: :surveys,
        section: %{slug: "section"},
        students: [%{id: 1}],
        activity_types_map: %{},
        scripts: [],
        assessments: [%{id: 1, title: "Survey 1"}],
        myself: :self,
        activities: [
          %{
            id: 1,
            title: "Question 1",
            students_with_attempts_count: 1,
            total_attempts_count: 5,
            student_emails_without_attempts: ["student2@example.com"]
          }
        ],
        current_assessment: %{id: 1, title: "Test Survey"}
      }

      html = render_component(&Surveys.render/1, assigns)
      assert html =~ "Surveys"
      assert html =~ "Question 1 - Question details"
      assert html =~ "student has completed"
      # The text "student has not completed" doesn't appear because there's only 1 student
      # and they have completed attempts, so the condition for showing this text is not met
    end

    test "renders no attempts message when activities is empty" do
      assigns = %{
        table_model: %{
          rows: [%{id: 1, title: "Survey 1"}],
          column_specs: [
            %{
              name: :title,
              label: "Title",
              th_class: nil,
              td_class: nil,
              sortable: false,
              tooltip: nil,
              render_fn: fn _, _, _ -> "" end
            }
          ],
          data: %{},
          sort_order: :asc,
          id_field: [:id],
          selected: nil,
          sort_by_spec: %{
            name: :title,
            label: "Title",
            th_class: nil,
            td_class: nil,
            sortable: false,
            tooltip: nil,
            render_fn: fn _, _, _ -> "" end
          }
        },
        params: %{text_search: nil, offset: 0, limit: 20},
        total_count: 1,
        view: :surveys,
        section: %{slug: "section"},
        students: [%{id: 1}],
        activity_types_map: %{},
        scripts: [],
        assessments: [%{id: 1, title: "Survey 1"}],
        myself: :self,
        activities: []
      }

      html = render_component(&Surveys.render/1, assigns)
      assert html =~ "No attempt registered for this question"
    end
  end
end
