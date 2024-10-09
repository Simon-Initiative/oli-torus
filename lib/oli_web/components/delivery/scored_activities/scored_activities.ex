defmodule OliWeb.Components.Delivery.ScoredActivities do
  use OliWeb, :live_component

  import Ecto.Query

  alias Oli.Accounts.User
  alias Oli.Analytics.Summary.ResourcePartResponse
  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Analytics.Summary.ResponseSummary
  alias Oli.Analytics.Summary.StudentResponse
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.ActivityAttempt
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo
  alias Oli.Resources.ResourceType
  alias Oli.Resources.Revision

  alias OliWeb.Common.InstructorDashboardPagedTable
  alias OliWeb.Common.PagingParams
  alias OliWeb.Common.Params
  alias OliWeb.Common.SearchInput
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Delivery.ScoredActivities.ActivitiesTableModel
  alias OliWeb.Delivery.ScoredActivities.AssessmentsTableModel
  alias OliWeb.ManualGrading.Rendering
  alias OliWeb.ManualGrading.RenderedActivity
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
        preview_rendered: nil
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

            activities = get_activities(current_assessment, assigns.section, student_ids)

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
               activities: activities,
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
            <div class="text-zinc-700 text-sm font-semibold tracking-tight">
              Back to Activities
            </div>
          </div>
        </div>
      </button>
      <.loader if={!@table_model} />
      <div :if={@table_model} class="bg-white shadow-sm dark:bg-gray-800 dark:text-white">
        <div class="flex flex-col space-y-4 lg:space-y-0 lg:flex-row lg:justify-between px-9">
          <%= if @current_assessment != nil do %>
            <div class="flex flex-col">
              <%= if @current_assessment.container_label do %>
                <h4 class="torus-h4 whitespace-nowrap"><%= @current_assessment.container_label %></h4>
                <span class="text-lg"><%= @current_assessment.title %></span>
              <% else %>
                <h4 class="torus-h4 whitespace-nowrap"><%= @current_assessment.title %></h4>
              <% end %>
            </div>
          <% else %>
            <h4 class="torus-h4 whitespace-nowrap">Scored Activities</h4>
          <% end %>
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
            <div
              :if={@current_assessment != nil}
              id="student_attempts_summary"
              class="flex flex-row mt-auto"
            >
              <span class="text-xs">
                <%= if @students_with_attempts_count == 0 do %>
                  No student has completed any attempts.
                <% else %>
                  <%= ~s{#{@students_with_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "student has", "students have", @students_with_attempts_count)} completed #{@total_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "attempt", "attempts", @total_attempts_count)}.} %>
                <% end %>
              </span>
              <div :if={@students_with_attempts_count < Enum.count(@students)} class="flex flex-col">
                <span class="text-xs ml-2">
                  <%= ~s{#{Enum.count(@student_emails_without_attempts)} #{Gettext.ngettext(OliWeb.Gettext,
                  "student has",
                  "students have",
                  Enum.count(@student_emails_without_attempts))} not completed any attempt.} %>
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
                  class="text-xs text-primary underline ml-auto mb-6"
                  phx-hook="CopyListener"
                  data-clipboard-target="#email_inputs"
                >
                  <i class="fa-solid fa-copy mr-2" /><%= Gettext.ngettext(
                    OliWeb.Gettext,
                    "Copy email address",
                    "Copy email addresses",
                    Enum.count(@student_emails_without_attempts)
                  ) %>
                </button>
              </div>
            </div>
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
          allow_selection={!is_nil(@current_assessment)}
          show_bottom_paging={false}
          limit_change={JS.push("paged_table_limit_change", target: @myself)}
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
          <%= if @preview_rendered != nil do %>
            <RenderedActivity.render id={@rendered_activity_id} rendered_activity={@preview_rendered} />
          <% else %>
            <p class="pt-9 pb-5">No attempt registered for this question</p>
          <% end %>
        </div>
      </div>
    </div>
    """
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

  def handle_event("search_assessment", %{"assessment_name" => assessment_name}, socket) do
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

    section = socket.assigns.section
    activity_types_map = socket.assigns.activity_types_map
    page_id = socket.assigns.current_assessment.resource_id

    case get_activity_details(selected_activity, section, activity_types_map, page_id) do
      nil ->
        assign(socket, table_model: table_model)

      activity_attempt ->
        part_attempts = Core.get_latest_part_attempts(activity_attempt.attempt_guid)

        rendering_context =
          Rendering.create_rendering_context(
            activity_attempt,
            part_attempts,
            activity_types_map,
            section
          )
          |> Map.merge(%{is_liveview: true})

        preview_rendered = Rendering.render(rendering_context, :instructor_preview)

        socket
        |> assign(table_model: table_model, preview_rendered: preview_rendered)
        |> case do
          %{assigns: %{scripts_loaded: true}} = socket ->
            socket

          socket ->
            push_event(socket, "load_survey_scripts", %{
              script_sources: socket.assigns.scripts
            })
        end
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
         %Section{analytics_version: :v2, id: section_id},
         student_ids
       ) do
    page_type_id = ResourceType.get_id_by_type("page")

    from(rs in ResourceSummary,
      where:
        rs.section_id == ^section_id and rs.resource_id == ^current_assessment.resource_id and
          rs.user_id in ^student_ids and rs.project_id == -1 and rs.publication_id == -1 and
          rs.resource_type_id == ^page_type_id,
      select: sum(rs.num_attempts)
    )
    |> Repo.one()
  end

  defp count_attempts(current_assessment, section, student_ids) do
    from(ra in ResourceAttempt,
      join: access in ResourceAccess,
      on: access.id == ra.resource_access_id,
      where:
        ra.lifecycle_state == :evaluated and access.section_id == ^section.id and
          access.resource_id == ^current_assessment.resource_id and access.user_id in ^student_ids,
      select: count(ra.id)
    )
    |> Repo.one()
  end

  defp get_activities(
         current_assessment,
         %Section{analytics_version: :v2} = section,
         _student_ids
       ) do
    # Fetch all unique acitivty ids from the v2 tracked responses for this section
    activity_ids_from_responses =
      get_unique_activities_from_responses(current_assessment.resource_id, section.id)

    details_by_activity =
      from(rs in ResourceSummary,
        where: rs.section_id == ^section.id,
        where: rs.project_id == -1,
        where: rs.publication_id == -1,
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
        Map.merge(rev, %{total_attempts: total_attempts, avg_score: avg_score})
      end)

    add_objective_mapper(activities, section.slug)
  end

  defp get_activities(current_assessment, section, student_ids) do
    activities =
      from(aa in ActivityAttempt,
        join: res_attempt in ResourceAttempt,
        on: aa.resource_attempt_id == res_attempt.id,
        where: res_attempt.lifecycle_state == :evaluated and aa.lifecycle_state == :evaluated,
        join: res_access in ResourceAccess,
        on: res_attempt.resource_access_id == res_access.id,
        where:
          res_access.section_id == ^section.id and
            res_access.resource_id == ^current_assessment.resource_id and
            res_access.user_id in ^student_ids,
        join: rev in Revision,
        on: aa.revision_id == rev.id,
        join: pr in PublishedResource,
        on: rev.id == pr.revision_id,
        join: spp in SectionsProjectsPublications,
        on: pr.publication_id == spp.publication_id,
        where: spp.section_id == ^section.id,
        group_by: [rev.resource_id, rev.id],
        select:
          {rev, count(aa.id),
           sum(aa.score) /
             fragment("CASE WHEN SUM(?) = 0.0 THEN 1.0 ELSE SUM(?) END", aa.out_of, aa.out_of)}
      )
      |> Repo.all()
      |> Enum.map(fn {rev, total_attempts, avg_score} ->
        Map.merge(rev, %{total_attempts: total_attempts, avg_score: avg_score})
      end)

    add_objective_mapper(activities, section.slug)
  end

  defp get_unique_activities_from_responses(page_id, section_id) do
    from(rs in ResponseSummary,
      where: rs.section_id == ^section_id,
      where: rs.page_id == ^page_id,
      where: rs.project_id == -1,
      where: rs.publication_id == -1,
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

  defp get_activity_details(selected_activity, section, activity_types_map, page_id) do
    multiple_choice_type_id =
      Enum.find_value(activity_types_map, fn {k, v} -> if v.title == "Multiple Choice", do: k end)

    single_response_type_id =
      Enum.find_value(activity_types_map, fn {k, v} -> if v.title == "Single Response", do: k end)

    multi_input_type_id =
      Enum.find_value(activity_types_map, fn {k, v} ->
        if v.title == "Multi Input",
          do: k
      end)

    likert_type_id =
      Enum.find_value(activity_types_map, fn {k, v} -> if v.title == "Likert", do: k end)

    activity_attempt =
      ActivityAttempt
      |> join(:left, [aa], resource_attempt in ResourceAttempt,
        on: aa.resource_attempt_id == resource_attempt.id
      )
      |> join(:left, [_, resource_attempt], ra in ResourceAccess,
        on: resource_attempt.resource_access_id == ra.id
      )
      |> join(:left, [_, _, ra], a in assoc(ra, :user))
      |> join(:left, [aa, _, _, _], activity_revision in Revision,
        on: activity_revision.id == aa.revision_id
      )
      |> join(:left, [_, resource_attempt, _, _, _], resource_revision in Revision,
        on: resource_revision.id == resource_attempt.revision_id
      )
      |> where(
        [aa, _resource_attempt, resource_access, _u, activity_revision, _resource_revision],
        resource_access.section_id == ^section.id and
          activity_revision.resource_id == ^selected_activity.resource_id
      )
      |> order_by([aa, _, _, _, _, _], desc: aa.inserted_at)
      |> limit(1)
      |> Ecto.Query.select([aa, _, _, _, _, _], aa)
      |> select_merge(
        [aa, resource_attempt, resource_access, user, activity_revision, resource_revision],
        %{
          activity_type_id: activity_revision.activity_type_id,
          activity_title: activity_revision.title,
          page_title: resource_revision.title,
          page_id: resource_revision.resource_id,
          resource_attempt_number: resource_attempt.attempt_number,
          graded: resource_revision.graded,
          user: user,
          revision: activity_revision,
          resource_attempt_guid: resource_attempt.attempt_guid,
          resource_access_id: resource_access.id
        }
      )
      |> Repo.one()

    if section.analytics_version == :v2 do
      response_summaries =
        from(rs in ResponseSummary,
          join: rpp in ResourcePartResponse,
          on: rs.resource_part_response_id == rpp.id,
          join: sr in StudentResponse,
          on:
            rs.section_id == sr.section_id and rs.page_id == sr.page_id and
              rs.resource_part_response_id == sr.resource_part_response_id,
          join: u in User,
          on: sr.user_id == u.id,
          where:
            rs.section_id == ^section.id and rs.activity_id == ^selected_activity.resource_id and
              rs.publication_id == -1 and rs.project_id == -1 and
              rs.page_id == ^page_id,
          select: %{
            part_id: rpp.part_id,
            response: rpp.response,
            count: rs.count,
            user: u,
            activity_id: rs.activity_id
          }
        )
        |> Repo.all()

      case activity_attempt.activity_type_id do
        ^multiple_choice_type_id ->
          add_choices_frequencies(activity_attempt, response_summaries)

        ^single_response_type_id ->
          add_single_response_details(activity_attempt, response_summaries)

        ^multi_input_type_id ->
          add_multi_input_details(activity_attempt, response_summaries)

        ^likert_type_id ->
          add_likert_details(activity_attempt, response_summaries)

        _ ->
          activity_attempt
      end
    else
      activity_attempt
    end
  end

  defp add_single_response_details(activity_attempt, response_summaries) do
    responses =
      Enum.reduce(response_summaries, [], fn response_summary, acc ->
        if response_summary.activity_id == activity_attempt.resource_id do
          [
            %{
              text: response_summary.response,
              user_name: OliWeb.Common.Utils.name(response_summary.user)
            }
            | acc
          ]
        else
          acc
        end
      end)
      |> Enum.reverse()

    update_in(
      activity_attempt,
      [Access.key!(:revision), Access.key!(:content)],
      &Map.put(&1, "responses", responses)
    )
  end

  defp add_choices_frequencies(activity_attempt, response_summaries) do
    responses =
      Enum.filter(response_summaries, fn response_summary ->
        response_summary.activity_id == activity_attempt.resource_id
      end)

    choices =
      activity_attempt.transformed_model["choices"]
      |> Enum.map(
        &Map.merge(&1, %{
          "frequency" =>
            Enum.find(responses, %{count: 0}, fn r -> r.response == &1["id"] end).count
        })
      )
      |> then(fn choices ->
        blank_reponses = Enum.find(responses, fn r -> r.response == "" end)

        if blank_reponses[:response] do
          [
            %{
              "content" => [
                %{
                  "children" => [
                    %{
                      "text" =>
                        "Blank attempt (user submitted assessment without selecting any choice for this activity)"
                    }
                  ],
                  "type" => "p"
                }
              ],
              "frequency" => blank_reponses.count
            }
            | choices
          ]
        else
          choices
        end
      end)

    update_in(
      activity_attempt,
      [Access.key!(:transformed_model)],
      &Map.put(&1, "choices", choices)
    )
  end

  defp add_multi_input_details(activity_attempt, response_summaries) do
    if activity_attempt.transformed_model do
      mapper = build_input_mapper(activity_attempt.transformed_model["inputs"])

      Enum.reduce(
        activity_attempt.transformed_model["inputs"],
        activity_attempt,
        fn input, acc2 ->
          case input["inputType"] do
            response when response in ["numeric", "text"] ->
              add_text_or_numeric_responses(
                acc2,
                response_summaries,
                mapper
              )

            "dropdown" ->
              add_dropdown_choices(acc2, response_summaries)
          end
        end
      )
    end
  end

  defp add_dropdown_choices(acc, response_summaries) do
    add_choices_frequencies(acc, response_summaries)
    |> update_in(
      [
        Access.key!(:transformed_model),
        Access.key!("inputs"),
        Access.filter(&(&1["inputType"] == "dropdown")),
        Access.key!("choiceIds")
      ],
      &List.insert_at(&1, -1, "0")
    )
  end

  defp add_text_or_numeric_responses(acumulator, response_summaries, mapper) do
    responses =
      relevant_responses(acumulator.resource_id, response_summaries, mapper)

    update_in(
      acumulator,
      [Access.key!(:transformed_model), Access.key!("authoring")],
      &Map.put(&1, "responses", responses)
    )
  end

  defp relevant_responses(resource_id, response_summaries, mapper) do
    Enum.reduce(response_summaries, [], fn response_summary, acc_responses ->
      if response_summary.activity_id == resource_id do
        [
          %{
            text: response_summary.response,
            user_name: OliWeb.Common.Utils.name(response_summary.user),
            type: mapper[response_summary.part_id],
            part_id: response_summary.part_id,
            count: response_summary.count
          }
          | acc_responses
        ]
      else
        acc_responses
      end
    end)
  end

  defp build_input_mapper(nil) do
    %{}
  end

  defp build_input_mapper(inputs) do
    Enum.into(inputs, %{}, fn input ->
      {input["partId"], input["inputType"]}
    end)
  end

  defp add_likert_details(activity_attempt, response_summaries) do
    responses =
      Enum.filter(response_summaries, fn response_summary ->
        response_summary.activity_id == activity_attempt.resource_id
      end)

    choices =
      activity_attempt.revision.content["choices"]
      |> Enum.map(
        &Map.merge(&1, %{
          "frequency" =>
            Enum.find(responses, %{count: 0}, fn r -> r.response == &1["id"] end).count
        })
      )
      |> then(fn choices ->
        blank_reponses = Enum.find(responses, fn r -> r.response == "" end)

        if blank_reponses[:response] do
          [
            %{
              "content" => [
                %{
                  "children" => [
                    %{
                      "text" =>
                        "Blank attempt (user submitted assessment without selecting any choice for this activity)"
                    }
                  ],
                  "type" => "p"
                }
              ],
              "frequency" => blank_reponses.count
            }
            | choices
          ]
        else
          choices
        end
      end)

    update_in(
      activity_attempt,
      [Access.key!(:revision), Access.key!(:content)],
      &Map.put(&1, "choices", choices)
    )
    |> update_in(
      [
        Access.key!(:revision),
        Access.key!(:content)
      ],
      &Map.put(&1, "activityTitle", activity_attempt.revision.title)
    )
  end
end
