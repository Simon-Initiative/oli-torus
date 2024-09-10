defmodule OliWeb.ManualGrading.TableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  use Phoenix.Component

  def new(attempts, activity_types_map, ctx) do
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
          name: :attempt_number,
          label: "Attempt"
        },
        %ColumnSpec{
          name: :page_title,
          label: "Page"
        },
        %ColumnSpec{
          name: :resource_attempt_number,
          label: "Attempt"
        },
        date_submitted_spec(),
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
      id_field: [:id],
      data: %{
        activity_types_map: activity_types_map,
        ctx: ctx
      }
    )
  end

  def date_submitted_spec() do
    %ColumnSpec{
      name: :date_submitted,
      label: "Date Submitted",
      render_fn: &OliWeb.Common.Table.Common.render_date/3
    }
  end

  def render_student(_, row, _) do
    OliWeb.Common.Utils.name(row.user)
  end

  def render_purpose(_, row, _) do
    if row.graded do
      "Scored"
    else
      "Practice"
    end
  end

  def render_activity_type(%{activity_types_map: activity_types_map}, row, _) do
    Map.get(activity_types_map, row.activity_type_id).title
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
