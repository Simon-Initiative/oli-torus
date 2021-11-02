defmodule OliWeb.Common.Listing do
  use Surface.Component
  alias OliWeb.Common.SortableTable.Table
  alias OliWeb.Common.Paging

  prop total_count, :integer, required: true
  prop filter, :string, required: true
  prop limit, :integer, required: true
  prop offset, :integer, required: true
  prop table_model, :struct, required: true
  prop sort, :event, required: true
  prop page_change, :event, required: true
  prop show_bottom_paging, :boolean, default: true
  prop additional_table_class, :string

  def render(assigns) do
    ~F"""
    <div>
      {#if @filter != ""}
      <strong>Results filtered on &quot;{@filter}&quot;</strong>
      {/if}
      {#if @total_count > 0}
        <Paging id="header_paging" total_count={@total_count} offset={@offset} limit={@limit} click={@page_change}/>
        <Table model={@table_model} sort={@sort} additional_table_class={@additional_table_class}/>
        {#if @show_bottom_paging}
          <Paging id="footer_paging" total_count={@total_count} offset={@offset} limit={@limit} click={@page_change}/>
        {/if}
      {#else}
        <p>None exist</p>
      {/if}
      </div>
    """
  end
end
