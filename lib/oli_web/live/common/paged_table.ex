defmodule OliWeb.Common.PagedTable do
  use Surface.Component
  alias OliWeb.Common.SortableTable.Table
  alias OliWeb.Common.Paging

  prop total_count, :integer, required: true
  prop filter, :string, required: true
  prop limit, :integer, required: true
  prop offset, :integer, required: true
  prop table_model, :struct, required: true
  prop allow_selection, :boolean, required: false, default: false
  prop sort, :event, default: "paged_table_sort"
  prop page_change, :event, default: "paged_table_page_change"
  prop selection_change, :event, default: "paged_table_selection_change"
  prop show_bottom_paging, :boolean, default: true
  prop additional_table_class, :string, default: ""
  prop render_top_info, :boolean, default: true

  def render(assigns) do
    ~F"""
      <div class="overflow-x-scroll">
        {#if @filter != "" and @render_top_info}
          <strong>Results filtered on &quot;{@filter}&quot;</strong>
        {/if}

        {#if @total_count > 0 and @total_count > @limit}
          <Paging id="header_paging" total_count={@total_count} offset={@offset} limit={@limit} click={@page_change}/>
          {render_table(assigns)}
          {#if @show_bottom_paging}
            <Paging id="footer_paging" total_count={@total_count} offset={@offset} limit={@limit} click={@page_change}/>
          {/if}
        {#elseif @total_count > 0}
          {#if @render_top_info}
            <div class="px-5 py-2">Showing all results ({@total_count} total)</div>
          {/if}
          {render_table(assigns)}
        {#else}
          <p class="px-5 py-2">None exist</p>
        {/if}
      </div>
    """
  end

  def render_table(assigns) do
    if assigns.allow_selection do
      ~F"""
      <Table model={@table_model} sort={@sort} select={@selection_change} additional_table_class={@additional_table_class}/>
      """
    else
      ~F"""
      <Table model={@table_model} sort={@sort} additional_table_class={@additional_table_class}/>
      """
    end
  end

  @spec handle_delegated(<<_::64, _::_*8>>, map, any, (any, any -> any), any) :: any
  def handle_delegated(event, params, socket, patch_fn, model_key \\ :table_model) do
    delegate_handle_event(event, params, socket, patch_fn, model_key)
  end

  def delegate_handle_event("paged_table_page_change", %{"offset" => offset}, socket, patch_fn, _) do
    patch_fn.(socket, %{offset: offset})
  end

  def delegate_handle_event(
        "paged_table_selection_change",
        %{"id" => selected},
        socket,
        patch_fn,
        _
      ) do
    patch_fn.(socket, %{selected: selected})
  end

  # handle change of selection
  def delegate_handle_event(
        "paged_table_sort",
        %{"sort_by" => sort_by},
        socket,
        patch_fn,
        model_key
      ) do
    sort_order =
      case Atom.to_string(socket.assigns[model_key].sort_by_spec.name) do
        ^sort_by ->
          if socket.assigns[model_key].sort_order == :asc do
            :desc
          else
            :asc
          end

        _ ->
          socket.assigns[model_key].sort_order
      end

    patch_fn.(socket, %{
      sort_by: sort_by,
      sort_order: sort_order
    })
  end

  def delegate_handle_event(_, _, _, _) do
    :not_handled
  end
end
