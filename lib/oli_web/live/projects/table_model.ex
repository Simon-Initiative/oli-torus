defmodule OliWeb.Projects.TableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  use Surface.LiveComponent

  alias OliWeb.Router.Helpers, as: Routes

  def new(sections, include_status?) do
    column_specs =
      [
        %ColumnSpec{
          name: :title,
          label: "Title",
          render_fn: &__MODULE__.custom_render/3
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &OliWeb.Common.Table.Common.render_relative_date/3
        },
        %ColumnSpec{
          name: :name,
          label: "Created By"
        }
      ] ++
        if include_status? do
          [
            %ColumnSpec{
              name: :status,
              label: "Status",
              render_fn: &__MODULE__.custom_render/3
            }
          ]
        else
          []
        end

    SortableTableModel.new(
      rows: sections,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id]
    )
  end

  def custom_render(assigns, project, %ColumnSpec{name: name}) do
    case name do
      :title ->
        ~F"""
          <a href={Routes.project_path(OliWeb.Endpoint, :overview, project.slug)}>{project.title}</a>
        """

      :status ->
        case project.status do
          :active ->
            ~F"""
            <span class="text-success">Active</span>
            """

          :deleted ->
            ~F"""
            <span class="text-danger">Deleted</span>
            """
        end
    end
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
