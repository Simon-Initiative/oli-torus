defmodule OliWeb.Components.Delivery.Surveys do
  use OliWeb, :live_component

  alias Oli.Publishing.DeliveryResolver
  alias OliWeb.Delivery.ActivityHelpers
  alias OliWeb.Common.StripedPagedTable
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
    text_search: nil,
    selected_survey_ids: []
  }

  def mount(socket) do
    {:ok,
     assign(socket,
       scripts_loaded: false,
       table_model: nil,
       current_page: nil,
       activities: nil
     )}
  end

  def update(assigns, socket) do
    params = decode_params(assigns.params)

    {total_count, rows} = apply_filters(assigns.assessments, params)

    {:ok, table_model} =
      SurveysAssessmentsTableModel.new(
        rows,
        socket.assigns.myself,
        assigns.students,
        assigns.activity_types_map
      )

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order
      })
      |> SortableTableModel.update_sort_params(params.sort_by)

    socket =
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
      )
      |> assign_selected_survey_activities(params.selected_survey_ids)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.loader :if={!@table_model} />
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
          no_records_message={no_records_message(@params.text_search)}
          details_render_fn={&SurveysAssessmentsTableModel.render_survey_details/2}
          sticky_header_offset={56}
        />
      </div>
    </div>
    """
  end

  def handle_event("paged_table_selection_change", %{"id" => survey_id}, socket) do
    decoded_id = parse_survey_id(survey_id)

    current_ids =
      (socket.assigns.table_model &&
         Map.get(socket.assigns.table_model.data || %{}, :selected_survey_ids)) ||
        socket.assigns.params.selected_survey_ids

    new_ids =
      if decoded_id in current_ids do
        List.delete(current_ids, decoded_id)
      else
        [decoded_id | current_ids]
      end

    {:noreply,
     push_patch(socket,
       to: route_to(socket, update_params(socket.assigns.params, %{selected_survey_ids: new_ids}))
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

  defp assign_selected_survey_activities(socket, []) do
    table_model =
      socket.assigns.table_model
      |> Map.update!(:data, fn data ->
        Map.merge(data, %{
          selected_survey_ids: [],
          survey_activities_map: %{},
          expanded_rows: MapSet.new()
        })
      end)

    socket
    |> assign(table_model: table_model)
  end

  defp assign_selected_survey_activities(socket, selected_survey_ids) do
    %{
      section: section,
      students: students,
      activity_types_map: activity_types_map,
      scripts: scripts,
      table_model: table_model
    } = socket.assigns

    existing_map = Map.get(table_model.data || %{}, :survey_activities_map, %{})

    new_survey_ids = Enum.reject(selected_survey_ids, &Map.has_key?(existing_map, &1))

    survey_activities_map =
      if new_survey_ids == [] do
        existing_map
      else
        revisions_list = DeliveryResolver.from_resource_id(section.slug, new_survey_ids)

        id_revision_pairs =
          Enum.zip(new_survey_ids, revisions_list)
          |> Enum.reject(fn {_id, rev} -> is_nil(rev) end)

        students_count = length(students)

        new_entries =
          Task.async_stream(
            id_revision_pairs,
            fn {survey_id, revision} ->
              activity_ids = get_survey_activity_ids(revision)

              activities =
                ActivityHelpers.summarize_activity_performance(
                  section,
                  revision,
                  activity_types_map,
                  students,
                  activity_ids
                )

              activities_with_counts =
                Enum.map(activities, fn a ->
                  Map.merge(a, %{
                    students_count: students_count,
                    emails_without_attempts_count: length(a.student_emails_without_attempts || [])
                  })
                end)

              {survey_id, activities_with_counts}
            end,
            max_concurrency: 4,
            ordered: false
          )
          |> Enum.reduce(existing_map, fn
            {:ok, {survey_id, activities}}, acc ->
              Map.put(acc, survey_id, activities)

            _other, acc ->
              acc
          end)

        new_entries
      end

    table_model =
      table_model
      |> Map.update!(:data, fn data ->
        Map.merge(data, %{
          selected_survey_ids: selected_survey_ids,
          survey_activities_map: survey_activities_map,
          expanded_rows: MapSet.new(Enum.map(selected_survey_ids, &"row_#{&1}")),
          activity_types_map: activity_types_map,
          scripts: scripts,
          target: socket.assigns.myself
        })
      end)

    socket
    |> assign(table_model: table_model)
    |> then(fn s ->
      if s.assigns.scripts_loaded do
        s
      else
        push_event(s, "load_survey_scripts", %{script_sources: scripts})
      end
    end)
  end

  defp get_survey_activity_ids(revision) do
    Oli.Resources.PageContent.survey_activities(revision.content)
    |> Map.values()
    |> List.flatten()
  end

  defp parse_survey_id(id) when is_integer(id), do: id
  defp parse_survey_id(id) when is_binary(id), do: String.to_integer(id)

  defp no_records_message(text_search) when text_search in [nil, ""],
    do: "There are no surveys present in this course"

  defp no_records_message(_), do: "No surveys match your search"

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
      selected_activity: Params.get_param(params, "selected_activity", nil),
      selected_survey_ids:
        decode_selected_survey_ids(Params.get_param(params, "selected_survey_ids", []))
    }
  end

  defp decode_selected_survey_ids(nil), do: []
  defp decode_selected_survey_ids([]), do: []
  defp decode_selected_survey_ids(ids) when is_list(ids), do: normalize_survey_ids(ids)

  defp decode_selected_survey_ids(encoded) when is_binary(encoded) do
    case Jason.decode(encoded) do
      {:ok, []} -> []
      {:ok, decoded} when is_list(decoded) -> normalize_survey_ids(decoded)
      _ -> []
    end
  end

  defp decode_selected_survey_ids(_), do: []

  defp normalize_survey_ids(list) do
    Enum.map(list, fn
      id when is_integer(id) -> id
      id when is_binary(id) -> String.to_integer(id)
    end)
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
