defmodule OliWeb.Admin.RegistrationsTableModel do
  use Surface.LiveComponent

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias Surface.Components.Link

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end

  def new(authors) do
    SortableTableModel.new(
      rows: authors,
      column_specs: [
        %ColumnSpec{
          name: :issuer,
          label: "Issuer"
        },
        %ColumnSpec{
          name: :client_id,
          label: "Client ID"
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &SortableTableModel.render_inserted_at_column/3
        },
        %ColumnSpec{
          name: :deployments_count,
          label: "# of Deployments"
        },
        %ColumnSpec{
          name: :actions,
          label: "Actions",
          render_fn: &__MODULE__.render_actions_column/3
        }
      ],
      event_suffix: "",
      id_field: [:id]
    )
  end

  def render_actions_column(
        assigns,
        %{id: id},
        _
      ) do
    ~F"""
    <Link label="Details" to={Routes.registration_path(OliWeb.Endpoint, :show, id)} class="btn btn-sm btn-outline-primary" />
    """
  end
end
