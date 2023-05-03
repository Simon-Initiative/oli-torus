defmodule OliWeb.Components.Delivery.Students do
  use Surface.LiveComponent

  alias Phoenix.LiveView.JS

  alias OliWeb.Common.{PagedTable, SearchInput}
  alias OliWeb.Delivery.Sections.EnrollmentsTableModel
  alias OliWeb.Common.Params
  alias OliWeb.Common.Utils
  alias OliWeb.Router.Helpers, as: Routes

  prop(params, :map, required: true)
  prop(total_count, :number, required: true)
  prop(table_model, :struct, required: true)

  @default_params %{
    offset: 0,
    limit: 25,
    container_id: nil,
    page_id: nil,
    sort_order: :asc,
    sort_by: :name,
    text_search: nil
  }

  def update(
        %{params: params, section: section, context: context, students: students} = _assigns,
        socket
      ) do
    {total_count, rows} = apply_filters(students, params)

    {:ok, table_model} = EnrollmentsTableModel.new(rows, section, context)

    table_model =
      Map.merge(table_model, %{
        rows: rows,
        sort_order: params.sort_order,
        sort_by_spec:
          Enum.find(table_model.column_specs, fn col_spec -> col_spec.name == params.sort_by end)
      })

    {:ok,
     assign(socket,
       total_count: total_count,
       table_model: table_model,
       params: params,
       section_slug: section.slug
     )}
  end

  defp apply_filters(students, params) do
    students =
      students
      |> maybe_filter_by_text(params.text_search)
      |> sort_by(params.sort_by, params.sort_order)

    {length(students), students |> Enum.drop(params.offset) |> Enum.take(params.limit)}
  end

  defp maybe_filter_by_text(students, nil), do: students
  defp maybe_filter_by_text(students, ""), do: students

  defp maybe_filter_by_text(students, text_search) do
    Enum.filter(students, fn student ->
      String.contains?(
        String.downcase(Utils.name(student.name, student.given_name, student.family_name)),
        String.downcase(text_search)
      )
    end)
  end

  defp sort_by(students, sort_by, sort_order) do
    case sort_by do
      :name ->
        Enum.sort_by(
          students,
          fn student -> Utils.name(student.name, student.given_name, student.family_name) end,
          sort_order
        )

      :last_interaction ->
        Enum.sort_by(students, fn student -> student.last_interaction end, sort_order)

      :progress ->
        Enum.sort_by(students, fn student -> student.progress end, sort_order)

      :overall_mastery ->
        Enum.sort_by(students, fn student -> student.overall_mastery end, sort_order)

      :engagement ->
        Enum.sort_by(students, fn student -> student.engagement end, sort_order)

      _ ->
        Enum.sort_by(
          students,
          fn student -> Utils.name(student.name, student.given_name, student.family_name) end,
          sort_order
        )
    end
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

  def decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      container_id: Params.get_int_param(params, "container_id", @default_params.container_id),
      page_id: Params.get_int_param(params, "page_id", @default_params.page_id),
      sort_order:
        Params.get_atom_param(params, "sort_order", [:asc, :desc], @default_params.sort_order),
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [:name, :last_interaction, :progress, :overall_mastery, :engagement],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search)
    }
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
