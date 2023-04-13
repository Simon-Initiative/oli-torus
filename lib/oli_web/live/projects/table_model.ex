defmodule OliWeb.Projects.TableModel do
  use Surface.LiveComponent

  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(%SessionContext{} = context, sections) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "Title",
        render_fn: &__MODULE__.custom_render/3
      },
      %ColumnSpec{
        name: :inserted_at,
        label: "Created",
        render_fn: &OliWeb.Common.Table.Common.render_date/3
      },
      %ColumnSpec{
        name: :name,
        label: "Created By",
        render_fn: &__MODULE__.custom_render/3
      },
      %ColumnSpec{
        name: :status,
        label: "Status",
        render_fn: &__MODULE__.custom_render/3
      }
    ]

    SortableTableModel.new(
      rows: sections,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        context: context
      }
    )
  end

  def custom_render(assigns, project, %ColumnSpec{name: name}) do
    case name do
      :title ->
        ~F"""
          <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.OverviewLive, project.slug)}>{project.title}</a>
        """

      :status ->
        case project.status do
          :active ->
            SortableTableModel.render_span_column(assigns, "Active", "text-success")

          :deleted ->
            SortableTableModel.render_span_column(assigns, "Deleted", "text-danger")
        end

      :name ->
        ~F"""
        <span>{project.name}</span> <small class="text-muted">{project.email}</small>
        """
    end
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
