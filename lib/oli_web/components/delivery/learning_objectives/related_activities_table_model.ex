defmodule OliWeb.Components.Delivery.LearningObjectives.RelatedActivitiesTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(activities) do
    column_specs = [
      %ColumnSpec{
        name: :question_stem,
        label: "Question Stem",
        render_fn: &custom_render/3,
        th_class: "w-1/2",
        td_class: "pr-4"
      },
      %ColumnSpec{
        name: :attempts,
        label: "Attempts",
        render_fn: &custom_render/3,
        th_class: "w-1/4 text-center",
        td_class: "text-center"
      },
      %ColumnSpec{
        name: :percent_correct,
        label: "% Correct",
        render_fn: &custom_render/3,
        th_class: "w-1/4 text-center",
        td_class: "text-center"
      }
    ]

    SortableTableModel.new(
      rows: activities,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:resource_id]
    )
  end

  # QUESTION STEM
  defp custom_render(assigns, activity, %ColumnSpec{name: :question_stem}) do
    assigns =
      Map.merge(assigns, %{
        question_stem: activity.question_stem || "No question stem available",
        activity_title: activity.title || "Untitled Activity"
      })

    ~H"""
    <div class="flex flex-col text-Text-text-high">
      <span class="font-bold text-sm leading-4 text-Text-text-high mb-1">
        {@activity_title}
      </span>
      <span
        class="text-base font-normal leading-6 text-Text-text-medium"
        title={@question_stem}
      >
        {@question_stem}
      </span>
    </div>
    """
  end

  # ATTEMPTS
  defp custom_render(assigns, activity, %ColumnSpec{name: :attempts}) do
    attempts_count = activity.attempts || 0

    assigns = Map.merge(assigns, %{attempts_count: attempts_count})

    ~H"""
    <div class="text-left">
      <span class="Text-text-high text-sm font-bold">
        {format_number(@attempts_count)}
      </span>
    </div>
    """
  end

  # PERCENT CORRECT
  defp custom_render(assigns, activity, %ColumnSpec{name: :percent_correct}) do
    percent_correct = activity.percent_correct || 0

    text_color =
      if percent_correct <= 80, do: "text-Text-text-danger", else: "text-Text-text-high"

    assigns =
      Map.merge(assigns, %{
        text_color: text_color,
        formatted_percent: format_percent(percent_correct)
      })

    ~H"""
    <div class="text-left">
      <span class={"text-sm font-bold #{@text_color}"}>
        {@formatted_percent}
      </span>
    </div>
    """
  end

  # Helper functions
  defp format_number(num) when is_integer(num), do: Integer.to_string(num)
  defp format_number(num) when is_float(num), do: :erlang.float_to_binary(num, decimals: 0)
  defp format_number(_), do: "0"

  defp format_percent(percent) when is_number(percent) do
    formatted =
      if is_float(percent) do
        :erlang.float_to_binary(percent, decimals: 1)
      else
        Integer.to_string(percent)
      end

    "#{formatted}%"
  end

  defp format_percent(_), do: "0%"
end
