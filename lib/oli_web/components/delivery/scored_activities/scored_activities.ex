defmodule OliWeb.Components.Delivery.ScoredActivities do
  use Phoenix.LiveComponent

  import Ecto.Query
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo

  alias Oli.Publishing.DeliveryResolver

  alias OliWeb.Delivery.ScoredActivities.{
    ActivitiesTableModel,
    AssessmentsTableModel
  }

  alias OliWeb.Common.Params
  alias Phoenix.LiveView.JS
  alias OliWeb.Common.{PagedTable, SearchInput}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Table.SortableTableModel
  alias Oli.Delivery.Attempts.Core
  alias OliWeb.ManualGrading.RenderedActivity
  alias Oli.Repo
  alias Oli.Delivery.Sections.SectionsProjectsPublications

  alias Oli.Delivery.Attempts.Core.{
    ResourceAccess,
    ResourceAttempt,
    ActivityAttempt
  }

  alias Oli.Resources.Revision

  @default_params %{
    offset: 0,
    limit: 10,
    sort_order: :asc,
    sort_by: :title,
    text_search: nil
  }

  def mount(socket) do
    {:ok, assign(socket, scripts_loaded: false)}
  end

  def update(assigns, socket) do
    params = decode_params(assigns.params)

    socket =
      case params.assessment_id do
        nil ->
          {total_count, rows} = apply_filters(assigns.assessments, params)

          {:ok, table_model} = AssessmentsTableModel.new(rows, assigns.ctx, socket.assigns.myself)

          table_model =
            Map.merge(table_model, %{
              rows: rows,
              sort_order: params.sort_order
            })
            |> SortableTableModel.update_sort_params(params.sort_by)

          assign(socket,
            table_model: table_model,
            total_count: total_count,
            current_assessment: nil
          )

        assessment_id ->
          current_assessment =
            Enum.find(assigns.assessments, fn a ->
              a.id == assessment_id
            end)

          student_ids = Enum.map(assigns.students, & &1.id)

          activities = get_activities(current_assessment, assigns.section, student_ids)

          students_with_attempts =
            DeliveryResolver.students_with_attempts_for_page(
              current_assessment,
              assigns.section.id,
              student_ids
            )

          student_emails_without_attempts =
            Enum.reduce(assigns.students, [], fn s, acc ->
              if s.id in students_with_attempts do
                acc
              else
                [s.email | acc]
              end
            end)

          {total_count, rows} = apply_filters(activities, params)

          {:ok, table_model} = ActivitiesTableModel.new(rows)

          table_model =
            table_model
            |> Map.merge(%{
              rows: rows,
              sort_order: params.sort_order
            })
            |> SortableTableModel.update_sort_params(params.sort_by)

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
      end

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

    socket =
      if socket.assigns.current_assessment != nil,
        do: assign_selected_activity(socket, params[:selected_activity]),
        else: socket

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div class="bg-white shadow-sm dark:bg-gray-800 dark:text-white">
        <div class="flex flex-col space-y-4 lg:space-y-0 lg:flex-row lg:justify-between px-9">
          <%= if @current_assessment != nil do %>
            <div class="flex flex-col">
              <%= if @current_assessment.container_label do %>
                <h4 class="torus-h4 whitespace-nowrap"><%= @current_assessment.container_label %></h4>
                <span class="text-lg"><%= @current_assessment.title %></span>
              <% else %>
                <h4 class="torus-h4 whitespace-nowrap"><%= @current_assessment.title %></h4>
              <% end %>
              <button
                class="btn btn-primary whitespace-nowrap mr-auto my-6"
                phx-click="back"
                phx-target={@myself}
              >Go back</button>
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
            <%= if @current_assessment != nil do %>
              <div id="student_attempts_summary" class="flex flex-row mt-auto">
                <span class="text-xs">
                  <%= if @students_with_attempts_count == 0 do %>
                    No student has completed any attempts.
                  <% else %>
                    <%= ~s{#{@students_with_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "student has", "students have", @students_with_attempts_count)} completed #{@total_attempts_count} #{Gettext.ngettext(OliWeb.Gettext, "attempt", "attempts", @total_attempts_count)}.} %>
                  <% end %>
                </span>
                <%= if @students_with_attempts_count < Enum.count(@students) do %>
                  <div class="flex flex-col">
                    <span class="text-xs ml-2">
                      <%= ~s{#{Enum.count(@student_emails_without_attempts)} #{Gettext.ngettext(
                        OliWeb.Gettext,
                        "student has",
                        "students have",
                        Enum.count(@student_emails_without_attempts)
                      )} not completed any attempt.} %>
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
                    ><i class="fa-solid fa-copy mr-2" /><%= Gettext.ngettext(
                        OliWeb.Gettext,
                        "Copy email address",
                        "Copy email addresses",
                        Enum.count(@student_emails_without_attempts)
                    )  %></button>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <PagedTable.render
          __context__={assigns[:__context_]}
          table_model={@table_model}
          total_count={@total_count}
          offset={@params.offset}
          limit={@params.limit}
          page_change={JS.push("paged_table_page_change", target: @myself)}
          selection_change={JS.push("paged_table_selection_change", target: @myself)}
          sort={JS.push("paged_table_sort", target: @myself)}
          additional_table_class="instructor_dashboard_table"
          filter=""
          show_top_paging={true}
          show_bottom_paging={false}
          render_top_info={false}
          allow_selection={!is_nil(@current_assessment)}
        />
      </div>
      <%= if @current_assessment != nil and @activities != [] do %>
        <div class="mt-9">
          <div class="bg-white dark:bg-gray-800 dark:text-white w-min whitespace-nowrap rounded-t-md block font-medium text-sm leading-tight uppercase border-x-1 border-t-1 border-b-0 border-gray-300 px-6 py-4">Question details</div>
          <div class="bg-white dark:bg-gray-800 dark:text-white shadow-sm px-6 -mt-5" id="activity_detail" phx-hook="LoadSurveyScripts">
            <%= if @preview_rendered != nil do %>
             <RenderedActivity.render id={@rendered_activity_id} rendered_activity={@preview_rendered} myself={@myself} />
            <% else %>
              <p class="pt-9 pb-5">No attempt registered for this question</p>
            <% end %>
          </div>
        </div>
      <% end %>
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

  def handle_event(
        "paged_table_selection_change",
        %{"id" => activity_resource_id},
        socket
      )
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

  def handle_event(
        "paged_table_selection_change",
        %{"id" => selected_assessment_id},
        socket
      ) do
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

  defp assign_selected_activity(socket, selected_activity_id)
       when selected_activity_id in ["", nil] do
    case socket.assigns.table_model.rows do
      [] ->
        socket

      rows ->
        assign_selected_activity(socket, hd(rows).resource_id |> Integer.to_string())
    end
  end

  defp assign_selected_activity(socket, selected_activity_id) do
    table_model =
      Map.merge(socket.assigns.table_model, %{
        selected: selected_activity_id
      })

    case get_activity_attempt(selected_activity_id, socket.assigns.section.id) do
      nil ->
        socket
        |> assign(table_model: table_model)

      activity_attempt ->
        part_attempts = Core.get_latest_part_attempts(activity_attempt.attempt_guid)

        rendering_context =
          OliWeb.ManualGrading.Rendering.create_rendering_context(
            activity_attempt,
            part_attempts,
            socket.assigns.activity_types_map,
            socket.assigns.section
          )
          |> Map.merge(%{is_liveview: true})

        preview_rendered =
          OliWeb.ManualGrading.Rendering.render(
            rendering_context,
            :instructor_preview
          )

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
      assessment_table_params: params["assessment_table_params"],
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

    objectives_mapper =
      Enum.reduce(activities, [], fn activity, acc ->
        (Map.values(activity.objectives) |> List.flatten()) ++ acc
      end)
      |> Enum.uniq()
      |> DeliveryResolver.objectives_by_resource_ids(section.slug)
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
            Enum.map(objective_ids, fn id ->
              Map.get(objectives_mapper, id)
            end)
          )
      end
    end)
  end

  defp get_activity_attempt(selected_activity_id, section_id) do
    query =
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
        resource_access.section_id == ^section_id and
          activity_revision.resource_id == ^selected_activity_id
      )
      |> order_by([aa, _, _, _, _, _], desc: aa.inserted_at)
      |> limit(1)
      |> select([aa, _, _, _, _, _], aa)
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

    Repo.one(query)
  end
end
