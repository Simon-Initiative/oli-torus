defmodule OliWeb.Attempt.TableModel do
  use Surface.LiveComponent

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(members) do
    SortableTableModel.new(
      rows: members,
      column_specs: [
        %ColumnSpec{
          name: :updated,
          label: "Updated",
          render_fn: &__MODULE__.render_updated/3
        },
        %ColumnSpec{
          name: :attempt_guid,
          label: "Attempt Guid",
          render_fn: &__MODULE__.render_attempts/3
        },
        %ColumnSpec{
          name: :resource_id,
          label: "Resource Id"
        },
        %ColumnSpec{
          name: :attempt_number,
          label: "Attempt Number"
        },
        %ColumnSpec{
          name: :activity_title,
          label: "Title"
        },
        %ColumnSpec{
          name: :lifecycle_state,
          label: "State"
        },
        %ColumnSpec{
          name: :score,
          label: "Score"
        },
        %ColumnSpec{
          name: :out_of,
          label: "Out Of"
        },
        %ColumnSpec{
          name: :scoreable,
          label: "Scoreable"
        },
        %ColumnSpec{
          name: :date_evaluated,
          label: "Date Evaluated"
        }
      ],
      event_suffix: "",
      id_field: [:id]
    )
  end


  def render_updated(assigns, row, _) do
    if row.updated do
      ~F"""
      <div style="background-color: black; color: white;">UPDATED</div>
      """
    else
      ~F"""
      <div></div>
    """
    end
  end

  def render_attempts(assigns, row, _) do

    if row.id == assigns.model.selected do
      ~F"""
      <div>
        <strong>{row.attempt_guid}</strong>

      </div>
      """
    else
      ~F"""
      <div>
        <span style="color: blue; cursor: pointer;""><u>{row.attempt_guid}</u></span>

      </div>
      """
    end
  end

  def render(assigns) do
    ~F"""
      <div>nothing</div>
    """
  end
end
