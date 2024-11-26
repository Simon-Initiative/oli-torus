defmodule OliWeb.Components.Delivery.Surveys do
  use OliWeb, :live_component

  alias OliWeb.Delivery.ActivityHelpers
  alias OliWeb.Common.InstructorDashboardPagedTable
  alias OliWeb.Common.Params
  alias OliWeb.Common.SearchInput
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Delivery.Surveys.SurveysAssessmentsTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    sort_order: :asc,
    sort_by: :title,
    text_search: nil
  }

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
      SurveysAssessmentsTableModel.new(rows, assigns.ctx, socket.assigns.myself)

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order
      })
      |> SortableTableModel.update_sort_params(params.sort_by)

    {:ok,
     assign(socket,
       params: params,
       section: assigns.section,
       view: assigns.view,
       ctx: assigns.ctx,
       assessments: assigns.assessments,
       students: assigns.students,
       student_ids: Enum.map(assigns.students, & &1.id),
       scripts: assigns.scripts,
       activity_types_map: assigns.activity_types_map,
       preview_rendered: nil,
       table_model: table_model,
       total_count: total_count
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.loader if={!@table_model} />
      <div :if={@table_model} class="bg-white shadow-sm dark:bg-gray-800 dark:text-white">
        <div class="flex flex-col space-y-4 lg:space-y-0 lg:flex-row lg:justify-between px-9 lg:items-center">
          <h4 class="torus-h4 whitespace-nowrap">Surveys</h4>

          <div class="flex flex-col">
            <form
              for="search"
              phx-target={@myself}
              phx-change="search_assessment"
              class="pb-6 lg:ml-auto lg:pt-7"
            >
              <SearchInput.render
                id="assessments_search_input"
                name="assessment_name"
                text={@params.text_search}
              />
            </form>
          </div>
        </div>
        <InstructorDashboardPagedTable.render
          table_model={@table_model}
          total_count={@total_count}
          offset={@params.offset}
          limit={@params.limit}
          page_change={JS.push("paged_table_page_change", target: @myself)}
          selection_change={JS.push("paged_table_selection_change", target: @myself)}
          sort={JS.push("paged_table_sort", target: @myself)}
          additional_table_class="instructor_dashboard_table"
          allow_selection={true}
          show_bottom_paging={false}
          limit_change={JS.push("paged_table_limit_change", target: @myself)}
          show_limit_change={true}
          no_records_message="There are no surveys present in this course"
        />
        <%= unless is_nil(@activities) do %>
          <%= if @activities == [] do %>
            <div class="bg-white dark:bg-gray-800 dark:text-white shadow-sm px-10 my-5 mx-10">
              <p class="py-5">No attempt registered for this question</p>
            </div>
          <% else %>
            <div class="mt-9">
              <div :for={activity <- @activities} class="px-10">
                <div class="flex flex-col bg-white dark:bg-gray-800 dark:text-white w-min whitespace-nowrap rounded-t-md block font-medium text-sm leading-tight uppercase border-x-1 border-t-1 border-b-0 border-gray-300 px-6 py-4 my-4 gap-y-2">
                  <div role="activity_title"><%= activity.title %> - Question details</div>
                  <div
                    :if={@current_assessment != nil and @activities not in [nil, []]}
                    id="student_attempts_summary"
                    class="flex flex-row gap-x-2 lowercase"
                  >
                    <span class="text-xs">
                      <%= if activity.students_with_attempts_count == 0 do %>
                        No student has completed any attempts.
                      <% else %>
                        <%= ~s{#{activity.students_with_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "student has", "students have", activity.students_with_attempts_count)} completed #{activity.total_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "attempt", "attempts", activity.total_attempts_count)}.} %>
                      <% end %>
                    </span>
                    <div
                      :if={activity.students_with_attempts_count < Enum.count(@students)}
                      class="flex flex-col gap-x-2 items-center"
                    >
                      <span class="text-xs">
                        <%= ~s{#{Enum.count(activity.student_emails_without_attempts)} #{Gettext.ngettext(OliWeb.Gettext,
                        "student has",
                        "students have",
                        Enum.count(activity.student_emails_without_attempts))} not completed any attempt.} %>
                      </span>
                      <input
                        type="text"
                        id="email_inputs"
                        class="form-control hidden"
                        value={Enum.join(activity.student_emails_without_attempts, "; ")}
                        readonly
                      />
                      <button
                        id="copy_emails_button"
                        class="text-xs text-primary underline ml-auto"
                        phx-hook="CopyListener"
                        data-clipboard-target="#email_inputs"
                      >
                        <i class="fa-solid fa-copy mr-2" /><%= Gettext.ngettext(
                          OliWeb.Gettext,
                          "Copy email address",
                          "Copy email addresses",
                          Enum.count(activity.student_emails_without_attempts)
                        ) %>
                      </button>
                    </div>
                  </div>
                </div>
                <div
                  class="bg-white dark:bg-gray-800 dark:text-white shadow-sm px-6 -mt-5"
                  id="activity_detail"
                  phx-hook="LoadSurveyScripts"
                >
                  <%= if Map.get(activity, :preview_rendered) != nil do %>
                    <ActivityHelpers.rendered_activity activity={activity} />
                  <% else %>
                    <p class="pt-9 pb-5">No attempt registered for this question</p>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event(
        "paged_table_selection_change",
        %{"id" => survey_id},
        socket
      ) do
    %{
      students: students,
      student_ids: student_ids,
      section: section
    } =
      socket.assigns

    current_assessment = find_current_assessment(socket, survey_id)

    current_activities =
      find_current_activities(current_assessment, section, student_ids, students, socket)

    assign_assessments_activities_table_model(
      socket,
      current_assessment,
      current_activities
    )
  end

  def handle_event(
        "search_assessment",
        %{"assessment_name" => assessment_name},
        socket
      ) do
    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{
             text_search: assessment_name,
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

  defp assign_assessments_activities_table_model(
         socket,
         current_assessment,
         current_activities
       ) do
    {:noreply,
     assign(socket,
       current_assessment: current_assessment,
       activities: current_activities
     )
     |> assign_selected_assessment(current_assessment.id)
     |> case do
       %{assigns: %{scripts_loaded: true}} = socket ->
         socket

       socket ->
         push_event(socket, "load_survey_scripts", %{
           script_sources: socket.assigns.scripts
         })
     end}
  end

  defp find_current_activities(current_assessment, section, student_ids, students, socket) do
    activities =
      ActivityHelpers.get_activities(
        current_assessment.resource_id,
        section.id,
        student_ids,
        true
      )

    activity_resource_ids =
      Enum.map(activities, fn activity -> activity.resource_id end)

    activities_details =
      ActivityHelpers.get_activities_details(
        activity_resource_ids,
        socket.assigns.section,
        socket.assigns.activity_types_map,
        current_assessment.resource_id
      )

    Enum.map(activities, fn activity ->
      activity_details =
        Enum.find(activities_details, fn activity_details ->
          activity.resource_id == activity_details.revision.resource_id
        end)

      Map.put(
        activity,
        :preview_rendered,
        ActivityHelpers.get_preview_rendered(
          activity_details,
          socket.assigns.activity_types_map,
          socket.assigns.section
        )
      )
      |> Map.put(:datasets, Map.get(activity_details, :datasets))
      |> Map.put(:analytics_version, section.analytics_version)
      |> ActivityHelpers.add_activity_attempts_info(students, student_ids, section)
    end)
  end

  defp find_current_assessment(socket, survey_id) do
    Enum.find(socket.assigns.assessments, fn assessment ->
      assessment.id == String.to_integer(survey_id)
    end)
  end

  defp assign_selected_assessment(socket, selected_assessment_id)
       when selected_assessment_id in ["", nil] do
    case socket.assigns.table_model.rows do
      [] ->
        socket

      rows ->
        assign_selected_assessment(socket, hd(rows).resource_id)
    end
  end

  defp assign_selected_assessment(socket, selected_assessment_id) do
    table_model =
      Map.merge(socket.assigns.table_model, %{
        selected: "#{selected_assessment_id}"
      })

    assign(socket, table_model: table_model)
  end

  defp apply_filters(assessments, params) do
    assessments =
      assessments
      |> maybe_filter_by_text(params.text_search)
      |> sort_by(params.sort_by, params.sort_order)

    {length(assessments), assessments |> Enum.drop(params.offset) |> Enum.take(params.limit)}
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
      selected_activity: Params.get_param(params, "selected_activity", nil)
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
      :surveys,
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
      :surveys,
      params
    )
  end
end
