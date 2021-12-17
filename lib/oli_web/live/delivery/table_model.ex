defmodule OliWeb.Delivery.SelectSource.TableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  use Surface.LiveComponent

  defp is_product?(item) do
    Map.has_key?(item, :type) and Map.get(item, :type) == :blueprint
  end

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
          label: "Requires Payment",
          render_fn: &__MODULE__.render_payment_column/3
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &SortableTableModel.render_inserted_at_column/3
        }
      ],
      event_suffix: "",
      id_field: [:unique_id]
    )
  end

  def render_payment_column(_, item, _) do
    case is_product?(item) do
      true ->
        if item.requires_payment do
          case Money.to_string(item.amount) do
            {:ok, m} -> m
            _ -> "Yes"
          end
        else
          "None"
        end

      _ ->
        "None"
    end
  end

  def render_title_column(assigns, item, _) do
    case is_product?(item) do
      true ->
        route_path = Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, item.slug)
        SortableTableModel.render_link_column(assigns, item.title, route_path)

      _ ->
        route_path = Routes.project_path(OliWeb.Endpoint, :overview, item.project.slug)
        SortableTableModel.render_link_column(assigns, item.project.title, route_path)
    end
  end

  def sort_title_column(sort_order, sort_spec),
    do: {& &1.project, ColumnSpec.default_sort_fn(sort_order, sort_spec)}

  def render_action_column(assigns, item, _) do
    id =
      case is_product?(item) do
        true ->
          "product:#{item.id}"

        _ ->
          "publication:#{item.id}"
      end

    ~F"""
    <button class="btn btn-primary" phx-click="selected" phx-value-id={id}>Select</button>
    """
  end

  def render_type_column(_, item, _) do
    case is_product?(item) do
      true -> "Product"
      _ -> "Course Project"
    end
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
