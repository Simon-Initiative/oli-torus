defmodule OliWeb.Components.Delivery.Content do
  use Surface.LiveComponent

  alias Phoenix.LiveView.JS
  alias Surface.Components.Form
  alias Surface.Components.Form.{Field, Select}

  alias OliWeb.Common.{PagedTable, SearchInput}
  alias OliWeb.Components.Delivery.ContentTableModel
  alias OliWeb.Common.Params
  alias OliWeb.Router.Helpers, as: Routes

  prop params, :map, required: true
  prop total_count, :number, required: true
  prop table_model, :struct, required: true
  prop options_for_container_select, :list

  @default_params %{
    offset: 0,
    limit: 25,
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

    {:ok, table_model} = ContentTableModel.new(rows, column_name, assigns.section_slug)

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
       section_slug: assigns.section_slug,
       options_for_container_select: options_for_container_select(containers)
     )}
  end

  def render(assigns) do
    ~F"""
    <div class="mx-10 mb-10 bg-white shadow-sm">
      <div class="flex flex-col sm:flex-row sm:items-center pr-6 bg-white h-16">
        <Form for={:containers} id="container-select-form" change="filter_container" class="pl-9 torus-h4 mr-auto">
          <Field name={:container_type}>
            <Select id="container_select" options={@options_for_container_select} selected={@params.container_filter_by} class="text-delivery-body-color text-xl font-bold tracking-wide pl-0 underline underline-offset-4 mt-6 mb-3 border-none focus:!border-none"/>
          </Field>
        </Form>
        <form for="search" phx-target={@myself} phx-change="search_container" class="pb-6 ml-9 sm:pb-0">
          <SearchInput.render id="content_search_input" name="container_name" text={@params.text_search} />
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

  def handle_event(
        "filter_container",
        %{"containers" => %{"container_type" => container_type}},
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           :content,
           update_params(socket.assigns.params, %{
             container_filter_by: container_type,
             text_search: @default_params.text_search
           })
         )
     )}
  end

  def handle_event("search_container", %{"container_name" => container_name}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           :content,
           update_params(socket.assigns.params, %{text_search: container_name})
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
           :content,
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
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [
            :numbering_index,
            :container_name,
            :student_completion,
            :student_mastery,
            :student_engagement
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

      :student_mastery ->
        Enum.sort_by(containers, fn container -> container.student_mastery end, sort_order)

      :student_engagement ->
        Enum.sort_by(containers, fn container -> container.student_engagement end, sort_order)

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
end
