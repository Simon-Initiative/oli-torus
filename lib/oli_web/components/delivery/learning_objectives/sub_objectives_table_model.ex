defmodule OliWeb.Delivery.LearningObjectives.SubObjectivesTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.Chip

  @proficiency_labels ["Not enough data", "Low", "Medium", "High"]

  def new(sub_objectives) do
    column_specs = [
      %ColumnSpec{
        name: :sub_objective,
        label: "Sub-objective",
        render_fn: &custom_render/3,
        sortable: true,
        th_class: "w-1/2"
      },
      %ColumnSpec{
        name: :student_proficiency,
        label: "Student Proficiency",
        render_fn: &custom_render/3,
        sortable: true
      },
      %ColumnSpec{
        name: :proficiency_distribution,
        label: "Proficiency Distribution",
        render_fn: &custom_render/3,
        sortable: false
      },
      %ColumnSpec{
        name: :related_activities,
        label: "Related Activities",
        render_fn: &custom_render/3,
        sortable: false
      }
    ]

    SortableTableModel.new(
      rows: sub_objectives,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{}
    )
  end

  # SUB-OBJECTIVE NAME
  defp custom_render(_assigns, sub_objective, %ColumnSpec{name: :sub_objective}) do
    sub_objective.title
  end

  # STUDENT PROFICIENCY CHIP
  defp custom_render(assigns, sub_objective, %ColumnSpec{name: :student_proficiency}) do
    student_proficiency = sub_objective.student_proficiency || "Not enough data"

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

  # PROFICIENCY DISTRIBUTION CHART
  defp custom_render(assigns, sub_objective, %ColumnSpec{name: :proficiency_distribution}) do
    proficiency_distribution =
      sub_objective.proficiency_distribution ||
        %{
          "Not enough data" => 0,
          "Low" => 0,
          "Medium" => 0,
          "High" => 0
        }

    assigns =
      assigns
      |> Map.put(:sub_objective_id, sub_objective.id)
      |> Map.put(:proficiency_distribution, proficiency_distribution)

    ~H"""
    <div class="group flex relative">
      {render_proficiency_chart(@sub_objective_id, @proficiency_distribution)}
      <div class="-translate-y-[calc(100%-90px)] absolute left-1/2 -translate-x-1/2 bg-black text-white text-sm px-4 py-2 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity shadow-lg whitespace-nowrap inline-block z-50">
        <%= for {label, value} <- calc_percentages(@proficiency_distribution) do %>
          <p>{label}: {value}%</p>
        <% end %>
      </div>
    </div>
    """
  end

  # RELATED ACTIVITIES COUNT
  defp custom_render(assigns, sub_objective, %ColumnSpec{name: :related_activities}) do
    activities_count = sub_objective.activities_count || 0

    assigns = Map.put(assigns, :activities_count, activities_count)

    ~H"""
    <span class="text-Text-text-high">{@activities_count}</span>
    """
  end

  # RENDER PROFICIENCY CHART (same as main table but for sub-objectives)
  defp render_proficiency_chart(sub_objective_id, data) do
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
      id: "proficiency-chart-sub-objective-#{sub_objective_id}"
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
