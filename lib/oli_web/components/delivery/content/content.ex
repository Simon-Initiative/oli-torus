defmodule OliWeb.Components.Delivery.Content do
  use OliWeb, :live_component

  alias OliWeb.Components.Delivery.ContentTableModel
  alias OliWeb.Common.InstructorDashboardPagedTable
  alias OliWeb.Common.SearchInput
  alias OliWeb.Common.Params
  alias OliWeb.Router.Helpers, as: Routes

  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    container_id: nil,
    sort_order: :asc,
    sort_by: :numbering_index,
    text_search: nil,
    container_filter_by: :units
  }

  def update(%{containers: {container_count, containers}} = assigns, socket) do
    params =
      if container_count == 0 do
        decode_params(assigns.params)
        |> Map.merge(%{container_filter_by: :pages})
      else
        decode_params(assigns.params)
      end

    {total_count, column_name, rows} = apply_filters(containers, params)

    {:ok, table_model} =
      ContentTableModel.new(
        rows,
        column_name,
        assigns.section_slug,
        assigns[:view],
        assigns.patch_url_type
      )

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec -> col_spec.name == params.sort_by end)
      })

    {:ok,
     assign(socket,
       total_count: total_count,
       table_model: table_model,
       params: params,
       student_id: assigns[:student_id],
       patch_url_type: assigns.patch_url_type,
       section_slug: assigns.section_slug,
       options_for_container_select: options_for_container_select(containers),
       view: assigns[:view]
     )}
  end

  attr(:params, :map, required: true)
  attr(:total_count, :integer, required: true)
  attr(:table_model, :map, required: true)
  attr(:options_for_container_select, :list)
  attr(:patch_url_type, :atom, required: true)
  attr(:view, :atom)
  attr(:section_slug, :string)

  def render(assigns) do
    ~H"""
    <div class="flex flex-col mb-10">
      <div class="w-full h-9 relative my-7">
        <button
          id="filter_units_button"
          class={"w-[6.5rem] h-9 left-0 top-0 absolute rounded-tl-lg rounded-bl-lg border border-slate-300 #{set_button_background(@params.container_filter_by, :units)} text-xs #{set_button_text(@params.container_filter_by, :units)}"}
          phx-click="filter_container"
          phx-value-filter="units"
          phx-target={@myself}
        >
          Units
        </button>
        <button
          id="filter_modules_button"
          class={"w-28 h-9 left-[100.52px] top-0 absolute rounded-tr-lg rounded-br-lg border border-slate-300 #{set_button_background(@params.container_filter_by, :modules)} text-xs #{set_button_text(@params.container_filter_by, :modules)}"}
          phx-click="filter_container"
          phx-value-filter="modules"
          phx-target={@myself}
        >
          Modules
        </button>
      </div>
      <div class="bg-white dark:bg-gray-800 shadow-sm">
        <div
          style="min-height: 83px;"
          class="flex justify-between gap-2 items-end px-4 sm:px-9 py-4 instructor_dashboard_table"
        >
          <div>
            <a
              href={
                Routes.delivery_path(OliWeb.Endpoint, :download_course_content_info, @section_slug,
                  container_filter_by: @params.container_filter_by
                )
              }
              download="course_content.csv"
              class="self-end"
            >
              <i class="fa-solid fa-download ml-1" /> Download
            </a>
          </div>
          <.form for={%{}} phx-target={@myself} phx-change="search_container" class="w-44">
            <SearchInput.render
              id="content_search_input"
              name="container_name"
              text={@params.text_search}
            />
          </.form>
        </div>

        <InstructorDashboardPagedTable.render
          table_model={@table_model}
          total_count={@total_count}
          offset={@params.offset}
          limit={@params.limit}
          render_top_info={false}
          additional_table_class="instructor_dashboard_table"
          sort={JS.push("paged_table_sort", target: @myself)}
          page_change={JS.push("paged_table_page_change", target: @myself)}
          limit_change={JS.push("paged_table_limit_change", target: @myself)}
          show_limit_change={true}
        />
      </div>
    </div>
    """
  end

  def handle_event("filter_container", %{"filter" => filter}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{
             container_filter_by: filter,
             text_search: @default_params.text_search
           },
           socket.assigns.patch_url_type
         )
     )}
  end

  def handle_event("search_container", %{"container_name" => container_name}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{text_search: container_name},
           socket.assigns.patch_url_type
         )
     )}
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{limit: limit, offset: offset},
           socket.assigns.patch_url_type
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
         route_for(
           socket,
           %{limit: new_limit, offset: new_offset},
           socket.assigns.patch_url_type
         )
     )}
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by} = _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{sort_by: String.to_existing_atom(sort_by)},
           socket.assigns.patch_url_type
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
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [
            :numbering_index,
            :container_name,
            :student_completion,
            :student_proficiency
          ],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      container_filter_by:
        Params.get_atom_param(
          params,
          "container_filter_by",
          [:modules, :units, :pages],
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

  defp apply_filters(containers, params) do
    case params.container_filter_by do
      :modules ->
        modules =
          containers
          |> Enum.filter(fn container -> container.numbering_level == 2 end)
          |> maybe_filter_by_text(params.text_search)
          |> sort_by(params.sort_by, params.sort_order)

        {length(modules), "MODULES",
         modules |> Enum.drop(params.offset) |> Enum.take(params.limit)}

      :units ->
        units =
          containers
          |> Enum.filter(fn container -> container.numbering_level == 1 end)
          |> maybe_filter_by_text(params.text_search)
          |> sort_by(params.sort_by, params.sort_order)

        {length(units), "UNITS", units |> Enum.drop(params.offset) |> Enum.take(params.limit)}

      :pages ->
        pages =
          containers
          |> maybe_filter_by_text(params.text_search)
          |> sort_by(params.sort_by, params.sort_order)

        {length(pages), "PAGES", pages |> Enum.drop(params.offset) |> Enum.take(params.limit)}
    end
  end

  defp sort_by(containers, sort_by, sort_order) do
    case sort_by do
      :numbering_index ->
        Enum.sort_by(containers, fn container -> container.numbering_index end, sort_order)

      :container_name ->
        Enum.sort_by(containers, fn container -> container.title end, sort_order)

      :student_completion ->
        Enum.sort_by(containers, fn container -> container.progress end, sort_order)

      :student_proficiency ->
        Enum.sort_by(containers, fn container -> container.student_proficiency end, sort_order)

      _ ->
        Enum.sort_by(containers, fn container -> container.title end, sort_order)
    end
  end

  defp maybe_filter_by_text(containers, nil), do: containers
  defp maybe_filter_by_text(containers, ""), do: containers

  defp maybe_filter_by_text(containers, text_search) do
    containers
    |> Enum.filter(fn container ->
      String.contains?(String.downcase(container.title), String.downcase(text_search))
    end)
  end

  defp options_for_container_select(containers) do
    Enum.reduce(containers, %{units: false, modules: false}, fn container, acc ->
      case container[:numbering_level] do
        1 -> %{acc | units: true}
        2 -> %{acc | modules: true}
        nil -> acc
      end
    end)
    |> case do
      %{units: true, modules: true} -> [Modules: :modules, Units: :units]
      %{units: true, modules: false} -> [Units: :units]
      %{units: false, modules: true} -> [Modules: :modules]
      %{units: false, modules: false} -> [Pages: :pages]
    end
  end

  defp route_for(socket, new_params, :instructor_dashboard) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      socket.assigns.section_slug,
      socket.assigns.view,
      :content,
      update_params(socket.assigns.params, new_params)
    )
  end

  defp route_for(socket, new_params, :student_dashboard) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
      socket.assigns.section_slug,
      socket.assigns.student_id,
      :content,
      update_params(socket.assigns.params, new_params)
    )
  end

  defp set_button_background(container_filter_by, filter),
    do: if(container_filter_by == filter, do: "bg-blue-500 dark:bg-gray-800", else: "bg-white")

  defp set_button_text(container_filter_by, filter),
    do:
      if(container_filter_by == filter,
        do: "text-white font-bold",
        else: "text-zinc-700 font-normal"
      )
end
