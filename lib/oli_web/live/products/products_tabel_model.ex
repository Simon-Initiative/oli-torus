defmodule OliWeb.Products.ProductsTableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(products) do
    SortableTableModel.new(
      rows: products,
      column_specs: [
        %ColumnSpec{
          name: :title,
          label: "Product Title",
          render_fn: &__MODULE__.render_title_column/3
        },
        %ColumnSpec{name: :status, label: "Status"},
        %ColumnSpec{
          name: :requires_payment,
          label: "Requires Payment",
          render_fn: &__MODULE__.render_payment_column/3
        },
        %ColumnSpec{
          name: :base_project_id,
          label: "Base Project",
          render_fn: &__MODULE__.render_project_column/3
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &SortableTableModel.render_inserted_at_column/3
        }
      ],
      event_suffix: "",
      id_field: [:id]
    )
  end

  def render_payment_column(_, %{requires_payment: requires_payment, amount: amount}, _) do
    if requires_payment do
      case Money.to_string(amount) do
        {:ok, m} -> m
        _ -> "Yes"
      end
    else
      "None"
    end
  end

  def render_title_column(assigns, %{title: title, slug: slug}, _) do
    route_path = Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, slug)
    SortableTableModel.render_link_column(assigns, title, route_path)
  end

  def render_project_column(assigns, %{base_project: base_project}, _) do
    route_path = Routes.project_path(OliWeb.Endpoint, :overview, base_project.slug)
    SortableTableModel.render_link_column(assigns, base_project.title, route_path)
  end
end
