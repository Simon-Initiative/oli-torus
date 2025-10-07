defmodule OliWeb.Delivery.LearningObjectives.StudentProficiencyTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents
  alias Phoenix.LiveView.JS

  def new(student_data, opts \\ []) do
    sort_by_spec = Keyword.get(opts, :sort_by_spec)
    sort_order = Keyword.get(opts, :sort_order)
    selected_students = Keyword.get(opts, :selected_students, [])
    target = Keyword.get(opts, :target)

    column_specs = [
      %ColumnSpec{
        name: :selection,
        label: render_select_all_header(student_data, selected_students, target),
        render_fn: &__MODULE__.render_selection_column/3,
        sortable: false,
        th_class: "w-4"
      },
      %ColumnSpec{
        name: :student_name,
        label: "Student Name",
        render_fn: &custom_render/3,
        sortable: true,
        th_class: "w-1/2 !border-b-0"
      },
      %ColumnSpec{
        name: :activities_attempted,
        label:
          HTMLComponents.render_label(%{
            title: "Activities Attempted",
            info_tooltip:
              "The number of activities linked to this learning objective that the student has tried at least once, compared to the total tied to this learning objective."
          }),
        render_fn: &custom_render/3,
        th_class: "flex items-center gap-x-2 !border-b-0",
        sortable: true
      }
    ]

    data = %{
      selected_students: selected_students,
      target: target
    }

    if sort_by_spec && sort_order do
      SortableTableModel.new(
        rows: student_data,
        column_specs: column_specs,
        event_suffix: "",
        id_field: [:student_id],
        sort_by_spec: sort_by_spec,
        sort_order: sort_order,
        data: data
      )
    else
      SortableTableModel.new(
        rows: student_data,
        column_specs: column_specs,
        event_suffix: "",
        id_field: [:student_id],
        data: data
      )
    end
  end

  def custom_render(_assigns, student, %ColumnSpec{name: :student_name}) do
    student.student_name
  end

  def custom_render(_assigns, student, %ColumnSpec{name: :activities_attempted}) do
    activities_attempted = Map.get(student, :activities_attempted_count, 0)
    total_activities = Map.get(student, :total_related_activities, 0)
    "#{activities_attempted} out of #{total_activities}"
  end

  def render_select_all_header(students, selected_students, target) do
    all_student_ids = Enum.map(students, & &1.student_id)

    all_selected =
      length(selected_students) > 0 && Enum.all?(all_student_ids, &(&1 in selected_students))

    assigns = %{
      all_selected: all_selected,
      target: target,
      has_students: length(students) > 0
    }

    ~H"""
    <div class="flex items-center justify-center">
      <input
        :if={@has_students}
        type="checkbox"
        checked={@all_selected}
        class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
        phx-click="select_all_students"
        phx-target={@target}
      />
    </div>
    """
  end

  def render_selection_column(assigns, student, _) do
    selected_students = Map.get(assigns, :selected_students, [])
    is_selected = student.student_id in selected_students

    assigns = Map.merge(assigns, %{is_selected: is_selected, student_id: student.student_id})

    ~H"""
    <div class="flex items-center justify-center">
      <input
        type="checkbox"
        checked={@is_selected}
        class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
        phx-click={JS.push("paged_table_selection_change", value: %{id: @student_id})}
        phx-target={@target}
      />
    </div>
    """
  end
end
