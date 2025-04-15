defmodule OliWeb.Delivery.PracticeActivities.PracticeAssessmentsTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(assessments, ctx, target) do
    column_specs = [
      %ColumnSpec{
        name: :order,
        label: "ORDER",
        render_fn: &__MODULE__.render_order_column/3,
        th_class: "pl-10"
      },
      %ColumnSpec{
        name: :title,
        label: "ASSESSMENT",
        render_fn: &__MODULE__.render_assessment_column/3,
        th_class: "pl-10"
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
        label: "STUDENTS PROGRESS",
        tooltip:
          "Progress is percent attempted of activities present on the page from the most recent page attempt. If there are no activities within the page, and if the student has visited that page, we count that as an attempt.",
        render_fn: &__MODULE__.render_students_completion_column/3
      }
    ]

    SortableTableModel.new(
      rows: assessments,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:resource_id],
      data: %{
        ctx: ctx,
        target: target
      }
    )
  end

  def render_order_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{order: assessment.order})

    ~H"""
    <div class="pl-9 pr-4 flex flex-col">
      <%= @order %>
    </div>
    """
  end

  def render_assessment_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        title: assessment.title,
        container_label: assessment.container_label
      })

    ~H"""
    <div class="pl-9 pr-4 flex flex-col">
      <%= if @container_label do %>
        <span class="text-gray-600 font-bold text-sm"><%= @container_label %></span>
      <% end %>
      <span>
        <%= @title %>
      </span>
    </div>
    """
  end

  def render_avg_score_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{avg_score: assessment.avg_score})

    ~H"""
    <div class={if @avg_score < 0.40, do: "text-red-600 font-bold"}>
      <%= format_value(@avg_score) %>
    </div>
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
    <div class={if @students_completion < 0.40, do: "text-red-600 font-bold"}>
      <%= format_value(@students_completion) %>
    </div>
    """
  end

  defp format_value(nil), do: "-"
  defp format_value(value), do: "#{parse_percentage(value)}%"

  defp parse_percentage(value) when is_integer(value) do
    value * 100
  end

  defp parse_percentage(value) when is_float(value) do
    {value, _} =
      Float.round(value * 100)
      |> Float.to_string()
      |> Integer.parse()

    value
  end
end
