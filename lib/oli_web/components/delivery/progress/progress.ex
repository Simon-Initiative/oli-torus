defmodule OliWeb.Components.Delivery.Progress do
  use OliWeb, :live_component

  alias OliWeb.Common.{PagedTable, SearchInput, Params}
  alias OliWeb.Components.Delivery.StudentProgressTabelModel
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    sort_order: :asc,
    sort_by: :title,
    text_search: nil
  }

  def update(
        %{
          student_id: student_id,
          section_slug: section_slug,
          params: params,
          ctx: ctx,
          pages: pages
        } = _assigns,
        socket
      ) do
    params = decode_params(params)

    {total_count, rows} = apply_filters(pages, params)

    {:ok, table_model} =
      StudentProgressTabelModel.new(
        rows,
        section_slug,
        student_id,
        ctx
      )

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec ->
            col_spec.name == params.sort_by
          end)
      })

    {:ok,
     assign(socket,
       table_model: table_model,
       total_count: total_count,
       params: params,
       section_slug: section_slug,
       student_id: student_id
     )}
  end

  attr(:title, :string, default: "Progress")
  attr(:params, :map, required: true)
  attr(:total_count, :integer, required: true)
  attr(:table_model, :map, required: true)
  attr(:ctx, :map, required: true)

  def render(assigns) do
    ~H"""
    <div class="mx-10 mb-10 bg-white">
      <div class="flex flex-col sm:flex-row sm:items-end px-6 py-4 instructor_dashboard_table">
        <h4 class="pl-9 !py-2 torus-h4 mr-auto">{@title}</h4>
        <form
          for="search"
          phx-target={@myself}
          phx-change="search_progress"
          class="pb-6 ml-9 w-44 sm:pb-0"
        >
          <SearchInput.render
            id="progress_search_input"
            name="resource_title"
            text={@params.text_search}
          />
        </form>
      </div>

      <%= if @total_count > 0 do %>
        <div id="progress-table">
          <PagedTable.render
            table_model={@table_model}
            page_change={JS.push("paged_table_page_change", target: @myself)}
            sort={JS.push("paged_table_sort", target: @myself)}
            total_count={@total_count}
            offset={@params.offset}
            limit={@params.limit}
            additional_table_class="instructor_dashboard_table"
            show_bottom_paging={false}
            render_top_info={false}
            limit_change={JS.push("paged_table_limit_change", target: @myself)}
            show_limit_change={true}
          />
        </div>
      <% else %>
        <h6 class="text-center py-4">There are no progress to show</h6>
      <% end %>
    </div>
    """
  end

  def handle_event("search_progress", %{"resource_title" => resource_title}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.student_id,
           :progress,
           update_params(socket.assigns.params, %{text_search: resource_title})
         )
     )}
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.student_id,
           :progress,
           update_params(socket.assigns.params, %{sort_by: String.to_existing_atom(sort_by)})
         )
     )}
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.student_id,
           :progress,
           update_params(socket.assigns.params, %{limit: limit, offset: offset})
         )
     )}
  end

  def handle_event(
        "paged_table_limit_change",
        params,
        %{assigns: %{params: current_params}} = socket
      ) do
    new_limit = Params.get_int_param(params, "limit", 20)

    new_offset =
      OliWeb.Common.PagingParams.calculate_new_offset(
        current_params.offset,
        new_limit,
        socket.assigns.total_count
      )

    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.student_id,
           :progress,
           update_params(socket.assigns.params, %{limit: new_limit, offset: new_offset})
         )
     )}
  end

  defp decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      sort_order:
        Params.get_atom_param(params, "sort_order", [:asc, :desc], @default_params.sort_order),
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [:title, :type, :index],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search)
    }
  end

  defp update_params(%{sort_by: current_sort_by, sort_order: current_sort_order} = params, %{
         sort_by: new_sort_by
       })
       when current_sort_by == new_sort_by do
    toggled_sort_order = if current_sort_order == :asc, do: :desc, else: :asc
    update_params(params, %{sort_order: toggled_sort_order})
  end

  defp update_params(params, new_param) do
    Map.merge(params, new_param)
    |> purge_default_params()
  end

  defp purge_default_params(params) do
    # there is no need to add a param to the url if its value is equal to the default one
    Map.filter(params, fn {key, value} ->
      @default_params[key] != value
    end)
  end

  defp apply_filters(page_nodes, params) do
    page_nodes =
      page_nodes
      |> maybe_filter_by_text(params.text_search)
      |> sort_by(params.sort_by, params.sort_order)

    {length(page_nodes), page_nodes |> Enum.drop(params.offset) |> Enum.take(params.limit)}
  end

  defp sort_by(page_nodes, sort_by, sort_order) do
    case sort_by do
      :title ->
        Enum.sort_by(page_nodes, fn node -> node.title end, sort_order)

      :type ->
        Enum.sort_by(page_nodes, fn node -> node.type end, sort_order)

      :index ->
        Enum.sort_by(page_nodes, fn node -> node.index end, sort_order)

      _ ->
        Enum.sort_by(page_nodes, fn node -> node.title end, sort_order)
    end
  end

  defp maybe_filter_by_text(page_nodes, nil), do: page_nodes
  defp maybe_filter_by_text(page_nodes, ""), do: page_nodes

  defp maybe_filter_by_text(page_nodes, text_search) do
    page_nodes
    |> Enum.filter(fn node ->
      String.contains?(String.downcase(node.title), String.downcase(text_search))
    end)
  end
end
