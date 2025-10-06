defmodule OliWeb.Components.Delivery.PracticeActivities do
  use OliWeb, :live_component

  alias OliWeb.Common.{Params, SearchInput, StripedPagedTable}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Components.Delivery.CardHighlights
  alias OliWeb.Delivery.ActivityHelpers
  alias OliWeb.Delivery.Content.{MultiSelect, PercentageSelector}
  alias OliWeb.Delivery.PracticeActivities.PracticeAssessmentsTableModel
  alias OliWeb.Icons
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    sort_order: :asc,
    sort_by: :order,
    text_search: nil,
    selected_card_value: nil,
    progress_percentage: nil,
    progress_selector: nil,
    avg_score_percentage: nil,
    avg_score_selector: nil,
    selected_attempts_ids: Jason.encode!([])
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
       current_assessment: nil,
       activities: nil
     )}
  end

  def update(assigns, socket) do
    params = decode_params(assigns.params)

    {total_count, rows} = apply_filters(assigns.assessments, params)

    {:ok, table_model} =
      PracticeAssessmentsTableModel.new(rows, assigns.ctx, socket.assigns.myself)

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order
      })
      |> SortableTableModel.update_sort_params(params.sort_by)

    selected_card_value = Map.get(assigns.params, "selected_card_value", nil)
    assessments_count = assessments_count(assigns.assessments)

    card_props = [
      %{
        title: "Low Scores",
        count: Map.get(assessments_count, :low_scores),
        is_selected: selected_card_value == "low_scores",
        value: :low_scores
      },
      %{
        title: "Low Progress",
        count: Map.get(assessments_count, :low_progress),
        is_selected: selected_card_value == "low_progress",
        value: :low_progress
      },
      %{
        title: "Low or No Attempts",
        count: Map.get(assessments_count, :low_or_no_attempts),
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
       params: params,
       section: assigns.section,
       section_slug: assigns.section.slug,
       view: assigns.view,
       ctx: assigns.ctx,
       assessments: assigns.assessments,
       students: assigns.students,
       student_ids: Enum.map(assigns.students, & &1.id),
       scripts: assigns.scripts,
       activity_types_map: assigns.activity_types_map,
       preview_rendered: nil,
       units_and_modules_options: assigns.units_and_modules_options,
       table_model: table_model,
       total_count: total_count,
       card_props: card_props,
       params_from_url: assigns.params,
       attempts_options: attempts_options,
       selected_attempts_ids: selected_attempts_ids,
       selected_attempts_options: selected_attempts_options
     )}
  end

  attr(:params, :map, required: true)
  attr(:section_slug, :string, required: true)
  attr(:card_props, :list)

  def render(assigns) do
    ~H"""
    <div>
      <.loader :if={!@table_model} />
      <div :if={@table_model} class="bg-white shadow-sm dark:bg-gray-800 dark:text-white">
        <div class="flex flex-col space-y-4 lg:space-y-0 lg:flex-row lg:justify-between px-4 pt-8 pb-4 lg:items-center instructor_dashboard_table dark:bg-[#262626]">
          <div class="self-stretch justify-center text-zinc-700 text-lg font-bold leading-normal dark:text-white">
            Practice Pages
          </div>
          <div>
            <a
              href=""
              class="flex items-center justify-center gap-x-2 text-Text-text-button font-bold leading-none"
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
              container_filter_by={:pages}
            />
          <% end %>
        </div>

        <div class="flex w-fit gap-2 mx-4 mt-4 mb-4 shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)] border border-Border-border-default bg-Background-bg-secondary">
          <div class="flex p-2 gap-2">
            <.form for={%{}} phx-target={@myself} phx-change="search_page" class="w-56">
              <SearchInput.render
                id="practice_activities_search_input"
                name="page_name"
                text={@params.text_search}
              />
            </.form>

            <PercentageSelector.render
              target={@myself}
              percentage={@params.progress_percentage}
              selector={@params.progress_selector}
            />

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
          allow_selection={true}
          show_bottom_paging={false}
          show_limit_change={true}
        />
      </div>

      <%= unless is_nil(@activities) do %>
        <%= if @activities == [] do %>
          <div class="bg-white dark:bg-gray-800 dark:text-white shadow-sm px-10 my-5 mx-10">
            <p class="py-5">No attempt registered for this question</p>
          </div>
        <% else %>
          <div class="mt-9">
            <div :for={activity <- @activities} class="px-10">
              <div class="flex flex-col bg-white dark:bg-gray-800 dark:text-white w-min whitespace-nowrap rounded-t-md block font-medium text-sm leading-tight uppercase border-x-1 border-t-1 border-b-0 border-gray-300 px-6 py-4 my-4 gap-y-2">
                <div role="activity_title">{activity.title} - Question details</div>
                <div
                  :if={@current_assessment != nil and @activities not in [nil, []]}
                  id={"student_attempts_summary_#{activity.id}"}
                  class="flex flex-row gap-x-2 lowercase"
                  role="student attempts summary"
                >
                  <span class="text-xs font-bold">
                    <%= if activity.students_with_attempts_count == 0 do %>
                      No student has responded
                    <% else %>
                      {~s{#{activity.students_with_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "student has", "students have", activity.students_with_attempts_count)} responded}}
                    <% end %>
                  </span>
                </div>
              </div>
              <div
                class="bg-white dark:bg-gray-800 dark:text-white shadow-sm px-6 -mt-5"
                id={"activity_detail_#{activity.id}"}
                phx-hook="LoadSurveyScripts"
              >
                <%= if Map.get(activity, :preview_rendered) != nil do %>
                  <ActivityHelpers.rendered_activity
                    activity={activity}
                    activity_types_map={@activity_types_map}
                  />
                <% else %>
                  <p class="pt-9 pb-5">No attempt registered for this question</p>
                <% end %>
              </div>
              <div class="flex mt-2 mb-10 bg-white gap-x-20 dark:bg-gray-800 dark:text-white shadow-sm px-6 py-4">
                <ActivityHelpers.percentage_bar
                  id={Integer.to_string(activity.id) <> "_first_try_correct"}
                  value={activity.first_attempt_pct}
                  label="First Try Correct"
                />
                <ActivityHelpers.percentage_bar
                  id={Integer.to_string(activity.id) <> "_eventually_correct"}
                  value={activity.all_attempt_pct}
                  label="Eventually Correct"
                />
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  def handle_event(
        "paged_table_selection_change",
        %{"id" => selected_assessment_resource_id},
        socket
      ) do
    details_enabled = Application.get_env(:oli, :instructor_dashboard_details, true)

    if details_enabled do
      %{
        section: section,
        students: students,
        activity_types_map: activity_types_map
      } =
        socket.assigns

      current_assessment =
        Enum.find(socket.assigns.assessments, fn assessment ->
          assessment.resource_id == String.to_integer(selected_assessment_resource_id)
        end)

      page_revision =
        Oli.Publishing.DeliveryResolver.from_resource_id(
          section.slug,
          current_assessment.resource_id
        )

      activities =
        ActivityHelpers.summarize_activity_performance(
          section,
          page_revision,
          activity_types_map,
          students
        )

      {:noreply,
       assign(
         socket,
         current_assessment: current_assessment,
         activities: activities
       )
       |> assign_selected_assessment(current_assessment.resource_id)
       |> case do
         %{assigns: %{scripts_loaded: true}} = socket ->
           socket

         socket ->
           push_event(socket, "load_survey_scripts", %{
             script_sources: socket.assigns.scripts
           })
       end}
    else
      {:noreply, socket}
    end
  end

  def handle_event(
        "search_page",
        %{"page_name" => page_name},
        socket
      ) do
    {:noreply,
     socket
     |> assign(activities: nil, current_assessment: nil)
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

  def handle_event(
        "paged_table_page_change",
        %{"limit" => limit, "offset" => offset},
        socket
      ) do
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
         route_to(
           socket,
           update_params(socket.assigns.params, %{limit: new_limit, offset: new_offset})
         )
     )}
  end

  def handle_event("survey_scripts_loaded", %{"error" => _}, socket) do
    {:noreply, assign(socket, error: true)}
  end

  def handle_event("survey_scripts_loaded", _params, socket) do
    {:noreply, assign(socket, scripts_loaded: true)}
  end

  def handle_event(
        "paged_table_sort",
        %{"sort_by" => sort_by} = _params,
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{
             sort_by: String.to_existing_atom(sort_by)
           })
         )
     )}
  end

  def handle_event("toggle_selected", %{"_target" => [id]}, socket) do
    selected_id = String.to_integer(id)
    do_update_selection(socket, selected_id)
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

  def handle_event("select_card", %{"selected" => value}, socket) do
    value =
      if String.to_existing_atom(value) == Map.get(socket.assigns.params, :selected_card_value),
        do: nil,
        else: String.to_existing_atom(value)

    send(self(), {:selected_card_assessments, value, :practice_activities})

    {:noreply, socket}
  end

  def handle_event("clear_all_filters", _params, socket) do
    section_slug = socket.assigns.section.slug
    path = ~p"/sections/#{section_slug}/instructor_dashboard/insights/practice_activities"
    {:noreply, push_patch(socket, to: path)}
  end

  defp apply_filters(assessments, params) do
    assessments =
      assessments
      |> maybe_filter_by_text(params.text_search)
      |> maybe_filter_by_card(params.selected_card_value)
      |> maybe_filter_by_progress(params.progress_selector, params.progress_percentage)
      |> maybe_filter_by_avg_score(params.avg_score_selector, params.avg_score_percentage)
      |> maybe_filter_by_attempts(params.selected_attempts_ids)
      |> sort_by(params.sort_by, params.sort_order)

    {length(assessments), assessments |> Enum.drop(params.offset) |> Enum.take(params.limit)}
  end

  defp maybe_filter_by_card(assessments, :low_scores),
    do:
      Enum.filter(assessments, fn assessment ->
        assessment.avg_score < 0.40
      end)

  defp maybe_filter_by_card(assessments, :low_progress),
    do: Enum.filter(assessments, fn assessment -> assessment.students_completion < 0.40 end)

  defp maybe_filter_by_card(assessments, :low_or_no_attempts),
    do:
      Enum.filter(assessments, fn assessment ->
        assessment.total_attempts <= 5 || assessment.total_attempts == nil
      end)

  defp maybe_filter_by_card(assessments, _), do: assessments

  defp maybe_filter_by_progress(assessments, progress_selector, percentage) do
    case progress_selector do
      :is_equal_to ->
        Enum.filter(assessments, fn assessment ->
          parse_progress(assessment.students_completion || 0.0) == percentage
        end)

      :is_less_than_or_equal ->
        Enum.filter(assessments, fn assessment ->
          parse_progress(assessment.students_completion || 0.0) <= percentage
        end)

      :is_greather_than_or_equal ->
        Enum.filter(assessments, fn assessment ->
          parse_progress(assessment.students_completion || 0.0) >= percentage
        end)

      nil ->
        assessments
    end
  end

  defp maybe_filter_by_avg_score(assessments, avg_score_selector, avg_score_percentage) do
    case avg_score_selector do
      :is_equal_to ->
        Enum.filter(assessments, fn assessment ->
          parse_progress(assessment.avg_score || 0.0) == avg_score_percentage
        end)

      :is_less_than_or_equal ->
        Enum.filter(assessments, fn assessment ->
          parse_progress(assessment.avg_score || 0.0) <= avg_score_percentage
        end)

      :is_greather_than_or_equal ->
        Enum.filter(assessments, fn assessment ->
          parse_progress(assessment.avg_score || 0.0) >= avg_score_percentage
        end)

      nil ->
        assessments
    end
  end

  defp maybe_filter_by_attempts(assessments, "[]"), do: assessments

  defp maybe_filter_by_attempts(assessments, selected_attempts_ids) do
    selected_attempts_ids = Jason.decode!(selected_attempts_ids)

    Enum.filter(assessments, fn assessment ->
      Enum.any?(selected_attempts_ids, fn
        1 -> assessment.total_attempts in [nil, 0]
        2 -> not is_nil(assessment.total_attempts) and assessment.total_attempts <= 5
        3 -> not is_nil(assessment.total_attempts) and assessment.total_attempts > 5
        _ -> false
      end)
    end)
  end

  defp parse_progress(progress) do
    {progress, _} =
      Float.round(progress * 100)
      |> Float.to_string()
      |> Integer.parse()

    progress
  end

  defp assessments_count(assessments) do
    %{
      low_scores:
        Enum.count(assessments, fn assessment ->
          assessment.avg_score < 0.40
        end),
      low_progress:
        Enum.count(assessments, fn assessment ->
          assessment.students_completion < 0.40
        end),
      low_or_no_attempts:
        Enum.count(assessments, fn assessment ->
          assessment.total_attempts <= 5 || assessment.total_attempts == nil
        end)
    }
  end

  defp maybe_filter_by_text(assessments, nil), do: assessments
  defp maybe_filter_by_text(assessments, ""), do: assessments

  defp maybe_filter_by_text(assessments, text_search) do
    Enum.filter(assessments, fn assessment ->
      String.contains?(
        String.downcase(assessment.title),
        String.downcase(text_search)
      )
    end)
  end

  defp sort_by(assessments, sort_by, sort_order) do
    case sort_by do
      :due_date ->
        Enum.sort_by(
          assessments,
          fn a ->
            if a.scheduling_type != :due_by, do: 0, else: Map.get(a, :due_date)
          end,
          sort_order
        )

      sb when sb in [:avg_score, :students_completion, :total_attempts] ->
        Enum.sort_by(assessments, fn a -> Map.get(a, sb) || -1 end, sort_order)

      :title ->
        Enum.sort_by(
          assessments,
          fn a -> Map.get(a, :title) |> String.downcase() end,
          sort_order
        )

      :order ->
        Enum.sort_by(assessments, fn a -> Map.get(a, :order) end, sort_order)
    end
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
            :order,
            :title,
            :due_date,
            :avg_score,
            :total_attempts,
            :students_completion
          ],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      assessment_id: Params.get_int_param(params, "assessment_id", nil),
      selected_activity: Params.get_param(params, "selected_activity", nil),
      selected_card_value:
        Params.get_atom_param(
          params,
          "selected_card_value",
          [:low_scores, :low_progress, :low_or_no_attempts],
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
        Params.get_param(params, "selected_attempts_ids", @default_params.selected_attempts_ids)
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
  end

  defp route_to(socket, params)
       when not is_nil(socket.assigns.params.assessment_id) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      socket.assigns.section.slug,
      socket.assigns.view,
      :practice_activities,
      socket.assigns.params.assessment_id,
      params
    )
  end

  defp route_to(socket, params) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      socket.assigns.section.slug,
      socket.assigns.view,
      :practice_activities,
      params
    )
  end

  defp update_attempts_options(selected_attempts_ids, attempts_options) do
    Enum.map(attempts_options, fn option ->
      if option.id in selected_attempts_ids, do: %{option | selected: true}, else: option
    end)
  end

  defp assign_selected_assessment(socket, selected_assessment_resource_id)
       when selected_assessment_resource_id in ["", nil] do
    case socket.assigns.table_model.rows do
      [] ->
        socket

      rows ->
        assign_selected_assessment(socket, hd(rows).resource_id)
    end
  end

  defp assign_selected_assessment(socket, selected_assessment_resource_id) do
    table_model =
      Map.merge(socket.assigns.table_model, %{
        selected: "#{selected_assessment_resource_id}"
      })

    assign(socket, table_model: table_model)
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
end
