defmodule OliWeb.PublisherLive.TableModel do
  use Phoenix.Component

  alias Oli.Inventories.Publisher
  alias OliWeb.Common.Table.{ColumnSpec, Common, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(publishers, ctx) do
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
          render_fn: &Common.render_date/3,
          sort_fn: &Common.sort_date/2
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
        ctx: ctx
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
    assigns = Map.merge(assigns, %{name: name, default: default})

    ~H"""
    <div>
      <%= @name %>
      <%= if @default do %>
        <span class="badge badge-info">default</span>
      <% end %>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end
end
