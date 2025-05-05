defmodule OliWeb.Delivery.LearningObjectives.ObjectivesTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  @proficiency_labels ["Not enough data", "Low", "Medium", "High"]

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(objectives, :instructor_dashboard) do
    column_specs = [
      %ColumnSpec{
        name: :objective,
        label: "LEARNING OBJECTIVE",
        render_fn: &custom_render/3,
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
        sortable: false,
        render_fn: &custom_render/3
      }
    ]

    SortableTableModel.new(
      rows: objectives,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id]
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
      id_field: [:id]
    )
  end

  defp custom_render(
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

  defp custom_render(assigns, %{objective: objective} = _objectives, %ColumnSpec{
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

  defp custom_render(assigns, %{subobjective: subobjective} = _objectives, %ColumnSpec{
         name: :subobjective
       }) do
    assigns = Map.merge(assigns, %{subobjective: subobjective})

    ~H"""
    <div><%= if is_nil(@subobjective), do: "-", else: @subobjective %></div>
    """
  end

  defp custom_render(
         assigns,
         %{
           resource_id: objective_id,
           student_proficiency_obj_dist: student_proficiency_obj_dist
         },
         %ColumnSpec{
           name: :student_proficiency_distribution
         }
       ) do
    assigns =
      Map.merge(assigns, %{
        objective_id: objective_id,
        proficiency_distribution: student_proficiency_obj_dist
      })

    ~H"""
    <div class="group flex relative">
      <%= render_proficiency_data_chart(@objective_id, @proficiency_distribution) %>
      <div class="-translate-y-[calc(100%-90px)] absolute left-1/2 -translate-x-1/2 bg-black text-white text-sm px-4 py-2 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity shadow-lg whitespace-nowrap inline-block z-50">
        <%= for {label, value} <- calc_percentages(@proficiency_distribution) do %>
          <p><%= label %>: <%= value %>%</p>
        <% end %>
      </div>
    </div>
    """
  end

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
