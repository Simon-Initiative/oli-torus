defmodule OliWeb.Components.Delivery.Content do
  use OliWeb, :live_component

  alias Phoenix.LiveView.JS

  alias Oli.Delivery.Metrics
  alias OliWeb.Common.SearchInput
  alias OliWeb.Components.Delivery.{CardHighlights, ContentTableModel}
  alias OliWeb.Common.{StripedPagedTable, Params}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Delivery.Content.{MultiSelect, Progress}

  alias Phoenix.LiveView.JS
  alias OliWeb.Icons

  @default_params %{
    offset: 0,
    limit: 20,
    container_id: nil,
    sort_order: :asc,
    sort_by: :numbering_index,
    text_search: nil,
    container_filter_by: :units,
    selected_card_value: nil,
    progress_percentage: 100,
    progress_selector: nil,
    selected_proficiency_ids: Jason.encode!([])
  }

  @proficiency_options [
    %{id: 1, name: "Low", selected: false},
    %{id: 2, name: "Medium", selected: false},
    %{id: 3, name: "High", selected: false}
  ]

  def update(%{containers: {container_count, containers}} = assigns, socket) do
    params =
      if container_count == 0,
        do:
          decode_params(assigns.params)
          |> Map.merge(%{container_filter_by: :pages}),
        else: decode_params(assigns.params)

    {total_count, column_name, rows} = apply_filters(containers, params)

    containers_list = create_containers_list(containers, rows)

    request_path =
      ~p"/sections/#{assigns.section_slug}/instructor_dashboard/insights/content?#{params_without_nil_values(params)}"

    navigation_data = %{
      request_path: request_path,
      containers: containers_list,
      filter_criteria_card: params.selected_card_value,
      container_filter_by: params.container_filter_by,
      filtered_count: total_count,
      navigation_criteria: :by_filtered
    }

    {:ok, table_model} =
      ContentTableModel.new(
        rows,
        column_name,
        assigns.section_slug,
        assigns[:view],
        assigns.patch_url_type,
        navigation_data
      )

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec -> col_spec.name == params.sort_by end)
      })

    selected_card_value = Map.get(assigns.params, "selected_card_value", nil)
    containers_count = containers_count(containers, params.container_filter_by)

    card_props = [
      %{
        title: "High Progress, Low Proficiency",
        count: Map.get(containers_count, :high_progress_low_proficiency),
        is_selected: selected_card_value == "high_progress_low_proficiency",
        value: :high_progress_low_proficiency
      },
      %{
        title: "Zero Student Progress",
        count: Map.get(containers_count, :zero_student_progress),
        is_selected: selected_card_value == "zero_student_progress",
        value: :zero_student_progress
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
       total_count: total_count,
       table_model: table_model,
       params: params,
       student_id: assigns[:student_id],
       patch_url_type: assigns.patch_url_type,
       section_slug: assigns.section_slug,
       options_for_container_select: options_for_container_select(containers),
       view: assigns[:view],
       card_props: card_props,
       proficiency_options: proficiency_options,
       selected_proficiency_options: selected_proficiency_options,
       selected_proficiency_ids: selected_proficiency_ids,
       params_from_url: assigns.params,
       disable_containers_filter: container_count == 0
     )}
  end

  attr(:params, :map, required: true)
  attr(:total_count, :integer, required: true)
  attr(:table_model, :map, required: true)
  attr(:options_for_container_select, :list)
  attr(:patch_url_type, :atom, required: true)
  attr(:view, :atom)
  attr(:section_slug, :string)
  attr(:card_props, :list)
  attr(:disable_containers_filter, :boolean)

  def render(assigns) do
    ~H"""
    <div class="flex flex-col mb-10">
      <div class="w-full h-10 relative my-7">
        <button
          id="filter_units_button"
          class={"w-24 h-10 left-0 top-0 absolute rounded-tl-lg rounded-bl-lg border border-Border-border-default #{set_button_background(@params.container_filter_by, :units)} text-xs #{set_button_text(@params.container_filter_by, :units)}"}
          phx-click="filter_container"
          phx-value-filter="units"
          phx-target={@myself}
          disabled={@disable_containers_filter}
        >
          Units
        </button>
        <button
          id="filter_modules_button"
          class={"w-24 h-10 left-[95px] top-0 absolute rounded-tr-lg rounded-br-lg border border-Border-border-default #{set_button_background(@params.container_filter_by, :modules)} text-xs #{set_button_text(@params.container_filter_by, :modules)}"}
          phx-click="filter_container"
          phx-value-filter="modules"
          phx-target={@myself}
          disabled={@disable_containers_filter}
        >
          Modules
        </button>
      </div>
      <div class="bg-white dark:bg-[#262626] shadow-sm">
        <div class="flex justify-between gap-2 items-center px-4 pt-8 pb-4 instructor_dashboard_table dark:bg-[#262626]">
          <div class="text-zinc-700 text-lg font-bold leading-none tracking-tight dark:bg-gray-800 dark:text-white">
            Course <%= if @params.container_filter_by == :units, do: "Units", else: "Modules" %>
          </div>
          <div>
            <a
              href={
                Routes.delivery_path(OliWeb.Endpoint, :download_course_content_info, @section_slug,
                  container_filter_by: @params.container_filter_by
                )
              }
              download="course_content.csv"
              class="flex items-center justify-center gap-x-2 text-Text-text-button font-bold"
            >
              Download CSV <Icons.download />
            </a>
          </div>
        </div>

        <div class="flex flex-row mx-4 gap-x-4">
          <%= for card <- @card_props do %>
            <CardHighlights.render
              title={card.title}
              count={card.count}
              is_selected={card.is_selected}
              value={card.value}
              on_click={JS.push("select_card", target: @myself)}
              container_filter_by={@params.container_filter_by}
            />
          <% end %>
        </div>

        <div class="flex w-fit gap-2 mx-4 mt-4 mb-4 shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)] border border-Border-border-default bg-Background-bg-secondary">
          <div class="flex p-2 gap-2">
            <.form for={%{}} phx-target={@myself} phx-change="search_container" class="w-56">
              <SearchInput.render
                id="content_search_input"
                name="container_name"
                text={@params.text_search}
              />
            </.form>

            <Progress.render
              target={@myself}
              progress_percentage={@params.progress_percentage}
              progress_selector={@params.progress_selector}
              params_from_url={@params_from_url}
            />

            <MultiSelect.render
              id="proficiency_select"
              options={@proficiency_options}
              selected_values={@selected_proficiency_options}
              selected_proficiency_ids={@selected_proficiency_ids}
              target={@myself}
              disabled={@selected_proficiency_ids == %{}}
              placeholder="Proficiency"
            />

            <button
              class="ml-2 mr-6 text-center text-Text-text-high text-sm font-normal leading-none flex items-center gap-x-2"
              phx-click="clear_all_filters"
              phx-target={@myself}
            >
              <Icons.trash /> Clear All Filters
            </button>
          </div>
        </div>

        <StripedPagedTable.render
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

  def handle_event(
        "apply_progress_filter",
        %{
          "progress_percentage" => progress_percentage,
          "progress" => %{"option" => progress_selector}
        },
        socket
      ) do
    new_params = %{
      progress_percentage: progress_percentage,
      progress_selector: progress_selector
    }

    {:noreply,
     push_patch(socket,
       to: route_for(socket, new_params, socket.assigns.patch_url_type)
     )}
  end

  def handle_event("clear_all_filters", _params, socket) do
    section_slug = socket.assigns.section_slug
    path = ~p"/sections/#{section_slug}/instructor_dashboard/insights/content"

    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("filter_container", %{"filter" => filter}, socket) do
    socket =
      update(socket, :params, fn params ->
        %{params | progress_percentage: 100, progress_selector: nil}
      end)

    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{
             container_filter_by: filter,
             text_search: @default_params.text_search,
             selected_card_value: @default_params.selected_card_value
           },
           socket.assigns.patch_url_type
         )
     )}
  end

  def handle_event("search_container", %{"container_name" => container_name}, socket) do
    params = Map.merge(socket.assigns.params, %{text_search: container_name})
    socket = assign(socket, :params, params)

    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           params,
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

  def handle_event("select_card", %{"selected" => value}, socket) do
    value =
      if String.to_existing_atom(value) == Map.get(socket.assigns.params, :selected_card_value),
        do: nil,
        else: String.to_existing_atom(value)

    send(self(), {:selected_card_containers, value})

    {:noreply, socket}
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
        ),
      selected_card_value:
        Params.get_atom_param(
          params,
          "selected_card_value",
          [:high_progress_low_proficiency, :zero_student_progress],
          @default_params.selected_card_value
        ),
      progress_percentage:
        Params.get_int_param(params, "progress_percentage", @default_params.progress_percentage),
      progress_selector:
        Params.get_atom_param(
          params,
          "progress_selector",
          [:is_equal_to, :is_less_than_or_equal, :is_greather_than_or_equal],
          @default_params.progress_selector
        ),
      selected_proficiency_ids:
        Params.get_param(
          params,
          "selected_proficiency_ids",
          @default_params.selected_proficiency_ids
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
          |> maybe_filter_by_card(params.selected_card_value)
          |> maybe_filter_by_progress(params.progress_selector, params.progress_percentage)
          |> maybe_filter_by_proficiency(params.selected_proficiency_ids)
          |> sort_by(params.sort_by, params.sort_order)

        {length(modules), "Modules",
         modules |> Enum.drop(params.offset) |> Enum.take(params.limit)}

      :units ->
        units =
          containers
          |> Enum.filter(fn container -> container.numbering_level == 1 end)
          |> maybe_filter_by_text(params.text_search)
          |> maybe_filter_by_card(params.selected_card_value)
          |> maybe_filter_by_progress(params.progress_selector, params.progress_percentage)
          |> maybe_filter_by_proficiency(params.selected_proficiency_ids)
          |> sort_by(params.sort_by, params.sort_order)

        {length(units), "Units", units |> Enum.drop(params.offset) |> Enum.take(params.limit)}

      :pages ->
        pages =
          containers
          |> maybe_filter_by_text(params.text_search)
          |> maybe_filter_by_card(params.selected_card_value)
          |> maybe_filter_by_progress(params.progress_selector, params.progress_percentage)
          |> maybe_filter_by_proficiency(params.selected_proficiency_ids)
          |> sort_by(params.sort_by, params.sort_order)

        {length(pages), "Pages", pages |> Enum.drop(params.offset) |> Enum.take(params.limit)}
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

  defp maybe_filter_by_proficiency(containers, "[]") do
    containers
  end

  defp maybe_filter_by_proficiency(containers, selected_proficiency_ids) do
    selected_proficiency_ids = Jason.decode!(selected_proficiency_ids)

    mapper_ids =
      Enum.reduce(selected_proficiency_ids, [], fn id, acc ->
        case id do
          1 -> ["Low" | acc]
          2 -> ["Medium" | acc]
          3 -> ["High" | acc]
          _ -> acc
        end
      end)

    Enum.filter(containers, fn container ->
      container.student_proficiency in mapper_ids
    end)
  end

  defp maybe_filter_by_progress(containers, progress_selector, percentage) do
    case progress_selector do
      :is_equal_to ->
        Enum.filter(containers, fn container ->
          parse_progress(container.progress || 0.0) == percentage
        end)

      :is_less_than_or_equal ->
        Enum.filter(containers, fn container ->
          parse_progress(container.progress || 0.0) <= percentage
        end)

      :is_greather_than_or_equal ->
        Enum.filter(containers, fn container ->
          parse_progress(container.progress || 0.0) >= percentage
        end)

      nil ->
        containers
    end
  end

  defp parse_progress(progress) do
    {progress, _} =
      Float.round(progress * 100)
      |> Float.to_string()
      |> Integer.parse()

    progress
  end

  defp maybe_filter_by_text(containers, nil), do: containers
  defp maybe_filter_by_text(containers, ""), do: containers

  defp maybe_filter_by_text(containers, text_search) do
    containers
    |> Enum.filter(fn container ->
      String.contains?(String.downcase(container.title), String.downcase(text_search))
    end)
  end

  defp maybe_filter_by_card(containers, :high_progress_low_proficiency),
    do:
      Enum.filter(containers, fn container ->
        Metrics.progress_range(container.progress) == "High" and
          container.student_proficiency == "Low"
      end)

  defp maybe_filter_by_card(containers, :zero_student_progress),
    do: Enum.filter(containers, fn container -> container.progress == 0 end)

  defp maybe_filter_by_card(containers, _), do: containers

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

  defp set_button_background(:pages, _filter), do: "bg-gray-100 dark:bg-gray-800"

  defp set_button_background(container_filter_by, filter),
    do:
      if(container_filter_by == filter,
        do: "bg-Fill-Buttons-fill-primary",
        else: "bg-Background-bg-primary"
      )

  defp set_button_text(:pages, _filter), do: "text-gray-700 dark:text-white cursor-not-allowed"

  defp set_button_text(container_filter_by, filter),
    do:
      if(container_filter_by == filter,
        do: "text-Text-text-white font-semibold",
        else: "text-Text-text-low font-normal"
      )

  defp containers_count(containers, container_filter) do
    container_filter_id =
      case container_filter do
        :units -> 1
        :modules -> 2
        _ -> nil
      end

    %{
      zero_student_progress:
        Enum.count(containers, fn container ->
          (is_nil(container_filter_id) or
             Map.get(container, :numbering_level) == container_filter_id) and
            container.progress == 0
        end),
      high_progress_low_proficiency:
        Enum.count(containers, fn container ->
          (is_nil(container_filter_id) or
             Map.get(container, :numbering_level) == container_filter_id) and
            Metrics.progress_range(container.progress) == "High" and
            container.student_proficiency == "Low"
        end)
    }
  end

  defp params_without_nil_values(params) do
    Enum.reject(params, fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  defp create_containers_list(containers, rows) do
    rows_ids = rows |> Enum.map(& &1.id) |> MapSet.new()

    containers
    |> Enum.map(fn container ->
      container
      |> Map.put(:was_filtered, MapSet.member?(rows_ids, container.id))
      |> Map.drop([:progress, :student_proficiency, :numbering_index, :numbering_level])
    end)
  end

  defp update_proficiency_options(selected_proficiency_ids, proficiency_options) do
    Enum.map(proficiency_options, fn option ->
      if option.id in selected_proficiency_ids,
        do: %{option | selected: true},
        else: option
    end)
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
end
