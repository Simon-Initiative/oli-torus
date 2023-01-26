defmodule OliWeb.PublisherLive.TableModel do
  use Surface.LiveComponent

  alias Oli.Inventories.Publisher
  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(publishers, context) do
    SortableTableModel.new(
      rows: publishers,
      column_specs: [
        %ColumnSpec{
          name: :name,
          label: "Name",
          render_fn: &__MODULE__.render_name/3
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
          render_fn: &Common.render_date/3
        },
        %ColumnSpec{
          name: :actions,
          label: "Actions",
          render_fn: &__MODULE__.render_overview_button/3
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        context: context
      }
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

  def render_name(assigns, %Publisher{name: name, default: default}, _) do
    ~F"""
    {name}
    {#if default}
      <span class="badge badge-info">default</span>
    {/if}
    """
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
