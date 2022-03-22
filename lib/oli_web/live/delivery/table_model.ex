defmodule OliWeb.Delivery.SelectSource.TableModel do
  use Surface.LiveComponent

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(products) do
    SortableTableModel.new(
      rows: products,
      column_specs: [
        %ColumnSpec{
          name: :action,
          label: "",
          render_fn: &__MODULE__.render_action_column/3
        },
        %ColumnSpec{
          name: :title,
          label: "Title",
          render_fn: &__MODULE__.render_title_column/3,
          sort_fn: &__MODULE__.sort_title_column/2
        },
        %ColumnSpec{
          name: :type,
          label: "Type",
          render_fn: &__MODULE__.render_type_column/3
        },
        %ColumnSpec{
          name: :requires_payment,
          label: "Payment",
          render_fn: &__MODULE__.render_payment_column/3,
          sort_fn: &__MODULE__.sort_payment_column/2
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &SortableTableModel.render_inserted_at_column/3,
          sort_fn: &OliWeb.Common.Table.Common.sort_date/2
        }
      ],
      event_suffix: "",
      id_field: [:unique_id]
    )
  end

  def is_product?(item),
    do: Map.has_key?(item, :type) and Map.get(item, :type) == :blueprint

  def render_payment_column(_, item, _) do
    if is_product?(item) and item.requires_payment do
      case Money.to_string(item.amount) do
        {:ok, m} -> m
        _ -> "Yes"
      end
    else
      "None"
    end
  end

  def sort_payment_column(sort_order, sort_spec) do
    {fn item ->
      amount =
        if is_product?(item) and item.requires_payment do
          case Money.to_string(item.amount) do
            {:ok, m} -> m
            _ -> 0
          end
        else
          0
        end

      %{requires_payment: amount}
    end,
    ColumnSpec.default_sort_fn(sort_order, sort_spec)}
  end

  def render_title_column(assigns, item, _) do
    if is_product?(item) do
      route_path = Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, item.slug)
      SortableTableModel.render_link_column(assigns, item.title, route_path)
    else
      route_path = Routes.project_path(OliWeb.Endpoint, :overview, item.project.slug)
      SortableTableModel.render_link_column(assigns, item.project.title, route_path)
    end
  end

  def sort_title_column(sort_order, sort_spec) do
    {fn item -> if is_product?(item),
      do: Map.put(item, :title, String.downcase(item.title)),
      else: Map.put(item.project, :title, String.downcase(item.project.title))
    end,
    ColumnSpec.default_sort_fn(sort_order, sort_spec)}
  end

  def render_action_column(assigns, item, _) do
    id = if is_product?(item), do: "product:#{item.id}", else: "publication:#{item.id}"

    ~F"""
      <button class="btn btn-primary" phx-click="selected" phx-value-id={id}>Select</button>
    """
  end

  def render_type_column(_, item, _),
    do: if is_product?(item), do: "Product", else: "Course Project"

  def render(assigns) do
    ~F"""
      <div>nothing</div>
    """
  end
end
