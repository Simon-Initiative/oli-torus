defmodule OliWeb.Components.Delivery.Content do
  use Surface.LiveComponent

  alias Phoenix.LiveView.JS

  alias OliWeb.Common.{PagedTable, SearchInput}
  alias OliWeb.Components.Delivery.ContentTableModel
  alias OliWeb.Common.Params
  alias OliWeb.Router.Helpers, as: Routes

  prop params, :map, required: true
  prop total_count, :number, required: true
  prop table_model, :struct, required: true

  @default_params %{
    offset: 0,
    limit: 25,
    container_id: nil,
    sort_order: :asc,
    sort_by: :container_name,
    text_search: nil,
    container_filter_by: :modules
  }

  def update(%{containers: {0, pages}} = assigns, socket) do
    # TODO handle pages case
    IO.inspect(assigns)
    {:ok, socket}
  end

  def update(
        %{params: params, containers: {_, containers}, section_slug: section_slug} = _assigns,
        socket
      ) do
    params = decode_params(params)
    {total_count, container_column_name, containers} = apply_filters(containers, params)

    {:ok, table_model} = ContentTableModel.new(containers, container_column_name)

    table_model =
      Map.merge(table_model, %{
        rows: containers,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec -> col_spec.name == params.sort_by end)
      })

    {:ok,
     assign(socket,
       total_count: total_count,
       table_model: table_model,
       params: params,
       students_table_model: table_model,
       section_slug: section_slug
     )}
  end

  defp apply_filters(containers, params) do
    case params.container_filter_by do
      :modules ->
        modules =
          containers
          |> Enum.filter(fn container -> container.numbering_level == 2 end)
          |> Enum.take(params.limit)

        {length(modules), "MODULES", modules}

      :units ->
        units =
          containers
          |> Enum.filter(fn container -> container.numbering_level == 1 end)
          |> Enum.sort_by(fn container -> container.title end, params.sort_order)

        {length(units), "UNITS", units |> Enum.drop(params.offset) |> Enum.take(params.limit)}
    end
  end

  def render(assigns) do
    ~F"""
    <div class="mx-10 mb-10 bg-white shadow-sm">
      <div class="flex flex-col sm:flex-row sm:items-center pr-6 bg-white">
        <h4 class="pl-9 torus-h4 mr-auto">Content</h4>
        <form for="search" phx-target={@myself} phx-change="search_student" class="pb-6 ml-9 sm:pb-0">
          <SearchInput.render id="students_search_input" name="student_name" text={@params.text_search} />
        </form>
      </div>

      <PagedTable
        table_model={@table_model}
        total_count={@total_count}
        offset={@params.offset}
        limit={@params.limit}
        render_top_info={false}
        additional_table_class="instructor_dashboard_table"
        sort={JS.push("paged_table_sort", target: @myself)}
        page_change={JS.push("paged_table_page_change", target: @myself)}
      />
    </div>
    """
  end

  def handle_event("search_student", %{"student_name" => student_name}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           :students,
           update_params(socket.assigns.params, %{text_search: student_name})
         )
     )}
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           :students,
           update_params(socket.assigns.params, %{limit: limit, offset: offset})
         )
     )}
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by} = _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           :content,
           update_params(socket.assigns.params, %{sort_by: String.to_existing_atom(sort_by)})
         )
     )}
  end

  defp decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      container_id: Params.get_int_param(params, "container_id", @default_params.container_id),
      sort_order:
        Params.get_atom_param(params, "sort_order", [:asc, :desc], @default_params.sort_order),
      # we currently only support sorting by container_name since the other metrics have not yet been created
      sort_by:
        Params.get_atom_param(params, "sort_by", [:container_name], @default_params.sort_by),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      container_filter_by:
        Params.get_atom_param(
          params,
          "container_filter_by",
          [:modules, :units],
          @default_params.container_filter_by
        )
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
end
