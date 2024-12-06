defmodule OliWeb.Products.PaymentsView do
  use OliWeb, :live_view

  import OliWeb.DelegatedEvents

  alias Oli.Delivery.Paywall
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb, Params, PagedTable, TextSearch}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Products.Payments.CreateCodes
  alias OliWeb.Router.Helpers, as: Routes

  @limit 20
  @text_search_tooltip """
  Search by payment code and section title.
  """

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def live_path(socket, params) do
    Routes.live_path(socket, OliWeb.Products.PaymentsView, socket.assigns.product_slug, params)
  end

  def mount(%{"product_id" => product_slug}, _session, socket) do
    ctx = socket.assigns.ctx

    payments =
      browse_payments(product_slug, %Paging{offset: 0, limit: @limit}, %Sorting{
        direction: :asc,
        field: :type
      })

    total_count = determine_total(payments)

    {:ok, table_model} = OliWeb.Products.Payments.TableModel.new(payments, ctx)

    {:ok,
     assign(socket,
       product: Oli.Delivery.Sections.get_section_by(slug: product_slug),
       product_slug: product_slug,
       total_count: total_count,
       table_model: table_model,
       breadcrumbs: [Breadcrumb.new(%{full_title: "Payments"})],
       title: "Payments",
       code_count: 50,
       offset: 0,
       limit: @limit,
       text_search: "",
       text_search_tooltip: @text_search_tooltip,
       download_enabled: false
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <CreateCodes.render
        disabled={!@product.requires_payment}
        count={@code_count}
        product_slug={@product_slug}
        download_enabled={@download_enabled}
        create_codes="create"
        change="change_count"
      />

      <hr class="mt-5 mb-5" />

      <TextSearch.render
        id="text-search"
        reset="text_search_reset"
        change="text_search_change"
        text={@text_search}
        event_target={nil}
        tooltip={@text_search_tooltip}
      />

      <div class="mb-3" />

      <PagedTable.render
        page_change="paged_table_page_change"
        sort="paged_table_sort"
        total_count={@total_count}
        filter={@text_search}
        limit={@limit}
        offset={@offset}
        table_model={@table_model}
      />
    </div>
    """
  end

  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = Params.get_int_param(params, "offset", 0)
    text_search = Params.get_param(params, "text_search", "")

    payments =
      browse_payments(
        socket.assigns.product_slug,
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        text_search
      )

    table_model = Map.put(table_model, :rows, payments)

    total_count = determine_total(payments)

    {:noreply,
     assign(socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count,
       text_search: text_search
     )}
  end

  defp browse_payments(product_slug, paging, sorting, text_search \\ "") do
    Paywall.browse_payments(
      product_slug,
      paging,
      sorting,
      text_search: text_search
    )
    |> Enum.map(fn element ->
      Map.put(
        element,
        :code,
        case element.payment.code do
          nil ->
            ""

          code ->
            Paywall.Payment.to_human_readable(code)
        end
      )
      |> Map.put(:unique_id, element.payment.id)
    end)
  end

  def handle_event("create", _, %{assigns: assigns} = socket) do
    create_payment_codes =
      Paywall.create_payment_codes(
        assigns.product_slug,
        assigns.code_count
      )

    case create_payment_codes do
      {:ok, _} ->
        payments =
          browse_payments(
            assigns.product_slug,
            %Paging{offset: assigns.offset, limit: @limit},
            %Sorting{
              direction: assigns.table_model.sort_order,
              field: assigns.table_model.sort_by_spec.name
            },
            assigns.text_search
          )

        table_model = Map.put(assigns.table_model, :rows, payments)

        total_count = determine_total(payments)

        {:noreply,
         socket
         |> put_flash(:info, "Payment codes successfully added.")
         |> assign(
           total_count: total_count,
           table_model: table_model,
           download_enabled: true
         )}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Code payments couldn't be added.")}
    end
  end

  def handle_event("change_count", %{"value" => count}, socket) do
    count =
      case String.to_integer(count) do
        i when i > 0 -> i
        _ -> 1
      end

    {:noreply, assign(socket, code_count: count, download_enabled: false)}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to:
         live_path(
           socket,
           Map.merge(
             %{
               sort_by: socket.assigns.table_model.sort_by_spec.name,
               sort_order: socket.assigns.table_model.sort_order,
               offset: socket.assigns.offset,
               text_search: socket.assigns.text_search
             },
             changes
           )
         ),
       replace: true
     )}
  end

  defp determine_total(payments) do
    case payments do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end
end
