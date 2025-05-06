defmodule OliWeb.Products.Payments.Discounts.TableModel do
  use Phoenix.Component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  def new(discounts, ctx) do
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
          name: :value,
          label: "Value",
          render_fn: &__MODULE__.render_value_column/3,
          sort_fn: &__MODULE__.sort_value_column/2
        },
        %ColumnSpec{
          name: :bypass_paywall,
          label: "Paywall Turned Off",
          render_fn: &__MODULE__.render_bypass_paywall_column/3
        },
        %ColumnSpec{
          name: :inserted_at,
          label: "Created",
          render_fn: &OliWeb.Common.Table.Common.render_date/3
        },
        %ColumnSpec{
          name: :actions,
          label: "Actions",
          render_fn: &__MODULE__.render_actions_column/3
        }
      ],
      event_suffix: "",
      id_field: [:id],
      data: %{
        ctx: ctx
      }
    )
  end

  def render_bypass_paywall_column(_assigns, %{bypass_paywall: true}, _), do: "Yes"
  def render_bypass_paywall_column(_assigns, _, _), do: "No"

  def render_institution_column(_assigns, item, _), do: item.institution.name

  def render_type_column(_assigns, item, _), do: humanize_type(item.type)

  def render_value_column(_assigns, %{type: :percentage} = item, _), do: item.percentage
  def render_value_column(_assigns, %{type: :fixed_amount} = item, _), do: item.amount

  def sort_value_column(sort_order, sort_spec) do
    {fn
       %{type: :percentage} = item -> %{value: item.percentage}
       %{type: :fixed_amount} = item -> %{value: item.amount}
     end, ColumnSpec.default_sort_fn(sort_order, sort_spec)}
  end

  def render_actions_column(assigns, item, _) do
    assigns = Map.merge(assigns, %{item: item})

    ~H"""
    <.link
      href={Routes.discount_path(OliWeb.Endpoint, :product, @item.section.slug, @item.id)}
      class="btn btn-outline-primary"
    >
      Edit
    </.link>
    <button class="btn btn-outline-danger" phx-click="remove" phx-value-id={@item.id}>Remove</button>
    """
  end

  def render(assigns) do
    ~H"""
    <div>nothing</div>
    """
  end

  defp humanize_type(:fixed_amount), do: "Fixed price"
  defp humanize_type(type), do: Phoenix.Naming.humanize(type)
end
