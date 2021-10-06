defmodule OliWeb.Projects.TableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  use Surface.LiveComponent

  alias OliWeb.Router.Helpers, as: Routes

  def new(sections) do
    SortableTableModel.new(
      rows: sections,
      column_specs: [
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
      ],
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
    end
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
