defmodule OliWeb.Delivery.Sections.EnrollmentsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  use Surface.LiveComponent

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end

  def new(users) do
    SortableTableModel.new(
      rows: users,
      column_specs: [
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
      ],
      event_suffix: "",
      id_field: [:id]
    )
  end

  def render_name_column(
        assigns,
        %{id: id, name: name, given_name: given_name, family_name: family_name},
        _
      ) do
    ~F"""
      <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersDetailView, id)}>{OliWeb.Users.UsersTableModel.normalize(name, given_name, family_name)}</a>
    """
  end
end
