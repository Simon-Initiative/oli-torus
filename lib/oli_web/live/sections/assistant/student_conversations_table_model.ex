defmodule OliWeb.Sections.StudentConversationsTableModel do
  use OliWeb, :html

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(students, resource_titles) do
    column_specs = [
      %ColumnSpec{
        name: :student,
        label: "Student",
        render_fn: &__MODULE__.render_student_column/3
      },
      %ColumnSpec{
        name: :resource,
        label: "Page",
        render_fn: &__MODULE__.render_resource_column/3
      },
      %ColumnSpec{
        name: :num_messages,
        label: "# Messages",
        render_fn: &__MODULE__.render_num_messages/3
      }
    ]

    SortableTableModel.new(
      rows: students,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:resource_id],
      data: %{
        resource_titles: resource_titles
      }
    )
  end

  def render_student_column(assigns, row, _) do
    assigns = Map.merge(assigns, %{name: name_or_guest(row.user)})

    ~H"""
    <div>
      <%= @name %>
    </div>
    """
  end

  defp name_or_guest(user) do
    case user do
      %{name: nil} -> "Guest"
      %{name: name} -> name
    end
  end

  def render_resource_column(assigns, row, _) do
    assigns = Map.merge(assigns, %{resource_id: row.resource_id})

    ~H"""
    <div>
      <%= @resource_titles[@resource_id] %>
    </div>
    """
  end

  def render_num_messages(assigns, row, _) do
    assigns = Map.merge(assigns, %{num_messages: row.num_messages})

    ~H"""
    <div>
      <%= @num_messages %>
    </div>
    """
  end
end
