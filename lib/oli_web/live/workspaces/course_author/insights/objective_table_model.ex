defmodule OliWeb.Workspaces.CourseAuthor.Insights.ObjectiveTableModel do
  use Phoenix.Component

  import OliWeb.Workspaces.CourseAuthor.Insights.Common

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(rows, ctx) do
    SortableTableModel.new(
      rows: rows,
      column_specs: [
        %ColumnSpec{
          name: :title,
          label: "Objective",
          render_fn: &render_title/3
        },
        %ColumnSpec{
          name: :num_attempts,
          label: "# Attempts"
        },
        %ColumnSpec{
          name: :num_first_attempts,
          label: "# First Attempts"
        },
        %ColumnSpec{
          name: :first_attempt_correct,
          label: "First Attempt Correct%",
          render_fn: &render_percentage/3
        },
        %ColumnSpec{
          name: :eventually_correct,
          label: "Eventually Correct%",
          render_fn: &render_percentage/3
        },
        %ColumnSpec{
          name: :relative_difficulty,
          label: "Relative Difficulty",
          render_fn: &render_float/3
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx
      }
    )
  end

  def render_title(_, row, _assigns) do
    row.title
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
