defmodule OliWeb.Components.Delivery.Students do
  use Surface.LiveComponent

  alias Phoenix.LiveView.JS

  alias OliWeb.Common.{PagedTable, SearchInput, Params, Utils}
  alias OliWeb.Delivery.Sections.EnrollmentsTableModel
  alias OliWeb.Router.Helpers, as: Routes

  prop(ctx, :struct, required: true)
  prop(title, :string, default: "Students")
  prop(tab_name, :atom, default: :students)
  prop(section_slug, :string, default: nil)
  prop(params, :map, required: true)
  prop(total_count, :number, required: true)
  prop(table_model, :struct, required: true)
  prop(dropdown_options, :list, required: true)
  prop(show_progress_csv_download, :boolean, default: false)
  prop(view, :atom)

  @default_params %{
    offset: 0,
    limit: 25,
    container_id: nil,
    section_slug: nil,
    page_id: nil,
    sort_order: :asc,
    sort_by: :name,
    text_search: nil,
    filter_by: :enrolled,
    payment_status: nil
  }

  def update(
        %{
          params: params,
          section: section,
          ctx: ctx,
          students: students,
          dropdown_options: dropdown_options
        } = assigns,
        socket
      ) do
    {total_count, rows} = apply_filters(students, params)

    {:ok, table_model} = EnrollmentsTableModel.new(rows, section, ctx)

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
       section_slug: section.slug,
       dropdown_options: dropdown_options,
       view: assigns[:view],
       title: Map.get(assigns, :title, "Students"),
       tab_name: Map.get(assigns, :tab_name, :students),
       show_progress_csv_download: Map.get(assigns, :show_progress_csv_download, false)
     )}
  end

  defp apply_filters(students, params) do
    students =
      students
      |> maybe_filter_by_text(params.text_search)
      |> maybe_filter_by_option(params.filter_by)
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

  defp maybe_filter_by_option(students, dropdown_value) do
    case dropdown_value do
      :enrolled ->
        Enum.filter(students, fn student ->
          student.enrollment_status == :enrolled and
            student.user_role_id == 4
        end)

      :suspended ->
        Enum.filter(students, fn student ->
          student.enrollment_status == :suspended and
            student.user_role_id == 4
        end)

      :paid ->
        Enum.filter(students, fn student ->
          student.enrollment_status == :enrolled and
            student.user_role_id == 4 and student.payment_status == :paid
        end)

      :not_paid ->
        Enum.filter(students, fn student ->
          student.enrollment_status == :enrolled and
            student.user_role_id == 4 and student.payment_status == :not_paid
        end)

      :grace_period ->
        Enum.filter(students, fn student ->
          student.enrollment_status == :enrolled and
            student.user_role_id == 4 and student.payment_status == :within_grace_period
        end)

      :non_students ->
        Enum.filter(students, fn student ->
          student.enrollment_status == :enrolled and
            student.user_role_id != 4
        end)

      _ ->
        students
    end
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

      :overall_proficiency ->
        Enum.sort_by(students, fn student -> student.overall_proficiency end, sort_order)

      :engagement ->
        Enum.sort_by(students, fn student -> student.engagement end, sort_order)

      :payment_status ->
        Enum.sort_by(students, fn student -> student.payment_status end, sort_order)

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
    <div class="flex flex-col gap-2 mx-10 mb-10">
      <div class="bg-white dark:bg-gray-800 shadow-sm">
        <div class="flex justify-between sm:items-end px-4 sm:px-9 py-4 instructor_dashboard_table">
          <div>
            <h4 class="torus-h4 !py-0 sm:mr-auto mb-2">{@title}</h4>
            {#if @show_progress_csv_download}
              <a class="self-end" href={Routes.metrics_path(OliWeb.Endpoint, :download_container_progress, @section_slug, @params.container_id)} download="progress.csv">
                <i class="fa-solid fa-download mr-1" />
                Download student progress CSV
              </a>
            {#else}
              <a href={Routes.delivery_path(OliWeb.Endpoint, :download_students_progress, @section_slug)} class="self-end"><i class="fa-solid fa-download ml-1" /> Download</a>
            {/if}
          </div>
          <div class="flex flex-col-reverse sm:flex-row gap-2 items-end">
            <div class="flex w-full sm:w-auto sm:items-end gap-2">
              <form class="w-full" phx-change="filter_by" phx-target={@myself}>
                <label class="cursor-pointer inline-flex flex-col gap-1 w-full">
                  <small class="torus-small uppercase">Filter by</small>
                  <select class="torus-select" name="filter">
                    {#for elem <- @dropdown_options}
                      <option selected={@params.filter_by == elem.value} value={elem.value}>{elem.label}</option>
                    {/for}
                  </select>
                </label>
              </form>
            </div>
            <form for="search" phx-target={@myself} phx-change="search_student" class="w-44">
              <SearchInput.render id="students_search_input" name="student_name" text={@params.text_search} />
            </form>
          </div>
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
           socket.assigns.view,
           socket.assigns.tab_name,
           update_params(socket.assigns.params, %{text_search: student_name, offset: 0})
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
           socket.assigns.view,
           socket.assigns.tab_name,
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
           socket.assigns.view,
           socket.assigns.tab_name,
           update_params(socket.assigns.params, %{sort_by: String.to_existing_atom(sort_by)})
         )
     )}
  end

  def handle_event("filter_by", %{"filter" => filter}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive,
           socket.assigns.section_slug,
           socket.assigns.view,
           socket.assigns.tab_name,
           update_params(socket.assigns.params, %{filter_by: String.to_existing_atom(filter)})
         )
     )}
  end

  def decode_params(params) do
    %{
      offset: Params.get_int_param(params, "offset", @default_params.offset),
      limit: Params.get_int_param(params, "limit", @default_params.limit),
      container_id: Params.get_int_param(params, "container_id", @default_params.container_id),
      section_slug: Params.get_int_param(params, "section_slug", @default_params.section_slug),
      page_id: Params.get_int_param(params, "page_id", @default_params.page_id),
      sort_order:
        Params.get_atom_param(params, "sort_order", [:asc, :desc], @default_params.sort_order),
      sort_by:
        Params.get_atom_param(
          params,
          "sort_by",
          [
            :name,
            :last_interaction,
            :progress,
            :overall_proficiency,
            :engagement,
            :payment_status
          ],
          @default_params.sort_by
        ),
      text_search: Params.get_param(params, "text_search", @default_params.text_search),
      filter_by:
        Params.get_atom_param(
          params,
          "filter_by",
          [:enrolled, :suspended, :paid, :not_paid, :grace_period, :non_students],
          @default_params.filter_by
        )
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
