defmodule OliWeb.Components.Delivery.LearningObjectives.SubObjectivesList do
  use OliWeb, :live_component

  def update(assigns, socket) do
    # Create the sub-objectives table model and add computed assigns
    {:ok, sub_objectives_table_model} =
      OliWeb.Delivery.LearningObjectives.SubObjectivesTableModel.new(
        assigns.sub_objectives_data,
        assigns.parent_unique_id
      )

    socket =
      socket
      |> assign(assigns)
      |> assign(:sub_objectives_table_model, sub_objectives_table_model)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="w-full">
      <OliWeb.Common.SortableTable.Table.render
        model={@sub_objectives_table_model}
        sort={JS.push("sub_objectives_sort", target: @myself)}
        additional_row_class="bg-Table-table-row-1"
      />
    </div>
    """
  end

  def handle_event("sub_objectives_sort", %{"sort_by" => sort_by}, socket) do
    current_model = socket.assigns.sub_objectives_table_model

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
    sorted_rows = sort_sub_objectives(socket.assigns.sub_objectives_data, sort_by, sort_order)

    # Create new table model with sorted data
    {:ok, new_table_model} =
      OliWeb.Delivery.LearningObjectives.SubObjectivesTableModel.new(
        sorted_rows,
        socket.assigns[:parent_unique_id]
      )

    updated_table_model =
      Map.merge(new_table_model, %{
        sort_order: sort_order,
        sort_by_spec: sort_by_spec
      })

    {:noreply,
     socket
     |> assign(:sub_objectives_table_model, updated_table_model)
     |> assign(:sub_objectives_data, sorted_rows)}
  end

  defp sort_sub_objectives(sub_objectives_data, sort_by, sort_order) do
    sorted =
      case sort_by do
        "sub_objective" ->
          Enum.sort_by(sub_objectives_data, &(&1.title || ""))

        "student_proficiency" ->
          # Define proficiency order for sorting
          proficiency_order = %{
            "High" => 4,
            "Medium" => 3,
            "Low" => 2,
            "Not enough data" => 1
          }

          Enum.sort_by(sub_objectives_data, fn obj ->
            Map.get(proficiency_order, obj.student_proficiency || "Not enough data", 1)
          end)

        _ ->
          sub_objectives_data
      end

    case sort_order do
      :desc -> Enum.reverse(sorted)
      :asc -> sorted
    end
  end
end
