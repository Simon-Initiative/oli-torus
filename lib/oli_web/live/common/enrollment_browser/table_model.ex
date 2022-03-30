defmodule OliWeb.Common.EnrollmentBrowser.TableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  import OliWeb.Common.Utils
  use Surface.Component

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end

  def new(users, section, context) do
    column_specs = [
      %ColumnSpec{name: :name, label: "Name", render_fn: &__MODULE__.render_name_column/3},
      %ColumnSpec{
        name: :email,
        label: "Email",
        render_fn: &OliWeb.Users.Common.render_email_column/3
      }
    ]

    {:ok, model} =
      SortableTableModel.new(
        rows: users,
        column_specs: column_specs,
        event_suffix: "",
        id_field: [:id],
        data: %{
          context: context
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
    <button class="btn btn-primary" :on-click="select_user" phx-value-id={id}>
      {name(name, given_name, family_name)}
    </button>
    """
  end
end
