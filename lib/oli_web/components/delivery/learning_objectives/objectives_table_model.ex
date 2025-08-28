defmodule OliWeb.Delivery.LearningObjectives.ObjectivesTableModel do
  use Phoenix.Component

  import OliWeb.Components.Common

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.Chip
  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  @proficiency_labels ["Not enough data", "Low", "Medium", "High"]

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(objectives, :instructor_dashboard) do
    column_specs = [
      %ColumnSpec{
        render_fn: &render_expanded/3,
        sortable: false,
        th_class: "w-4"
      },
      %ColumnSpec{
        name: :objective_instructor_dashboard,
        label: "Learning Objective",
        render_fn: &custom_render/3,
        th_class: "w-1/2",
        td_class: "pr-4"
      },
      %ColumnSpec{
        name: :student_proficiency_obj,
        label: HTMLComponents.render_proficiency_label(%{title: "Student Proficiency"}),
        render_fn: &custom_render/3,
        tooltip:
          "For all students, or one specific student, proficiency for a learning objective will be calculated off the percentage of correct answers for first part attempts within first activity attempts - for those parts that have that learning objective or any of its sub-objectives attached to it."
      },
      %ColumnSpec{
        name: :student_proficiency_distribution,
        label: "Proficiency Distribution",
        sortable: false,
        render_fn: &custom_render/3
      }
    ]

    SortableTableModel.new(
      rows: objectives,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:resource_id],
      data: %{expandable_rows: true, view_type: :objectives_instructor_dashboard}
    )
  end

  def new(objectives, _patch_url_type) do
    column_specs = [
      %ColumnSpec{
        name: :objective,
        label: "LEARNING OBJECTIVE",
        render_fn: &custom_render/3,
        th_class: "pl-10"
      },
      %ColumnSpec{
        name: :subobjective,
        label: "SUB LEARNING OBJ.",
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :student_proficiency_obj,
        label: "STUDENT PROFICIENCY OBJ.",
        tooltip:
          "For all students, or one specific student, proficiency for a learning objective will be calculated off the percentage of correct answers for first part attempts within first activity attempts - for those parts that have that learning objective or any of its sub-objectives attached to it."
      },
      %ColumnSpec{
        name: :student_proficiency_subobj,
        label: "STUDENT PROFICIENCY (SUB OBJ.)",
        tooltip:
          "For all students, or one specific student, proficiency for a learning objective will be calculated off the percentage of correct answers for first part attempts within first activity attempts - for those parts that have that learning objective or any of its sub-objectives attached to it."
      }
    ]

    SortableTableModel.new(
      rows: objectives,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:resource_id]
    )
  end

  # STUDENT PROFICIENCY
  defp custom_render(assigns, objectives, %ColumnSpec{name: :student_proficiency_obj}) do
    student_proficiency =
      case Map.get(objectives, :student_proficiency_subobj) do
        nil -> objectives.student_proficiency_obj
        _ -> objectives.student_proficiency_subobj
      end

    {bg_color, text_color} =
      case student_proficiency do
        "High" -> {"bg-Fill-Chip-Green", "text-Text-Chip-Green"}
        "Medium" -> {"bg-Fill-Accent-fill-accent-orange", "text-Text-Chip-Orange"}
        "Low" -> {"bg-Fill-fill-danger", "text-Text-text-danger"}
        _ -> {"bg-Fill-Chip-Gray", "text-Text-Chip-Gray"}
      end

    assigns =
      Map.merge(assigns, %{
        label: student_proficiency,
        bg_color: bg_color,
        text_color: text_color
      })

    ~H"""
    <Chip.render {assigns} />
    """
  end

  # OBJECTIVE
  defp custom_render(assigns, objective, %ColumnSpec{name: :objective}) do
    assigns =
      Map.merge(assigns, %{
        objective: objective.objective,
        student_proficiency: Map.get(objective, :student_proficiency)
      })

    ~H"""
    <div
      class="flex items-center gap-x-4"
      data-proficiency-check={if @student_proficiency == "Low", do: "false", else: "true"}
    >
      <span class={"flex flex-shrink-0 rounded-full w-2 h-2 #{if @student_proficiency == "Low", do: "bg-red-600", else: "bg-gray-500"}"}>
      </span>
      <span>{@objective}</span>
    </div>
    """
  end

  # OBJECTIVE INSTRUCTOR DASHBOARD
  defp custom_render(assigns, objective, %ColumnSpec{name: :objective_instructor_dashboard}) do
    objective =
      case Map.get(objective, :subobjective) do
        nil -> objective.objective
        subobjective -> subobjective
      end

    assigns = Map.merge(assigns, %{objective: objective})

    ~H"""
    <div class="flex items-center gap-x-4">
      <span class="text-Text-text-high">{@objective}</span>
    </div>
    """
  end

  # SUBOBJECTIVE
  defp custom_render(assigns, objectives, %ColumnSpec{name: :subobjective}) do
    assigns = Map.merge(assigns, %{subobjective: objectives[:subobjective]})

    ~H"""
    <div>{if is_nil(@subobjective), do: "-", else: @subobjective}</div>
    """
  end

  # STUDENT PROFICIENCY DISTRIBUTION
  defp custom_render(assigns, objective, %ColumnSpec{name: :student_proficiency_distribution}) do
    %{resource_id: objective_id, student_proficiency_obj_dist: student_proficiency_obj_dist} =
      objective

    proficiency_distribution =
      case Map.get(objective, :student_proficiency_subobj_dist) do
        nil -> student_proficiency_obj_dist
        student_proficiency_subobj_dist -> student_proficiency_subobj_dist
      end

    assigns =
      Map.merge(assigns, %{
        objective_id: objective_id,
        proficiency_distribution: proficiency_distribution
      })

    ~H"""
    <div class="group flex relative">
      {render_proficiency_data_chart(@objective_id, @proficiency_distribution)}
      <div class="-translate-y-[calc(100%-90px)] absolute left-1/2 -translate-x-1/2 bg-black text-white text-sm px-4 py-2 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity shadow-lg whitespace-nowrap inline-block z-50">
        <%= for {label, value} <- calc_percentages(@proficiency_distribution) do %>
          <p>{label}: {value}%</p>
        <% end %>
      </div>
    </div>
    """
  end

  # RENDER EXPANDED
  defp render_expanded(assigns, objective, _) do
    assigns = Map.merge(assigns, %{id: objective.unique_id})

    ~H"""
    <.button
      id={"button_#{@id}"}
      class="flex !p-0"
      phx-click={
        JS.toggle(to: "#details-#{@id}")
        |> JS.toggle_class("rotate-180", to: "#button_#{@id} svg")
        |> JS.toggle_class("bg-Table-table-select", to: ~s(tr[data-row-id="#{@id}"]))
      }
    >
      <Icons.chevron_down class="fill-Text-text-high transition-transform duration-200" />
    </.button>
    """
  end

  # RENDER PROFICIENCY DATA CHART
  defp render_proficiency_data_chart(objective_id, data) do
    data =
      @proficiency_labels
      |> Enum.map(fn label ->
        %{proficiency: label, count: Map.get(data, label, 0)}
      end)

    spec = %{
      mark: "bar",
      data: %{values: data},
      encoding: %{
        x: %{aggregate: "sum", field: "count"},
        color: %{
          field: "proficiency",
          scale: %{
            domain: ["Not enough data", "Low", "Medium", "High"],
            range: ["#C2C2C2", "#E6D4FA", "#B37CEA", "#7B19C1"]
          }
        }
      },
      config: %{
        axis: %{
          domain: false,
          ticks: false,
          labels: false,
          title: false
        },
        legend: %{disable: true},
        background: nil
      }
    }

    OliWeb.Common.React.component(
      %{is_liveview: true},
      "Components.VegaLiteRenderer",
      %{spec: spec},
      id: "proficiency-data-bar-chart-for-objective-#{objective_id}"
    )
  end

  # CALCULATE PERCENTAGES
  defp calc_percentages(data) do
    total = data |> Map.values() |> Enum.sum()

    perc = fn label ->
      if total == 0, do: 0, else: round(Map.get(data, label, 0) / total * 100)
    end

    @proficiency_labels
    |> Enum.map(fn label -> {label, perc.(label)} end)
    |> Map.new()
  end
end
