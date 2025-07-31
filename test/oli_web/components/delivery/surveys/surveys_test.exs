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
        params: %{},
        section: %{},
        view: :surveys,
        ctx: %{},
        assessments: [%{id: 1, title: "Survey 1"}],
        students: [%{id: 1}],
        scripts: [],
        activity_types_map: %{}
      }

      socket = %Phoenix.LiveView.Socket{assigns: %{myself: :self, __changed__: %{}}}
      {:ok, updated_socket} = Surveys.update(assigns, socket)
      assert updated_socket.assigns.table_model != nil
      assert updated_socket.assigns.total_count == 1
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
  end
end
