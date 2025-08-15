defmodule OliWeb.Projects.TableModel do
  use Phoenix.Component
  use OliWeb, :verified_routes

  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}

  def new(%SessionContext{} = ctx, sections) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "Title",
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :inserted_at,
        label: "Created",
        render_fn: &Common.render_date/3
      },
      %ColumnSpec{
        name: :name,
        label: "Created By",
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :status,
        label: "Status",
        render_fn: &custom_render/3
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
          {@project.title}
        </a>
        """

      :status ->
        case project.status do
          :active ->
            SortableTableModel.render_span_column(
              %{},
              "Active",
              "text-[#245D45] dark:text-[#39E581]"
            )

          :deleted ->
            SortableTableModel.render_span_column(
              %{},
              "Deleted",
              "text-[#A42327] dark:text-[#FF8787]"
            )
        end

      :name ->
        ~H"""
        <span class="text-[#1B67B2] dark:text-[#99CCFF]">{@project.name}</span>
        <small class="text-[#45464C] dark:text-[#BAB8BF]">{@project.email}</small>
        """
    end
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
