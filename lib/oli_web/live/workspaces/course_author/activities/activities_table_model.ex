defmodule OliWeb.Workspaces.CourseAuthor.Activities.ActivitiesTableModel do
  use OliWeb, :verified_routes

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias Oli.Resources.Revision

  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(activities, project, ctx, activities_by_type_id, parent_pages) do
    column_specs = [
      %ColumnSpec{
        name: :activity_type_id,
        label: "Type",
        render_fn: &render_type_column/3
      },
      %ColumnSpec{
        name: :title,
        label: "Title"
      },
      %ColumnSpec{
        name: :scope,
        label: "Scope"
      },
      %ColumnSpec{
        name: :stem,
        label: "Stem",
        render_fn: &render_content_column/3,
        sortable: false
      },
      %ColumnSpec{
        name: :resource_id,
        label: "Page",
        render_fn: &render_page_column/3,
        sortable: false
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
        ctx: ctx,
        project_slug: project.slug,
        activities_by_type_id: activities_by_type_id,
        parent_pages: parent_pages
      }
    )
  end

  def render_page_column(
        assigns,
        %Revision{
          resource_id: resource_id
        },
        _
      ) do
    case Map.get(assigns.parent_pages, resource_id) do
      nil ->
        ""

      %{title: title, slug: slug} ->
        assigns = Map.merge(assigns, %{slug: slug, title: title})

        ~H"""
        <.link href={~p"/workspaces/course_author/#{@project_slug}/curriculum/#{@slug}/edit"}>
          {@title}
        </.link>
        """
    end
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

  defp best_effort_stem_extract(%{"model" => items}), do: best_effort_stem_extract(items)
  defp best_effort_stem_extract([]), do: "[Empty]"
  defp best_effort_stem_extract([item | _]), do: extract(item)
  defp best_effort_stem_extract(_), do: "[Empty]"

  defp extract(%{"type" => "p", "children" => children}) do
    value =
      Enum.reduce(children, "", fn c, s ->
        s <> Map.get(c, "text", "")
      end)

    cond do
      String.length(value) > 75 -> String.slice(value, 0..75) <> "..."
      true -> value
    end
  end

  defp extract(%{"text" => t}), do: t
  defp extract(%{"type" => t}), do: "[#{t}]"
  defp extract(_), do: "[Unknown]"
end
