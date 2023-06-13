defmodule OliWeb.Delivery.ScoredActivities.AssessmentsTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.FormatDateTime

  def new(assessments, ctx) do
    column_specs = [
      %ColumnSpec{
        name: :title,
        label: "ASSESSMENT",
        render_fn: &__MODULE__.render_assessment_column/3,
        th_class: "pl-10"
      },
      %ColumnSpec{
        name: :due_date,
        label: "DUE DATE",
        render_fn: &__MODULE__.render_due_date_column/3
      },
      %ColumnSpec{
        name: :avg_score,
        label: "AVG SCORE",
        render_fn: &__MODULE__.render_avg_score_column/3
      },
      %ColumnSpec{
        name: :total_attempts,
        label: "TOTAL ATTEMPTS",
        render_fn: &__MODULE__.render_attempts_column/3
      },
      %ColumnSpec{
        name: :students_completion,
        label: "STUDENTS COMPLETION",
        render_fn: &__MODULE__.render_students_completion_column/3
      }
    ]

    SortableTableModel.new(
      rows: assessments,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx
      }
    )
  end

  def render_assessment_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{title: assessment.title, container_label: assessment.container_label})

    ~H"""
      <div class="pl-9 pr-4 flex flex-col">
        <%= if @container_label do %>
          <span class="text-gray-600 font-bold text-sm"><%= @container_label %></span>
        <% end %>
        <div class="text-base"><%= @title %></div>
      </div>
    """
  end

  def render_due_date_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        due_date: assessment.end_date,
        scheduling_type: assessment.scheduling_type
      })

    ~H"""
      <%= parse_due_date(@due_date, @ctx, @scheduling_type) %>
    """
  end

  def render_avg_score_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{avg_score: assessment.avg_score})

    ~H"""
      <div class={if @avg_score < 0.40, do: "text-red-600 font-bold"}><%= format_value(@avg_score) %></div>
    """
  end

  def render_attempts_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{total_attempts: assessment.total_attempts})

    ~H"""
      <%= @total_attempts || "-" %>
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
        <div class={if @students_completion < 0.40, do: "text-red-600 font-bold"}><%= format_value(@students_completion) %></div>
      <% else %>
        -
      <% end %>
    """
  end

  defp parse_due_date(datetime, ctx, :due_by) do
    datetime
    |> FormatDateTime.convert_datetime(ctx)
    |> Timex.format!("{Mshort}. {0D}, {YYYY} - {h12}:{m} {AM}")
  end

  defp parse_due_date(_datetime, _ctx, _scheduling_type), do: "No due date"

  defp format_value(nil), do: "-"
  defp format_value(value), do: "#{parse_percentage(value)}%"

  defp parse_percentage(value) do
    {value, _} =
      Float.round(value * 100)
      |> Float.to_string()
      |> Integer.parse()

    value
  end
end
