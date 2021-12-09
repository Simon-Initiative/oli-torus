defmodule OliWeb.CommunityLive.MembersTableModel do
  use Surface.LiveComponent

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  def new(members) do
    SortableTableModel.new(
      rows: members,
      column_specs: [
        %ColumnSpec{
          name: :name,
          label: "Name"
        },
        %ColumnSpec{
          name: :email,
          label: "Email"
        },
        %ColumnSpec{
          name: :actions,
          label: "Actions",
          render_fn: &__MODULE__.render_remove_button/3
        }
      ],
      event_suffix: "",
      id_field: [:id]
    )
  end

  def render_remove_button(assigns, item, _) do
    ~F"""
      <button class="btn btn-primary" phx-click="remove" phx-value-id={item.id}>Remove</button>
    """
  end

  def render(assigns) do
    ~F"""
      <div>nothing</div>
    """
  end
end
