defmodule OliWeb.Admin.RegistrationsTableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  def new(authors, ctx) do
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
          render_fn: &Common.render_date/3
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
      id_field: [:id],
      data: %{
        ctx: ctx
      }
    )
  end

  def render_actions_column(
        assigns,
        %{id: id},
        _
      ) do
    assigns = Map.merge(assigns, %{id: id})

    ~H"""
    <.link
      href={Routes.registration_path(OliWeb.Endpoint, :show, @id)}
      class="btn btn-sm btn-outline-primary"
    >
      Details
    </.link>
    """
  end
end
