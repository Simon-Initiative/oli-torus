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
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    sort_order: :asc,
    sort_by: :title,
    text_search: nil,
    selected_attempts_ids: Jason.encode!([])
  }

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

        students = Sections.enrolled_students(section.slug, [:context_learner])

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
           students: students,
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

    # Decode and apply filters
    decoded_params = decode_params(params)
    selected_attempts_ids = decode_attempts_ids(decoded_params.selected_attempts_ids)
    {total_count, filtered_activities} = apply_filters(activities, decoded_params)

    # Create table model
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
       attempts_options: update_attempts_options(selected_attempts_ids),
       selected_attempts_options: selected_attempts_options(selected_attempts_ids),
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
         selected_attempts_options: selected_attempts_options(selected_ids),
         attempts_options: update_attempts_options(selected_ids)
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
                disabled={@selected_attempts_ids == %{}}
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

  # Helper functions

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
        params
        |> Params.get_atom_param(
          "sort_by",
          [:title, :total_attempts, :avg_score, :question_stem, :attempts, :percent_correct],
          :title
        )
        |> normalize_sort_by(),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      selected_attempts_ids:
        Params.get_param(params, "selected_attempts_ids", @default_params.selected_attempts_ids),
      avg_score_percentage: Params.get_int_param(params, "avg_score_percentage", nil),
      avg_score_selector:
        Params.get_atom_param(
          params,
          "avg_score_selector",
          [:is_equal_to, :is_less_than_or_equal, :is_greather_than_or_equal],
          nil
        ),
      back_params: extract_back_url_params(params)
    }
  end

  defp apply_filters(activities, params) do
    filtered_activities =
      activities
      |> maybe_filter_by_text(params.text_search)
      |> maybe_filter_by_attempts(decode_attempts_ids(params.selected_attempts_ids))
      |> maybe_filter_by_score(params.avg_score_selector, params.avg_score_percentage)
      |> sort_by(params.sort_by, params.sort_order)

    total_count = length(filtered_activities)

    paginated_activities =
      filtered_activities
      |> Enum.drop(params.offset)
      |> Enum.take(params.limit)

    {total_count, paginated_activities}
  end

  defp maybe_filter_by_text(activities, nil), do: activities
  defp maybe_filter_by_text(activities, ""), do: activities

  defp maybe_filter_by_text(activities, text_search) do
    Enum.filter(activities, fn activity ->
      search = String.downcase(text_search)
      stem = String.downcase(activity.question_stem || "")
      title = String.downcase(activity.title || "")

      String.contains?(stem, search) or String.contains?(title, search)
    end)
  end

  defp decode_attempts_ids(encoded) when is_binary(encoded) do
    case Jason.decode(encoded) do
      {:ok, ids} when is_list(ids) -> ids
      _ -> []
    end
  end

  defp decode_attempts_ids(_), do: []

  defp maybe_filter_by_attempts(activities, []), do: activities

  defp maybe_filter_by_attempts(activities, selected_ids) do
    Enum.filter(activities, fn activity ->
      # Mirrors the `Pages` predicates, where "Less than 5" also includes zero attempts.
      Enum.any?(selected_ids, fn
        1 -> activity.total_attempts in [nil, 0]
        2 -> not is_nil(activity.total_attempts) and activity.total_attempts <= 5
        3 -> not is_nil(activity.total_attempts) and activity.total_attempts > 5
        _ -> false
      end)
    end)
  end

  defp maybe_filter_by_score(activities, nil, _), do: activities
  defp maybe_filter_by_score(activities, _, nil), do: activities

  defp maybe_filter_by_score(activities, selector, percentage) do
    Enum.filter(activities, fn activity ->
      score = round((activity.avg_score || 0.0) * 100)

      case selector do
        :is_equal_to -> score == percentage
        :is_less_than_or_equal -> score <= percentage
        :is_greather_than_or_equal -> score >= percentage
      end
    end)
  end

  # Legacy sort names from older URLs are mapped by `normalize_sort_by/1` in `decode_params`.
  defp sort_by(activities, :title, sort_order) do
    Enum.sort_by(activities, &String.downcase(&1.question_stem || &1.title || ""), sort_order)
  end

  defp sort_by(activities, :total_attempts, sort_order) do
    Enum.sort_by(activities, &(&1.total_attempts || 0), sort_order)
  end

  defp sort_by(activities, :avg_score, sort_order) do
    Enum.sort_by(activities, &(&1.avg_score || 0), sort_order)
  end

  defp sort_by(activities, _sort_by, _sort_order), do: activities

  defp normalize_sort_by(:question_stem), do: :title
  defp normalize_sort_by(:attempts), do: :total_attempts
  defp normalize_sort_by(:percent_correct), do: :avg_score
  defp normalize_sort_by(sort_by), do: sort_by

  defp update_attempts_options(selected_ids) do
    Enum.map(ActivityHelpers.attempts_filter_options(), &%{&1 | selected: &1.id in selected_ids})
  end

  defp selected_attempts_options(selected_ids) do
    ActivityHelpers.attempts_filter_options()
    |> Enum.filter(&(&1.id in selected_ids))
    |> Map.new(&{&1.id, &1.name})
  end

  defp route_for(socket, new_params) do
    params = update_params(socket.assigns.params, new_params)

    ~p"/sections/#{socket.assigns.section_slug}/instructor_dashboard/insights/learning_objectives/related_activities/#{socket.assigns.objective.resource_id}?#{params}"
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
    {_, rows} = apply_filters(socket.assigns.activities, socket.assigns.params)
    {:ok, table_model} = ActivitiesTableModel.new(rows, columns: :linked_activities)
    assign(socket, table_model: put_detail_state(table_model, socket))
  end

  defp maybe_load_activity_summary(socket, activity_id) do
    if ActivityInsightsState.loaded?(socket.assigns.loaded_activity_summaries, activity_id) do
      socket
    else
      activity = Enum.find(socket.assigns.activities, &(&1.resource_id == activity_id))

      case activity && activity.canonical_page_context do
        %{page_resource_id: page_id} ->
          page_revision = DeliveryResolver.from_resource_id(socket.assigns.section.slug, page_id)

          summary =
            if page_revision do
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

          summary =
            summary ||
              %{
                resource_id: activity_id,
                id: activity_id,
                revision: activity.revision,
                first_attempt_pct: 0.0,
                all_attempt_pct: 0.0,
                preview_rendered: nil
              }

          cache_summary(socket, activity_id, summary)

        _ when not is_nil(activity) ->
          cache_summary(socket, activity_id, empty_summary(activity))

        _ ->
          socket
      end
    end
  rescue
    exception ->
      Logger.warning("Linked activity summary load failed",
        section_id: socket.assigns.section.id,
        activity_id: activity_id,
        error: exception.__struct__
      )

      case Enum.find(socket.assigns.activities, &(&1.resource_id == activity_id)) do
        nil ->
          socket

        activity ->
          # Flagged so the detail pane omits the bars instead of showing a 0% that reads as real.
          summary = Map.put(empty_summary(activity), :metrics_unavailable, true)
          cache_summary(socket, activity_id, summary)
      end
  end

  defp cache_summary(socket, activity_id, summary) do
    socket
    |> assign(
      loaded_activity_summaries:
        Map.put(socket.assigns.loaded_activity_summaries, activity_id, summary),
      activity_summary_cache: Map.put(socket.assigns.activity_summary_cache, activity_id, summary)
    )
  end

  defp empty_summary(activity) do
    %{
      resource_id: activity.resource_id,
      id: activity.resource_id,
      revision: activity.revision,
      first_attempt_pct: 0.0,
      all_attempt_pct: 0.0,
      preview_rendered: nil
    }
  end

  defp extract_back_url_params(params) do
    # Extract and decode the back_params parameter
    case Map.get(params, "back_params") do
      nil ->
        %{}

      params when is_map(params) ->
        params

      encoded_params ->
        try do
          encoded_params
          |> URI.decode()
          |> Jason.decode!()
        rescue
          _ -> %{}
        end
    end
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
