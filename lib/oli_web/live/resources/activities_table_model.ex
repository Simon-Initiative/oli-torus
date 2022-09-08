defmodule OliWeb.Resources.ActivitiesTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias Oli.Resources.Revision
  use Surface.LiveComponent

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end

  def new(activities, project, context, activities_by_type_id) do
    column_specs = [
      %ColumnSpec{
        name: :activity_type_id,
        label: "Type",
        render_fn: &OliWeb.Resources.ActivitiesTableModel.render_type_column/3
      },
      %ColumnSpec{
        name: :scope,
        label: "Scope"
      },
      %ColumnSpec{
        name: :content,
        label: "Stem",
        render_fn: &OliWeb.Resources.ActivitiesTableModel.render_content_column/3
      },
      %ColumnSpec{
        name: :updated_at,
        label: "Last Updated",
        render_fn: &OliWeb.Common.Table.Common.render_date/3
      }
    ]

    SortableTableModel.new(
      rows: activities,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        context: context,
        project_slug: project.slug,
        activities_by_type_id: activities_by_type_id
      }
    )
  end

  def render_type_column(
        assigns,
        %Revision{
          activity_type_id: activity_type_id
        },
        _
      ) do
    Map.get(assigns.activities_by_type_id, activity_type_id).petite_label
  end

  def render_content_column(
        _,
        %Revision{
          content: content
        },
        _
      ) do
    Map.get(content, "stem", %{"content" => []})
    |> Map.get("content", [%{"type" => "p", "children" => [%{"text" => "Unknown stem"}]}])
    |> best_effort_stem_extract()
  end

  defp best_effort_stem_extract([]), do: "[Empty]"
  defp best_effort_stem_extract([item | _]), do: extract(item)

  defp extract(%{"type" => "p", "children" => children}) do
    Enum.reduce(children, "", fn c, s ->
      s <> Map.get(c, "text", "")
    end)
  end

  defp extract(%{"type" => t}), do: "[#{t}]"
end
