defmodule OliWeb.Delivery.LearningObjectives.ObjectivesTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  @proficiency_labels ["Not enough data", "Low", "Medium", "High"]

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
        %{section_id: section_id, resource_id: objective_id},
        %ColumnSpec{
          name: :student_proficiency_distribution
        }
      ) do
    proficiency_distribution =
      section_id
      |> Oli.Delivery.Metrics.proficiency_per_student_for_objective(objective_id)
      |> Enum.frequencies_by(fn {_student_id, proficiency} -> proficiency end)

    assigns =
      Map.merge(assigns, %{
        objective_id: objective_id,
        proficiency_distribution: proficiency_distribution
      })

    ~H"""
    <div class="group flex relative">
      <%= render_proficiency_data_chart(@objective_id, @proficiency_distribution) %>
      <div class="absolute left-1/2 -translate-x-1/2 -translate-y-full bg-black text-white text-sm px-4 py-2 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity shadow-lg whitespace-nowrap inline-block">
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
        color: %{field: "proficiency"}
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

  defp calc_percentages(data) do
    total = data |> Map.values() |> Enum.sum()

    @proficiency_labels
    |> Enum.map(fn label ->
      {label, round(Map.get(data, label, 0) / total * 100)}
    end)
    |> Map.new()
  end
end
