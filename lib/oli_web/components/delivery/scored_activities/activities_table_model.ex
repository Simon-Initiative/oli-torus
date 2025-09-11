defmodule OliWeb.Delivery.ScoredActivities.ActivitiesTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Icons

  def new(activities) do
    column_specs = [
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
      id_field: [:resource_id]
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
