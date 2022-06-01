defmodule OliWeb.Products.Payments.Discounts.TableModel do
  use Surface.LiveComponent

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes
  alias Surface.Components.Link

  def new(discounts) do
    SortableTableModel.new(
      rows: discounts,
      column_specs: [
        %ColumnSpec{
          name: :institution,
          label: "Institution",
          render_fn: &__MODULE__.render_institution_column/3
        },
        %ColumnSpec{
          name: :type,
          label: "Type",
          render_fn: &__MODULE__.render_type_column/3
        },
        %ColumnSpec{
          name: :percentage,
          label: "Percentage"
        },
        %ColumnSpec{
          name: :amount,
          label: "Amount"
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &SortableTableModel.render_inserted_at_column/3
        },
        %ColumnSpec{
          name: :actions,
          label: "Actions",
          render_fn: &__MODULE__.render_actions_column/3
        }
      ],
      event_suffix: "",
      id_field: [:id]
    )
  end

  def render_institution_column(_assigns, item, _), do: item.institution.name

  def render_type_column(_assigns, item, _), do: Phoenix.Naming.humanize(item.type)

  def render_actions_column(assigns, item, _) do
    ~F"""
      <Link
        to={Routes.discount_path(OliWeb.Endpoint, :product, item.section.slug, item.id)}
        class="btn btn-outline-primary">
        Edit
      </Link>
      <button class="btn btn-outline-danger" phx-click="remove" phx-value-id={item.id}>Remove</button>
    """
  end

  def render(assigns) do
    ~F"""
      <div>nothing</div>
    """
  end
end
