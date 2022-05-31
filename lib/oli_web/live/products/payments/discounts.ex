defmodule OliWeb.Products.Payments.Discounts do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias Oli.Delivery.{Paywall, Sections}
  alias Oli.Delivery.Paywall.Discount
  alias Oli.Delivery.Sections.Section
  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias Oli.Lti.Tool.Deployment
  alias OliWeb.Common.{Breadcrumb, FormContainer}
  alias OliWeb.Products.Payments.DiscountsForm
  alias OliWeb.InstitutionController
  alias OliWeb.Router.Helpers, as: Routes

  data breadcrumbs, :any
  data title, :string, default: "Manage Discount"
  data product, :any, default: nil
  data institution, :any, default: nil
  data discount, :any, default: nil
  data changeset, :changeset, default: nil
  data institution_name, :string, default: ""

  defp set_breadcrumbs(:product = live_action, product) do
    breadcrumb(
      OliWeb.Products.DetailsView.set_breadcrumbs(product),
      live_action,
      product.slug
    )
  end

  defp set_breadcrumbs(:institution = live_action, institution) do
    (InstitutionController.root_breadcrumbs() ++
      [
        Breadcrumb.new(%{
          full_title: "#{institution.name}",
          link: Routes.institution_path(OliWeb.Endpoint, :show, institution.id)
        })
      ]
    )
    |> breadcrumb(live_action, institution.id)
  end

  def breadcrumb(previous, live_action, entity_slug) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Discounts",
          link: Routes.discount_path(OliWeb.Endpoint, live_action, entity_slug)
        })
      ]
  end

  def mount(params, _session, socket) do
    # Discounts used in two routes.
    # live_action is :institution or :product
    live_action = socket.assigns.live_action

    mount_for(live_action, params, socket)
  end

  defp mount_for(:product = live_action, %{"product_id" => product_slug}, socket) do
    case Sections.get_section_by_slug(product_slug) do
      %Section{
        type: :blueprint,
        lti_1p3_deployment: %Deployment{
          institution: %Institution{id: institution_id, name: institution_name}
        }
      } = product ->
        {discount, changeset} =
          case Paywall.get_discount_by!(%{
            section_id: product.id,
            institution_id: institution_id
          }) do
            nil -> {nil, Paywall.change_discount(%Discount{})}
            discount -> {discount, Paywall.change_discount(discount)}
          end

        {:ok, assign(socket,
          breadcrumbs: set_breadcrumbs(live_action, product),
          institution_name: institution_name,
          product: product,
          discount: discount,
          changeset: changeset
        )}

      _ -> {:ok, Phoenix.LiveView.redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :not_found))}
    end
  end

  defp mount_for(:institution = live_action, %{"institution_id" => institution_id}, socket) do
    case Institutions.get_institution_by!(%{id: institution_id}) do
      %Institution{name: name} = institution ->
        {discount, changeset} =
          case Paywall.get_institution_wide_discount!(institution_id) do
            nil -> {nil, Paywall.change_discount(%Discount{})}
            discount -> {discount, Paywall.change_discount(discount)}
          end

        {:ok, assign(socket,
          breadcrumbs: set_breadcrumbs(live_action, institution),
          institution_name: name,
          institution: institution,
          discount: discount,
          changeset: changeset
        )}

      _ -> {:ok, Phoenix.LiveView.redirect(socket, to: Routes.static_page_path(OliWeb.Endpoint, :not_found))}
    end
  end

  def render(assigns) do
    ~F"""
      <FormContainer title={@title}>
        <DiscountsForm
          institution_name={@institution_name}
          discount={@discount}
          changeset={@changeset}
          save="save"
          change="change"
          clear="clear" />
      </FormContainer>
    """
  end

  def handle_event("save", %{"discount" => params}, socket) do
    socket = clear_flash(socket)

    rels_params = get_rels_params(socket.assigns)
    attrs = %{
      section_id: rels_params.section_id,
      institution_id: rels_params.institution_id,
      percentage: params["percentage"],
      amount: params["amount"],
      type: params["type"]
    }

    case Paywall.create_or_update_discount(attrs) do
      {:ok, discount} ->
        {:noreply,
          socket
          |> put_flash(:info, "Discount successfully created/updated.")
          |> assign(discount: discount, changeset: Paywall.change_discount(discount))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "Discount couldn't be created/updated. Please check the errors below.")
          |> assign(changeset: changeset)}
    end
  end

  def handle_event("clear", _params, socket) do
    socket = clear_flash(socket)

    case Paywall.delete_discount(socket.assigns.discount) do
      {:ok, _discount} ->
        {:noreply,
          socket
          |> put_flash(:info, "Discount successfully cleared.")
          |> assign(discount: nil, changeset: Paywall.change_discount(%Discount{}))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "Discount couldn't be cleared.")
          |> assign(changeset: changeset)}
    end
  end

  def handle_event("change", %{"discount" => params}, socket) do
    params =
      params
      |> Map.put("percentage", (if params["type"] == "percentage", do: params["percentage"], else: nil))
      |> Map.put("amount", (if params["type"] == "fixed_amount", do: params["amount"], else: nil))

    {:noreply, assign(socket, changeset: Paywall.change_discount(socket.assigns.changeset.data, params))}
  end

  defp get_rels_params(%{live_action: :product} = assigns) do
    %{
      section_id: assigns.product.id,
      institution_id: assigns.product.lti_1p3_deployment.institution.id
    }
  end

  defp get_rels_params(%{live_action: :institution} = assigns) do
    %{
      section_id: nil,
      institution_id: assigns.institution.id,
    }
  end
end
