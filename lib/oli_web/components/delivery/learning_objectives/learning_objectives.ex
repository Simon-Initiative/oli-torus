defmodule OliWeb.Components.Delivery.LearningObjectives do
  use OliWeb, :live_component

  alias OliWeb.Common.{Params, StripedPagedTable, SearchInput}
  alias OliWeb.Components.Delivery.CardHighlights
  alias OliWeb.Delivery.Content.MultiSelect
  alias OliWeb.Delivery.LearningObjectives.ObjectivesTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    container_id: nil,
    sort_order: :asc,
    sort_by: :objective,
    text_search: nil,
    filter_by: "root",
    selected_proficiency_ids: [],
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

    {total_count, rows, filtered_objectives} =
      apply_filters(objectives_tab.objectives, params, assigns[:patch_url_type])

    indexed_rows =
      Enum.with_index(rows)
      |> Enum.map(fn {row, index} ->
        Map.put(row, :unique_id, "row_#{row.resource_id}_#{index}")
      end)

    {:ok, objectives_table_model} =
      ObjectivesTableModel.new(indexed_rows, assigns[:patch_url_type])

    expanded_objectives = socket.assigns[:expanded_objectives] || MapSet.new()

    expanded_objectives =
      maybe_expand_for_matching_subobjectives(
        expanded_objectives,
        filtered_objectives,
        params,
        assigns[:patch_url_type]
      )

    objectives_table_model =
      Map.merge(objectives_table_model, %{
        rows: indexed_rows,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(objectives_table_model.column_specs, fn col_spec ->
            col_spec.name == params.sort_by
          end),
        data:
          Map.merge(objectives_table_model.data, %{
            section_slug: section_slug,
            section_id: assigns[:section_id],
            section_title: assigns[:section_title],
            current_user: assigns[:current_user],
            current_params: encode_params_for_url(params),
            component_target: socket.assigns.myself,
            expanded_rows: expanded_objectives
          })
      })

    selected_card_value = Map.get(assigns.params, "selected_card_value", nil)

    scoped_objectives = scoped_objectives(objectives_tab.objectives, params)
    objectives_count = objectives_count(scoped_objectives)

    card_props = [
      %{
        title: "Low Proficiency Outcomes",
        count: Map.get(objectives_count, :low_proficiency_outcomes),
        is_selected: selected_card_value == "low_proficiency_outcomes",
        value: :low_proficiency_outcomes,
        subtitle: "learning objective"
      },
      %{
        title: "Low Proficiency Sub-objectives",
        count: Map.get(objectives_count, :low_proficiency_skills),
        is_selected: selected_card_value == "low_proficiency_skills",
        value: :low_proficiency_skills,
        subtitle: "sub-objective"
      }
    ]

    selected_proficiency_ids = params.selected_proficiency_ids

    proficiency_options =
      update_proficiency_options(selected_proficiency_ids, @proficiency_options)

    selected_proficiency_options =
      Enum.reduce(proficiency_options, %{}, fn option, acc ->
        if option.selected,
          do: Map.put(acc, option.id, option.name),
          else: acc
      end)

    {:ok,
     socket
     |> assign(
       table_model: objectives_table_model,
       total_count: total_count,
       params: params,
       student_id: assigns[:student_id],
       patch_url_type: assigns.patch_url_type,
       section_slug: section_slug,
       navigator_items: build_navigator_items(objectives_tab.navigator_items),
       filter_disabled?: filter_by_module_disabled?(v25_migration),
       view: assigns[:view],
       proficiency_options: proficiency_options,
       selected_proficiency_options: selected_proficiency_options,
       selected_proficiency_ids: selected_proficiency_ids,
       card_props: card_props,
       expanded_objectives: expanded_objectives
     )}
  end

  attr(:params, :any)
  attr(:table_model, :any)
  attr(:total_count, :integer)
  attr(:navigator_items, :map)
  attr(:student_id, :integer)
  attr(:patch_url_type, :atom, required: true)
  attr(:filter_disabled?, :boolean)
  attr(:view, :atom)
  attr(:section_slug, :string)
  attr(:card_props, :list)

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 mb-10">
      <div :if={!@filter_disabled?} class="flex justify-center mb-4">
        <.live_component
          id="objectives_containers_navigator"
          module={OliWeb.Components.Delivery.ListNavigator}
          items={@navigator_items}
          current_item_resource_id={@params.filter_by}
          path_builder_fn={
            if assigns[:patch_url_type] == :instructor_dashboard do
              fn item ->
                ~p"/sections/#{@section_slug}/instructor_dashboard/insights/learning_objectives?#{%{filter_by: item.resource_id}}"
              end
            else
              fn item ->
                ~p"/sections/#{@section_slug}/student_dashboard/#{@student_id}/learning_objectives?#{%{filter_by: item.resource_id}}"
              end
            end
          }
        />
      </div>
      <div class="bg-white shadow-sm dark:bg-gray-800">
        <div class="flex justify-between items-center px-4 pt-8 pb-4 instructor_dashboard_table">
          <h4 class="justify-center text-Text-text-high text-lg font-bold leading-normal">
            Learning Objectives
          </h4>

          <a
            href={Routes.delivery_path(OliWeb.Endpoint, :download_learning_objectives, @section_slug)}
            download={"#{@section_slug}_learning_objectives.csv"}
            class="flex items-center justify-center gap-x-2 text-Text-text-button font-bold"
          >
            Download CSV <Icons.download />
          </a>
        </div>
        <div class="flex flex-row mx-4 gap-x-4">
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

        <div class="flex w-fit gap-2 mx-4 mt-4 mb-4 shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)] border border-Border-border-default bg-Background-bg-secondary">
          <div class="flex p-2 gap-2">
            <.form for={%{}} phx-target={@myself} phx-change="search_objective" class="w-56">
              <SearchInput.render
                id="objective_search_input"
                name="objective_name"
                text={@params.text_search}
              />
            </.form>

            <MultiSelect.render
              id="proficiency_select"
              options={@proficiency_options}
              selected_values={@selected_proficiency_options}
              selected_ids={@selected_proficiency_ids}
              target={@myself}
              disabled={@selected_proficiency_ids == %{}}
              placeholder="Proficiency"
            />

            <button
              class="ml-2 mr-4 text-center text-Text-text-high text-sm font-normal leading-none flex items-center gap-x-1 hover:text-Text-text-button"
              phx-click="clear_all_filters"
              phx-target={@myself}
            >
              <Icons.trash /> Clear All Filters
            </button>
          </div>
        </div>

        <%= if @total_count > 0 do %>
          <div id="objectives-table">
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
              selection_change={JS.push("paged_table_selection_change", target: @myself)}
              show_limit_change={true}
              show_bottom_paging={false}
              allow_selection={true}
              additional_row_class="!h-20"
              details_render_fn={&ObjectivesTableModel.render_objective_details/2}
              sticky_header_offset={if @patch_url_type == :instructor_dashboard, do: 56, else: 0}
            />
          </div>
        <% else %>
          <h6 class="text-center py-4 bg-white dark:bg-gray-800">There are no objectives to show</h6>
        <% end %>
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
    section_slug = socket.assigns.section_slug

    path =
      case Map.get(socket.assigns, :student_id) do
        nil ->
          ~p"/sections/#{section_slug}/instructor_dashboard/insights/learning_objectives"

        student_id ->
          ~p"/sections/#{section_slug}/student_dashboard/#{student_id}/learning_objectives"
      end

    {:noreply, socket |> assign(expanded_objectives: MapSet.new()) |> push_patch(to: path)}
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

  def handle_event("paged_table_selection_change", %{"id" => _selected_objective_id}, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_objective_details", %{"objective_id" => objective_id}, socket) do
    # Get current expanded state
    expanded_objectives = socket.assigns.expanded_objectives

    # Toggle the state
    expanded_objectives =
      if MapSet.member?(expanded_objectives, objective_id) do
        MapSet.delete(expanded_objectives, objective_id)
      else
        MapSet.put(expanded_objectives, objective_id)
      end

    # Update the table model with the new expanded_rows
    updated_table_model =
      Map.update!(socket.assigns.table_model, :data, fn data ->
        Map.put(data, :expanded_rows, expanded_objectives)
      end)

    {:noreply,
     socket
     |> assign(expanded_objectives: expanded_objectives)
     |> assign(table_model: updated_table_model)}
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
            :objective_instructor_dashboard,
            :subobjective,
            :student_proficiency_obj,
            :student_proficiency_subobj,
            :related_activities_count
          ],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      filter_by: Params.get_int_param(params, "filter_by", @default_params.filter_by),
      selected_proficiency_ids:
        Params.get_list_param(
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

  defp encode_params_for_url(params) do
    case Map.fetch(params, :selected_proficiency_ids) do
      {:ok, ids} when is_list(ids) ->
        Map.put(params, :selected_proficiency_ids, Jason.encode!(ids))

      _ ->
        params
    end
  end

  defp apply_filters(objectives, params, patch_url_type) do
    scoped_objectives = scoped_objectives(objectives, params)
    filtered_objectives = filtered_objectives(scoped_objectives, params)

    table_objectives =
      case patch_url_type do
        :instructor_dashboard ->
          parent_objectives_from(filtered_objectives, scoped_objectives)
          |> sort_by(params.sort_by, params.sort_order)

        _ ->
          filtered_objectives
          |> sort_by(params.sort_by, params.sort_order)
      end

    total_count = length(table_objectives)

    rows =
      table_objectives
      |> Enum.drop(params.offset)
      |> Enum.take(params.limit)

    {total_count, rows, filtered_objectives}
  end

  @doc false
  def filtered_objectives(objectives, params) do
    objectives
    |> maybe_filter_by_text(params.text_search)
    |> maybe_filter_by_proficiency(params.selected_proficiency_ids)
    |> maybe_filter_by_card(params.selected_card_value)
  end

  defp maybe_expand_for_matching_subobjectives(
         expanded_rows,
         filtered_objectives,
         params,
         :instructor_dashboard
       ) do
    filtered_objectives
    |> filtered_subobjectives(params)
    |> Enum.reduce(expanded_rows, fn obj, acc ->
      MapSet.put(acc, "row_#{parent_id(obj)}")
    end)
  end

  defp maybe_expand_for_matching_subobjectives(
         expanded_rows,
         _objectives,
         _params,
         _patch_url_type
       ),
       do: expanded_rows

  defp filtered_subobjectives(filtered_objectives, params) do
    if subobjective_filters_active?(params) do
      filtered_objectives
      |> Enum.filter(&subobjective?/1)
      |> maybe_filter_by_subobjective_text(params.text_search)
      |> maybe_filter_by_subobjective_proficiency(params.selected_proficiency_ids)
      |> maybe_filter_by_subobjective_card(params.selected_card_value)
    else
      []
    end
  end

  defp subobjective_filters_active?(params) do
    (not is_nil(params.text_search) and params.text_search != "") or
      params.selected_proficiency_ids != [] or
      params.selected_card_value == :low_proficiency_skills
  end

  defp maybe_filter_by_subobjective_text(objectives, nil), do: objectives
  defp maybe_filter_by_subobjective_text(objectives, ""), do: objectives

  defp maybe_filter_by_subobjective_text(objectives, text_search) do
    text = String.downcase(text_search)

    Enum.filter(objectives, fn obj ->
      String.contains?(String.downcase(to_string(obj.subobjective || "")), text)
    end)
  end

  defp maybe_filter_by_subobjective_proficiency(objectives, []), do: objectives

  defp maybe_filter_by_subobjective_proficiency(objectives, selected_proficiency_ids) do
    do_filter_by_subobjective_proficiency(objectives, selected_proficiency_ids)
  end

  defp do_filter_by_subobjective_proficiency(objectives, selected_proficiency_ids) do
    mapper_ids =
      Enum.reduce(selected_proficiency_ids, [], fn id, acc ->
        case id do
          1 -> ["Low" | acc]
          2 -> ["Medium" | acc]
          3 -> ["High" | acc]
          _ -> acc
        end
      end)

    if mapper_ids == [] do
      objectives
    else
      Enum.filter(objectives, fn objective ->
        objective.student_proficiency_subobj in mapper_ids
      end)
    end
  end

  defp maybe_filter_by_subobjective_card(objectives, :low_proficiency_skills),
    do: Enum.filter(objectives, &(&1.student_proficiency_subobj == "Low"))

  defp maybe_filter_by_subobjective_card(objectives, _), do: objectives

  # Unit/Module scope filter defines base set (unordered) of objectives/subobjectives for the view
  defp scoped_objectives(objectives, params) do
    objectives
    |> maybe_filter_by_option(params.filter_by)
  end

  defp parent_objectives_from(filtered_objectives, scoped_objectives) do
    parent_ids =
      filtered_objectives
      |> Enum.map(&parent_id/1)
      |> MapSet.new()

    Enum.filter(scoped_objectives, fn obj ->
      top_level_objective?(obj) and MapSet.member?(parent_ids, obj.resource_id)
    end)
  end

  @proficiency_rank ["High", "Medium", "Low", "Not enough data"]
                    |> Enum.with_index()
                    |> Enum.into(%{})

  @proficiency_rank_desc [nil, "High", "Medium", "Low", "Not enough data"]
                         |> Enum.with_index()
                         |> Enum.into(%{})

  defp sort_by(objectives, :student_proficiency_obj, sort_order) do
    Enum.sort_by(
      objectives,
      fn objective ->
        proficiency_rank =
          case Map.get(objective, :subobjective) do
            nil -> @proficiency_rank[objective.student_proficiency_obj]
            _ -> @proficiency_rank[objective.student_proficiency_subobj]
          end

        {proficiency_rank, normalized_title(objective)}
      end,
      sort_order
    )
  end

  defp sort_by(objectives, :objective, sort_order) do
    Enum.sort_by(objectives, &{&1.title}, sort_order)
  end

  defp sort_by(objectives, :objective_instructor_dashboard, sort_order) do
    Enum.sort_by(objectives, &{&1.title}, sort_order)
  end

  defp sort_by(objectives, :student_proficiency_subobj, sort_order) do
    case sort_order do
      :desc ->
        Enum.sort_by(
          objectives,
          fn objective ->
            {@proficiency_rank_desc[objective.student_proficiency_subobj],
             normalized_title(objective)}
          end,
          sort_order
        )

      :asc ->
        Enum.sort_by(
          objectives,
          fn objective ->
            {@proficiency_rank[objective.student_proficiency_subobj], normalized_title(objective)}
          end,
          sort_order
        )
    end
  end

  defp sort_by(objectives, :related_activities_count, sort_order) do
    Enum.sort_by(
      objectives,
      fn objective ->
        {Map.get(objective, :related_activities_count, 0), normalized_title(objective)}
      end,
      sort_order
    )
  end

  defp sort_by(objectives, sort_by, sort_order) do
    Enum.sort_by(objectives, fn obj -> obj[sort_by] end, sort_order)
  end

  defp normalized_title(objective) do
    objective
    |> Map.get(:title, "")
    |> String.downcase()
  end

  defp maybe_filter_by_option(objectives, "root"), do: objectives

  defp maybe_filter_by_option(objectives, container_id) do
    Enum.filter(objectives, &(container_id in &1.container_ids))
  end

  defp maybe_filter_by_text(objectives, nil), do: objectives
  defp maybe_filter_by_text(objectives, ""), do: objectives

  defp maybe_filter_by_text(objectives, text_search) do
    text = String.downcase(text_search)

    objectives
    |> Enum.filter(fn objective ->
      String.contains?(String.downcase(objective.objective), text) or
        String.contains?(String.downcase(to_string(objective.subobjective || "")), text)
    end)
  end

  defp maybe_filter_by_proficiency(objectives, []), do: objectives

  defp maybe_filter_by_proficiency(objectives, selected_proficiency_ids) do
    do_filter_by_proficiency(objectives, selected_proficiency_ids)
  end

  defp do_filter_by_proficiency(objectives, selected_proficiency_ids) do
    mapper_ids =
      Enum.reduce(selected_proficiency_ids, [], fn id, acc ->
        case id do
          1 -> ["Low" | acc]
          2 -> ["Medium" | acc]
          3 -> ["High" | acc]
          _ -> acc
        end
      end)

    if mapper_ids == [] do
      objectives
    else
      Enum.filter(objectives, fn objective ->
        proficiency =
          if top_level_objective?(objective),
            do: objective.student_proficiency_obj,
            else: objective.student_proficiency_subobj

        proficiency in mapper_ids
      end)
    end
  end

  defp maybe_filter_by_card(objectives, :low_proficiency_outcomes),
    do: Enum.filter(objectives, &(&1.student_proficiency_obj == "Low"))

  defp maybe_filter_by_card(objectives, :low_proficiency_skills),
    do: Enum.filter(objectives, &(&1.student_proficiency_subobj == "Low"))

  defp maybe_filter_by_card(objectives, _), do: objectives

  defp route_for(socket, new_params, :instructor_dashboard) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      socket.assigns.section_slug,
      socket.assigns.view,
      :learning_objectives,
      update_params(socket.assigns.params, new_params) |> encode_params_for_url()
    )
  end

  defp route_for(socket, new_params, :student_dashboard) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
      socket.assigns.section_slug,
      socket.assigns.student_id,
      :learning_objectives,
      update_params(socket.assigns.params, new_params) |> encode_params_for_url()
    )
  end

  @doc false
  def objectives_count(objectives) do
    in_scope_parent_ids = in_scope_parent_ids(objectives)

    %{
      low_proficiency_outcomes:
        Enum.count(objectives, fn obj ->
          obj.student_proficiency_obj == "Low" and top_level_objective?(obj)
        end),
      low_proficiency_skills:
        Enum.count(objectives, fn obj ->
          obj.student_proficiency_subobj == "Low" and
            subobjective_with_in_scope_parent?(obj, in_scope_parent_ids)
        end)
    }
  end

  defp subobjective?(objective), do: not is_nil(objective.subobjective)
  defp top_level_objective?(objective), do: is_nil(objective.subobjective)

  defp in_scope_parent_ids(objectives) do
    objectives
    |> Enum.filter(&top_level_objective?/1)
    |> Enum.map(& &1.resource_id)
    |> MapSet.new()
  end

  defp subobjective_with_in_scope_parent?(objective, in_scope_parent_ids) do
    case Map.get(objective, :objective_resource_id) do
      nil -> false
      parent_id -> subobjective?(objective) and MapSet.member?(in_scope_parent_ids, parent_id)
    end
  end

  defp parent_id(objective),
    do:
      if(top_level_objective?(objective),
        do: objective.resource_id,
        else: objective.objective_resource_id
      )

  # Returns true if the filter by module feature is disabled for the section.
  # This happens when the contained objectives for the section were not yet created.
  defp filter_by_module_disabled?(v25_migration)
  defp filter_by_module_disabled?(:done), do: false
  defp filter_by_module_disabled?(_), do: true

  defp build_navigator_items(navigator_items) do
    [
      %{
        resource_id: "root",
        title: "All",
        resource_type_id: Oli.Resources.ResourceType.get_id_by_type("container"),
        numbering_level: 0,
        numbering_index: -1
      }
    ] ++ navigator_items
  end
end
