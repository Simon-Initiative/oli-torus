defmodule OliWeb.Products.Payments.TableModel do
  use OliWeb, :surface_component

  alias OliWeb.Common.Table.{ColumnSpec, SortableTableModel}
  alias OliWeb.Common.Utils

  def new(payments, context) do
    inserted_at_spec = %ColumnSpec{
      name: :generation_date,
      label: "Created Date",
      render_fn: &__MODULE__.render_date_column/3,
      sort_fn: &__MODULE__.sort_date/2
    }

    SortableTableModel.new(
      rows: payments,
      column_specs: [
        %ColumnSpec{
          name: :type,
          label: "Type",
          render_fn: &__MODULE__.render_type_column/3,
          sort_fn: &__MODULE__.sort/2
        },
        inserted_at_spec,
        %ColumnSpec{
          name: :application_date,
          label: "Application Date",
          render_fn: &__MODULE__.render_date_column/3,
          sort_fn: &__MODULE__.sort_date/2
        },
        %ColumnSpec{
          name: :details,
          label: "Details",
          render_fn: &__MODULE__.render_details_column/3
        },
        %ColumnSpec{
          name: :user,
          label: "User",
          render_fn: &__MODULE__.render_user_column/3
        },
        %ColumnSpec{
          name: :section,
          label: "Section",
          render_fn: &__MODULE__.render_section_column/3
        }
      ],
      event_suffix: "",
      id_field: [:unique_id],
      sort_by_spec: inserted_at_spec,
      sort_order: :desc,
      data: %{
        context: context
      }
    )
  end

  def render_section_column(_, %{section: section}, _) do
    case section do
      nil -> ""
      s -> s.title
    end
  end

  def render_user_column(_, %{user: user}, _) do
    case user do
      nil ->
        ""

      user ->
        safe_get(user.family_name, "Unknown") <> ", " <> safe_get(user.given_name, "Unknown")
    end
  end

  defp safe_get(item, default_value) do
    case item do
      nil -> default_value
      item -> item
    end
  end

  def render_type_column(assigns, %{payment: payment, code: code}, _) do
    case payment.type do
      :direct ->
        ~F"""
        Direct: <span class="badge badge-success">{payment.provider_type}</span>
        """

      :deferred ->
        ~F"""
        Code: <code>{code}</code>
        """
    end
  end

  def render_details_column(assigns, %{payment: payment}, _) do
    case {payment.type, payment.provider_type} do
      {:direct, :stripe} ->
        ~F"""
        <a href={"https://dashboard.stripe.com/test/payments/#{payment.provider_payload["id"]}"}>View <i class="fas fa-external-link-alt ml-1"></i></a>
        """

      _ ->
        ""
    end
  end

  def sort(direction, _) do
    {fn v ->
       case v.payment.type do
         :direct -> "zzzDirect: #{v.payment.provider_type}"
         :deferred -> "Code: [#{v.code}]"
       end
     end, direction}
  end

  def sort_date(direction, spec) do
    {fn r ->
       case Map.get(r.payment, spec.name) do
         nil ->
           0

         d ->
           DateTime.to_unix(d)
       end
     end, direction}
  end

  def render_date_column(%{context: context}, %{payment: payment}, %ColumnSpec{name: name}) do
    Utils.render_date(payment, name, context)
  end

  def render(assigns) do
    ~F"""
    <div>nothing</div>
    """
  end
end
