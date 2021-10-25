defmodule OliWeb.Delivery.Sections.EnrollmentsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}

  import OliWeb.Common.Utils
  use Surface.LiveComponent

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end

  def new(users, section) do
    base_columns = [
      %ColumnSpec{name: :name, label: "Name", render_fn: &__MODULE__.render_name_column/3},
      %ColumnSpec{
        name: :email,
        label: "Email",
        render_fn: &OliWeb.Users.Common.render_email_column/3
      },
      %ColumnSpec{
        name: :enrollment_date,
        label: "Enrolled On",
        render_fn: &OliWeb.Common.Table.Common.render_short_date/3
      }
    ]

    column_specs =
      if section.requires_payment do
        base_columns ++
          [
            %ColumnSpec{
              name: :payment_date,
              label: "Paid On",
              render_fn: &OliWeb.Common.Table.Common.render_short_date/3
            }
          ]
      else
        base_columns
      end

    SortableTableModel.new(
      rows: users,
      column_specs: column_specs,
      event_suffix: "",
      id_field: [:id]
    )
  end

  def render_name_column(
        _,
        %{name: name, given_name: given_name, family_name: family_name},
        _
      ) do
    name(name, given_name, family_name)
  end
end
