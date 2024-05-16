defmodule OliWeb.Common.InstructorDashboardPagedTable do
  use Phoenix.Component

  alias OliWeb.Common.Paging
  alias OliWeb.Common.SortableTable.Table

  def render(assigns) do
    ~H"""
    <Table.render
      model={@table_model}
      additional_table_class="instructor_dashboard_table"
      sort={@sort}
    />

    <Paging.render
      id="footer_paging"
      total_count={@total_count}
      offset={@offset}
      limit={@limit}
      click={@click}
      limit_change={@limit_change}
      has_shorter_label={true}
      show_limit_change={true}
      should_add_empty_flex={false}
      is_page_size_right={true}
    />
    """
  end
end
