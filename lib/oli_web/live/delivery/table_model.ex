defmodule OliWeb.Delivery.SelectSource.TableModel do
  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias Surface.Components.Link
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
          name: :title,
          label: "",
          render_fn: &__MODULE__.render_action_column/3
        },
        %ColumnSpec{
          name: :title,
          label: "Title",
          render_fn: &__MODULE__.render_title_column/3
        },
        %ColumnSpec{
          name: :title,
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
          render_fn: &__MODULE__.render_date_column/3
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
        ~F"""
        <Link
          label={item.title}
          to={Routes.live_path(OliWeb.Endpoint, OliWeb.Products.DetailsView, item.slug)}
        />
        """

      _ ->
        ~F"""
        <Link
          label={item.project.title}
          to={Routes.project_path(OliWeb.Endpoint, :overview, item.project.slug)}
        />
        """
    end
  end

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

  def render_date_column(_, %{inserted_at: inserted_at}, _) do
    Timex.format!(inserted_at, "{relative}", :relative)
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
