defmodule OliWeb.Common.PagedTable do
  use Phoenix.Component
  alias OliWeb.Common.SortableTable.Table
  alias OliWeb.Common.Paging

  attr :total_count, :integer, required: true
  attr :filter, :string, default: ""
  attr :limit, :integer, required: true
  attr :offset, :integer, required: true
  attr :table_model, :map, required: true
  attr :allow_selection, :boolean, required: false, default: false
  attr :sort, :string, default: "paged_table_sort"
  attr :page_change, :string, default: "paged_table_page_change"
  attr :selection_change, :string, default: "paged_table_selection_change"
  attr :show_bottom_paging, :boolean, default: true
  attr :show_top_paging, :boolean, default: true
  attr :additional_table_class, :string, default: ""
  attr :render_top_info, :boolean, default: true

  def render(assigns) do
    ~H"""
    <div class="overflow-x-scroll">
      <%= if @filter != "" and @render_top_info do %>
        <strong>Results filtered on &quot;<%= @filter %>&quot;</strong>
      <% end %>

      <%= if(@total_count > 0 and @total_count > @limit) do %>
        <%= if @show_top_paging do %>
          <Paging.render
            id="header_paging"
            total_count={@total_count}
            offset={@offset}
            limit={@limit}
            click={@page_change}
          />
        <% end %>
        <%= render_table(%{
          allow_selection: @allow_selection,
          table_model: @table_model,
          sort: @sort,
          selection_change: @selection_change,
          additional_table_class: @additional_table_class
        }) %>
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
          <%= if @render_top_info do %>
            <div class="px-5 py-2">Showing all results (<%= @total_count %> total)</div>
          <% end %>
          <%= render_table(%{
            allow_selection: @allow_selection,
            table_model: @table_model,
            sort: @sort,
            selection_change: @selection_change,
            additional_table_class: @additional_table_class
          }) %>
        <% else %>
          <p class="px-5 py-2">None exist</p>
        <% end %>
      <% end %>
    </div>
    """
  end

  def render_table(assigns) do
    if assigns.allow_selection do
      ~H"""
      <Table.render
        model={@table_model}
        sort={@sort}
        select={@selection_change}
        additional_table_class={@additional_table_class}
      />
      """
    else
      ~H"""
      <Table.render model={@table_model} sort={@sort} additional_table_class={@additional_table_class} />
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
