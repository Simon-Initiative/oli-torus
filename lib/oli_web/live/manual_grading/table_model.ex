defmodule OliWeb.ManualGrading.TableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  use Surface.LiveComponent

  def new(attempts) do
    SortableTableModel.new(
      rows: attempts,
      column_specs: [
        %ColumnSpec{
          name: :user,
          label: "Student",
          render_fn: &__MODULE__.render_student/3
        },
        %ColumnSpec{
          name: :activity_title,
          label: "Activity"
        },
        %ColumnSpec{
          name: :page_title,
          label: "Page"
        },
        %ColumnSpec{
          name: :details,
          label: "Date Submitted",
          render_fn: &OliWeb.Common.Table.Common.render_date/3
        },
        %ColumnSpec{
          name: :activity_type_id,
          label: "Activity Type",
          render_fn: &__MODULE__.render_activity_type/3

        },
        %ColumnSpec{
          name: :graded,
          label: "Purpose",
          render_fn: &__MODULE__.render_purpose/3
        }
      ],
      event_suffix: "",
      id_field: [:index]
    )
  end

  def render_student(_, row, _) do
    OliWeb.Common.Utils.name(row.user)
  end

  def render_purpose(_, row, _) do
    if row.graded do
      "Graded"
    else
      "Practice"
    end
  end

  def render_activity_type(_, row, _) do

  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
