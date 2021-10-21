defmodule OliWeb.Products.PaymentsView do
  use Surface.LiveView

  alias(OliWeb.Products.Filter)

  alias OliWeb.Products.Listing
  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Products.Payments.CreateCodes
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes

  data breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Payments"})]
  data title, :string, default: "Payments"
  data code_count, :integer, default: 50
  data product_slug, :string
  data payments, :list, default: []
  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: 20
  data filter, :string, default: ""
  data applied_filter, :string, default: ""

  @table_filter_fn &OliWeb.Products.PaymentsView.filter_rows/2
  @table_push_patch_path &OliWeb.Products.PaymentsView.live_path/2

  def filter_rows(socket, filter) do
    case String.downcase(filter) do
      "" ->
        socket.assigns.payments

      str ->
        Enum.filter(socket.assigns.payments, fn p ->
          title =
            case is_nil(p.section) do
              true -> ""
              false -> p.section.title
            end

          String.contains?(String.downcase(p.code), str) or
            String.contains?(String.downcase(title), str)
        end)
    end
  end

  def live_path(socket, params) do
    Routes.live_path(socket, OliWeb.Products.PaymentsView, socket.assigns.product_slug, params)
  end

  def mount(%{"product_id" => product_slug}, _, socket) do
    payments =
      Oli.Delivery.Paywall.list_payments(product_slug)
      |> Enum.map(fn element ->
        Map.put(
          element,
          :code,
          if is_nil(element.payment.code) do
            ""
          else
            Oli.Delivery.Paywall.Payment.to_human_readable(element.payment.code)
          end
        )
        |> Map.put(:unique_id, element.payment.id)
      end)

    total_count = length(payments)

    {:ok, table_model} = OliWeb.Products.Payments.TableModel.new(payments)

    {:ok,
     assign(socket,
       product_slug: product_slug,
       payments: payments,
       total_count: total_count,
       table_model: table_model
     )}
  end

  def render(assigns) do
    ~F"""
    <div>

      <CreateCodes id="create_codes" count={@code_count} product_slug={@product_slug} click="create_codes" change="change_count"/>

      <hr class="mt-5 mb-5"/>

      <Filter apply={"apply_filter"} change={"change_filter"} reset="reset_filter"/>

      <div class="mb-3"/>

      <Listing
        filter={@applied_filter}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
        sort="sort"
        page_change="page_change"/>

    </div>

    """
  end

  def handle_event("change_count", %{"value" => count}, socket) do
    count =
      case String.to_integer(count) do
        i when i > 0 -> i
        _ -> 1
      end

    {:noreply, assign(socket, code_count: count)}
  end

  use OliWeb.Common.SortableTable.TableHandlers
end
