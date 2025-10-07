defmodule OliWeb.Delivery.LearningObjectives.ObjectivesTableModel do
  use Phoenix.Component

  import OliWeb.Components.Common

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.Chip
  alias OliWeb.Delivery.InstructorDashboard.HTMLComponents
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  @proficiency_labels ["Not enough data", "Low", "Medium", "High"]
  @student_proficiency_tooltip_text "Proficiency is based on the percentage of correct answers on first attempts for activities linked to this learning objective or its sub-objectives."

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
        label:
          HTMLComponents.render_label(%{
            title: "Student Proficiency",
            info_tooltip: @student_proficiency_tooltip_text
          }),
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :student_proficiency_distribution,
        label: "Proficiency Distribution",
        sortable: false,
        render_fn: &custom_render/3
      },
      %ColumnSpec{
        name: :related_activities_count,
        label: "Related Activities",
        render_fn: &custom_render/3,
        tooltip: "Number of activities that have this learning objective attached"
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
        tooltip: @student_proficiency_tooltip_text
      },
      %ColumnSpec{
        name: :student_proficiency_subobj,
        label: "STUDENT PROFICIENCY (SUB OBJ.)",
        tooltip: @student_proficiency_tooltip_text
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
    <div class="group relative flex">
      {render_proficiency_data_chart(@objective_id, @proficiency_distribution)}
      <dialog class="absolute top-[calc(100%+5px)] left-1/2 -translate-x-1/2 p-0 m-0 w-60 min-h-[100px] rounded-md border border-Border-border-default bg-white dark:bg-gray-900 px-4 py-2 text-left text-sm font-normal leading-normal text-Text-text-high shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] hidden flex-col gap-1 group-hover:flex z-50">
        <%= for {label, value} <- calc_percentages(@proficiency_distribution) do %>
          <div class="w-full text-left">
            <span class="font-medium">{label}</span>: {value}%
          </div>
        <% end %>
      </dialog>
    </div>
    """
  end

  # RELATED ACTIVITIES COUNT
  defp custom_render(assigns, objective, %ColumnSpec{name: :related_activities_count}) do
    count = Map.get(objective, :related_activities_count, 0)
    section_slug = Map.get(assigns, :section_slug)

    # Build URL with current page parameters as "back_params"
    base_url =
      "/sections/#{section_slug}/instructor_dashboard/insights/learning_objectives/related_activities/#{objective.resource_id}"

    # Get current page parameters from assigns (passed by parent LiveView)
    current_params = Map.get(assigns, :current_params, %{})

    full_url =
      if map_size(current_params) > 0 do
        # Encode the entire params map as a single "back_params" parameter
        encoded_params = current_params |> Jason.encode!() |> URI.encode()
        "#{base_url}?back_params=#{encoded_params}"
      else
        base_url
      end

    assigns =
      Map.merge(assigns, %{
        count: count,
        navigate_url: full_url
      })

    ~H"""
    <div class="text-center">
      <.link
        navigate={@navigate_url}
        class="text-Text-text-link"
        aria-label={~s(View #{@count} related activities)}
      >
        {@count}
      </.link>
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
