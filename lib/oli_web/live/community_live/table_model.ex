defmodule OliWeb.CommunityLive.TableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(communities) do
    SortableTableModel.new(
      rows: communities,
      column_specs: [
        %ColumnSpec{
          name: :name,
          label: "Name"
        },
        %ColumnSpec{
          name: :description,
          label: "Description"
        },
        %ColumnSpec{
          name: :key_contact,
          label: "Key Contact"
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &SortableTableModel.render_date_column/3
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

  def render_overview_button(assigns, community, _) do
    route_path = Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.Show, community.id)

    SortableTableModel.render_link_column(
      assigns,
      "Overview",
      route_path,
      "btn btn-sm btn-primary"
    )
  end
end
