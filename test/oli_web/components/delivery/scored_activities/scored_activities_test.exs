defmodule OliWeb.Components.Delivery.ScoredActivitiesTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.ScoredActivities

  describe "mount/1" do
    test "mounts with default assigns" do
      {:ok, socket} = ScoredActivities.mount(%Phoenix.LiveView.Socket{})
      assert socket.assigns.scripts_loaded == false
      assert socket.assigns.table_model == nil
      assert socket.assigns.current_assessment == nil
    end
  end

  describe "update/2" do
    test "updates assigns and table_model for no assessment_id" do
      assigns = %{
        params: %{"assessment_id" => nil},
        section: %{},
        view: :scored_activities,
        ctx: %{},
        assessments: [%{id: 1, title: "A1", order: 1}],
        students: [%{id: 1}],
        scripts: [],
        activity_types_map: %{}
      }

      socket = %Phoenix.LiveView.Socket{assigns: %{myself: :self, __changed__: %{}}}
      {:ok, updated_socket} = ScoredActivities.update(assigns, socket)
      assert updated_socket.assigns.table_model != nil
      assert updated_socket.assigns.current_assessment == nil
    end
  end

  describe "render/1" do
    test "renders loader if table_model is nil" do
      assigns = %{table_model: nil, current_assessment: nil}
      html = render_component(&ScoredActivities.render/1, assigns)
      assert html =~ "spinner-border"
    end

    test "renders table and activities if table_model present" do
      assigns = %{
        table_model: %{
          rows: [%{id: 1, title: "A1"}],
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
        current_assessment: nil,
        params: %{text_search: nil, offset: 0, limit: 20},
        total_count: 1,
        view: :scored_activities,
        section: %{slug: "section"},
        students: [%{id: 1}],
        activity_types_map: %{},
        scripts: [],
        assessments: [%{id: 1, title: "A1"}],
        myself: :self
      }

      html = render_component(&ScoredActivities.render/1, assigns)
      assert html =~ "Scored Activities"
      assert html =~ "instructor_dashboard_table"
    end
  end
end
