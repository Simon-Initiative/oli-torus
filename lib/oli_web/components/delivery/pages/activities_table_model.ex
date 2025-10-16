defmodule OliWeb.Delivery.Pages.ActivitiesTableModel do
  use Phoenix.Component

  import OliWeb.Components.Common

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Delivery.ActivityHelpers
  alias OliWeb.Icons
  alias Phoenix.LiveView.JS

  def new(activities) do
    column_specs = [
      %ColumnSpec{
        render_fn: &render_expanded/3,
        sortable: false,
        th_class: "w-4"
      },
      %ColumnSpec{
        name: :title,
        label: "QUESTION",
        render_fn: &__MODULE__.render_question_column/3,
        th_class: "pl-10",
        td_class: "pl-10"
      },
      %ColumnSpec{
        name: :learning_objectives,
        label: "LEARNING OBJECTIVES",
        render_fn: &__MODULE__.render_learning_objectives_column/3,
        sortable: false
      },
      %ColumnSpec{
        name: :avg_score,
        label: "% CORRECT",
        render_fn: &__MODULE__.render_avg_score_column/3
      },
      %ColumnSpec{
        name: :total_attempts,
        label: "ATTEMPTS",
        render_fn: &__MODULE__.render_attempts_column/3
      }
    ]

    SortableTableModel.new(
      rows: activities,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:resource_id],
      data: %{expandable_rows: true, view_type: :activities_instructor_dashboard},
    )
  end

  def render_question_column(assigns, %{content: content} = activity, _) do
    title =
      Map.get(content, "stem", %{"content" => []})
      |> Map.get("content", [%{"type" => "p", "children" => [%{"text" => "Unknown stem"}]}])
      |> best_effort_stem_extract()

    assigns =
      Map.merge(assigns, %{
        header: activity.title,
        title: title,
        resource_id: activity.resource_id,
        has_lti_activity: activity.has_lti_activity
      })

    ~H"""
    <%= if @has_lti_activity do %>
      <div
        id={"lti_title_#{@resource_id}"}
        phx-hook="GlobalTooltip"
        data-tooltip="<div>LTI 1.3 External Tool</div>"
        data-tooltip-align="left"
        class="flex items-center gap-2"
      >
        <Icons.plug />
        <.question_text header={@header} title={@title} />
      </div>
    <% else %>
      <.question_text header={@header} title={@title} />
    <% end %>
    """
  end

  defp render_expanded(assigns, assessment, _) do
    index = Map.get(assessment, :row_index, 0)

    assigns =
      Map.merge(assigns, %{
        id: "#{assessment.resource_id}_#{index}",
        target: assigns.model.data.target
      })

    ~H"""
    <.button
      id={"button_#{@id}"}
      class="flex !p-0"
      phx-click={
        JS.push("paged_table_selection_change", value: %{id: assessment.resource_id}, target: @target)
        |> JS.toggle(to: "#details-row_#{@id}")
        |> JS.toggle_class("rotate-180", to: "#button_#{@id} svg")
        |> JS.toggle_class("bg-Table-table-select", to: ~s(tr[data-row-id="row_#{@id}"]))
      }
    >
      <Icons.chevron_down class="fill-Text-text-high transition-transform duration-200" />
    </.button>
    """
  end

  # RENDER EXPANDED DETAILS FOR STRIPED TABLE
  def render_assessment_details(assigns, assessment) do
    selected_activities = assigns.model.data.selected_activities

    # Find the specific activity data for this assessment
    current_activity = Enum.find(selected_activities, &(&1.resource_id == assessment.resource_id))

    # Only show details if this specific activity is selected/expanded
    should_show_details = current_activity != nil

    assigns =
      Map.merge(assigns, %{
        id: assessment.resource_id,
        current_activity: current_activity,
        activity_types_map: assigns[:activity_types_map],
        should_show_details: should_show_details
      })

    ~H"""
    <%= if @should_show_details do %>
      <div class="p-6" id={"details-#{@id}"}>
        <div
          role="activity_title"
          class="bg-white dark:bg-gray-800 dark:text-white w-min whitespace-nowrap rounded-t-md block font-medium text-sm leading-tight uppercase border-x-1 border-t-1 border-b-0 border-gray-300 px-6 py-4"
        >
          Question details
        </div>
        <div
          class="bg-white dark:bg-gray-800 dark:text-white shadow-sm px-6 -mt-5"
          id={"activity_detail_#{@id}"}
          phx-hook="LoadSurveyScripts"
          phx-update="ignore"
        >
          <%= if Map.get(@current_activity, :preview_rendered) != nil do %>
            <ActivityHelpers.rendered_activity
              activity={@current_activity}
              activity_types_map={@activity_types_map}
            />
          <% else %>
            <p class="pt-9 pb-5">No attempt registered for this question</p>
          <% end %>
        </div>
        <div class="flex mt-2 mb-10 bg-white gap-x-20 dark:bg-gray-800 dark:text-white shadow-sm px-6 py-4">
          <ActivityHelpers.percentage_bar
            id={Integer.to_string(@current_activity.id) <> "_first_try_correct"}
            value={@current_activity.first_attempt_pct}
            label="First Try Correct"
          />
          <ActivityHelpers.percentage_bar
            id={Integer.to_string(@current_activity.id) <> "_eventually_correct"}
            value={@current_activity.all_attempt_pct}
            label="Eventually Correct"
          />
        </div>
      </div>
    <% else %>
      <div class="p-6 flex justify-center items-center">
        <span
          class="spinner-border spinner-border-sm h-8 w-8 text-Text-text-button"
          role="status"
          aria-hidden="true"
        >
        </span>
      </div>
    <% end %>
    """
  end

  defp question_text(assigns) do
    ~H"""
    <div class="flex flex-col">
      <span class="font-bold">{@header}:</span>
      <span class="text-ellipsis">{@title}</span>
    </div>
    """
  end

  def render_learning_objectives_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        objectives: assessment.objectives
      })

    ~H"""
    <ul class="flex flex-col space-y-2">
      <%= for objective <- @objectives do %>
        <li>{objective.title}</li>
      <% end %>
    </ul>
    """
  end

  def render_avg_score_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{avg_score: assessment.avg_score})

    ~H"""
    <div class={if @avg_score < 0.40, do: "text-red-600 font-bold"}>
      {format_value(@avg_score)}
    </div>
    """
  end

  def render_attempts_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{total_attempts: assessment.total_attempts})

    ~H"""
    {@total_attempts || "-"}
    """
  end

  def render_students_completion_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        students_completion: assessment.students_completion,
        avg_score: assessment.avg_score
      })

    ~H"""
    <%= if @avg_score != nil do %>
      <div class={if @students_completion < 0.40, do: "text-red-600 font-bold"}>
        {format_value(@students_completion)}
      </div>
    <% else %>
      -
    <% end %>
    """
  end

  defp format_value(nil), do: "-"
  defp format_value(value), do: "#{parse_percentage(value)}%"

  defp parse_percentage(value) do
    {value, _} =
      Float.round(value * 100)
      |> Float.to_string()
      |> Integer.parse()

    value
  end

  defp best_effort_stem_extract(%{"model" => items}), do: best_effort_stem_extract(items)
  defp best_effort_stem_extract([]), do: "[Empty]"
  defp best_effort_stem_extract([item | _]), do: extract(item)
  defp best_effort_stem_extract(_), do: "[Empty]"

  defp extract(%{"type" => "p", "children" => children}) do
    Enum.reduce(children, "", fn c, s ->
      s <> Map.get(c, "text", "")
    end)
  end

  defp extract(%{"text" => t}), do: t
  defp extract(%{"type" => t}), do: "[#{t}]"
  defp extract(_), do: "[Unknown]"
end
