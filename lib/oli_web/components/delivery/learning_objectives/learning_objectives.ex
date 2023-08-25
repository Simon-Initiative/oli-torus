defmodule OliWeb.Components.Delivery.LearningObjectives do
  use OliWeb, :live_component

  alias OliWeb.Common.{PagedTable, SearchInput}
  alias Phoenix.LiveView.JS
  alias OliWeb.Delivery.LearningObjectives.ObjectivesTableModel
  alias OliWeb.Common.Params
  alias OliWeb.Router.Helpers, as: Routes

  @default_params %{
    offset: 0,
    limit: 10,
    container_id: nil,
    sort_order: :asc,
    sort_by: :objective,
    text_search: nil,
    filter_by: "all"
  }

  def update(
        %{
          objectives_tab: objectives_tab,
          section_slug: section_slug,
          params: params
        } = assigns,
        socket
      ) do
    params = decode_params(params)

    units_modules = objectives_tab.filter_options

    {total_count, rows} = apply_filters(objectives_tab.objectives, params, units_modules)

    {:ok, objectives_table_model} = ObjectivesTableModel.new(rows)

    objectives_table_model =
      Map.merge(objectives_table_model, %{
        rows: rows,
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
       student_id: assigns[:student_id],
       patch_url_type: assigns.patch_url_type,
       section_slug: section_slug,
       units_modules: units_modules,
       view: assigns[:view]
     )}
  end

  attr(:params, :any)
  attr(:table_model, :any)
  attr(:total_count, :integer)
  attr(:units_modules, :map)
  attr(:student_id, :integer)
  attr(:patch_url_type, :atom, required: true)
  attr(:view, :atom)
  attr(:section_slug, :string)

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 mx-10 mb-10">
      <div class="bg-white shadow-sm">
        <div class="flex justify-between sm:items-end px-4 sm:px-9 py-4 instructor_dashboard_table">
          <div>
            <h4 class="torus-h4 !py-0 mr-auto mb-2">Learning Objectives</h4>
            <a
              href={
                Routes.delivery_path(OliWeb.Endpoint, :download_learning_objectives, @section_slug)
              }
              class="self-end"
            >
              <i class="fa-solid fa-download ml-1" /> Download
            </a>
          </div>
          <div class="flex flex-col-reverse sm:flex-row gap-2 items-end">
            <.form for={:search} phx-target={@myself} phx-change="search_objective" class="w-44">
              <SearchInput.render
                id="objective_search_input"
                name="objective_name"
                text={@params.text_search}
              />
            </.form>
          </div>
        </div>

        <%= if @total_count > 0 do %>
          <div id="objectives-table">
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
            />
          </div>
        <% else %>
          <h6 class="text-center py-4">There are no objectives to show</h6>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("filter_by", %{"filter" => filter}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{filter_by: filter, offset: 0},
           socket.assigns.patch_url_type
         )
     )}
  end

  def handle_event(
        "search_objective",
        %{"objective_name" => objective_name},
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{text_search: objective_name},
           socket.assigns.patch_url_type
         )
     )}
  end

  def handle_event(
        "paged_table_sort",
        %{"sort_by" => sort_by} = _params,
        socket
      ) do
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

  def handle_event(
        "paged_table_page_change",
        %{"limit" => limit, "offset" => offset},
        socket
      ) do
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

  defp decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      sort_order:
        Params.get_atom_param(
          params,
          "sort_order",
          [:asc, :desc],
          @default_params.sort_order
        ),
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [
            :objective,
            :subobjective,
            :student_proficiency_obj,
            :student_proficiency_subobj
          ],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      filter_by: Params.get_param(params, "filter_by", @default_params.filter_by)
    }
  end

  defp update_params(
         %{sort_by: current_sort_by, sort_order: current_sort_order} = params,
         %{
           sort_by: new_sort_by
         }
       )
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

  defp apply_filters(objectives, params, units_modules) do
    objectives =
      objectives
      |> maybe_filter_by_text(params.text_search)
      |> maybe_filter_by_option(params.filter_by, units_modules)
      |> sort_by(params.sort_by, params.sort_order)

    {length(objectives), objectives |> Enum.drop(params.offset) |> Enum.take(params.limit)}
  end

  defp sort_by(objectives, sort_by, sort_order) do
    Enum.sort_by(objectives, fn obj -> obj[sort_by] end, sort_order)
  end

  defp maybe_filter_by_option(objectives, "all", _units_modules), do: objectives

  defp maybe_filter_by_option(objectives, container_id, units_modules) do
    container =
      Enum.filter(units_modules, fn elem ->
        elem.container_id == String.to_integer(container_id)
      end)
      |> List.first()

    Enum.filter(objectives, fn objective ->
      if is_nil(objective[:pages_id]),
        do: false,
        else:
          Enum.any?(objective[:pages_id], fn page_id ->
            Enum.member?(container.children, page_id)
          end)
    end)
  end

  defp maybe_filter_by_text(objectives, nil), do: objectives
  defp maybe_filter_by_text(objectives, ""), do: objectives

  defp maybe_filter_by_text(objectives, text_search) do
    objectives
    |> Enum.filter(fn objective ->
      String.contains?(
        String.downcase(objective.objective),
        String.downcase(text_search)
      )
    end)
  end

  defp route_for(socket, new_params, :instructor_dashboard) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      socket.assigns.section_slug,
      socket.assigns.view,
      :learning_objectives,
      update_params(socket.assigns.params, new_params)
    )
  end

  defp route_for(socket, new_params, :student_dashboard) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
      socket.assigns.section_slug,
      socket.assigns.student_id,
      :learning_objectives,
      update_params(socket.assigns.params, new_params)
    )
  end
end
