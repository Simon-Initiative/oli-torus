defmodule OliWeb.Components.Delivery.QuizScores do
  use OliWeb, :live_component

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.EnrollmentBrowseOptions
  alias Oli.Repo.Paging
  alias Oli.Repo.Sorting
  alias OliWeb.Common.InstructorDashboardPagedTable
  alias OliWeb.Common.Params
  alias OliWeb.Common.SearchInput
  alias OliWeb.Grades.GradebookTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.JS

  @default_params %{
    offset: 0,
    limit: 20,
    sort_order: :asc,
    sort_by: :name,
    text_search: nil,
    show_all_links: false
  }

  def update(
        %{
          params: params,
          section: section
        } = assigns,
        socket
      ) do
    params = decode_params(params)

    if is_nil(assigns[:student_id]),
      do:
        get_grades_all_students(section, assigns[:view], assigns[:patch_url_type], params, socket),
      else:
        get_scores_for_student(
          assigns[:scores].scores,
          assigns[:student_id],
          section,
          assigns[:view],
          assigns[:patch_url_type],
          params,
          socket
        )
  end

  attr(:params, :map, required: true)
  attr(:total_count, :integer, required: true)
  attr(:grades_table_model, :map, required: true)
  attr(:student_id, :integer, default: nil)
  attr(:scores, :map, default: %{})
  attr(:patch_url_type, :atom, default: nil)
  attr(:view, :atom)
  attr(:section_slug, :string)

  def render(assigns) do
    ~H"""
    <div class="container mx-auto flex flex-col gap-2 mb-10">
      <div class="bg-white dark:bg-gray-800 shadow-sm">
        <div
          style="min-height: 83px;"
          class="flex justify-between sm:items-end px-4 sm:px-9 py-4 instructor_dashboard_table"
        >
          <div>
            <h4 class="torus-h4 !py-0 sm:mr-auto mb-2">Quiz Scores</h4>
            <a
              href={Routes.delivery_path(OliWeb.Endpoint, :download_quiz_scores, @section_slug)}
              class="self-end"
            >
              <i class="fa-solid fa-download ml-1" /> Download
            </a>
          </div>
          <div class="flex flex-col-reverse sm:flex-row gap-2 items-center">
            <%= if is_nil(assigns[:student_id]) do %>
              <div class="form-check">
                <input
                  type="checkbox"
                  id="toggle_show_all_links"
                  class="form-check-input -mt-1"
                  checked={@params.show_all_links}
                  phx-click="show_all_links"
                  phx-target={@myself}
                  phx-debounce="500"
                />
                <label for="toggle_show_all_links" class="form-check-label">
                  Shows links for all entries
                </label>
              </div>
            <% end %>
            <form for="search" phx-target={@myself} phx-change="search_student" class="w-44">
              <SearchInput.render
                id="student_search_input"
                name="student_name"
                text={@params.text_search}
              />
            </form>
          </div>
        </div>

        <%= if @total_count > 0 do %>
          <InstructorDashboardPagedTable.render
            table_model={@grades_table_model}
            total_count={@total_count}
            offset={@params.offset}
            limit={@params.limit}
            render_top_info={false}
            additional_table_class="instructor_dashboard_table"
            show_bottom_paging={false}
            sort={JS.push("paged_table_sort", target: @myself)}
            page_change={JS.push("paged_table_page_change", target: @myself)}
            limit_change={JS.push("paged_table_limit_change", target: @myself)}
            show_limit_change={true}
            overflow_class="block scrollbar"
          />
        <% else %>
          <h6 class="text-center py-4">There are no quiz scores to show</h6>
        <% end %>
      </div>
    </div>
    """
  end

  defp get_scores_for_student(scores, student_id, section, view, patch_url_type, params, socket) do
    {total_count, rows} = apply_filters(scores, params)

    {:ok, table_model} =
      GradebookTableModel.new(
        rows,
        section.slug,
        student_id
      )

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec ->
            col_spec.name == params.sort_by
          end)
      })

    {:ok,
     assign(
       socket,
       total_count: total_count,
       grades_table_model: table_model,
       params: params,
       section_slug: section.slug,
       patch_url_type: patch_url_type,
       student_id: student_id,
       view: view
     )}
  end

  defp get_grades_all_students(section, view, patch_url_type, params, socket) do
    enrollments =
      Sections.browse_enrollments(
        section,
        %Paging{offset: params.offset, limit: params.limit},
        %Sorting{direction: params.sort_order, field: params.sort_by},
        %EnrollmentBrowseOptions{
          text_search: params.text_search,
          is_student: true,
          is_instructor: false
        }
      )

    graded_pages = Oli.Delivery.Sections.SectionResourceDepot.graded_pages(section.id)

    resource_accesses = fetch_resource_accesses(enrollments, section)

    {:ok, table_model} =
      GradebookTableModel.new(
        enrollments,
        graded_pages,
        resource_accesses,
        section,
        params.show_all_links
      )

    table_model =
      Map.merge(table_model, %{
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec -> col_spec.name == params.sort_by end)
      })

    {:ok,
     assign(
       socket,
       total_count: determine_total(enrollments),
       grades_table_model: table_model,
       params: params,
       section_slug: section.slug,
       patch_url_type: patch_url_type,
       view: view
     )}
  end

  def handle_event("search_student", %{"student_name" => student_name}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{text_search: student_name, offset: 0},
           socket.assigns.patch_url_type
         )
     )}
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{limit: limit, offset: offset},
           socket.assigns.patch_url_type
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
         route_for(
           socket,
           %{limit: new_limit, offset: new_offset},
           socket.assigns.patch_url_type
         )
     )}
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by} = _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{sort_by: String.to_existing_atom(sort_by)},
           socket.assigns.patch_url_type
         )
     )}
  end

  def handle_event("show_all_links", _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{show_all_links: !socket.assigns.params.show_all_links},
           socket.assigns.patch_url_type
         )
     )}
  end

  defp decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      sort_order:
        Params.get_atom_param(params, "sort_order", [:asc, :desc], @default_params.sort_order),
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [:name],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      show_all_links:
        Params.get_boolean_param(params, "show_all_links", @default_params.show_all_links)
    }
  end

  defp apply_filters(scores, params) do
    scores =
      scores
      |> maybe_filter_by_text(params.text_search)
      |> sort_by(params.sort_order)

    {length(scores), scores |> Enum.drop(params.offset) |> Enum.take(params.limit)}
  end

  defp sort_by(scores, sort_order) do
    Enum.sort_by(scores, fn score -> score.label end, sort_order)
  end

  defp maybe_filter_by_text(scores, nil), do: scores
  defp maybe_filter_by_text(scores, ""), do: scores

  defp maybe_filter_by_text(scores, text_search) do
    scores
    |> Enum.filter(fn score ->
      String.contains?(String.downcase(score.label), String.downcase(text_search))
    end)
  end

  defp fetch_resource_accesses(enrollments, section) do
    student_ids = Enum.map(enrollments, fn user -> user.id end)

    Oli.Delivery.Attempts.Core.get_graded_resource_access_for_context(
      section.id,
      student_ids
    )
  end

  defp determine_total(enrollments) do
    case(enrollments) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
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
    |> purge_default_params()
  end

  defp purge_default_params(params) do
    Map.filter(params, fn {key, value} ->
      @default_params[key] != value
    end)
  end

  defp route_for(socket, new_params, :gradebook_view) do
    Routes.live_path(
      socket,
      OliWeb.Grades.GradebookView,
      socket.assigns.section_slug,
      update_params(socket.assigns.params, new_params)
    )
  end

  defp route_for(socket, new_params, :quiz_scores_instructor) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      socket.assigns.section_slug,
      socket.assigns.view,
      :quiz_scores,
      update_params(socket.assigns.params, new_params)
    )
  end

  defp route_for(socket, new_params, :quiz_scores_student) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.StudentDashboard.StudentDashboardLive,
      socket.assigns.section_slug,
      socket.assigns.student_id,
      :quizz_scores,
      update_params(socket.assigns.params, new_params)
    )
  end
end
