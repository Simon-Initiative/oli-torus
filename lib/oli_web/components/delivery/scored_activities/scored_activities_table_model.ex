defmodule OliWeb.Delivery.ScoredActivities.ScoredActivitiesTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  # alias OliWeb.Common.FormatDateTime

  # TODO revalidate section_slug need
  def new(assessments, section_slug, context) do
    column_specs = [
      %ColumnSpec{
        name: :name,
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
        label: "AVG SCORE"
      },
      %ColumnSpec{
        name: :total_attempts,
        label: "TOTAL ATTEMPTS",
        render_fn: &__MODULE__.render_attempts_column/3
      },
      %ColumnSpec{
        name: :students_completion,
        label: "STUDENTS COMPLETION"
      }
    ]

    SortableTableModel.new(
      rows: assessments,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{
        section_slug: section_slug,
        # TODO revalidate context need
        context: context
      }
    )
  end

  def render_assessment_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{name: assessment.name})

    ~H"""
      <div class="pl-9 pr-4"><%= @name %></div>
    """
  end

  def render_due_date_column(assigns, assessment, _) do
    assigns =
      Map.merge(assigns, %{
        due_date: assessment.end_date,
        scheduling_type: assessment.scheduling_type
      })

    # TODO render date
    ~H"""
      <%= if @scheduling_type == :due_by do %>
        aca iria la fecha
      <% else %>
        No due date
      <% end %>
    """
  end

  def render_attempts_column(assigns, assessment, _) do
    assigns = Map.merge(assigns, %{total_attempts: assessment.total_attempts})

    ~H"""
      <%= @total_attempts %>
    """
  end

  # defp value_from_datetime(nil, _context), do: nil

  # defp value_from_datetime(datetime, context) do
  #   datetime
  #   |> FormatDateTime.convert_datetime(context)
  #   |> DateTime.to_iso8601()
  #   |> String.slice(0, 16)
  # end
end
