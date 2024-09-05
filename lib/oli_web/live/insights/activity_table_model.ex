defmodule OliWeb.Insights.ActivityTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  use Phoenix.Component

  def new(rows, activity_types_map, ctx) do
    SortableTableModel.new(
      rows: rows,
      column_specs: [
        %ColumnSpec{
          name: :title,
          label: "Activity",
          render_fn: &__MODULE__.render_title/3
        },
        %ColumnSpec{
          name: :activity_type_id,
          label: "Type",
          render_fn: &__MODULE__.render_activity_type/3
        },
        %ColumnSpec{
          name: :part,
          label: "Part"
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
          label: "First Attempt Correct%"
        },
        %ColumnSpec{
          name: :eventually_correct,
          label: "Eventually Correct%"
        },
        %ColumnSpec{
          name: :relative_difficulty,
          label: "Relative Difficulty"
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        activity_types_map: activity_types_map,
        ctx: ctx
      }
    )
  end

  def render_title(_, row, assigns) do
    ~H"""
    <%= row.title %>
    """
  end

  def render_activity_type(%{activity_types_map: activity_types_map}, row, _) do
    Map.get(activity_types_map, row.activity_type_id).petite_label
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
