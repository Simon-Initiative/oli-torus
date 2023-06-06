defmodule OliWeb.Delivery.LearningObjectives.ObjectivesTableModel do
  use Surface.LiveComponent

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def render(assigns) do
    ~F"""
      <div>nothing</div>
    """
  end

  def new(objectives) do
    column_specs = [
      %ColumnSpec{
        name: :objective,
        label: "LEARNING OBJECTIVE",
        render_fn: &__MODULE__.custom_render/3,
        th_class: "pl-10 instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :subobjective,
        label: "SUB LEARNING OBJ.",
        render_fn: &__MODULE__.custom_render/3,
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :student_proficiency_obj,
        label: "STUDENT PROFICIENCY OBJ.",
        th_class: "instructor_dashboard_th"
      },
      %ColumnSpec{
        name: :student_proficiency_subobj,
        label: "STUDENT PROFICIENCY (SUB OBJ.)",
        th_class: "instructor_dashboard_th"
      }
    ]

    SortableTableModel.new(
      rows: objectives,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id]
    )
  end

  def custom_render(
        assigns,
        %{objective: objective, student_proficiency: student_proficiency} = _objectives,
        %ColumnSpec{
          name: :objective
        }
      ) do
    ~F"""
      <div class="flex items-center ml-8 gap-x-4" data-proficiency-check={if student_proficiency == "Low", do: "false", else: "true"}>
        <span class={"flex flex-shrink-0 rounded-full w-2 h-2 #{if student_proficiency == "Low", do: "bg-red-600", else: "bg-gray-500"}"}></span>
        <span>{objective}</span>
      </div>
    """
  end

  def custom_render(assigns, %{objective: objective} = _objectives, %ColumnSpec{
        name: :objective
      }) do
    ~F"""
      <div class="flex items-center ml-8 gap-x-4">
        <span></span>
        <span>{objective}</span>
      </div>
    """
  end

  def custom_render(assigns, %{subobjective: subobjective} = _objectives, %ColumnSpec{
        name: :subobjective
      }) do
    ~F"""
      <div>{if is_nil(subobjective), do: "-", else: subobjective}</div>
    """
  end
end
