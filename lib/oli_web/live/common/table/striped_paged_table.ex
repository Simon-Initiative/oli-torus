defmodule OliWeb.Common.StripedPagedTable do
  use Phoenix.Component
  alias OliWeb.Common.SortableTable.StripedTable
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
  attr :limit_change, :string, default: "paged_table_limit_change"
  attr :show_bottom_paging, :boolean, default: true

  attr :additional_table_class, :string, default: ""
  attr :render_top_info, :boolean, default: true
  attr :scrollable, :boolean, default: true
  attr :show_limit_change, :boolean, default: false
  attr :no_records_message, :string, default: "None exist"
  attr :overflow_class, :string, default: "inline"

  def render(assigns) do
    ~H"""
    <div class={if @scrollable, do: "overflow-x-auto #{@overflow_class}"}>
      <%= if @filter != "" and @render_top_info do %>
        <strong>Results filtered on &quot;{@filter}&quot;</strong>
      <% end %>

      <%= if @total_count > 0 do %>
        <div :if={@total_count <= @limit and @render_top_info} class="px-5 py-2">
          Showing all results ({@total_count} total)
        </div>
        <div class="relative max-h-[650px] overflow-y-auto overflow-x-auto mx-4">
          {render_table(%{
            allow_selection: @allow_selection,
            table_model: @table_model,
            sort: @sort,
            selection_change: @selection_change,
            additional_table_class: @additional_table_class
          })}
        </div>
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
          <p>{@no_records_message}</p>
        </div>
      <% end %>
    </div>
    """
  end

  def render_table(assigns) do
    if assigns.allow_selection do
      ~H"""
      <StripedTable.render
        model={@table_model}
        sort={@sort}
        select={@selection_change}
        additional_table_class={@additional_table_class}
      />
      """
    else
      ~H"""
      <StripedTable.render
        model={@table_model}
        sort={@sort}
        additional_table_class={@additional_table_class}
      />
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
        "paged_table_limit_change",
        params,
        %{assigns: %{params: current_params}} = socket,
        patch_fn,
        _
      ) do
    new_limit = OliWeb.Common.Params.get_int_param(params, "limit", 20)

    new_offset =
      if socket.assigns.total_count < new_limit do
        0
      else
        OliWeb.Common.PagingParams.calculate_new_offset(
          current_params.offset,
          new_limit,
          socket.assigns.total_count
        )
      end

    patch_fn.(socket, %{limit: new_limit, offset: new_offset})
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
