defmodule OliWeb.Components.Delivery.ScoredActivities do
  use OliWeb, :live_component

  import Ecto.Query

  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Analytics.Summary.ResponseSummary
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Resources.ResourceType
  alias OliWeb.Common.StripedPagedTable
  alias OliWeb.Common.PagingParams
  alias OliWeb.Common.Params
  alias OliWeb.Common.SearchInput
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Delivery.ActivityHelpers
  alias OliWeb.Delivery.ScoredActivities.ActivitiesTableModel
  alias OliWeb.Delivery.ScoredActivities.AssessmentsTableModel

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Icons

  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    sort_order: :asc,
    sort_by: :order,
    text_search: nil
  }

  def mount(socket) do
    {:ok, assign(socket, scripts_loaded: false, table_model: nil, current_assessment: nil)}
  end

  def update(assigns, socket) do
    params = decode_params(assigns.params)

    socket =
      assign(socket,
        params: params,
        section: assigns.section,
        view: assigns.view,
        ctx: assigns.ctx,
        assessments: assigns.assessments,
        students: assigns.students,
        scripts: assigns.scripts,
        activity_types_map: assigns.activity_types_map,
        selected_activity: nil
      )

    case params.assessment_id do
      nil ->
        {total_count, rows} = apply_filters(assigns.assessments, params)

        {:ok, table_model} = AssessmentsTableModel.new(rows, assigns.ctx, socket.assigns.myself)

        table_model =
          Map.merge(table_model, %{rows: rows, sort_order: params.sort_order})
          |> SortableTableModel.update_sort_params(params.sort_by)

        {:ok,
         assign(socket,
           table_model: table_model,
           total_count: total_count,
           current_assessment: nil
         )}

      assessment_id ->
        case Enum.find(assigns.assessments, fn a -> a.id == assessment_id end) do
          nil ->
            send(self(), {:redirect_with_warning, "The assessment doesn't exist"})
            {:ok, socket}

          current_assessment ->
            student_ids = Enum.map(assigns.students, & &1.id)

            activities =
              get_activities(current_assessment, assigns.section, assigns[:list_lti_activities])

            students_with_attempts =
              DeliveryResolver.students_with_attempts_for_page(
                current_assessment,
                assigns.section,
                student_ids
              )

            student_emails_without_attempts =
              Enum.reduce(assigns.students, [], fn s, acc ->
                if s.id in students_with_attempts, do: acc, else: [s.email | acc]
              end)

            {total_count, rows} = apply_filters(activities, params)

            {:ok, table_model} = ActivitiesTableModel.new(rows)

            table_model =
              table_model
              |> Map.merge(%{rows: rows, sort_order: params.sort_order})
              |> SortableTableModel.update_sort_params(params.sort_by)

            selected_activity =
              if params[:selected_activity] in ["", nil],
                do: nil,
                else: String.to_integer(params[:selected_activity])

            {:ok,
             assign(socket,
               current_assessment: current_assessment,
               page_revision:
                 DeliveryResolver.from_resource_id(
                   assigns.section.slug,
                   current_assessment.resource_id
                 ),
               activities: rows,
               table_model: table_model,
               total_count: total_count,
               students_with_attempts_count: Enum.count(students_with_attempts),
               student_emails_without_attempts: student_emails_without_attempts,
               total_attempts_count:
                 count_attempts(current_assessment, assigns.section, student_ids),
               rendered_activity_id: UUID.uuid4()
             )
             |> assign_selected_activity(selected_activity)}
        end
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <button
        :if={!is_nil(@current_assessment)}
        class="whitespace-nowrap"
        phx-click="back"
        phx-target={@myself}
      >
        <div class="w-36 h-9 justify-start items-start gap-3.5 inline-flex">
          <div class="px-1.5 py-2 border-zinc-700 justify-start items-center gap-1 flex">
            <Icons.chevron_down class="fill-blue-400 rotate-90" />
            <div class="justify-center text-[#373a44] dark:text-white text-sm font-semibold tracking-tight">Back to Scored Pages</div>
          </div>
        </div>
      </button>
      <.loader :if={!@table_model} />
      <div :if={@table_model} class="bg-white shadow-sm dark:bg-gray-800 dark:text-white">
        <div class="flex flex-col space-y-4 lg:space-y-0 lg:flex-row lg:justify-between px-4 pt-8 pb-4 lg:items-center instructor_dashboard_table dark:bg-[#262626]">
          <%= if @current_assessment != nil do %>
            <div class="flex flex-col gap-y-1">
              <%= if @current_assessment.container_label do %>
                <span class="text-Text-text-high text-base font-bold leading-none">{@current_assessment.container_label}</span>

                <div class="flex flex-row items-center gap-x-1">
                  <%= if !@current_assessment.batch_scoring do %>
                    <Icons.score_as_you_go />
                  <% end %>

                  <span class="text-Text-text-high text-lg font-bold leading-normal">{@current_assessment.title}</span>
                </div>
              <% else %>
                <span class="text-Text-text-high text-lg font-bold leading-normal">{@current_assessment.title}</span>
              <% end %>
            </div>
          <% else %>
            <span class="self-stretch justify-center text-zinc-700 text-lg font-bold leading-normal dark:text-white">
              Scored Pages
            </span>
            <a
              href=""
              class="flex items-center justify-center gap-x-2 text-Text-text-button font-bold leading-none"
            >
              Download CSV <Icons.download />
            </a>
          <% end %>
        </div>
        <div class="flex flex-row justify-between items-center">
          <div class="flex w-fit gap-2 mx-4 my-4 shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)] border border-Border-border-default bg-Background-bg-secondary">
            <div class="flex p-2 gap-2">
              <.form for={%{}} phx-target={@myself} phx-change={if @current_assessment == nil, do: "search_page", else: "search_assessment"} class="w-56">
                <SearchInput.render
                  id="scored_activities_search_input"
                  name={if @current_assessment == nil, do: "page_name", else: "assessment_name"}
                  text={@params.text_search}
                />
              </.form>

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
            :if={@current_assessment != nil}
            id="student_attempts_summary"
            class="flex flex-row mx-4"
          >
            <span class="text-xs">
              <%= if @students_with_attempts_count == 0 do %>
                No student has completed any attempts.
              <% else %>
                {~s{#{@students_with_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "student has", "students have", @students_with_attempts_count)} completed #{@total_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "attempt", "attempts", @total_attempts_count)}.}}
              <% end %>
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
          allow_selection={!is_nil(@current_assessment)}
          show_bottom_paging={false}
          show_limit_change={true}
          no_records_message="There are no activities to show"
        />
      </div>
      <div :if={@current_assessment != nil and @activities != []} class="mt-9">
        <div
          role="activity_title"
          class="bg-white dark:bg-gray-800 dark:text-white w-min whitespace-nowrap rounded-t-md block font-medium text-sm leading-tight uppercase border-x-1 border-t-1 border-b-0 border-gray-300 px-6 py-4"
        >
          Question details
        </div>
        <div
          class="bg-white dark:bg-gray-800 dark:text-white shadow-sm px-6 -mt-5"
          id="activity_detail"
          phx-hook="LoadSurveyScripts"
        >
          <%= if Map.get(@selected_activity, :preview_rendered) != nil do %>
            <ActivityHelpers.rendered_activity
              activity={@selected_activity}
              activity_types_map={@activity_types_map}
            />
          <% else %>
            <p class="pt-9 pb-5">No attempt registered for this question</p>
          <% end %>
        </div>
        <div class="flex mt-2 mb-10 bg-white gap-x-20 dark:bg-gray-800 dark:text-white shadow-sm px-6 py-4">
          <ActivityHelpers.percentage_bar
            id={Integer.to_string(@selected_activity.id) <> "_first_try_correct"}
            value={@selected_activity.first_attempt_pct}
            label="First Try Correct"
          />
          <ActivityHelpers.percentage_bar
            id={Integer.to_string(@selected_activity.id) <> "_eventually_correct"}
            value={@selected_activity.all_attempt_pct}
            label="Eventually Correct"
          />
        </div>
      </div>
    </div>
    """
  end

  def handle_event("clear_all_filters", _params, socket) do
    case socket.assigns.params.assessment_id do
      nil ->
        # No assessment selected, clear all filters and go to main page
        section_slug = socket.assigns.section.slug
        path = ~p"/sections/#{section_slug}/instructor_dashboard/insights/scored_activities"
        {:noreply, push_patch(socket, to: path)}

      _assessment_id ->
        # Assessment is selected, clear only search filters but keep assessment selected
        updated_params = update_params(socket.assigns.params, %{
          text_search: nil,
          offset: 0
        })
        {:noreply, push_patch(socket, to: route_to(socket, updated_params))}
    end
  end

  def handle_event("back", _params, socket) do
    socket =
      assign(socket,
        params: Map.put(socket.assigns.params, :assessment_id, nil),
        current_assessment: nil
      )

    {:noreply,
     push_patch(socket,
       to: route_to(socket, socket.assigns.params.assessment_table_params)
     )}
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

  def handle_event("search_assessment", %{"assessment_name" => assessment_name}, socket) do
    updated_params =
      update_params(socket.assigns.params, %{
        text_search: assessment_name,
        offset: 0
      })

    {:noreply, push_patch(socket, to: route_to(socket, updated_params))}
  end

  def handle_event("paged_table_selection_change", %{"id" => activity_resource_id}, socket)
      when not is_nil(socket.assigns.current_assessment) do
    {:noreply,
     push_patch(socket,
       to:
         route_to(
           socket,
           update_params(socket.assigns.params, %{
             selected_activity: activity_resource_id
           })
         )
     )}
  end

  def handle_event("paged_table_selection_change", %{"id" => selected_assessment_id}, socket) do
    assessment_table_params = socket.assigns.params

    socket =
      assign(socket,
        params:
          Map.put(
            socket.assigns.params,
            :assessment_id,
            selected_assessment_id
          )
      )

    {:noreply,
     push_patch(socket,
       to: route_to(socket, %{assessment_table_params: assessment_table_params})
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

  defp assign_selected_activity(socket, selected_activity_id)
       when selected_activity_id in ["", nil] do
    case socket.assigns.table_model.rows do
      [] ->
        socket

      rows ->
        assign_selected_activity(socket, hd(rows).resource_id)
    end
  end

  defp assign_selected_activity(socket, selected_activity_id) do
    selected_activity =
      Enum.find(socket.assigns.activities, fn a -> a.resource_id == selected_activity_id end)

    table_model =
      Map.merge(socket.assigns.table_model, %{selected: "#{selected_activity_id}"})

    %{
      section: section,
      page_revision: page_revision,
      students: students,
      activity_types_map: activity_types_map
    } = socket.assigns

    selected_activity =
      case ActivityHelpers.summarize_activity_performance(
             section,
             page_revision,
             activity_types_map,
             students,
             [selected_activity.resource_id]
           ) do
        [current_activity | _rest] -> current_activity
        _ -> nil
      end

    socket
    |> assign(table_model: table_model, selected_activity: selected_activity)
    |> case do
      %{assigns: %{scripts_loaded: true}} = socket ->
        socket

      socket ->
        push_event(socket, "load_survey_scripts", %{
          script_sources: socket.assigns.scripts
        })
    end
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
      String.contains?(String.downcase(assessment.title), String.downcase(text_search))
    end)
  end

  defp sort_by(assessments, sort_by, sort_order) do
    case sort_by do
      :due_date ->
        Enum.sort_by(
          assessments,
          fn
            %{scheduling_type: :due_by, end_date: nil} = _assessment ->
              DateTime.from_unix(0, :second) |> elem(1)

            %{scheduling_type: :due_by} = assessment ->
              assessment.end_date

            _ ->
              DateTime.from_unix(0, :second) |> elem(1)
          end,
          {sort_order, DateTime}
        )

      sb when sb in [:avg_score, :students_completion, :total_attempts] ->
        Enum.sort_by(assessments, fn a -> Map.get(a, sb) || -1 end, sort_order)

      :title ->
        Enum.sort_by(assessments, &String.downcase(&1.title), sort_order)

      :order ->
        Enum.sort_by(assessments, fn a -> Map.get(a, :order) end, sort_order)
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
      assessment_id: Params.get_int_param(params, "assessment_id", nil),
      assessment_table_params: params["assessment_table_params"],
      selected_activity: Params.get_param(params, "selected_activity", nil)
    }
  end

  defp update_params(%{sort_by: sort_by} = params, %{sort_by: sort_by}) do
    toggled_sort_order = if params.sort_order == :asc, do: :desc, else: :asc
    update_params(params, %{sort_order: toggled_sort_order})
  end

  defp update_params(params, new_param), do: Map.merge(params, new_param)

  defp route_to(socket, params)
       when not is_nil(socket.assigns.params.assessment_id) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      socket.assigns.section.slug,
      socket.assigns.view,
      :scored_activities,
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
      :scored_activities,
      params
    )
  end

  defp count_attempts(
         current_assessment,
         %Section{id: section_id},
         student_ids
       ) do
    page_type_id = ResourceType.get_id_by_type("page")

    from(rs in ResourceSummary,
      where:
        rs.section_id == ^section_id and rs.resource_id == ^current_assessment.resource_id and
          rs.user_id in ^student_ids and rs.project_id == -1 and
          rs.resource_type_id == ^page_type_id,
      select: sum(rs.num_attempts)
    )
    |> Repo.one()
  end

  defp get_activities(
         current_assessment,
         section,
         list_lti_activities
       ) do
    # Fetch all unique acitivty ids from the v2 tracked responses for this section
    activity_ids_from_responses =
      get_unique_activities_from_responses(current_assessment.resource_id, section.id)

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
end
