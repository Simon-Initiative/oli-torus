defmodule OliWeb.Components.Delivery.SurveysTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.Surveys

  describe "mount/1" do
    test "mounts with default assigns" do
      {:ok, socket} = Surveys.mount(%Phoenix.LiveView.Socket{})
      assert socket.assigns.scripts_loaded == false
      assert socket.assigns.table_model == nil
      assert socket.assigns.current_page == nil
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
        assessments: [%{resource_id: 1, id: 1, title: "Survey 1"}],
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
      assert updated_socket.assigns.table_model.id_field == [:resource_id]
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
          rows: [%{resource_id: 1, id: 1, title: "Survey 1"}],
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
          data: %{expanded_rows: [], survey_activities_map: %{}},
          sort_order: :asc,
          id_field: [:resource_id],
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
        assessments: [%{resource_id: 1, title: "Survey 1"}],
        myself: :self,
        activities: []
      }

      html = render_component(&Surveys.render/1, assigns)
      assert html =~ "Surveys"
      assert html =~ "instructor_dashboard_table"
    end

    test "renders activities when present" do
      activity = %{
        id: 1,
        title: "Question 1",
        students_with_attempts_count: 1,
        total_attempts_count: 5,
        student_emails_without_attempts: []
      }

      assigns = %{
        table_model: %{
          rows: [%{resource_id: 1, id: 1, title: "Survey 1"}],
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
          data: %{
            expandable_rows: true,
            selected_survey_ids: [1],
            survey_activities_map: %{1 => [activity]},
            expanded_rows: MapSet.new(["row_1"]),
            activity_types_map: %{},
            students: [%{id: 1}]
          },
          sort_order: :asc,
          id_field: [:resource_id],
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
        assessments: [%{resource_id: 1, title: "Survey 1"}],
        myself: :self,
        activities: []
      }

      html = render_component(&Surveys.render/1, assigns)
      assert html =~ "Surveys"
      assert html =~ "Question 1 - Question details"
      assert html =~ "student has completed"
    end

    test "renders no attempt registered message when activity has no preview_rendered" do
      activity = %{
        id: 1,
        title: "Question 1",
        students_with_attempts_count: 0,
        total_attempts_count: 0,
        student_emails_without_attempts: ["a@example.com"],
        preview_rendered: nil
      }

      assigns = %{
        table_model: %{
          rows: [%{resource_id: 1, id: 1, title: "Survey 1"}],
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
          data: %{
            expandable_rows: true,
            selected_survey_ids: [1],
            survey_activities_map: %{1 => [activity]},
            expanded_rows: MapSet.new(["row_1"]),
            activity_types_map: %{},
            students: [%{id: 1}]
          },
          sort_order: :asc,
          id_field: [:resource_id],
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
        assessments: [%{resource_id: 1, title: "Survey 1"}],
        myself: :self,
        activities: []
      }

      html = render_component(&Surveys.render/1, assigns)
      assert html =~ "No attempt registered for this question"
    end

    test "renders no student has completed any attempts when activity has zero attempts" do
      activity = %{
        id: 1,
        title: "Question 1",
        students_with_attempts_count: 0,
        total_attempts_count: 0,
        student_emails_without_attempts: ["a@example.com"]
      }

      assigns = %{
        table_model: %{
          rows: [%{resource_id: 1, id: 1, title: "Survey 1"}],
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
          data: %{
            expandable_rows: true,
            selected_survey_ids: [1],
            survey_activities_map: %{1 => [activity]},
            expanded_rows: MapSet.new(["row_1"]),
            activity_types_map: %{},
            students: [%{id: 1}]
          },
          sort_order: :asc,
          id_field: [:resource_id],
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
        assessments: [%{resource_id: 1, title: "Survey 1"}],
        myself: :self,
        activities: []
      }

      html = render_component(&Surveys.render/1, assigns)
      assert html =~ "No student has completed any attempts."
    end

    test "renders no surveys present message when empty and no text search" do
      assigns = %{
        table_model: %{
          rows: [],
          column_specs: [],
          data: %{},
          sort_order: :asc,
          id_field: [:resource_id],
          selected: nil,
          sort_by_spec: nil
        },
        params: %{text_search: nil, offset: 0, limit: 20},
        total_count: 0,
        view: :surveys,
        section: %{slug: "section"},
        students: [],
        activity_types_map: %{},
        scripts: [],
        assessments: [],
        myself: :self,
        activities: []
      }

      html = render_component(&Surveys.render/1, assigns)
      assert html =~ "There are no surveys present in this course"
    end

    test "renders no surveys match your search message when empty with text search" do
      assigns = %{
        table_model: %{
          rows: [],
          column_specs: [],
          data: %{},
          sort_order: :asc,
          id_field: [:resource_id],
          selected: nil,
          sort_by_spec: nil
        },
        params: %{text_search: "xyz", offset: 0, limit: 20},
        total_count: 0,
        view: :surveys,
        section: %{slug: "section"},
        students: [],
        activity_types_map: %{},
        scripts: [],
        assessments: [],
        myself: :self,
        activities: []
      }

      html = render_component(&Surveys.render/1, assigns)
      assert html =~ "No surveys match your search"
    end
  end
end
