defmodule OliWeb.Products.Payments.Discounts do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Delivery.{Paywall, Sections}
  alias Oli.Delivery.Paywall.Discount
  alias Oli.Delivery.Sections.Section
  alias Oli.Institutions.Institution
  alias Oli.Lti.Tool.Deployment
  alias OliWeb.Common.{Breadcrumb, FormContainer}
  alias OliWeb.Products.Payments.DiscountsForm
  alias OliWeb.Router.Helpers, as: Routes

  data breadcrumbs, :any
  data title, :string, default: "Product Discount"
  data product, :any, default: nil
  data discount, :any, default: nil
  data changeset, :changeset, default: nil

  defp set_breadcrumbs(product) do
    OliWeb.Products.DetailsView.set_breadcrumbs(product)
    |> breadcrumb(product)
  end

  def breadcrumb(previous, product) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Discounts",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, product.slug)
        })
      ]
  end

  def mount(%{"product_id" => product_slug}, _session, socket) do
    case Sections.get_section_by_slug(product_slug) do
      %Section{
        type: :blueprint,
        lti_1p3_deployment: %Deployment{
          institution: %Institution{id: institution_id}
        }
      } = product ->
        {has_discount, changeset} =
          case Paywall.get_discount_by!(%{
            section_id: product.id,
            institution_id: institution_id
          }) do
            nil -> {false, Paywall.change_discount(%Discount{})}
            discount -> {true, Paywall.change_discount(discount)}
          end

        {:ok, assign(socket,
          breadcrumbs: set_breadcrumbs(product),
          product: product,
          has_discount: has_discount,
          changeset: changeset
        )}

      _ -> {:ok, Phoenix.LiveView.redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :not_found))}
    end
  end

  def render(assigns) do
    ~F"""
      <FormContainer title={@title}>
        <DiscountsForm
          institution_name={@product.lti_1p3_deployment.institution.name}
          has_discount={@has_discount}
          changeset={@changeset}
          save="save"
          clear="clear" />
      </FormContainer>
    """
  end

  def handle_event("save", %{"discount" => params}, socket) do
    socket = clear_flash(socket)

    attrs = %{
      section_id: socket.assigns.product.id,
      institution_id: socket.assigns.product.lti_1p3_deployment.institution.id,
      percentage: params["percentage"],
      amount: params["amount"],
      type: params["type"]
    }

    case Paywall.create_or_update_discount(attrs) do
      {:ok, discount} ->
        {:noreply,
          socket
          |> put_flash(:info, "Discount successfully created/updated.")
          |> assign(has_discount: true, changeset: Paywall.change_discount(discount))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "Discount couldn't be created/updated. Please check the errors below.")
          |> assign(changeset: changeset)}
    end
  end

  def handle_event("clear", _params, socket) do
    socket = clear_flash(socket)

    attrs = %{
      section_id: socket.assigns.product.id,
      institution_id: socket.assigns.product.lti_1p3_deployment.institution.id,
    }

    case Paywall.delete_discount(attrs) do
      {:ok, _discount} ->
        {:noreply,
          socket
          |> put_flash(:info, "Discount successfully cleared.")
          |> assign(has_discount: false, changeset: Paywall.change_discount(%Discount{}))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "Discount couldn't be cleared.")
          |> assign(changeset: changeset)}
    end
  end
end
