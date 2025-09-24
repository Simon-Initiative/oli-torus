defmodule OliWeb.Components.Delivery.LearningObjectives.StudentProficiencyList do
  use OliWeb, :live_component

  def update(assigns, socket) do
    filtered_student_data =
      assigns.student_proficiency
      |> Enum.filter(fn student ->
        student.proficiency_range == assigns.selected_proficiency_level
      end)

    # Create the student proficiency table model
    {:ok, student_table_model} =
      OliWeb.Delivery.LearningObjectives.StudentProficiencyTableModel.new(filtered_student_data)

    socket =
      socket
      |> assign(assigns)
      |> assign(:student_table_model, student_table_model)
      |> assign(:filtered_student_data, filtered_student_data)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="w-full">
      <!-- Header with proficiency level -->
      <div class="mb-4">
        <h4 class="text-base font-medium text-gray-900 dark:text-gray-100">
          Students with {capitalize_proficiency_level(@selected_proficiency_level)} Estimated Proficiency
        </h4>
      </div>
      
    <!-- Students table -->
      <OliWeb.Common.SortableTable.Table.render
        model={@student_table_model}
        sort={JS.push("student_proficiency_sort", target: @myself)}
        additional_row_class="bg-Table-table-row-1"
      />
    </div>
    """
  end

  def handle_event("student_proficiency_sort", %{"sort_by" => sort_by}, socket) do
    current_model = socket.assigns.student_table_model

    # Toggle sort order if clicking the same column
    sort_order =
      if current_model.sort_by_spec &&
           Atom.to_string(current_model.sort_by_spec.name) == sort_by do
        if current_model.sort_order == :asc, do: :desc, else: :asc
      else
        :asc
      end

    # Find the column spec for the clicked column
    sort_by_spec =
      Enum.find(current_model.column_specs, fn col_spec ->
        Atom.to_string(col_spec.name) == sort_by
      end)

    # Sort the rows based on the column
    sorted_rows = sort_students(socket.assigns.filtered_student_data, sort_by, sort_order)

    # Create new table model with sorted data
    {:ok, updated_table_model} =
      OliWeb.Delivery.LearningObjectives.StudentProficiencyTableModel.new(
        sorted_rows,
        sort_by_spec: sort_by_spec,
        sort_order: sort_order
      )

    {:noreply,
     socket
     |> assign(:student_table_model, updated_table_model)
     |> assign(:filtered_student_data, sorted_rows)}
  end

  defp sort_students(students, sort_by, sort_order) do
    sorted =
      case sort_by do
        "student_name" ->
          Enum.sort_by(students, &(&1.student_name || ""))

        "activities_attempted" ->
          # For now, all students have the same placeholder value, so no actual sorting needed
          students

        _ ->
          students
      end

    case sort_order do
      :desc -> Enum.reverse(sorted)
      :asc -> sorted
    end
  end

  defp capitalize_proficiency_level(proficiency_level) do
    proficiency_level
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
