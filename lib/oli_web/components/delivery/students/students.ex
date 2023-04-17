defmodule OliWeb.Components.Delivery.Students do
  use Surface.LiveComponent

  alias Phoenix.LiveView.JS

  alias OliWeb.Common.{PagedTable, SearchInput}
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.EnrollmentBrowseOptions
  alias OliWeb.Delivery.Sections.EnrollmentsTableModel
  alias Oli.Delivery.Sections
  alias OliWeb.Common.Params
  alias Oli.Delivery.Metrics
  alias OliWeb.Router.Helpers, as: Routes

  prop params, :map, required: true
  prop total_count, :number, required: true
  prop table_model, :struct, required: true

  @default_params %{
    offset: 0,
    limit: 25,
    container_id: nil,
    page_id: nil,
    sort_order: :asc,
    sort_by: :name,
    text_search: nil
  }

  def update(%{params: params, section: section, context: context} = _assigns, socket) do
    params = decode_params(params)

    enrollments =
      case params.page_id do
        nil ->
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
          |> add_students_progress(section.id, params.container_id)

        page_id ->
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
          |> add_students_progress_for_page(section.id, page_id)
      end

    {:ok, table_model} = EnrollmentsTableModel.new(enrollments, section, context)

    table_model =
      Map.merge(table_model, %{
        rows: enrollments,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec -> col_spec.name == params.sort_by end)
      })

    {:ok,
     assign(socket,
       total_count: determine_total(enrollments),
       table_model: table_model,
       params: params,
       section_slug: section.slug
     )}
  end

  def render(assigns) do
    ~F"""
    <div class="mx-10 mb-10 bg-white shadow-sm">
      <div class="flex flex-col sm:flex-row sm:items-center pr-6 bg-white">
        <h4 class="pl-9 torus-h4 mr-auto">Students</h4>
        <form for="search" phx-target={@myself} phx-change="search_student" class="pb-6 ml-9 sm:pb-0">
          <SearchInput.render id="students_search_input" name="student_name" text={@params.text_search} />
        </form>
      </div>

      <PagedTable
        table_model={@table_model}
        total_count={@total_count}
        offset={@params.offset}
        limit={@params.limit}
        render_top_info={false}
        additional_table_class="instructor_dashboard_table"
        sort={JS.push("paged_table_sort", target: @myself)}
        page_change={JS.push("paged_table_page_change", target: @myself)}
      />
    </div>
    """
  end

  def handle_event("search_student", %{"student_name" => student_name}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           :students,
           update_params(socket.assigns.params, %{text_search: student_name})
         )
     )}
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           :students,
           update_params(socket.assigns.params, %{limit: limit, offset: offset})
         )
     )}
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by} = _params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           :students,
           update_params(socket.assigns.params, %{sort_by: String.to_existing_atom(sort_by)})
         )
     )}
  end

  defp decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      container_id: Params.get_int_param(params, "container_id", @default_params.container_id),
      page_id: Params.get_int_param(params, "page_id", @default_params.page_id),
      sort_order:
        Params.get_atom_param(params, "sort_order", [:asc, :desc], @default_params.sort_order),
      # we currently only support sorting by name since the other metrics have not yet been created
      sort_by: Params.get_atom_param(params, "sort_by", [:name], @default_params.sort_by),
      text_search: Params.get_param(params, "text_search", @default_params.text_search)
    }
  end

  defp add_students_progress(users, section_id, container_id) do
    users_progress = Metrics.progress_for(section_id, Enum.map(users, & &1.id), container_id)

    Enum.map(users, fn user ->
      Map.merge(user, %{progress: Map.get(users_progress, user.id)})
    end)
  end

  defp add_students_progress_for_page(users, section_id, page_id) do
    users_progress = Metrics.progress_for_page(section_id, Enum.map(users, & &1.id), page_id)

    Enum.map(users, fn user ->
      Map.merge(user, %{progress: Map.get(users_progress, user.id)})
    end)
  end

  defp determine_total(students) do
    case students do
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
    # there is no need to add a param to the url if its value is equal to the default one
    Map.filter(params, fn {key, value} ->
      @default_params[key] != value
    end)
  end
end
