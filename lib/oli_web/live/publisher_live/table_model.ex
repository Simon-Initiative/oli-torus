defmodule OliWeb.PublisherLive.TableModel do
  alias Oli.Inventories.Publisher
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(publishers) do
    SortableTableModel.new(
      rows: publishers,
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
          name: :address,
          label: "Address"
        },
        %ColumnSpec{
          name: :main_contact,
          label: "Main contact"
        },
        %ColumnSpec{
          name: :website_url,
          label: "Website URL"
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &SortableTableModel.render_inserted_at_column/3
        },
        %ColumnSpec{
          name: :actions,
          label: "Actions",
          render_fn: &__MODULE__.render_overview_button/3
        }
      ],
      event_suffix: "",
      id_field: [:id]
    )
  end

  def render_overview_button(assigns, %Publisher{id: id}, _) do
    route_path = Routes.live_path(OliWeb.Endpoint, OliWeb.PublisherLive.ShowView, id)

    SortableTableModel.render_link_column(
      assigns,
      "Overview",
      route_path,
      "btn btn-sm btn-primary"
    )
  end
end
