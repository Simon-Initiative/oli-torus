defmodule OliWeb.Products.Payments.Discounts.ProductsIndexView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.SortableTable.TableHandlers

  alias Oli.Delivery.{Sections, Paywall}
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Common.{Breadcrumb, Listing, SessionContext}
  alias OliWeb.Products.Payments.Discounts.TableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias Surface.Components.Link

  data title, :string, default: "Discounts"
  data breadcrumbs, :any
  data query, :string, default: ""
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: 20
  data sort, :string, default: "sort"
  data page_change, :string, default: "page_change"
  data show_bottom_paging, :boolean, default: false
  data additional_table_class, :string, default: ""

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  def filter_rows(socket, _, _), do: socket.assigns.discounts
  def live_path(socket, params), do: Routes.live_path(socket, __MODULE__, socket.assigns.product.slug, params)

  def set_breadcrumbs(product) do
    OliWeb.Products.DetailsView.set_breadcrumbs(product) ++
      [
        Breadcrumb.new(%{
          full_title: "Discounts",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, product.slug)
        })
      ]
  end

  def mount(%{"product_id" => product_slug}, session, socket) do
    case Sections.get_section_by_slug(product_slug) do
      %Section{type: :blueprint} = product ->
        discounts = Paywall.get_product_discounts(product.id)
        context = SessionContext.init(session)

        {:ok, table_model} = TableModel.new(discounts, context)

        {:ok, assign(socket,
          context: context,
          breadcrumbs: set_breadcrumbs(product),
          discounts: discounts,
          table_model: table_model,
          total_count: length(discounts),
          product: product
        )}

      _ -> {:ok, Phoenix.LiveView.redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :not_found))}
    end
  end

  def render(assigns) do
    ~F"""
      <Link
        to={Routes.discount_path(OliWeb.Endpoint, :product_new, @product.slug)}
        class="btn btn-outline-primary float-right">
        Create Discount
      </Link>

      <div id="discounts-table" class="p-4">
        <Listing
          filter={@query}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          sort={@sort}
          page_change={@page_change}
          show_bottom_paging={@show_bottom_paging}
          additional_table_class={@additional_table_class}/>
      </div>
    """
  end

  def handle_event("remove", %{"id" => id}, socket) do
    socket = clear_flash(socket)

    discount = Paywall.get_discount_by!(%{id: String.to_integer(id)})

    case Paywall.delete_discount(discount) do
      {:ok, _discount} ->
        discounts = Paywall.get_product_discounts(socket.assigns.product.id)
        {:ok, table_model} = TableModel.new(discounts, socket.assigns.context)

        {:noreply,
          socket
          |> put_flash(:info, "Discount successfully removed.")
          |> assign(discounts: discounts, table_model: table_model, total_count: length(discounts))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Discount couldn't be removed.")}
    end
  end
end
