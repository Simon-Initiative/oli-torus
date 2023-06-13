defmodule OliWeb.Components.Delivery.ScoredActivities do
  use Surface.LiveComponent

  alias Oli.Publishing.DeliveryResolver
  alias OliWeb.Delivery.ScoredActivities.{ActivitiesTableModel, AssessmentsTableModel}
  alias OliWeb.Common.Params
  alias Phoenix.LiveView.JS
  alias OliWeb.Common.{PagedTable, SearchInput}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Table.SortableTableModel

  prop(assessments, :list, required: true)
  prop(students, :list, required: true)
  prop(params, :map, required: true)
  prop(section_slug, :string, required: true)
  prop(view, :string, required: true)
  prop(ctx, :map, required: true)

  data(table_model, :map)
  data(total_count, :integer)
  data(student_emails_without_attempts, :list)
  data(students_with_attempts_count, :integer)
  data(total_attempts_count, :integer)
  data(scored_activity, :map)

  @default_params %{
    offset: 0,
    limit: 10,
    sort_order: :asc,
    sort_by: :title,
    text_search: nil
  }

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    params = decode_params(assigns.params)

    socket =
      case params.scored_activity_id do
        nil ->
          {total_count, rows} = apply_filters(assigns.assessments, params)

          {:ok, table_model} = AssessmentsTableModel.new(rows, assigns.ctx)

          table_model =
            Map.merge(table_model, %{
              rows: rows,
              sort_order: params.sort_order
            })
            |> SortableTableModel.update_sort_params(params.sort_by)

          assign(socket,
            table_model: table_model,
            total_count: total_count,
            scored_activity: nil
          )

        scored_activity_id ->
          scored_activity = Enum.find(assigns.assessments, fn a -> a.id == scored_activity_id end)

          activities = get_activities(scored_activity, assigns.section_slug)

          students_with_attempts =
            DeliveryResolver.students_with_attempts_for_page(scored_activity.id)

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
              sort_order: params.sort_order,
              selected: rows != [] && hd(rows).id |> Integer.to_string()
            })
            |> SortableTableModel.update_sort_params(params.sort_by)

          assign(socket,
            scored_activity: scored_activity,
            activities: activities,
            table_model: table_model,
            total_count: total_count,
            students_with_attempts_count: Enum.count(students_with_attempts),
            student_emails_without_attempts: student_emails_without_attempts,
            total_attempts_count:
              Enum.reduce(activities, 0, fn a, acc -> a.total_attempts + acc end)
          )
      end

    {:ok,
     assign(socket,
       params: params,
       section_slug: assigns.section_slug,
       view: assigns.view,
       ctx: assigns.ctx,
       assessments: assigns.assessments,
       students: assigns.students
     )}
  end

  def render(assigns) do
    ~F"""
    <div class="bg-white shadow-sm">
      <div class="flex flex-col space-y-4 lg:space-y-0 lg:flex-row lg:justify-between px-9 bg-white">
        {#if @scored_activity != nil }
          <div class="flex flex-col">
            {#if @scored_activity.container_label }
              <h4 class="torus-h4 whitespace-nowrap">{@scored_activity.container_label}</h4>
              <span class="text-lg">{@scored_activity.title}</span>
            {#else}
              <h4 class="torus-h4 whitespace-nowrap">{@scored_activity.title}</h4>
            {/if}
            <button class="btn btn-primary whitespace-nowrap mr-auto my-6" phx-click="back" phx-target={@myself}>Go back</button>
          </div>
        {#else}
          <h4 class="torus-h4 whitespace-nowrap">Scored Activities</h4>
        {/if}
        <div class="flex flex-col">
          <form for="search" phx-target={@myself} phx-change="search_assessment" class="pb-6 lg:ml-auto lg:pt-7">
            <SearchInput.render
              id="assessments_search_input"
              name="assessment_name"
              text={@params.text_search}
            />
          </form>
          {#if @scored_activity != nil }
            <div class="flex flex-row mt-auto">
              <span class="text-xs">
                {@students_with_attempts_count} {Gettext.ngettext(OliWeb.Gettext, "student has", "students have", @students_with_attempts_count)} completed {@total_attempts_count} {Gettext.ngettext(OliWeb.Gettext, "attempt", "attempts", @total_attempts_count)}.
              </span>
              {#if @students_with_attempts_count < Enum.count(@students)}
                <div class="flex flex-col">
                  <span class="text-xs ml-2">
                    {Enum.count(@student_emails_without_attempts)} {Gettext.ngettext(OliWeb.Gettext, "student has", "students have", Enum.count(@student_emails_without_attempts))} not completed any attempt.
                  </span>
                  <input type="text" id="email_inputs" class="form-control hidden" value={Enum.join(@student_emails_without_attempts, "; ")} readonly>
                  <button class="text-xs text-primary underline ml-auto mb-6" phx-hook="CopyListener" data-clipboard-target="#email_inputs"><i class="fa-solid fa-copy mr-2"></i>{Gettext.ngettext(OliWeb.Gettext, "Copy his email address", "Copy their email addresses", Enum.count(@student_emails_without_attempts))}</button>
                </div>
              {/if}
            </div>
          {/if}
        </div>
      </div>

      <PagedTable
        table_model={@table_model}
        total_count={@total_count}
        offset={@params.offset}
        limit={@params.limit}
        page_change={JS.push("paged_table_page_change", target: @myself)}
        selection_change={JS.push("paged_table_selection_change", target: @myself)}
        sort={JS.push("paged_table_sort", target: @myself)}
        additional_table_class="instructor_dashboard_table"
        show_bottom_paging={false}
        render_top_info={false}
        allow_selection={true}
      />
    </div>
    """
  end

  def handle_event("back", _params, socket) do
    socket =
      assign(socket,
        params: Map.put(socket.assigns.params, :scored_activity_id, nil),
        scored_activity: nil
      )

    {:noreply,
     push_patch(socket, to: route_to(socket, socket.assigns.params.assessment_table_params))}
  end

  def handle_event("paged_table_selection_change", %{"id" => selected_id}, socket)
      when not is_nil(socket.assigns.scored_activity) do
    table_model =
      Map.merge(socket.assigns.table_model, %{
        selected: selected_id
      })

    {:noreply, assign(socket, table_model: table_model)}
  end

  def handle_event("paged_table_selection_change", %{"id" => selected_scored_activity_id}, socket) do
    assessment_table_params = socket.assigns.params

    socket =
      assign(socket,
        params:
          Map.put(
            socket.assigns.params,
            :scored_activity_id,
            selected_scored_activity_id
          )
      )

    {:noreply,
     push_patch(socket, to: route_to(socket, %{assessment_table_params: assessment_table_params}))}
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
           update_params(socket.assigns.params, %{text_search: assessment_name, offset: 0})
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
        Enum.sort_by(assessments, fn a -> Map.get(a, :title) |> String.downcase() end, sort_order)
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
      scored_activity_id: Params.get_int_param(params, "scored_activity_id", nil),
      assessment_table_params: params["assessment_table_params"]
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
       when not is_nil(socket.assigns.params.scored_activity_id) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      socket.assigns.section_slug,
      socket.assigns.view,
      :scored_activities,
      socket.assigns.params.scored_activity_id,
      params
    )
  end

  defp route_to(socket, params) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      socket.assigns.section_slug,
      socket.assigns.view,
      :scored_activities,
      params
    )
  end

  defp get_activities(scored_activity, section_slug) do
    scored_activity.content["model"]
    |> Enum.filter(fn element -> element["type"] == "activity-reference" end)
    |> Enum.map(fn activity -> activity["activity_id"] end)
    |> case do
      [] ->
        []

      activity_ids ->
        activities = DeliveryResolver.activities_by_resource_ids(activity_ids, section_slug)

        objectives_mapper =
          Enum.reduce(activities, [], fn activity, acc ->
            activity.objectives["1"] ++ acc
          end)
          |> Enum.uniq()
          |> DeliveryResolver.objectives_by_resource_ids(section_slug)
          |> Enum.map(fn objective -> {objective.resource_id, objective} end)
          |> Enum.into(%{})

        activities
        |> Enum.map(fn activity ->
          case activity.objectives["1"] do
            [] ->
              activity

            objective_ids ->
              Map.put(
                activity,
                :objectives,
                Enum.map(objective_ids, fn id -> Map.get(objectives_mapper, id) end)
              )
          end
        end)
    end
  end
end
