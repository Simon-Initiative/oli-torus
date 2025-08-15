defmodule OliWeb.Workspaces.CourseAuthor.Insights.ActivityTableModel do
  use Phoenix.Component

  import OliWeb.Workspaces.CourseAuthor.Insights.Common

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(rows, activity_types_map, parent_pages, project_slug, ctx) do
    SortableTableModel.new(
      rows: rows,
      column_specs: [
        %ColumnSpec{
          name: :title,
          label: "Activity",
          render_fn: &render_title/3
        },
        %ColumnSpec{
          name: :activity_type_id,
          label: "Type",
          render_fn: &render_activity_type/3
        },
        %ColumnSpec{
          name: :part_id,
          label: "Part"
        },
        %ColumnSpec{
          name: :num_attempts,
          label: "# Attempts"
        },
        %ColumnSpec{
          name: :num_first_attempts,
          label: "# First Attempts"
        },
        %ColumnSpec{
          name: :first_attempt_correct,
          label: "First Attempt Correct%",
          render_fn: &render_percentage/3
        },
        %ColumnSpec{
          name: :eventually_correct,
          label: "Eventually Correct%",
          render_fn: &render_percentage/3
        },
        %ColumnSpec{
          name: :relative_difficulty,
          label: "Relative Difficulty",
          render_fn: &render_float/3
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        activity_types_map: activity_types_map,
        parent_pages: parent_pages,
        project_slug: project_slug,
        ctx: ctx
      }
    )
  end

  def render_title(%{parent_pages: parent_pages} = data, row, assigns) do
    case Map.has_key?(parent_pages, row.resource_id) do
      true -> render_with_link(data, row, assigns)
      false -> render_without_link(data, row, assigns)
    end
  end

  defp render_with_link(%{parent_pages: parent_pages, project_slug: project_slug}, row, assigns) do
    parent_page = Map.get(parent_pages, row.resource_id)
    assigns = Map.put(assigns, :project_slug, project_slug)
    assigns = Map.put(assigns, :parent_page, parent_page)
    assigns = Map.put(assigns, :row, row)

    ~H"""
    <a href={Routes.resource_path(OliWeb.Endpoint, :edit, @project_slug, @parent_page.slug)}>
      {@row.title}
    </a>
    """
  end

  defp render_without_link(_, row, _assigns) do
    row.title
  end

  def render_activity_type(%{activity_types_map: activity_types_map}, row, _) do
    Map.get(activity_types_map, row.activity_type_id).petite_label
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
