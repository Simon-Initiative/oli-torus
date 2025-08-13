defmodule OliWeb.Common.Listing do
  use Phoenix.Component
  alias OliWeb.Common.SortableTable.Table
  alias OliWeb.Common.{CardListing, Paging}

  attr :total_count, :integer, required: true
  attr :filter, :string, required: true
  attr :limit, :integer, required: true
  attr :offset, :integer, required: true
  attr :table_model, :map, required: true
  attr :sort, :string, required: true
  attr :page_change, :string, required: true
  attr :show_bottom_paging, :boolean, default: true
  attr :additional_table_class, :string, default: "table-sm"
  attr :cards_view, :boolean, default: false
  attr :selected, :any
  attr :with_body, :boolean, default: false
  slot :inner_block

  def render(assigns) do
    ~H"""
    <div class="pb-5">
      <%= if @filter != "" do %>
        <strong>{~s[Results filtered on "#{@filter}"]}</strong>
      <% end %>

      <%= if @total_count > 0 and @total_count > @limit do %>
        <Paging.render
          id="header_paging"
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          click={@page_change}
        /> {render_table(assigns)}
        <%= if @show_bottom_paging do %>
          <Paging.render
            id="footer_paging"
            total_count={@total_count}
            offset={@offset}
            limit={@limit}
            click={@page_change}
          />
        <% end %>
      <% else %>
        <%= if @total_count > 0 do %>
          <div>{"Showing all results (#{@total_count} total)"}</div>
          <br /> {render_table(assigns)}
        <% else %>
          <p>None exist</p>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp render_table(assigns) do
    ~H"""
    <%= if @cards_view do %>
      <CardListing.render model={@table_model} selected={@selected} ctx={@table_model.data.ctx} />
    <% else %>
      <%= if @with_body do %>
        {render_slot(@inner_block)}
      <% else %>
        <Table.render
          model={@table_model}
          sort={@sort}
          additional_table_class={@additional_table_class}
        />
      <% end %>
    <% end %>
    """
  end
end
