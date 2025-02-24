defmodule OliWeb.Components.Delivery.LearningObjectives do
  use OliWeb, :live_component

  import OliWeb.Components.Delivery.Buttons, only: [toggle_chevron: 1]

  alias OliWeb.Common.InstructorDashboardPagedTable
  alias OliWeb.Common.Params
  alias OliWeb.Common.SearchInput
  alias OliWeb.Components.Delivery.CardHighlights
  alias OliWeb.Delivery.LearningObjectives.ObjectivesTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.JS
  alias OliWeb.Icons

  @default_params %{
    offset: 0,
    limit: 20,
    container_id: nil,
    sort_order: :asc,
    sort_by: :objective,
    text_search: nil,
    filter_by: "root",
    selected_proficiency_ids: Jason.encode!([]),
    selected_card_value: nil
  }

  @proficiency_options [
    %{id: 1, name: "Low", selected: false},
    %{id: 2, name: "Medium", selected: false},
    %{id: 3, name: "High", selected: false}
  ]

  def update(
        %{
          objectives_tab: objectives_tab,
          params: params,
          section_slug: section_slug,
          v25_migration: v25_migration
        } = assigns,
        socket
      ) do
    params = decode_params(params)

    {total_count, rows} =
      apply_filters(objectives_tab.objectives, params, assigns[:patch_url_type])

    {:ok, objectives_table_model} = ObjectivesTableModel.new(rows, assigns[:patch_url_type])

    objectives_table_model =
      Map.merge(objectives_table_model, %{
        rows: rows,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(objectives_table_model.column_specs, fn col_spec ->
            col_spec.name == params.sort_by
          end)
      })

    selected_card_value = Map.get(assigns.params, "selected_card_value", nil)
    objectives_count = objectives_count(objectives_tab.objectives)

    card_props = [
      %{
        title: "Low Proficiency Outcomes",
        count: Map.get(objectives_count, :low_proficiency_outcomes),
        is_selected: selected_card_value == "low_proficiency_outcomes",
        value: :low_proficiency_outcomes,
        subtitle: "learning objectives"
      },
      %{
        title: "Low Proficiency Skills",
        count: Map.get(objectives_count, :low_proficiency_skills),
        is_selected: selected_card_value == "low_proficiency_skills",
        value: :low_proficiency_skills,
        subtitle: "sub-objectives"
      }
    ]

    selected_proficiency_ids = Jason.decode!(params.selected_proficiency_ids)

    proficiency_options =
      update_proficiency_options(selected_proficiency_ids, @proficiency_options)

    selected_proficiency_options =
      Enum.reduce(proficiency_options, %{}, fn option, acc ->
        if option.selected,
          do: Map.put(acc, option.id, option.name),
          else: acc
      end)

    {:ok,
     assign(socket,
       table_model: objectives_table_model,
       total_count: total_count,
       params: params,
       student_id: assigns[:student_id],
       patch_url_type: assigns.patch_url_type,
       section_slug: section_slug,
       units_modules: objectives_tab.filter_options,
       filter_disabled?: filter_by_module_disabled?(v25_migration),
       view: assigns[:view],
       proficiency_options: proficiency_options,
       selected_proficiency_options: selected_proficiency_options,
       selected_proficiency_ids: selected_proficiency_ids,
       card_props: card_props
     )}
  end

  attr(:params, :any)
  attr(:table_model, :any)
  attr(:total_count, :integer)
  attr(:units_modules, :map)
  attr(:student_id, :integer)
  attr(:patch_url_type, :atom, required: true)
  attr(:filter_disabled?, :boolean)
  attr(:view, :atom)
  attr(:section_slug, :string)
  attr(:card_props, :list)

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 mb-10">
      <div class="bg-white shadow-sm dark:bg-gray-800">
        <div class="flex justify-between items-center px-4 sm:px-9 py-4 instructor_dashboard_table">
          <div>
            <h4 class="torus-h4 !py-0 mr-auto mb-2">Learning Objectives</h4>
          </div>

          <div class="flex flex-col-reverse sm:flex-row gap-2 items-end overflow-hidden">
            <.form for={%{}} class="w-full" phx-change="filter_by" phx-target={@myself}>
              <label class="cursor-pointer inline-flex flex-col gap-1 w-full">
                <small class="torus-small uppercase">
                  Filter by module
                  <i
                    :if={@filter_disabled?}
                    id="filter-disabled-tooltip"
                    class="fas fa-info-circle"
                    title="This filter will be available soon"
                    phx-hook="TooltipInit"
                  />
                </small>
                <select class="torus-select" name="filter" disabled={@filter_disabled?}>
                  <option selected={@params.filter_by == "root"} value="root">Root</option>
                  <option
                    :for={module <- @units_modules}
                    selected={@params.filter_by == module.container_id}
                    value={module.container_id}
                  >
                    <%= module.title %>
                  </option>
                </select>
              </label>
            </.form>
          </div>
          <a
            href={Routes.delivery_path(OliWeb.Endpoint, :download_learning_objectives, @section_slug)}
            class="flex items-center justify-center gap-x-2"
          >
            Download CSV <Icons.download />
          </a>
        </div>
        <div class="flex flex-row mx-9 gap-x-4">
          <%= for card <- @card_props do %>
            <CardHighlights.render
              title={card.title}
              count={card.count}
              is_selected={card.is_selected}
              value={card.value}
              on_click={JS.push("select_card", target: @myself)}
              container_filter_by={card.subtitle}
            />
          <% end %>
        </div>
        <div class="flex flex-row items-center gap-x-4 mx-9 my-4 dark:bg-gray-800">
          <.form
            for={%{}}
            phx-target={@myself}
            phx-change="search_objective"
            class="w-44 border-zinc-400"
          >
            <SearchInput.render
              id="objective_search_input"
              name="objective_name"
              text={@params.text_search}
              class="w-44"
            />
          </.form>
          <.multi_select
            id="proficiency_select"
            options={@proficiency_options}
            selected_values={@selected_proficiency_options}
            selected_proficiency_ids={@selected_proficiency_ids}
            target={@myself}
            disabled={@selected_proficiency_ids == %{}}
            placeholder="Proficiency"
          />
          <button
            class="text-center text-blue-500 text-xs font-semibold underline leading-none"
            phx-click="clear_all_filters"
            phx-target={@myself}
          >
            Clear All Filters
          </button>
        </div>

        <%= if @total_count > 0 do %>
          <div id="objectives-table">
            <InstructorDashboardPagedTable.render
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
          <h6 class="text-center py-4 bg-white dark:bg-gray-800">There are no objectives to show</h6>
        <% end %>
      </div>
    </div>
    """
  end

  attr :placeholder, :string, default: "Select an option"
  attr :disabled, :boolean, default: false
  attr :options, :list, default: []
  attr :id, :string
  attr :target, :map, default: %{}
  attr :selected_values, :map, default: %{}
  attr :selected_proficiency_ids, :list, default: []

  def multi_select(assigns) do
    ~H"""
    <div class={"flex flex-col border relative rounded-md h-9 #{if @selected_values != %{}, do: "border-blue-500", else: "border-zinc-400"}"}>
      <div
        phx-click={
          if(!@disabled,
            do:
              JS.toggle(to: "##{@id}-options-container")
              |> JS.toggle(to: "##{@id}-down-icon")
              |> JS.toggle(to: "##{@id}-up-icon")
          )
        }
        class={[
          "flex gap-x-4 px-4 h-9 justify-between items-center w-auto hover:cursor-pointer rounded",
          if(@disabled, do: "bg-gray-300 hover:cursor-not-allowed")
        ]}
        id={"#{@id}-selected-options-container"}
      >
        <div class="flex gap-1 flex-wrap">
          <span
            :if={@selected_values == %{}}
            class="text-zinc-900 text-xs font-semibold leading-none dark:text-white"
          >
            <%= @placeholder %>
          </span>
          <span :if={@selected_values != %{}} class="text-blue-500 text-xs font-semibold leading-none">
            Proficiency is <%= show_proficiency_selected_values(@selected_values) %>
          </span>
        </div>
        <.toggle_chevron id={@id} map_values={@selected_values} />
      </div>
      <div class="relative">
        <div
          class="py-4 hidden z-50 absolute dark:bg-gray-800 bg-white w-48 border overflow-y-scroll top-1 rounded"
          id={"#{@id}-options-container"}
          phx-click-away={
            JS.hide() |> JS.hide(to: "##{@id}-up-icon") |> JS.show(to: "##{@id}-down-icon")
          }
        >
          <div>
            <.form
              :let={_f}
              class="flex flex-column gap-y-3 px-4"
              for={%{}}
              as={:options}
              phx-change="toggle_selected"
              phx-target={@target}
            >
              <.input
                :for={option <- @options}
                name={option.id}
                value={option.selected}
                label={option.name}
                checked={option.id in @selected_proficiency_ids}
                type="checkbox"
                label_class="text-zinc-900 text-xs font-normal leading-none dark:text-white"
              />
            </.form>
          </div>
          <div class="w-full border border-gray-200 my-4"></div>
          <div class="flex flex-row items-center justify-end px-4 gap-x-4">
            <button
              class="text-center text-neutral-600 text-xs font-semibold leading-none dark:text-white"
              phx-click={
                JS.hide(to: "##{@id}-options-container")
                |> JS.hide(to: "##{@id}-up-icon")
                |> JS.show(to: "##{@id}-down-icon")
              }
            >
              Cancel
            </button>
            <button
              class="px-4 py-2 bg-blue-500 rounded justify-center items-center gap-2 inline-flex opacity-90 text-right text-white text-xs font-semibold leading-none"
              phx-click={
                JS.push("apply_proficiency_filter")
                |> JS.hide(to: "##{@id}-options-container")
                |> JS.hide(to: "##{@id}-up-icon")
                |> JS.show(to: "##{@id}-down-icon")
              }
              phx-target={@target}
              phx-value={@selected_proficiency_ids}
              disabled={@disabled}
            >
              Apply
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("select_card", %{"selected" => value}, socket) do
    value =
      if String.to_existing_atom(value) == Map.get(socket.assigns.params, :selected_card_value),
        do: nil,
        else: String.to_existing_atom(value)

    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{selected_card_value: value},
           socket.assigns.patch_url_type
         )
     )}
  end

  def handle_event("toggle_selected", %{"_target" => [id]}, socket) do
    selected_id = String.to_integer(id)
    do_update_selection(socket, selected_id)
  end

  def handle_event("apply_proficiency_filter", _params, socket) do
    %{
      selected_proficiency_ids: selected_proficiency_ids,
      patch_url_type: patch_url_type
    } = socket.assigns

    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{selected_proficiency_ids: Jason.encode!(selected_proficiency_ids)},
           patch_url_type
         )
     )}
  end

  def handle_event("clear_all_filters", _params, socket) do
    %{section_slug: section_slug} = socket.assigns

    {:noreply,
     push_patch(socket,
       to: ~p"/sections/#{section_slug}/instructor_dashboard/insights/learning_objectives"
     )}
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

  defp do_update_selection(socket, selected_id) do
    %{proficiency_options: proficiency_options} = socket.assigns

    updated_options =
      Enum.map(proficiency_options, fn option ->
        if option.id == selected_id, do: %{option | selected: !option.selected}, else: option
      end)

    {selected_proficiency_options, selected_ids} =
      Enum.reduce(updated_options, {%{}, []}, fn option, {values, acc_ids} ->
        if option.selected,
          do: {Map.put(values, option.id, option.name), [option.id | acc_ids]},
          else: {values, acc_ids}
      end)

    {:noreply,
     assign(socket,
       selected_proficiency_options: selected_proficiency_options,
       proficiency_options: updated_options,
       selected_proficiency_ids: selected_ids
     )}
  end

  defp show_proficiency_selected_values(values) do
    Enum.map_join(values, ", ", fn {_id, values} -> values end)
  end

  defp update_proficiency_options(selected_proficiency_ids, proficiency_options) do
    Enum.map(proficiency_options, fn option ->
      if option.id in selected_proficiency_ids,
        do: %{option | selected: true},
        else: option
    end)
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
      filter_by: Params.get_int_param(params, "filter_by", @default_params.filter_by),
      selected_proficiency_ids:
        Params.get_param(
          params,
          "selected_proficiency_ids",
          @default_params.selected_proficiency_ids
        ),
      selected_card_value:
        Params.get_atom_param(
          params,
          "selected_card_value",
          [:low_proficiency_outcomes, :low_proficiency_skills],
          @default_params.selected_card_value
        )
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

  defp apply_filters(objectives, params, :instructor_dashboard) do
    objectives
    |> do_apply_filters(params)
  end

  defp apply_filters(objectives, params, _), do: do_apply_filters(objectives, params)

  defp do_apply_filters(objectives, params) do
    objectives =
      objectives
      |> maybe_filter_by_text(params.text_search)
      |> maybe_filter_by_option(params.filter_by)
      |> maybe_filter_by_proficiency(params.selected_proficiency_ids)
      |> maybe_filter_by_card(params.selected_card_value)
      |> sort_by(params.sort_by, params.sort_order)

    total_count = length(objectives)

    rows =
      objectives
      |> Enum.drop(params.offset)
      |> Enum.take(params.limit)

    {total_count, rows}
  end

  defp sort_by(objectives, sort_by, sort_order) do
    Enum.sort_by(objectives, fn obj -> obj[sort_by] end, sort_order)
  end

  defp maybe_filter_by_option(objectives, "root"), do: objectives

  defp maybe_filter_by_option(objectives, container_id) do
    Enum.filter(objectives, &(container_id in &1.container_ids))
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

  defp maybe_filter_by_proficiency(objectives, "[]"), do: objectives

  defp maybe_filter_by_proficiency(objectives, selected_proficiency_ids) do
    selected_proficiency_ids =
      Jason.decode!(selected_proficiency_ids)

    mapper_ids =
      Enum.reduce(selected_proficiency_ids, [], fn id, acc ->
        case id do
          1 -> ["Low" | acc]
          2 -> ["Medium" | acc]
          3 -> ["High" | acc]
          _ -> acc
        end
      end)

    Enum.filter(objectives, fn objective ->
      objective.student_proficiency_obj in mapper_ids
    end)
  end

  defp maybe_filter_by_card(objectives, :low_proficiency_outcomes),
    do:
      Enum.filter(objectives, fn objective ->
        objective.student_proficiency_obj == "Low"
      end)

  defp maybe_filter_by_card(objectives, :low_proficiency_skills),
    do:
      Enum.filter(objectives, fn objective ->
        objective.student_proficiency_subobj == "Low"
      end)

  defp maybe_filter_by_card(objectives, _), do: objectives

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

  defp objectives_count(objectives) do
    %{
      low_proficiency_outcomes:
        Enum.count(objectives, fn obj ->
          obj.student_proficiency_obj == "Low"
        end),
      low_proficiency_skills:
        Enum.count(objectives, fn obj ->
          obj.student_proficiency_subobj == "Low"
        end)
    }
  end

  # Returns true if the filter by module feature is disabled for the section.
  # This happens when the contained objectives for the section were not yet created.
  defp filter_by_module_disabled?(v25_migration)
  defp filter_by_module_disabled?(:done), do: false
  defp filter_by_module_disabled?(_), do: true
end
