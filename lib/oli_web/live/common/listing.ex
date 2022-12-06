defmodule OliWeb.Common.Listing do
  use Surface.Component
  alias OliWeb.Common.SortableTable.Table
  alias OliWeb.Common.{CardListing, Paging}

  prop total_count, :integer, required: true
  prop filter, :string, required: true
  prop limit, :integer, required: true
  prop offset, :integer, required: true
  prop table_model, :struct, required: true
  prop sort, :event, required: true
  prop page_change, :event, required: true
  prop show_bottom_paging, :boolean, default: true
  prop additional_table_class, :string, default: "table-sm"
  prop cards_view, :boolean, default: false
  prop selected, :event
  prop with_body, :boolean, default: false
  slot default

  def render(assigns) do
    ~F"""
      <div class="pb-5">
        {#if @filter != ""}
          <strong>Results filtered on &quot;{@filter}&quot;</strong>
        {/if}

        {#if @total_count > 0 and @total_count > @limit}
          <Paging id="header_paging" total_count={@total_count} offset={@offset} limit={@limit} click={@page_change}/>
          {render_table(assigns)}
          {#if @show_bottom_paging}
            <Paging id="footer_paging" total_count={@total_count} offset={@offset} limit={@limit} click={@page_change}/>
          {/if}
        {#elseif @total_count > 0}
          <div>Showing all results ({@total_count} total)</div>
          <br>
          {render_table(assigns)}
        {#else}
          <p>None exist</p>
        {/if}
      </div>
    """
  end

  defp render_table(assigns) do
    ~F"""
      {#if @cards_view}
        <CardListing model={@table_model} selected={@selected}/>
      {#elseif @with_body}
        <#slot />
      {#else}
        <Table model={@table_model} sort={@sort} additional_table_class={@additional_table_class}/>
      {/if}
    """
  end
end
