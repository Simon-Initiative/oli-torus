defmodule OliWeb.Delivery.InstructorDashboard.StudentsLive do
  # use OliWeb, :live_view
  use Surface.LiveView

  alias OliWeb.Components.Delivery.InstructorDashboard
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Delivery.Sections.EnrollmentBrowseOptions
  alias OliWeb.Delivery.Sections.EnrollmentsTableModel
  alias Oli.Delivery.Sections
  alias OliWeb.Common.Params
  alias OliWeb.Common.Table.SortableTableModel
  alias Oli.Delivery.Metrics

  @limit 25
  @default_options %EnrollmentBrowseOptions{
    is_student: true,
    is_instructor: false,
    text_search: nil
  }
  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{total_count: total_count, table_model: table_model} =
      student_assigns(socket.assigns.section, socket.assigns.context)

    {:ok,
     assign(socket,
       total_count: total_count,
       table_model: table_model,
       options: @default_options
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = Params.get_int_param(params, "offset", 0)
    limit = Params.get_int_param(params, "limit", @limit)
    container_id = Params.get_param(params, "container_id", nil)

    options = %EnrollmentBrowseOptions{
      text_search: Params.get_param(params, "text_search", ""),
      is_student: true,
      is_instructor: false
    }

    enrollments =
      Sections.browse_enrollments(
        socket.assigns.section,
        %Paging{offset: offset, limit: limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )
      |> add_students_progress(socket.assigns.section.id, container_id)

    table_model = Map.put(table_model, :rows, enrollments)
    total_count = determine_total(enrollments)

    {:noreply,
     assign(socket,
       offset: offset,
       limit: limit,
       table_model: table_model,
       total_count: total_count,
       options: options,
       active_tab: :students
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <InstructorDashboard.main_layout {assigns}>
         <InstructorDashboard.tabs active_tab={@active_tab} section_slug={@section_slug} preview_mode={@preview_mode} />

    <.live_component
        id="students_table"
        module={OliWeb.Components.Delivery.Students}
        limit={@limit}
        filter={""}
        offset={@offset}
        count={@total_count}
        students_table_model={@table_model}
         />
      </InstructorDashboard.main_layout>
    """
  end

  defp student_assigns(section, context, container_id \\ nil) do
    enrollments =
      Sections.browse_enrollments(
        section,
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :name},
        @default_options
      )
      |> add_students_progress(section.id, container_id)

    {:ok, table_model} = EnrollmentsTableModel.new(enrollments, section, context)

    %{total_count: determine_total(enrollments), table_model: table_model}
  end

  defp add_students_progress(users, section_id, container_id) do
    users
    |> Enum.map(fn user ->
      Map.merge(user, %{progress: Metrics.progress_for(section_id, user.id, container_id)})
    end)
  end

  defp determine_total(projects) do
    case(projects) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end
end
