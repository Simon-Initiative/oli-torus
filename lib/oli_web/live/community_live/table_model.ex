defmodule OliWeb.CommunityLive.TableModel do
  alias Oli.Groups.Community
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
          render_fn: &SortableTableModel.render_inserted_at_column/3
        },
        %ColumnSpec{
          name: :actions,
          label: "Actions",
          render_fn: &__MODULE__.render_overview_button/3
        },
        %ColumnSpec{
          name: :status,
          label: "Status",
          render_fn: &__MODULE__.render_status/3
        }
      ],
      event_suffix: "",
      id_field: [:id]
    )
  end

  def render_overview_button(assigns, %Community{id: id, status: status}, _) do
    route_path = Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.ShowView, id)

    SortableTableModel.render_link_column(
      assigns,
      "Overview",
      route_path,
      "btn btn-sm btn-primary #{if status == :deleted, do: "disabled"}"
    )
  end

  def render_status(assigns, %Community{status: :active}, _) do
    SortableTableModel.render_span_column(assigns, "Active", "text-success")
  end

  def render_status(assigns, %Community{status: :deleted}, _) do
    SortableTableModel.render_span_column(assigns, "Deleted", "text-danger")
  end
end
