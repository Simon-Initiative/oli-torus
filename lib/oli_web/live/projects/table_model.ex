defmodule OliWeb.Projects.TableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(%SessionContext{} = ctx, sections) do
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
        ctx: ctx
      }
    )
  end

  def custom_render(assigns, project, %ColumnSpec{name: name}) do
    assigns = Map.merge(assigns, %{project: project})

    case name do
      :title ->
        ~H"""
        <a href={~p"/workspaces/course_author/#{@project.slug}/overview"}>
          <%= @project.title %>
        </a>
        """

      :status ->
        case project.status do
          :active ->
            SortableTableModel.render_span_column(%{}, "Active", "text-success")

          :deleted ->
            SortableTableModel.render_span_column(%{}, "Deleted", "text-danger")
        end

      :name ->
        ~H"""
        <span><%= @project.name %></span> <small class="text-muted"><%= @project.email %></small>
        """
    end
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
