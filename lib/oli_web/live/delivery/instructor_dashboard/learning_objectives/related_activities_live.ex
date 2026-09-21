defmodule OliWeb.Delivery.InstructorDashboard.LearningObjectives.RelatedActivitiesLive do
  use OliWeb, :live_view

  require Logger

  alias Oli.Delivery.Sections.LinkedActivities
  alias Oli.Delivery.Sections
  alias Oli.Activities
  alias Oli.Publishing.DeliveryResolver
  alias OliWeb.Common.{Params, StripedPagedTable, SearchInput}
  alias OliWeb.Delivery.Content.{MultiSelect, PercentageSelector}
  alias OliWeb.Delivery.Pages.ActivitiesTableModel
  alias OliWeb.Delivery.ActivityHelpers
  alias OliWeb.Delivery.ActivityInsightsState
  alias OliWeb.Delivery.InstructorDashboard.LearningObjectives.RelatedActivities.Filters
  alias OliWeb.Delivery.InstructorDashboard.LearningObjectives.RelatedActivities.Summaries
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    %{section: section} = socket.assigns
    resource_id = String.to_integer(params["resource_id"])

    case DeliveryResolver.from_resource_id(section.slug, resource_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Learning objective not found")
         |> redirect(to: back_to_objectives_path(socket))}

      objective ->
        activity_types = Activities.list_activity_registrations()
        activity_types_map = Map.new(activity_types, &{&1.id, &1})

        scripts =
          activity_types
          |> Enum.map(& &1.authoring_script)
          |> Enum.concat(Oli.PartComponents.get_part_component_scripts(:delivery_script))
          |> Enum.map(&Routes.static_path(OliWeb.Endpoint, "/js/" <> &1))

        activities = LinkedActivities.get_activities_for_objective(section, resource_id)

        {:ok,
         assign(socket,
           objective: objective,
           activities: activities,
           activity_types_map: activity_types_map,
           students: nil,
           scripts: scripts,
           activity_summary_cache: %{},
           loaded_activity_summaries: %{},
           expanded_activity_ids: MapSet.new(),
           attempts_options: ActivityHelpers.attempts_filter_options(),
           selected_attempts_options: %{},
           selected_attempts_ids: [],
           view: :insights
         )}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    %{activities: activities} = socket.assigns
    socket = assign(socket, expanded_activity_ids: MapSet.new(), loaded_activity_summaries: %{})

    decoded_params = Filters.decode_params(params)
    selected_attempts_ids = Filters.decode_attempts_ids(decoded_params.selected_attempts_ids)
    {total_count, filtered_activities} = Filters.apply(activities, decoded_params)

    {:ok, table_model} =
      ActivitiesTableModel.new(filtered_activities, columns: :linked_activities)

    table_model =
      Map.merge(table_model, %{
        rows: filtered_activities,
        sort_order: decoded_params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec ->
            col_spec.name == decoded_params.sort_by
          end)
      })

    {:noreply,
     socket
     |> assign(
       table_model: put_detail_state(table_model, socket),
       total_count: total_count,
       params: decoded_params,
       attempts_options: Filters.attempts_options(selected_attempts_ids),
       selected_attempts_options: Filters.selected_attempts_options(selected_attempts_ids),
       selected_attempts_ids: selected_attempts_ids
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("search_activity", %{"activity_name" => activity_name}, socket) do
    {:noreply,
     push_patch(socket,
       to: route_for(socket, %{text_search: activity_name, offset: 0})
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("paged_table_sort", params, socket) do
    sort_by =
      Params.get_atom_param(
        params,
        "sort_by",
        [:title, :total_attempts, :avg_score, :question_stem, :attempts, :percent_correct],
        :title
      )

    {:noreply,
     push_patch(socket,
       to: route_for(socket, %{sort_by: sort_by})
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to: route_for(socket, %{limit: limit, offset: offset})
     )}
  end

  @impl Phoenix.LiveView
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
       to: route_for(socket, %{limit: new_limit, offset: new_offset})
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("paged_table_selection_change", %{"id" => id}, socket) do
    with {activity_id, ""} <- Integer.parse("#{id}"),
         true <- Enum.any?(socket.assigns.activities, &(&1.resource_id == activity_id)) do
      expanded_ids = socket.assigns.expanded_activity_ids

      if MapSet.member?(expanded_ids, activity_id) do
        {:noreply,
         socket
         |> assign(expanded_activity_ids: MapSet.delete(expanded_ids, activity_id))
         |> refresh_table_model()}
      else
        {:noreply,
         socket
         |> maybe_load_activity_summary(activity_id)
         |> assign(expanded_activity_ids: MapSet.put(expanded_ids, activity_id))
         |> refresh_table_model()}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("paged_table_selection_change", _params, socket), do: {:noreply, socket}

  def handle_event("apply_attempts_filter", _params, socket) do
    selected_ids = socket.assigns.selected_attempts_ids

    {:noreply,
     push_patch(socket,
       to: route_for(socket, %{selected_attempts_ids: Jason.encode!(selected_ids), offset: 0})
     )}
  end

  def handle_event("apply_avg_score_filter", params, socket) do
    selector =
      get_in(params, ["progress", "option"]) || Map.get(params, "avg_score_selector", "")

    percentage = Map.get(params, "avg_score_percentage", "")

    {:noreply,
     push_patch(socket,
       to:
         route_for(socket, %{
           avg_score_selector: if(selector == "", do: nil, else: selector),
           avg_score_percentage: if(percentage == "", do: nil, else: percentage),
           offset: 0
         })
     )}
  end

  def handle_event("toggle_selected", %{"_target" => [selected_id]}, socket) do
    with {selected_id, ""} <- Integer.parse(selected_id) do
      selected_ids =
        if selected_id in socket.assigns.selected_attempts_ids do
          List.delete(socket.assigns.selected_attempts_ids, selected_id)
        else
          [selected_id | socket.assigns.selected_attempts_ids]
        end

      {:noreply,
       assign(socket,
         selected_attempts_ids: selected_ids,
         selected_attempts_options: Filters.selected_attempts_options(selected_ids),
         attempts_options: Filters.attempts_options(selected_ids)
       )}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("clear_all_filters", _params, socket) do
    %{section_slug: section_slug, objective: objective, params: params} = socket.assigns

    query =
      case Map.get(params, :back_params, %{}) do
        back_params when back_params == %{} -> []
        back_params -> [back_params: Jason.encode!(back_params)]
      end

    {:noreply,
     push_patch(socket,
       to:
         ~p"/sections/#{section_slug}/instructor_dashboard/insights/learning_objectives/related_activities/#{objective.resource_id}?#{query}"
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <main class="container mx-auto">
      <div class="flex flex-col gap-2 mb-10">
        <!-- Back to Learning Objectives Button -->
        <div class="my-4 ml-2">
          <.link
            navigate={back_to_objectives_path(assigns)}
            class="inline-flex items-center text-sm font-medium text-gray-700 hover:text-blue-600 dark:text-gray-400 dark:hover:text-white"
          >
            <OliWeb.Icons.left_chevron />
            <span class="ml-2">Back to Learning Objectives</span>
          </.link>
        </div>
        
    <!-- Main Content -->
        <div class="bg-white shadow-sm dark:bg-gray-800">
          <div class="flex justify-between items-center px-4 pt-8 pb-4 instructor_dashboard_table">
            <div>
              <h1 class="text-Text-text-high text-lg font-bold leading-normal">
                {@objective.title}
              </h1>
            </div>
          </div>
          
    <!-- Search Bar -->

          <div class="flex w-fit gap-2 mx-4 my-4 shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)] border border-Border-border-default bg-Background-bg-secondary">
            <div class="flex p-2 gap-2">
              <.form for={%{}} phx-debounce="300" phx-change="search_activity" class="w-56">
                <label for="activity_search_input-input" class="sr-only">Search activities</label>
                <SearchInput.render
                  id="activity_search_input"
                  name="activity_name"
                  text={@params.text_search}
                />
              </.form>

              <MultiSelect.render
                id="attempts_select"
                label="Attempts"
                options={@attempts_options}
                selected_values={@selected_attempts_options}
                selected_ids={@selected_attempts_ids}
                target={nil}
                placeholder="Attempts"
                submit_event="apply_attempts_filter"
              />

              <PercentageSelector.render
                id="score"
                label="Score"
                target={nil}
                percentage={@params.avg_score_percentage}
                selector={@params.avg_score_selector}
                submit_event="apply_avg_score_filter"
                input_name="avg_score_percentage"
              />

              <button
                class="ml-2 mr-6 text-center text-Text-text-high text-sm font-normal leading-none flex items-center gap-x-2 hover:text-Text-text-button"
                phx-click="clear_all_filters"
              >
                <Icons.trash /> Clear All Filters
              </button>
            </div>
          </div>
          
    <!-- Activities Table -->
          <%= if @total_count > 0 do %>
            <div id="activities-table">
              <StripedPagedTable.render
                table_model={@table_model}
                total_count={@total_count}
                offset={@params.offset}
                limit={@params.limit}
                render_top_info={false}
                additional_table_class="instructor_dashboard_table"
                sort={JS.push("paged_table_sort")}
                page_change={JS.push("paged_table_page_change")}
                limit_change={JS.push("paged_table_limit_change")}
                selection_change={JS.push("paged_table_selection_change")}
                show_limit_change={true}
                show_bottom_paging={false}
                allow_selection={false}
                additional_row_class="!h-20"
                sticky_header_offset={56}
                details_render_fn={&ActivitiesTableModel.render_assessment_details/2}
              />
            </div>
          <% else %>
            <div class="text-center py-8">
              <p class="text-gray-500 dark:text-gray-400">
                <%= if @activities == [] do %>
                  No activities are linked to this learning objective.
                <% else %>
                  <%= if @params.text_search && @params.text_search != "" do %>
                    No activities found for <strong><%= @params.text_search %></strong>.
                  <% else %>
                    No activities match the selected filters.
                  <% end %>
                <% end %>
              </p>
            </div>
          <% end %>
        </div>
      </div>
    </main>
    """
  end

  defp route_for(socket, new_params) do
    params = Filters.update_params(socket.assigns.params, new_params)

    ~p"/sections/#{socket.assigns.section_slug}/instructor_dashboard/insights/learning_objectives/related_activities/#{socket.assigns.objective.resource_id}?#{params}"
  end

  defp put_detail_state(table_model, socket) do
    Map.update!(table_model, :data, fn data ->
      Map.merge(data, %{
        activity_summary_cache: socket.assigns.activity_summary_cache,
        loaded_activity_summaries: socket.assigns.loaded_activity_summaries,
        expanded_activity_ids: socket.assigns.expanded_activity_ids,
        expanded_rows: ActivityInsightsState.expanded_rows(socket.assigns.expanded_activity_ids),
        activity_types_map: socket.assigns.activity_types_map,
        scripts: socket.assigns.scripts,
        target: nil
      })
    end)
  end

  defp refresh_table_model(socket) do
    {_, rows} = Filters.apply(socket.assigns.activities, socket.assigns.params)
    {:ok, table_model} = ActivitiesTableModel.new(rows, columns: :linked_activities)
    assign(socket, table_model: put_detail_state(table_model, socket))
  end

  defp maybe_load_activity_summary(socket, activity_id) do
    if ActivityInsightsState.loaded?(socket.assigns.loaded_activity_summaries, activity_id) do
      socket
    else
      socket
      |> load_activity_summary(
        Enum.find(socket.assigns.activities, &(&1.resource_id == activity_id))
      )
    end
  end

  defp load_activity_summary(socket, nil), do: socket

  defp load_activity_summary(
         socket,
         %{canonical_page_context: %{page_resource_id: page_id}} = activity
       ) do
    page_revision = DeliveryResolver.from_resource_id(socket.assigns.section.slug, page_id)
    socket = ensure_students_loaded(socket)

    summary = summarize_activity(socket, page_revision, activity.resource_id)

    cache_summary(socket, activity.resource_id, Summaries.from_result(summary, activity))
  end

  defp load_activity_summary(socket, activity) do
    cache_summary(socket, activity.resource_id, Summaries.without_analytics(activity))
  end

  defp summarize_activity(_socket, nil, _activity_id), do: nil

  defp summarize_activity(socket, page_revision, activity_id) do
    ActivityHelpers.summarize_activity_performance(
      socket.assigns.section,
      page_revision,
      socket.assigns.activity_types_map,
      socket.assigns.students,
      [activity_id],
      include_adaptive_part_analytics: true
    )
    |> List.first()
  end

  # Learners are only needed to summarize an expanded row, so they are loaded on the first
  # expansion and kept for the rest of the session.
  defp ensure_students_loaded(%{assigns: %{students: nil}} = socket) do
    assign(socket,
      students: Sections.enrolled_students(socket.assigns.section.slug, [:context_learner])
    )
  end

  defp ensure_students_loaded(socket), do: socket

  defp cache_summary(socket, activity_id, summary) do
    socket
    |> assign(
      loaded_activity_summaries:
        Map.put(socket.assigns.loaded_activity_summaries, activity_id, summary),
      activity_summary_cache: Map.put(socket.assigns.activity_summary_cache, activity_id, summary)
    )
  end

  defp back_to_objectives_path(socket_or_assigns) do
    section_slug =
      case socket_or_assigns do
        %{assigns: %{section_slug: slug}} -> slug
        %{section_slug: slug} -> slug
        _ -> nil
      end

    back_params =
      case socket_or_assigns do
        %{assigns: %{params: %{back_params: back_params}}} -> back_params
        %{params: %{back_params: back_params}} -> back_params
        _ -> %{}
      end

    base_path = ~p"/sections/#{section_slug}/instructor_dashboard/insights/learning_objectives"

    if map_size(back_params) > 0 do
      query_string = URI.encode_query(back_params)
      "#{base_path}?#{query_string}"
    else
      base_path
    end
  end
end
