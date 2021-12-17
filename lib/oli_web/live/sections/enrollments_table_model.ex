defmodule OliWeb.Delivery.Sections.EnrollmentsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  import OliWeb.Common.Utils
  use Surface.LiveComponent

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end

  def new(users, section, local_tz) do
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
        render_fn: &OliWeb.Common.Table.Common.render_date/3
      },
      %ColumnSpec{
        name: :unenroll,
        label: "Unenroll",
        render_fn: &__MODULE__.render_unenroll_column/3
      }
    ]

    column_specs =
      if section.requires_payment do
        base_columns ++
          [
            %ColumnSpec{
              name: :payment_date,
              label: "Paid On",
              render_fn: &OliWeb.Common.Table.Common.render_date/3
            }
          ]
      else
        base_columns
      end

    {:ok, model} =
      SortableTableModel.new(
        rows: users,
        column_specs: column_specs,
        event_suffix: "",
        id_field: [:id],
        data: %{
          local_tz: local_tz
        }
      )

    {:ok, Map.put(model, :data, %{section_slug: section.slug})}
  end

  def render_name_column(
        assigns,
        %{
          id: id,
          name: name,
          given_name: given_name,
          family_name: family_name
        },
        _
      ) do
    ~F"""
    <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Progress.StudentView, assigns.section_slug, id)}>
      {name(name, given_name, family_name)}
    </a>
    """
  end

  def render_unenroll_column(assigns, user, _) do
    ~F"""
    <button class="btn btn-outline-danger" phx-click="unenroll" phx-value-id={user.id}>
      Unenroll
    </button>
    """
  end
end
