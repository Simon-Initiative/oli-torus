defmodule OliWeb.Delivery.InstructorDashboard.LearningObjectives.RelatedActivitiesLive do
  use OliWeb, :live_view

  alias Oli.Delivery.Sections
  alias OliWeb.Common.{Params, StripedPagedTable, SearchInput}
  alias OliWeb.Components.Delivery.LearningObjectives.RelatedActivitiesTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.JS

  on_mount {OliWeb.UserAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx
  on_mount OliWeb.LiveSessionPlugs.SetSection
  on_mount OliWeb.LiveSessionPlugs.SetBrand
  on_mount OliWeb.LiveSessionPlugs.SetPreviewMode
  on_mount OliWeb.Delivery.InstructorDashboard.InitialAssigns

  @default_params %{
    offset: 0,
    limit: 20,
    sort_order: :asc,
    sort_by: :question_stem,
    text_search: nil
  }

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, view: :insights)}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"resource_id" => resource_id} = params, _uri, socket) do
    case Integer.parse(resource_id) do
      {resource_id_int, ""} ->
        # Fetch the objective/subobjective details
        case Sections.get_resource_by_id(resource_id_int) do
          nil ->
            {:noreply,
             socket
             |> put_flash(:error, "Learning objective not found")
             |> redirect(to: back_to_objectives_path(socket))}

          objective ->
            # Fetch related activities for this objective
            activities =
              Sections.get_activities_for_objective(socket.assigns.section, resource_id_int)

            # Decode and apply filters
            decoded_params = decode_params(params)
            {total_count, filtered_activities} = apply_filters(activities, decoded_params)

            # Create table model
            {:ok, table_model} = RelatedActivitiesTableModel.new(filtered_activities)

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
             assign(socket,
               resource_id: resource_id_int,
               objective: objective,
               activities: activities,
               table_model: table_model,
               total_count: total_count,
               params: decoded_params
             )}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid learning objective ID")
         |> redirect(to: back_to_objectives_path(socket))}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("search_activity", %{"activity_name" => activity_name}, socket) do
    {:noreply,
     push_patch(socket,
       to: route_for(socket, %{text_search: activity_name, offset: 0})
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("paged_table_sort", %{"sort_by" => sort_by}, socket) do
    {:noreply,
     push_patch(socket,
       to: route_for(socket, %{sort_by: String.to_existing_atom(sort_by)})
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
  def handle_event("paged_table_selection_change", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="container mx-auto">
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
              <h4 class="text-Text-text-high text-lg font-bold leading-normal">
                {@objective.title}
              </h4>
            </div>
          </div>
          
    <!-- Search Bar -->

          <div class="flex w-fit gap-2 mx-4 mt-4 mb-4 shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)] border border-Border-border-default bg-Background-bg-secondary">
            <div class="flex p-2 gap-2">
              <.form for={%{}} phx-change="search_activity" class="w-56">
                <SearchInput.render
                  id="activity_search_input"
                  name="activity_name"
                  text={@params.text_search}
                />
              </.form>
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
              />
            </div>
          <% else %>
            <div class="text-center py-8">
              <p class="text-gray-500 dark:text-gray-400">
                No activities found for this learning objective.
              </p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
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
        Params.get_atom_param(
          params,
          "sort_by",
          [:question_stem, :attempts, :percent_correct],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      back_params: extract_back_url_params(params)
    }
  end

  defp apply_filters(activities, params) do
    filtered_activities =
      activities
      |> maybe_filter_by_text(params.text_search)
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
      String.contains?(
        String.downcase(activity.question_stem || ""),
        String.downcase(text_search)
      )
    end)
  end

  defp sort_by(activities, :question_stem, sort_order) do
    Enum.sort_by(activities, &(&1.question_stem || ""), sort_order)
  end

  defp sort_by(activities, :attempts, sort_order) do
    Enum.sort_by(activities, &(&1.attempts || 0), sort_order)
  end

  defp sort_by(activities, :percent_correct, sort_order) do
    Enum.sort_by(activities, &(&1.percent_correct || 0), sort_order)
  end

  defp sort_by(activities, _sort_by, _sort_order), do: activities

  defp route_for(socket, new_params) do
    IO.inspect(socket.assigns.params, label: "los params del socket.assigns")
    params = update_params(socket.assigns.params, new_params)

    Routes.live_path(
      socket,
      __MODULE__,
      socket.assigns.section_slug,
      socket.assigns.resource_id,
      params
    )
  end

  defp update_params(%{sort_by: current_sort_by, sort_order: current_sort_order} = params, %{
         sort_by: new_sort_by
       })
       when current_sort_by == new_sort_by do
    toggled_sort_order = if current_sort_order == :asc, do: :desc, else: :asc
    update_params(params, %{sort_order: toggled_sort_order})
  end

  defp update_params(params, new_param) do
    IO.inspect(params)
    IO.inspect(new_param)

    Map.merge(params, new_param)
    |> IO.inspect(label: "updated params")
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

    base_path =
      Routes.live_path(
        OliWeb.Endpoint,
        OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
        section_slug,
        :insights,
        :learning_objectives
      )

    if map_size(back_params) > 0 do
      query_string = URI.encode_query(back_params)
      "#{base_path}?#{query_string}"
    else
      base_path
    end
  end
end
