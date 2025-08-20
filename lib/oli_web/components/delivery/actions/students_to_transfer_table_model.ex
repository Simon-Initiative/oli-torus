defmodule OliWeb.Delivery.Actions.StudentsToTransferTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.FormatDateTime

  def new(students, target) do
    column_specs = [
      %ColumnSpec{
        name: :name,
        label: "NAME",
        render_fn: &__MODULE__.render_name_column/3,
        th_class: "pl-10"
      },
      %ColumnSpec{
        name: :enrollment_date,
        label: "ENROLLMENT DATE",
        render_fn: &__MODULE__.render_date/3
      }
    ]

    SortableTableModel.new(
      rows: students,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id],
      data: %{target: target}
    )
  end

  def render_name_column(assigns, student, _) do
    assigns = Map.merge(assigns, %{name: student.name, student_id: student.id})

    ~H"""
    <div class="pl-9 pr-4 flex flex-col">
      {@name}
    </div>
    """
  end

  def render_date(assigns, student, %ColumnSpec{name: :enrollment_date}) do
    assigns = Map.put(assigns, :enrollment_date, student.enrollment_date)

    ~H"""
    {FormatDateTime.format_datetime(@enrollment_date, show_timezone: false)}
    """
  end
end
