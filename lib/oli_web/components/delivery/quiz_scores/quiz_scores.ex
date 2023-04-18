defmodule OliWeb.Components.Delivery.QuizScores do
  use Surface.LiveComponent

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.EnrollmentBrowseOptions
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.Params
  alias OliWeb.Common.{PagedTable, SearchInput}
  alias OliWeb.Grades.GradebookTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.LiveView.JS

  prop(params, :map, required: true)
  prop(total_count, :number, required: true)
  prop(grades_table_model, :struct, required: true)

  @default_params %{
    offset: 0,
    limit: 10,
    sort_order: :asc,
    sort_by: :name,
    text_search: nil,
    show_all_links: false
  }

  def update(
        %{params: params, section: section, patch_url_type: patch_url_type} = _assigns,
        socket
      ) do
    params = decode_params(params)

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

    hierarchy = Oli.Publishing.DeliveryResolver.full_hierarchy(section.slug)

    graded_pages =
      hierarchy
      |> Oli.Delivery.Hierarchy.flatten()
      |> Enum.filter(fn node -> node.revision.graded end)
      |> Enum.map(fn node -> node.revision end)

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
       patch_url_type: patch_url_type
     )}
  end

  def render(assigns) do
    ~F"""
      <div class="mx-10 mb-10 bg-white shadow-sm">
        <div class="flex flex-col justify-between sm:flex-row items-center px-6 py-4 pl-9">
          <h4 class="!py-2 torus-h4 text-center">Quiz Scores</h4>
          <div class="flex flex-col gap-y-4 md:flex-row items-center">
            <div class="form-check">
              <input type="checkbox" id="toggle_show_all_links" class="form-check-input -mt-1" checked={@params.show_all_links} phx-click="show_all_links" phx-target={@myself} />
              <label for="toggle_show_all_links" class="form-check-label">Shows links for all entries</label>
            </div>
            <form for="search" phx-target={@myself} phx-change="search_student" class="pb-3 md:pl-9 sm:pb-0">
              <SearchInput.render id="student_search_input" name="student_name" text={@params.text_search} />
            </form>
          </div>
        </div>


        {#if @total_count > 0}
          <PagedTable
            table_model={@grades_table_model}
            total_count={@total_count}
            offset={@params.offset}
            limit={@params.limit}
            render_top_info={false}
            additional_table_class="instructor_dashboard_table"
            show_bottom_paging={false}
            sort={JS.push("paged_table_sort", target: @myself)}
            page_change={JS.push("paged_table_page_change", target: @myself)}
          />
        {#else}
          <h6 class="text-center py-4">There are no quiz scores to show</h6>
        {/if}
      </div>
    """
  end

  def handle_event("search_student", %{"student_name" => student_name}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         route_for(
           socket,
           %{text_search: student_name},
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

  defp route_for(socket, new_params, :quiz_scores) do
    Routes.live_path(
      socket,
      OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
      socket.assigns.section_slug,
      :quiz_scores,
      update_params(socket.assigns.params, new_params)
    )
  end
end
