defmodule OliWeb.Common.InstructorDashboardPagedTable do
  use Phoenix.Component

  alias OliWeb.Common.Paging
  alias OliWeb.Common.SortableTable.Table

  attr :table_model, :map, required: true
  attr :total_count, :integer, required: true
  attr :offset, :integer, required: true
  attr :limit, :integer, required: true
  attr :limit_change, :string, default: "paged_table_limit_change"
  attr :selection_change, :string, default: "paged_table_selection_change"
  attr :page_change, :string, default: "paged_table_page_change"
  attr :sort, :string, default: "paged_table_sort"
  attr :no_records_message, :string, default: "None exist"

  def render(assigns) do
    ~H"""
    <Table.render
      model={@table_model}
      additional_table_class="instructor_dashboard_table"
      sort={@sort}
      select={@selection_change}
    />

    <%= if @total_count > 0 do %>
      <Paging.render
        id="footer_paging"
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
        click={@page_change}
        limit_change={@limit_change}
        has_shorter_label={true}
        show_limit_change={true}
        should_add_empty_flex={false}
        is_page_size_right={true}
      />
    <% else %>
      <div class="bg-white dark:bg-gray-800 dark:text-white px-10 my-5">
        <p><%= @no_records_message %></p>
      </div>
    <% end %>
    """
  end
end
