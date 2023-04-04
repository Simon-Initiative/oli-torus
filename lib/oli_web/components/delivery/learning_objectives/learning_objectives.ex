defmodule OliWeb.Components.Delivery.LearningObjectives do
  use Surface.LiveComponent

  alias OliWeb.Common.{PagedTable, SearchInput}
  alias Phoenix.LiveView.JS
  alias Oli.Delivery.Sections
  alias OliWeb.Delivery.LearningObjectives.ObjectivesTableModel
  alias OliWeb.Common.Params
  alias OliWeb.Router.Helpers, as: Routes

  prop params, :any
  prop table_model, :any
  prop total_count, :integer
  prop units_modules, :map

  @default_params %{
    offset: 0,
    limit: 10,
    container_id: nil,
    sort_order: :asc,
    sort_by: :objective,
    text_search: nil,
    filter_by: "all"
  }

  def update(assigns, socket) do
    params = decode_params(assigns.params)

    {objectives, total_count} =
      Sections.get_objectives_and_subobjectives(assigns.section_slug, params)

    units_modules = Sections.get_units_and_modules_from_a_section(assigns.section_slug)

    {:ok, objectives_table_model} = ObjectivesTableModel.new(objectives)

    objectives_table_model =
      Map.merge(objectives_table_model, %{
        rows: objectives,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(objectives_table_model.column_specs, fn col_spec ->
            col_spec.name == params.sort_by
          end)
      })

    {:ok,
     assign(socket,
       table_model: objectives_table_model,
       total_count: total_count,
       params: params,
       section_slug: assigns.section_slug,
       units_modules: units_modules
     )}
  end

  def render(assigns) do
    ~F"""
    <div class="mx-10 mb-10 bg-white">
      <div class="flex flex-col sm:flex-row sm:items-end px-6 py-4 border instructor_dashboard_table">
        <h4 class="pl-9 !py-2 torus-h4 mr-auto">Learning Objectives</h4>
        <div class="flex items-end gap-2">
          <form phx-change="filter_by" phx-target={@myself}>
            <label class="cursor-pointer inline-flex flex-col gap-1">
              <small class="torus-small uppercase">Filter by</small>
              <select class="torus-select pr-32" name="filter">
                <option selected={@params.filter_by == "all"} value={"all"}>All</option>
                {#for elem <- @units_modules}
                  <option selected={@params.filter_by == Integer.to_string(elem.container_id)} value={elem.container_id}>{elem.title}</option>
                {/for}
              </select>
            </label>
          </form>
        </div>

        <form for="search" phx-target={@myself} phx-change="search_objective" class="pb-6 ml-9 sm:pb-0">
          <SearchInput.render id="objective_search_input" name="objective_name" text={@params.text_search} />
        </form>
      </div>

      {#if @total_count > 0}
        <div id="objectives-table">
          <PagedTable
            table_model={@table_model}
            page_change={JS.push("paged_table_page_change", target: @myself)}
            sort={JS.push("paged_table_sort", target: @myself)}
            total_count={@total_count}
            offset={@params.offset}
            limit={@params.limit}
            additional_table_class="instructor_dashboard_table"
            show_bottom_paging={false}
            render_top_info={false}
          />
        </div>
      {#else}
        <h6 class="text-center mt-4">There are no objectives to show</h6>
      {/if}
    </div>
    """
  end

  def handle_event("filter_by", %{"filter" => filter}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           :learning_objectives,
           update_params(socket.assigns.params, %{filter_by: filter, offset: 0})
         )
     )}
  end

  def handle_event("search_objective", %{"objective_name" => objective_name}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           :learning_objectives,
           update_params(socket.assigns.params, %{text_search: objective_name})
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
           :learning_objectives,
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
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           :learning_objectives,
           update_params(socket.assigns.params, %{limit: limit, offset: offset})
         )
     )}
  end

  defp decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      sort_order:
        Params.get_atom_param(params, "sort_order", [:asc, :desc], @default_params.sort_order),
      sort_by: Params.get_atom_param(params, "sort_by", [:objective, :subobjective], @default_params.sort_by),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      filter_by: Params.get_param(params, "filter_by", @default_params.filter_by)
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
