defmodule OliWeb.Components.Delivery.Pages do
  use OliWeb, :live_component

  import Ecto.Query

  alias Oli.Analytics.AdaptiveResponseSummaryRepairWorker
  alias Oli.Analytics.Summary
  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Analytics.Summary.ResponseSummary
  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Resources.ResourceType
  alias OliWeb.Common.StripedPagedTable
  alias OliWeb.Common.PagingParams
  alias OliWeb.Common.Params
  alias OliWeb.Common.SearchInput
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Components.Delivery.CardHighlights
  alias OliWeb.Delivery.Content.{MultiSelect, PercentageSelector}
  alias OliWeb.Delivery.ActivityHelpers
  alias OliWeb.Components.Delivery.Pages.PagesTableModel
  alias OliWeb.Delivery.Pages.ActivitiesTableModel

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Icons

  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    sort_order: :asc,
    sort_by: :order,
    text_search: nil,
    selected_card_value: nil,
    selected_activity_card_value: nil,
    progress_percentage: nil,
    progress_selector: nil,
    avg_score_percentage: nil,
    avg_score_selector: nil,
    selected_attempts_ids: Jason.encode!([]),
    selected_activities: Jason.encode!([]),
    card_props: [],
    card_activity_props: []
  }

  @attempts_options [
    %{id: 1, name: "None", selected: false},
    %{id: 2, name: "Less than 5", selected: false},
    %{id: 3, name: "More than 5", selected: false}
  ]

  def mount(socket) do
    {:ok,
     assign(socket,
       scripts_loaded: false,
       table_model: nil,
       current_page: nil,
       activity_summary_cache: %{},
       loaded_activity_summaries: %{},
       expanded_activity_ids: MapSet.new(),
       repair_poll_scheduled: false
     )}
  end

  def update(assigns, socket) do
    if Map.get(assigns, :poll_adaptive_repairs) do
      {:ok,
       socket
       |> refresh_adaptive_repairs()
       |> maybe_schedule_repair_poll()}
    else
      params = decode_params(assigns.params)

      socket =
        assign(socket,
          params: params,
          section: assigns.section,
          view: assigns.view,
          active_tab: assigns.active_tab,
          ctx: assigns.ctx,
          pages: assigns.pages,
          students: assigns.students,
          scripts: assigns.scripts,
          activity_types_map: assigns.activity_types_map,
          card_props: [],
          card_activity_props: [],
          attempts_options: @attempts_options
        )
        |> assign_new(:navigation_data, fn ->
          %{
            scored_pages: %{
              items: Oli.Delivery.Sections.SectionResourceDepot.graded_pages(assigns.section.id)
            },
            practice_pages: %{
              items: Oli.Delivery.Sections.SectionResourceDepot.practice_pages(assigns.section.id)
            }
          }
        end)

      case params.resource_id do
        nil ->
          {total_count, rows} = apply_filters(assigns.pages, params)

          {:ok, table_model} =
            PagesTableModel.new(rows, assigns.ctx, assigns.active_tab, socket.assigns.myself)

          table_model =
            Map.merge(table_model, %{rows: rows, sort_order: params.sort_order})
            |> SortableTableModel.update_sort_params(params.sort_by)

          selected_card_value = Map.get(assigns.params, "selected_card_value", nil)
          pages_count = pages_count(assigns.pages)

          card_props = [
            %{
              title: "Low Scores",
              count: Map.get(pages_count, :low_scores),
              is_selected: selected_card_value == "low_scores",
              value: :low_scores
            },
            %{
              title: "Low Progress",
              count: Map.get(pages_count, :low_progress),
              is_selected: selected_card_value == "low_progress",
              value: :low_progress
            },
            %{
              title: "Low or No Attempts",
              count: Map.get(pages_count, :low_or_no_attempts),
              is_selected: selected_card_value == "low_or_no_attempts",
              value: :low_or_no_attempts
            }
          ]

          selected_attempts_ids = Jason.decode!(params.selected_attempts_ids)
          attempts_options = update_attempts_options(selected_attempts_ids, @attempts_options)

          selected_attempts_options =
            Enum.reduce(attempts_options, %{}, fn option, acc ->
              if option.selected,
                do: Map.put(acc, option.id, option.name),
                else: acc
            end)

          {:ok,
           assign(socket,
             table_model: table_model,
             total_count: total_count,
             current_page: nil,
             activity_summary_cache: %{},
             loaded_activity_summaries: %{},
             expanded_activity_ids: MapSet.new(),
             card_props: card_props,
             attempts_options: attempts_options,
             selected_attempts_options: selected_attempts_options,
             selected_attempts_ids: selected_attempts_ids,
             repair_poll_scheduled: false
           )}

        resource_id ->
          case Enum.find(assigns.pages, fn a -> a.id == resource_id end) do
            nil ->
              send(self(), {:redirect_with_warning, "The page doesn't exist"})
              {:ok, socket}

            current_page ->
              student_ids = Enum.map(assigns.students, & &1.id)

              activities =
                get_activities(current_page, assigns.section, assigns[:list_lti_activities])

              students_with_attempts =
                DeliveryResolver.students_with_attempts_for_page(
                  current_page,
                  assigns.section,
                  student_ids
                )

              student_emails_without_attempts =
                Enum.reduce(assigns.students, [], fn s, acc ->
                  if s.id in students_with_attempts, do: acc, else: [s.email | acc]
                end)

              percentage_score =
                Metrics.avg_score_across_for_pages(
                  assigns.section,
                  [current_page.resource_id],
                  student_ids
                )
                |> Map.get(current_page.resource_id, 0)
                |> Kernel.*(100)
                |> round()

              selected_activity_card_value =
                Map.get(assigns.params, "selected_activity_card_value", nil)

              activities_count = activities_count(activities)

              card_activity_props = [
                %{
                  title: "Low Accuracy",
                  count: Map.get(activities_count, :low_accuracy),
                  is_selected: selected_activity_card_value == "low_accuracy",
                  value: :low_accuracy
                },
                %{
                  title: "Low or No Attempts",
                  count: Map.get(activities_count, :low_or_no_attempts),
                  is_selected: selected_activity_card_value == "low_or_no_attempts",
                  value: :low_or_no_attempts
                }
              ]

              selected_attempts_ids = Jason.decode!(params.selected_attempts_ids)
              attempts_options = update_attempts_options(selected_attempts_ids, @attempts_options)

              selected_attempts_options =
                Enum.reduce(attempts_options, %{}, fn option, acc ->
                  if option.selected,
                    do: Map.put(acc, option.id, option.name),
                    else: acc
                end)

              # Add order field to activities (1-based indexing for display)
              activities_with_order =
                Enum.with_index(activities)
                |> Enum.map(fn {activity, index} ->
                  Map.put(activity, :order, index + 1)
                end)

              {total_count, rows} = apply_filters(activities_with_order, params)

              {:ok, table_model} = ActivitiesTableModel.new(rows)

              page_revision =
                DeliveryResolver.from_resource_id(
                  assigns.section.slug,
                  current_page.resource_id
                )

              socket =
                socket
                |> maybe_reset_activity_detail_state(current_page.resource_id)
                |> assign(
                  current_page: current_page,
                  page_revision: page_revision,
                  activities: rows,
                  total_count: total_count,
                  students_with_attempts_count: Enum.count(students_with_attempts),
                  student_emails_without_attempts: student_emails_without_attempts,
                  total_attempts_count:
                    count_attempts(current_page, assigns.section, student_ids),
                  rendered_activity_id: UUID.uuid4(),
                  card_activity_props: card_activity_props,
                  attempts_options: attempts_options,
                  selected_attempts_options: selected_attempts_options,
                  selected_attempts_ids: selected_attempts_ids,
                  avg_score_percentage: percentage_score
                  # this dynamic id is used to force the liveview to reload the activity details.
                  # Without it the activity details will not be rendered correctly when the applied card filters change
                )
                |> assign(
                  activity_summary_cache:
                    build_activity_summary_cache(
                      assigns.section,
                      page_revision,
                      assigns.activity_types_map,
                      assigns.students,
                      rows
                    )
                )

              table_model =
                table_model
                |> Map.merge(%{
                  rows: rows,
                  sort_order: params.sort_order
                })
                |> SortableTableModel.update_sort_params(params.sort_by)

              {:ok,
               socket
               |> assign(table_model: table_model)
               |> maybe_preload_initial_activity_details(rows)
               |> assign_activity_details_state()
               |> maybe_schedule_repair_poll()}
          end
      end
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="flex flex-col items-center mb-6">
        <button
          :if={!is_nil(@current_page)}
          class="whitespace-nowrap self-start"
          phx-click="back"
          phx-target={@myself}
        >
          <div class="w-36 h-9 justify-start items-start gap-3.5 inline-flex">
            <div class="px-1.5 py-2 border-zinc-700 justify-start items-center gap-1 flex">
              <Icons.chevron_down class="fill-blue-400 rotate-90" />
              <div class="justify-center text-[#373a44] dark:text-white text-sm font-semibold tracking-tight">
                Back to {page_type(@active_tab)} Pages
              </div>
            </div>
          </div>
        </button>

        <.live_component
          :if={!is_nil(@current_page)}
          id="pages_navigator"
          module={OliWeb.Components.Delivery.ListNavigator}
          items={
            if @active_tab == :practice_pages,
              do: @navigation_data.practice_pages.items,
              else: @navigation_data.scored_pages.items
          }
          current_item_resource_id={@current_page.resource_id}
          path_builder_fn={fn item -> list_navigator_path(@section, @active_tab, @params, item) end}
        />
      </div>

      <.loader :if={!@table_model} />

      <div :if={@table_model} class="bg-white shadow-sm dark:bg-gray-800 dark:text-white">
        <div class="flex flex-col space-y-4 lg:space-y-0 lg:flex-row lg:justify-between px-4 pt-8 pb-4 lg:items-center instructor_dashboard_table dark:bg-[#262626]">
          <%= if @current_page != nil do %>
            <div class="flex flex-col gap-y-1">
              <%= if @current_page.container_label do %>
                <span class="text-Text-text-high text-base font-bold leading-none">
                  {@current_page.container_label}
                </span>

                <div class="flex flex-row items-center gap-x-1">
                  <%= if !@current_page.batch_scoring do %>
                    <Icons.score_as_you_go />
                  <% end %>

                  <span class="text-Text-text-high text-lg font-bold leading-normal">
                    {@current_page.title}
                  </span>
                </div>
              <% else %>
                <span class="text-Text-text-high text-lg font-bold leading-normal">
                  {@current_page.title}
                </span>
              <% end %>
            </div>
          <% else %>
            <span class="self-stretch justify-center text-zinc-700 text-lg font-bold leading-normal dark:text-white">
              {page_type(@active_tab)} Pages
            </span>
            <%= if path = pages_download_path(@section, @active_tab) do %>
              <a
                role="button"
                href={path}
                class="flex items-center justify-center gap-x-2 text-Text-text-button font-bold leading-none"
                download={filename_from_active_tab(@section, @active_tab)}
              >
                Download CSV <Icons.download />
              </a>
            <% end %>
          <% end %>
        </div>
        <%= if is_nil(@current_page) do %>
          <div class="flex flex-row mx-4 gap-x-4">
            <%= for card <- @card_props do %>
              <CardHighlights.render
                title={card.title}
                count={card.count}
                is_selected={card.is_selected}
                value={card.value}
                on_click={JS.push("select_card", target: @myself)}
                container_filter_by={:pages}
              />
            <% end %>
          </div>
        <% else %>
          <div class="flex flex-row mx-4 gap-x-4">
            <div class="inline-flex flex-col justify-start items-start gap-3 p-6 h-32 rounded-2xl
         cursor-pointer transition-colors">
              <div class="text-gray-700 text-base font-semibold leading-normal dark:text-[#EEEBF5]">
                Average Score
              </div>

              <div class="flex justify-start items-end gap-2 w-full">
                <div class="text-[32px] font-bold leading-[44px] text-[#353740] dark:text-[#EEEBF5]">
                  {@avg_score_percentage}%
                </div>
              </div>
            </div>
            <%= for card <- @card_activity_props do %>
              <CardHighlights.render
                title={card.title}
                count={card.count}
                is_selected={card.is_selected}
                value={card.value}
                on_click={JS.push("select_activity_card", target: @myself)}
                container_filter_by={:questions}
              />
            <% end %>
          </div>
        <% end %>
        <div class="flex flex-row justify-between items-center">
          <div class="flex w-fit gap-2 mx-4 my-4 shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)] border border-Border-border-default bg-Background-bg-secondary">
            <div class="flex p-2 gap-2">
              <.form
                for={%{}}
                phx-target={@myself}
                phx-change={if @current_page == nil, do: "search_page", else: "search_page"}
                class="w-56"
              >
                <SearchInput.render
                  id="scored_activities_search_input"
                  name={if @current_page == nil, do: "page_name", else: "page_name"}
                  text={@params.text_search}
                />
              </.form>

              <%= if is_nil(@current_page) do %>
                <PercentageSelector.render
                  target={@myself}
                  percentage={@params.progress_percentage}
                  selector={@params.progress_selector}
                />
              <% end %>

              <MultiSelect.render
                id="attempts_select"
                label="Attempts"
                options={@attempts_options}
                selected_values={@selected_attempts_options}
                selected_ids={@selected_attempts_ids}
                target={@myself}
                disabled={@selected_attempts_ids == %{}}
                placeholder="Attempts"
                submit_event="apply_attempts_filter"
              />

              <PercentageSelector.render
                id="score"
                label="Score"
                target={@myself}
                percentage={@params.avg_score_percentage}
                selector={@params.avg_score_selector}
                submit_event="apply_avg_score_filter"
                input_name="avg_score_percentage"
              />

              <button
                class="ml-2 mr-6 text-center text-Text-text-high text-sm font-normal leading-none flex items-center gap-x-2 hover:text-Text-text-button"
                phx-click="clear_all_filters"
                phx-target={@myself}
              >
                <Icons.trash /> Clear All Filters
              </button>
            </div>
          </div>
          <div
            :if={@current_page != nil}
            id="student_attempts_summary"
            class="flex flex-row mx-4"
          >
            <span class="text-xs" role="student attempts summary">
              {attempts_count(@students_with_attempts_count, @total_attempts_count, @active_tab)}
            </span>
            <div :if={@students_with_attempts_count < Enum.count(@students)} class="flex flex-col">
              <span class="text-xs ml-2">
                {~s{#{Enum.count(@student_emails_without_attempts)} #{Gettext.ngettext(OliWeb.Gettext,
                "student has",
                "students have",
                Enum.count(@student_emails_without_attempts))} not completed any attempt.}}
              </span>
              <input
                type="text"
                id="email_inputs"
                class="form-control hidden"
                value={Enum.join(@student_emails_without_attempts, "; ")}
                readonly
              />
              <button
                id="copy_emails_button"
                class="text-xs text-primary underline ml-auto"
                phx-hook="CopyListener"
                data-clipboard-target="#email_inputs"
              >
                <i class="fa-solid fa-copy mr-2" />{Gettext.ngettext(
                  OliWeb.Gettext,
                  "Copy email address",
                  "Copy email addresses",
                  Enum.count(@student_emails_without_attempts)
                )}
              </button>
            </div>
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
          selection_change={JS.push("paged_table_selection_change", target: @myself)}
          allow_selection={!is_nil(@current_page)}
          show_bottom_paging={false}
          show_limit_change={true}
          no_records_message="There are no activities to show"
          details_render_fn={&ActivitiesTableModel.render_assessment_details/2}
          sticky_header_offset={56}
        />
      </div>
    </div>
    """
  end

  def handle_event("clear_all_filters", _params, socket) do
    section_slug = socket.assigns.section.slug
    active_tab = socket.assigns.active_tab

    case socket.assigns.params.resource_id do
      nil ->
        # No page selected, clear all filters and go to main page
        path = ~p"/sections/#{section_slug}/instructor_dashboard/insights/#{active_tab}"
        {:noreply, push_patch(socket, to: path)}

      _resource_id ->
        # Assessment is selected, clear only search filters but keep page selected

        path =
          ~p"/sections/#{section_slug}/instructor_dashboard/insights/#{active_tab}/#{socket.assigns.params.resource_id}"

        {:noreply, push_patch(socket, to: path)}
    end
  end

  def handle_event("select_card", %{"selected" => value}, socket) do
    value =
      if String.to_existing_atom(value) == Map.get(socket.assigns.params, :selected_card_value),
        do: nil,
        else: String.to_existing_atom(value)

    send(self(), {:selected_card_pages, value, socket.assigns.active_tab})

    {:noreply, socket}
  end

  def handle_event("select_activity_card", %{"selected" => value}, socket) do
    value =
      if String.to_existing_atom(value) ==
           Map.get(socket.assigns.params, :selected_activity_card_value),
         do: nil,
         else: String.to_existing_atom(value)

    send(self(), {:selected_activity_card, value, socket.assigns.active_tab})
    {:noreply, socket}
  end

  def handle_event("back", _params, socket) do
    %{params: params} = socket.assigns

    {:noreply,
     socket
     |> assign(
       params: Map.put(params, :resource_id, nil),
       current_page: nil
     )
     |> push_patch(to: back_to_pages_path(socket))}
  end

  def handle_event(
        "search_page",
        %{"page_name" => page_name},
        socket
      ) do
    {:noreply,
     socket
     |> push_patch(
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{
             text_search: page_name,
             offset: 0
           })
         )
     )}
  end

  def handle_event("paged_table_selection_change", %{"id" => activity_resource_id}, socket)
      when not is_nil(socket.assigns.current_page) do
    activity_id = String.to_integer("#{activity_resource_id}")
    expanded_activity_ids = socket.assigns.expanded_activity_ids

    if MapSet.member?(expanded_activity_ids, activity_id) do
      {:noreply,
       socket
       |> assign(expanded_activity_ids: MapSet.delete(expanded_activity_ids, activity_id))
       |> assign_activity_details_state()}
    else
      socket =
        socket
        |> maybe_load_activity_summary(activity_id)
        |> assign(expanded_activity_ids: MapSet.put(expanded_activity_ids, activity_id))
        |> assign_activity_details_state()

      {:noreply, socket}
    end
  end

  def handle_event("paged_table_selection_change", %{"id" => selected_resource_id}, socket) do
    # Extract current filter params to preserve them for the back button
    back_params =
      socket.assigns.params
      |> Map.take([
        :text_search,
        :selected_card_value,
        :progress_percentage,
        :progress_selector,
        :avg_score_percentage,
        :avg_score_selector,
        :selected_attempts_ids,
        :offset,
        :limit,
        :sort_by,
        :sort_order
      ])
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" or v == "[]" end)
      |> Enum.into(%{})

    socket =
      assign(socket,
        params:
          Map.put(
            socket.assigns.params,
            :resource_id,
            selected_resource_id
          )
      )

    {:noreply,
     push_patch(socket,
       to: route_to(socket, %{back_params: Jason.encode!(back_params)})
     )}
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{limit: limit, offset: offset})
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
    new_params =
      %{
        progress_percentage: progress_percentage,
        progress_selector: progress_selector
      }

    {:noreply,
     push_patch(socket,
       to: route_to(socket, update_params(socket.assigns.params, new_params))
     )}
  end

  def handle_event(
        "apply_avg_score_filter",
        %{
          "avg_score_percentage" => avg_score_percentage,
          "progress" => %{"option" => avg_score_selector}
        },
        socket
      ) do
    new_params =
      %{
        avg_score_percentage: avg_score_percentage,
        avg_score_selector: avg_score_selector
      }

    {:noreply,
     push_patch(socket,
       to: route_to(socket, update_params(socket.assigns.params, new_params))
     )}
  end

  def handle_event("apply_attempts_filter", _params, socket) do
    %{
      selected_attempts_ids: selected_ids,
      params: params
    } = socket.assigns

    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(params, %{selected_attempts_ids: Jason.encode!(selected_ids)})
         )
     )}
  end

  def handle_event("toggle_selected", %{"_target" => [id]}, socket) do
    selected_id = String.to_integer(id)
    do_update_selection(socket, selected_id)
  end

  def handle_event("paged_table_limit_change", params, socket) do
    new_limit = Params.get_int_param(params, "limit", 20)
    total_count = socket.assigns.total_count
    current_offset = socket.assigns.params.offset
    new_offset = PagingParams.calculate_new_offset(current_offset, new_limit, total_count)
    updated_params = update_params(socket.assigns.params, %{limit: new_limit, offset: new_offset})

    {:noreply, push_patch(socket, to: route_to(socket, updated_params))}
  end

  def handle_event("survey_scripts_loaded", %{"error" => _}, socket) do
    {:noreply, assign(socket, error: true)}
  end

  def handle_event("survey_scripts_loaded", _params, socket) do
    {:noreply, assign(socket, scripts_loaded: true)}
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by} = _params, socket) do
    updated_params =
      update_params(socket.assigns.params, %{
        sort_by: String.to_existing_atom(sort_by)
      })

    {:noreply, push_patch(socket, to: route_to(socket, updated_params))}
  end

  defp assign_activity_details_state(%{assigns: %{table_model: nil}} = socket), do: socket

  defp assign_activity_details_state(socket) do
    %{
      table_model: table_model,
      loaded_activity_summaries: loaded_activity_summaries,
      activity_summary_cache: activity_summary_cache,
      expanded_activity_ids: expanded_activity_ids,
      scripts: scripts,
      activity_types_map: activity_types_map
    } = socket.assigns

    selected_activities =
      loaded_activity_summaries
      |> Map.values()
      |> Enum.sort_by(& &1.order)

    expanded_rows =
      expanded_activity_ids
      |> Enum.map(&"row_#{&1}")
      |> MapSet.new()

    table_model =
      table_model
      |> Map.update!(:data, fn data ->
        Map.merge(data, %{
          selected_activities: selected_activities,
          activity_summary_cache: activity_summary_cache,
          expanded_activity_ids: expanded_activity_ids,
          expanded_rows: expanded_rows,
          scripts: scripts,
          activity_types_map: activity_types_map,
          target: socket.assigns.myself
        })
      end)

    assign(socket,
      table_model: table_model,
      selected_activities: selected_activities
    )
  end

  defp maybe_load_activity_summary(
         %{assigns: %{loaded_activity_summaries: loaded_activity_summaries}} = socket,
         activity_id
       )
       when is_map_key(loaded_activity_summaries, activity_id),
       do: socket

  defp maybe_load_activity_summary(socket, activity_id) do
    load_activity_summary(socket, activity_id, maybe_enqueue_repair: true)
  end

  defp maybe_preload_initial_activity_details(
         %{assigns: %{active_tab: :practice_pages, expanded_activity_ids: expanded_activity_ids}} =
           socket,
         [first_activity | _]
       ) do
    if MapSet.size(expanded_activity_ids) == 0 do
      socket
      |> maybe_load_activity_summary(first_activity.resource_id)
      |> assign(
        expanded_activity_ids: MapSet.put(expanded_activity_ids, first_activity.resource_id)
      )
    else
      socket
    end
  end

  defp maybe_preload_initial_activity_details(socket, _rows), do: socket

  defp load_activity_summary(socket, activity_id, opts) do
    %{
      activities: activities,
      section: section,
      page_revision: page_revision,
      students: students,
      activity_types_map: activity_types_map
    } = socket.assigns

    case Enum.find(activities, &(&1.resource_id == activity_id)) do
      nil ->
        socket

      activity ->
        revision = Map.get(activity, :revision, activity)
        activity_type = Map.get(activity_types_map, revision.activity_type_id)

        repair_status =
          if Keyword.get(opts, :maybe_enqueue_repair, false) do
            maybe_enqueue_adaptive_summary_repair(activity_type, revision.resource_id)
          else
            Keyword.get(opts, :repair_status)
          end

        summary =
          socket.assigns.activity_summary_cache
          |> Map.get(activity_id)
          |> case do
            nil ->
              case activity_type do
                %{slug: "oli_adaptive"} ->
                  base_summary = %{
                    id: revision.resource_id,
                    resource_id: revision.resource_id,
                    graded: page_revision.graded,
                    title: revision.title,
                    revision: revision,
                    resource_summaries: [],
                    transformed_model: nil,
                    first_attempt_pct: 0.0,
                    all_attempt_pct: 0.0,
                    total_attempts_count: 0,
                    students_with_attempts: [],
                    students_with_attempts_count: 0,
                    student_emails_without_attempts: Enum.map(students, & &1.email)
                  }

                  base_summary =
                    ActivityHelpers.stage_performance_details(
                      [base_summary],
                      activity_types_map,
                      []
                    )
                    |> List.first()

                  base_summary
                  |> Map.put(
                    :preview_rendered,
                    ActivityHelpers.preview_render(
                      section,
                      page_revision,
                      revision,
                      activity_types_map,
                      Map.get(activity, :order),
                      Map.get(base_summary, :student_responses, %{})
                    )
                  )
                  |> maybe_put_adaptive_summary_repair_status(repair_status)
                  |> Map.put(:order, activity.order)

                _ ->
                  maybe_put_adaptive_summary_repair_status(activity, repair_status)
              end

            summary ->
              summary
              |> maybe_put_adaptive_summary_repair_status(repair_status)
              |> Map.put(:order, activity.order)
          end

        assign(
          socket,
          :loaded_activity_summaries,
          Map.put(socket.assigns.loaded_activity_summaries, activity_id, summary)
        )
        |> assign(
          :activity_summary_cache,
          Map.put(socket.assigns.activity_summary_cache, activity_id, summary)
        )
    end
  end

  defp build_activity_summary_cache(_section, _page_revision, _activity_types_map, _students, []),
    do: %{}

  defp build_activity_summary_cache(section, page_revision, activity_types_map, students, rows) do
    activity_ids = Enum.map(rows, & &1.resource_id)

    ActivityHelpers.summarize_activity_performance(
      section,
      page_revision,
      activity_types_map,
      students,
      activity_ids
    )
    |> Enum.reduce(%{}, fn summary, acc ->
      Map.put(acc, summary.resource_id, summary)
    end)
  end

  defp refresh_adaptive_repairs(socket) do
    refreshing_activity_ids =
      socket.assigns.loaded_activity_summaries
      |> Enum.filter(fn {_activity_id, summary} ->
        Map.get(summary, :adaptive_summary_repair_status) == :refreshing
      end)
      |> Enum.map(fn {activity_id, _summary} -> activity_id end)

    socket =
      Enum.reduce(refreshing_activity_ids, socket, fn activity_id, acc ->
        cond do
          AdaptiveResponseSummaryRepairWorker.in_progress?(activity_id) ->
            acc

          Summary.adaptive_response_summaries_stale?(activity_id) ->
            acc

          true ->
            load_activity_summary(acc, activity_id, repair_status: :refreshed)
        end
      end)

    socket
    |> assign(repair_poll_scheduled: false)
    |> assign_activity_details_state()
  end

  defp maybe_schedule_repair_poll(%{assigns: %{id: nil}} = socket), do: socket

  defp maybe_schedule_repair_poll(socket) do
    has_refreshing_repairs? =
      Enum.any?(socket.assigns.loaded_activity_summaries, fn {_activity_id, summary} ->
        Map.get(summary, :adaptive_summary_repair_status) == :refreshing
      end)

    cond do
      not has_refreshing_repairs? ->
        assign(socket, repair_poll_scheduled: false)

      socket.assigns.repair_poll_scheduled ->
        socket

      true ->
        Phoenix.LiveView.send_update_after(
          __MODULE__,
          [id: socket.assigns.id, poll_adaptive_repairs: true],
          2_000
        )

        assign(socket, repair_poll_scheduled: true)
    end
  end

  defp maybe_enqueue_adaptive_summary_repair(%{slug: "oli_adaptive"}, activity_resource_id) do
    cond do
      AdaptiveResponseSummaryRepairWorker.in_progress?(activity_resource_id) ->
        :refreshing

      Summary.adaptive_response_summaries_stale?(activity_resource_id) ->
        AdaptiveResponseSummaryRepairWorker.schedule(activity_resource_id)
        :refreshing

      true ->
        nil
    end
  end

  defp maybe_enqueue_adaptive_summary_repair(_, _), do: nil

  defp maybe_put_adaptive_summary_repair_status(summary, nil), do: summary

  defp maybe_put_adaptive_summary_repair_status(summary, status) do
    Map.put(summary, :adaptive_summary_repair_status, status)
  end

  defp maybe_reset_activity_detail_state(socket, current_page_resource_id) do
    case socket.assigns[:current_page] do
      %{resource_id: ^current_page_resource_id} ->
        socket

      _ ->
        assign(socket,
          loaded_activity_summaries: %{},
          expanded_activity_ids: MapSet.new(),
          selected_activities: []
        )
    end
  end

  defp apply_filters(pages, params) do
    pages =
      pages
      |> maybe_filter_by_text(params.text_search)
      |> maybe_filter_by_card(params.selected_card_value || params.selected_activity_card_value)
      |> maybe_filter_by_progress(params.progress_selector, params.progress_percentage)
      |> maybe_filter_by_avg_score(params.avg_score_selector, params.avg_score_percentage)
      |> maybe_filter_by_attempts(params.selected_attempts_ids)
      |> sort_by(params.sort_by, params.sort_order)

    {length(pages), pages |> Enum.drop(params.offset) |> Enum.take(params.limit)}
  end

  defp maybe_filter_by_text(pages, nil), do: pages
  defp maybe_filter_by_text(pages, ""), do: pages

  defp maybe_filter_by_text(pages, text_search) do
    Enum.filter(pages, fn page ->
      String.contains?(String.downcase(page.title), String.downcase(text_search))
    end)
  end

  defp maybe_filter_by_card(pages, :low_scores),
    do:
      Enum.filter(pages, fn page ->
        page.avg_score < 0.40
      end)

  defp maybe_filter_by_card(pages, :low_progress),
    do: Enum.filter(pages, fn page -> page.students_completion < 0.40 end)

  defp maybe_filter_by_card(pages, :low_or_no_attempts),
    do:
      Enum.filter(pages, fn page ->
        page.total_attempts <= 5 || page.total_attempts == nil
      end)

  defp maybe_filter_by_card(pages, :low_accuracy),
    do:
      Enum.filter(pages, fn page ->
        page.avg_score < 0.40
      end)

  defp maybe_filter_by_card(pages, _), do: pages

  defp maybe_filter_by_progress(pages, progress_selector, percentage) do
    case progress_selector do
      :is_equal_to ->
        Enum.filter(pages, fn page ->
          parse_progress(page.students_completion || 0.0) == percentage
        end)

      :is_less_than_or_equal ->
        Enum.filter(pages, fn page ->
          parse_progress(page.students_completion || 0.0) <= percentage
        end)

      :is_greather_than_or_equal ->
        Enum.filter(pages, fn page ->
          parse_progress(page.students_completion || 0.0) >= percentage
        end)

      nil ->
        pages
    end
  end

  defp maybe_filter_by_avg_score(pages, avg_score_selector, avg_score_percentage) do
    case avg_score_selector do
      :is_equal_to ->
        Enum.filter(pages, fn page ->
          parse_progress(page.avg_score || 0.0) == avg_score_percentage
        end)

      :is_less_than_or_equal ->
        Enum.filter(pages, fn page ->
          parse_progress(page.avg_score || 0.0) <= avg_score_percentage
        end)

      :is_greather_than_or_equal ->
        Enum.filter(pages, fn page ->
          parse_progress(page.avg_score || 0.0) >= avg_score_percentage
        end)

      nil ->
        pages
    end
  end

  defp maybe_filter_by_attempts(pages, "[]"), do: pages

  defp maybe_filter_by_attempts(pages, selected_attempts_ids) do
    selected_attempts_ids = Jason.decode!(selected_attempts_ids)

    Enum.filter(pages, fn page ->
      Enum.any?(selected_attempts_ids, fn
        1 -> page.total_attempts in [nil, 0]
        2 -> not is_nil(page.total_attempts) and page.total_attempts <= 5
        3 -> not is_nil(page.total_attempts) and page.total_attempts > 5
        _ -> false
      end)
    end)
  end

  defp sort_by(pages, sort_by, sort_order) do
    case sort_by do
      :due_date ->
        Enum.sort_by(
          pages,
          fn
            %{scheduling_type: :due_by, end_date: nil} = _page ->
              DateTime.from_unix(0, :second) |> elem(1)

            %{scheduling_type: :due_by} = page ->
              page.end_date

            _ ->
              DateTime.from_unix(0, :second) |> elem(1)
          end,
          {sort_order, DateTime}
        )

      sb when sb in [:avg_score, :students_completion, :total_attempts] ->
        Enum.sort_by(pages, fn a -> Map.get(a, sb) || -1 end, sort_order)

      :title ->
        Enum.sort_by(pages, &String.downcase(&1.title), sort_order)

      :order ->
        Enum.sort_by(pages, fn a -> Map.get(a, :order) end, sort_order)
    end
  end

  defp decode_params(params) do
    sort_options = [:order, :title, :due_date, :avg_score, :total_attempts, :students_completion]

    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      sort_order:
        Params.get_atom_param(params, "sort_order", [:asc, :desc], @default_params.sort_order),
      sort_by: Params.get_atom_param(params, "sort_by", sort_options, @default_params.sort_by),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      resource_id: Params.get_int_param(params, "resource_id", nil),
      page_table_params: params["page_table_params"],
      selected_activities:
        decode_selected_activities(Params.get_param(params, "selected_activities", [])),
      selected_card_value:
        Params.get_atom_param(
          params,
          "selected_card_value",
          [:low_scores, :low_progress, :low_or_no_attempts],
          @default_params.selected_card_value
        ),
      selected_activity_card_value:
        Params.get_atom_param(
          params,
          "selected_activity_card_value",
          [:low_accuracy, :low_or_no_attempts],
          @default_params.selected_activity_card_value
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
      avg_score_percentage:
        Params.get_int_param(params, "avg_score_percentage", @default_params.avg_score_percentage),
      avg_score_selector:
        Params.get_atom_param(
          params,
          "avg_score_selector",
          [:is_equal_to, :is_less_than_or_equal, :is_greather_than_or_equal],
          @default_params.avg_score_selector
        ),
      selected_attempts_ids:
        Params.get_param(params, "selected_attempts_ids", @default_params.selected_attempts_ids),
      card_props: Params.get_param(params, "card_props", @default_params.card_props),
      card_activity_props:
        Params.get_param(params, "card_activity_props", @default_params.card_activity_props),
      back_params: extract_back_url_params(params)
    }
  end

  defp parse_progress(progress) do
    {progress, _} =
      Float.round(progress * 100)
      |> Float.to_string()
      |> Integer.parse()

    progress
  end

  defp pages_count(pages) do
    %{
      low_scores:
        Enum.count(pages, fn page ->
          page.avg_score < 0.40
        end),
      low_progress:
        Enum.count(pages, fn page ->
          page.students_completion < 0.40
        end),
      low_or_no_attempts:
        Enum.count(pages, fn page ->
          page.total_attempts <= 5 || page.total_attempts == nil
        end)
    }
  end

  defp activities_count(activities) do
    %{
      low_accuracy:
        Enum.count(activities, fn activity ->
          activity.avg_score < 0.40
        end),
      low_or_no_attempts:
        Enum.count(activities, fn activity ->
          activity.total_attempts <= 5 || activity.total_attempts == nil
        end)
    }
  end

  defp pages_download_path(%Section{slug: slug}, :scored_pages),
    do: ~p"/sections/#{slug}/instructor_dashboard/downloads/scored_pages"

  defp pages_download_path(%Section{slug: slug}, :practice_pages),
    do: ~p"/sections/#{slug}/instructor_dashboard/downloads/practice_pages"

  defp pages_download_path(_, _), do: nil

  defp filename_from_active_tab(%Section{slug: slug}, :scored_pages),
    do: "#{slug}_scored_pages.csv"

  defp filename_from_active_tab(%Section{slug: slug}, :practice_pages),
    do: "#{slug}_practice_pages.csv"

  defp update_attempts_options(selected_attempts_ids, attempts_options) do
    Enum.map(attempts_options, fn option ->
      if option.id in selected_attempts_ids, do: %{option | selected: true}, else: option
    end)
  end

  defp do_update_selection(socket, selected_id) do
    %{attempts_options: attempts_options} = socket.assigns

    updated_options =
      Enum.map(attempts_options, fn option ->
        if option.id == selected_id, do: %{option | selected: !option.selected}, else: option
      end)

    {selected_attempts_options, selected_ids} =
      Enum.reduce(updated_options, {%{}, []}, fn option, {values, acc_ids} ->
        if option.selected,
          do: {Map.put(values, option.id, option.name), [option.id | acc_ids]},
          else: {values, acc_ids}
      end)

    {:noreply,
     assign(socket,
       selected_attempts_options: selected_attempts_options,
       attempts_options: updated_options,
       selected_attempts_ids: selected_ids
     )}
  end

  defp update_params(%{sort_by: sort_by} = params, %{sort_by: sort_by}) do
    toggled_sort_order = if params.sort_order == :asc, do: :desc, else: :asc
    update_params(params, %{sort_order: toggled_sort_order})
  end

  defp update_params(params, new_param), do: Map.merge(params, new_param)

  defp route_to(socket, params)
       when not is_nil(socket.assigns.params.resource_id) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      socket.assigns.section.slug,
      socket.assigns.view,
      socket.assigns.active_tab,
      socket.assigns.params.resource_id,
      params
    )
  end

  defp route_to(socket, params) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      socket.assigns.section.slug,
      socket.assigns.view,
      socket.assigns.active_tab,
      params
    )
  end

  defp count_attempts(
         current_page,
         %Section{id: section_id},
         student_ids
       ) do
    page_type_id = ResourceType.get_id_by_type("page")

    from(rs in ResourceSummary,
      where:
        rs.section_id == ^section_id and rs.resource_id == ^current_page.resource_id and
          rs.user_id in ^student_ids and rs.project_id == -1 and
          rs.resource_type_id == ^page_type_id,
      select: sum(rs.num_attempts)
    )
    |> Repo.one()
  end

  defp get_activities(
         current_page,
         section,
         list_lti_activities
       ) do
    # Fetch all unique acitivty ids from the v2 tracked responses for this section
    activity_ids_from_responses =
      get_unique_activities_from_responses(current_page.resource_id, section.id)

    details_by_activity =
      from(rs in ResourceSummary,
        where: rs.section_id == ^section.id,
        where: rs.project_id == -1,
        where: rs.user_id == -1,
        where: rs.resource_id in ^activity_ids_from_responses,
        select: {
          rs.resource_id,
          rs.num_attempts,
          fragment(
            "CAST(? as float) / CAST(? as float)",
            rs.num_correct,
            rs.num_attempts
          )
        }
      )
      |> Repo.all()
      |> Enum.reduce(%{}, fn {resource_id, total_attempts, avg_score}, acc ->
        Map.put(acc, resource_id, {total_attempts, avg_score})
      end)

    activities =
      DeliveryResolver.from_resource_id(section.slug, activity_ids_from_responses)
      |> Enum.reject(fn rev -> is_nil(rev) end)
      |> Enum.map(fn rev ->
        {total_attempts, avg_score} = Map.get(details_by_activity, rev.resource_id, {0, 0.0})

        Map.merge(rev, %{
          total_attempts: total_attempts,
          avg_score: avg_score,
          has_lti_activity: rev.activity_type_id in list_lti_activities
        })
      end)

    add_objective_mapper(activities, section.slug)
  end

  defp get_unique_activities_from_responses(page_id, section_id) do
    from(rs in ResponseSummary,
      where: rs.section_id == ^section_id,
      where: rs.page_id == ^page_id,
      where: rs.project_id == -1,
      distinct: true,
      select: rs.activity_id
    )
    |> Repo.all()
  end

  defp add_objective_mapper(activities, section_slug) do
    objectives_mapper =
      Enum.reduce(activities, [], fn activity, acc ->
        (Map.values(activity.objectives) |> List.flatten()) ++ acc
      end)
      |> Enum.uniq()
      |> DeliveryResolver.objectives_by_resource_ids(section_slug)
      |> Enum.map(fn objective -> {objective.resource_id, objective} end)
      |> Enum.into(%{})

    activities
    |> Enum.map(fn activity ->
      case Map.values(activity.objectives) |> List.flatten() do
        [] ->
          Map.put(activity, :objectives, [])

        objective_ids ->
          Map.put(
            activity,
            :objectives,
            Enum.reduce(objective_ids, MapSet.new(), fn id, activity_objectives ->
              MapSet.put(activity_objectives, Map.get(objectives_mapper, id))
            end)
            |> MapSet.to_list()
          )
      end
    end)
  end

  defp page_type(:practice_pages), do: "Practice"
  defp page_type(:scored_pages), do: "Scored"

  defp attempts_count(0 = _students_with_attempts_count, _total_attempts_count, :scored_pages),
    do: "No student has completed any attempts."

  defp attempts_count(students_with_attempts_count, total_attempts_count, :scored_pages) do
    ~s{#{students_with_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "student has", "students have", students_with_attempts_count)} completed #{total_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "attempt", "attempts", total_attempts_count)}.}
  end

  defp attempts_count(students_with_attempts_count, _total_attempts_count, :practice_pages) do
    ~s{#{students_with_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "student has responded", "students have responded", students_with_attempts_count)}}
  end

  defp decode_selected_activities(nil), do: []
  defp decode_selected_activities([]), do: []
  defp decode_selected_activities(list) when is_list(list), do: normalize_list_items(list)

  defp decode_selected_activities(encoded_list) when is_binary(encoded_list) do
    case Jason.decode!(encoded_list) do
      [] -> []
      decoded_list when is_list(decoded_list) -> normalize_list_items(decoded_list)
    end
  end

  defp decode_selected_activities(_), do: []

  defp normalize_list_items(list) do
    Enum.map(list, fn
      item when is_integer(item) -> item
      item when is_binary(item) -> String.to_integer(item)
    end)
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

  defp back_to_pages_path(socket) do
    section_slug = socket.assigns.section.slug
    active_tab = socket.assigns.active_tab
    back_params = socket.assigns.params.back_params

    base_path = ~p"/sections/#{section_slug}/instructor_dashboard/insights/#{active_tab}"
    build_url_with_params(base_path, back_params)
  end

  defp list_navigator_path(section, active_tab, params, item) do
    section_slug = section.slug

    base_path =
      ~p"/sections/#{section_slug}/instructor_dashboard/insights/#{active_tab}/#{item.id}"

    # Use current params but exclude resource_id since it changes with each item
    current_params =
      params
      |> Map.delete(:resource_id)

    build_url_with_params(base_path, current_params)
  end

  defp build_url_with_params(base_path, params) do
    # Filter out empty values and convert both keys and values to strings
    filtered_params =
      params
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> Enum.map(fn {key, value} ->
        {to_string(key), convert_value_to_string(value)}
      end)
      |> Map.new()

    if map_size(filtered_params) > 0 do
      query_string = URI.encode_query(filtered_params)
      "#{base_path}?#{query_string}"
    else
      base_path
    end
  end

  defp convert_value_to_string(value) when is_binary(value), do: value
  defp convert_value_to_string(value) when is_atom(value), do: to_string(value)
  defp convert_value_to_string(value) when is_integer(value), do: to_string(value)
  defp convert_value_to_string(value) when is_float(value), do: to_string(value)
  defp convert_value_to_string(value) when is_boolean(value), do: to_string(value)
  defp convert_value_to_string(value) when is_list(value), do: Jason.encode!(value)
  defp convert_value_to_string(value) when is_map(value), do: Jason.encode!(value)
  defp convert_value_to_string(value), do: to_string(value)
end
