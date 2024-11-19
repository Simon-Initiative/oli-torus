defmodule OliWeb.Delivery.LearningObjectives.ObjectivesTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(objectives) do
    column_specs = [
      %ColumnSpec{
        name: :objective,
        label: "LEARNING OBJECTIVE",
        render_fn: &__MODULE__.custom_render/3,
        th_class: "pl-10"
      },
      %ColumnSpec{
        name: :student_proficiency_obj,
        label: "STUDENT PROFICIENCY",
        tooltip:
          "For all students, or one specific student, proficiency for a learning objective will be calculated off the percentage of correct answers for first part attempts within first activity attempts - for those parts that have that learning objective or any of its sub-objectives attached to it."
      },
      %ColumnSpec{
        name: :student_proficiency_distribution,
        label: "PROFICIENCY DISTRIBUTION",
        render_fn: &__MODULE__.custom_render/3
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
    assigns =
      Map.merge(assigns, %{objective: objective, student_proficiency: student_proficiency})

    ~H"""
    <div
      class="flex items-center ml-8 gap-x-4"
      data-proficiency-check={if @student_proficiency == "Low", do: "false", else: "true"}
    >
      <span class={"flex flex-shrink-0 rounded-full w-2 h-2 #{if @student_proficiency == "Low", do: "bg-red-600", else: "bg-gray-500"}"}>
      </span>
      <span><%= @objective %></span>
    </div>
    """
  end

  def custom_render(assigns, %{objective: objective} = _objectives, %ColumnSpec{
        name: :objective
      }) do
    assigns = Map.merge(assigns, %{objective: objective})

    ~H"""
    <div class="flex items-center ml-8 gap-x-4">
      <span></span>
      <span><%= @objective %></span>
    </div>
    """
  end

  def custom_render(
        assigns,
        %{resource_id: objective_id, proficiency_distribution: proficiency_distribution},
        %ColumnSpec{
          name: :student_proficiency_distribution
        }
      ) do
    assigns =
      Map.merge(assigns, %{
        objective_id: objective_id,
        proficiency_distribution: proficiency_distribution
      })

    ~H"""
    <div><%= render_proficiency_data_chart(@objective_id, @proficiency_distribution) %></div>
    """
  end

  defp render_proficiency_data_chart(objective_id, data) do
    # TODO
    data = [
      %{type: "Not enough data", perc: 8},
      %{type: "Low", perc: 25},
      %{type: "Medium", perc: 21},
      %{type: "High", perc: 46}
    ]

    spec = %{
      mark: "bar",
      data: %{values: data},
      encoding: %{
        x: %{aggregate: "sum", field: "perc"},
        color: %{field: "type"}
      },
      config: %{
        axis: %{
          domain: false,
          ticks: false,
          labels: false,
          title: false
        },
        legend: %{disable: true}
      }
    }

    OliWeb.Common.React.component(
      %{is_liveview: true},
      "Components.VegaLiteRenderer",
      %{spec: spec},
      id: "proficiency-data-bar-chart-for-objective-#{objective_id}"
    )
  end
end
