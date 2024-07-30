defmodule OliWeb.Products.Payments.Discounts.ShowView do
  use OliWeb, :live_view
  alias Oli.Delivery.{Paywall, Sections}
  alias Oli.Delivery.Paywall.Discount
  alias Oli.Delivery.Sections.Section
  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias OliWeb.Common.{Breadcrumb, FormContainer}
  alias OliWeb.Products.Payments.Discounts.{Form, ProductsIndexView}
  alias OliWeb.InstitutionController
  alias OliWeb.Router.Helpers, as: Routes

  defp set_breadcrumbs(:product, product, discount_id) do
    ProductsIndexView.set_breadcrumbs(product) ++
      [
        Breadcrumb.new(%{
          full_title: "Manage Discount",
          link: Routes.discount_path(OliWeb.Endpoint, :product, product.slug, discount_id)
        })
      ]
  end

  defp set_breadcrumbs(:product_new, product) do
    ProductsIndexView.set_breadcrumbs(product) ++
      [Breadcrumb.new(%{full_title: "New Discount"})]
  end

  defp set_breadcrumbs(:institution, institution) do
    InstitutionController.root_breadcrumbs() ++
      [
        Breadcrumb.new(%{
          full_title: "#{institution.name}",
          link: Routes.institution_path(OliWeb.Endpoint, :show, institution.id)
        })
      ] ++
      [
        Breadcrumb.new(%{
          full_title: "Discount",
          link: Routes.discount_path(OliWeb.Endpoint, :institution, institution.id)
        })
      ]
  end

  defp mount_for(:product_new = live_action, %{"product_id" => product_slug}, socket) do
    case Sections.get_section_by_slug(product_slug) do
      %Section{type: :blueprint} = product ->
        institutions = Institutions.list_institutions()

        {:ok,
         assign(socket,
           title: "New Discount",
           breadcrumbs: set_breadcrumbs(live_action, product),
           institutions: institutions,
           institution_name: "",
           product: product,
           discount: nil,
           changeset: to_form(Paywall.change_discount(%Discount{})),
           live_action: live_action
         )}

      _ ->
        {:ok,
         Phoenix.LiveView.redirect(socket,
           to: Routes.static_page_path(OliWeb.Endpoint, :not_found)
         )}
    end
  end

  defp mount_for(
         :product = live_action,
         %{"product_id" => product_slug, "discount_id" => discount_id},
         socket
       ) do
    case Sections.get_section_by_slug(product_slug) do
      %Section{type: :blueprint} = product ->
        case Paywall.get_discount_by!(%{id: discount_id}) do
          nil ->
            {:ok,
             Phoenix.LiveView.redirect(socket,
               to: Routes.static_page_path(OliWeb.Endpoint, :not_found)
             )}

          discount ->
            {:ok,
             assign(socket,
               title: "Manage Discount",
               institutions: [],
               breadcrumbs: set_breadcrumbs(live_action, product, discount.id),
               institution: discount.institution,
               institution_name: discount.institution.name,
               product: product,
               discount: discount,
               changeset: to_form(Paywall.change_discount(discount)),
               live_action: live_action
             )}
        end

      _ ->
        {:ok,
         Phoenix.LiveView.redirect(socket,
           to: Routes.static_page_path(OliWeb.Endpoint, :not_found)
         )}
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

        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(live_action, institution),
           institution_name: name,
           title: "Manage Discount",
           institutions: [],
           institution: institution,
           discount: discount,
           changeset: to_form(changeset),
           live_action: live_action
         )}

      _ ->
        {:ok,
         Phoenix.LiveView.redirect(socket,
           to: Routes.static_page_path(OliWeb.Endpoint, :not_found)
         )}
    end
  end

  def mount(params, _session, socket) do
    # Discounts show view used in three routes.
    # live_action is :institution, :product or :product_new
    live_action = socket.assigns.live_action

    mount_for(live_action, params, socket)
  end

  def render(assigns) do
    ~H"""
    <FormContainer.render title={@title}>
      <Form.render
        institution_name={@institution_name}
        institutions={@institutions}
        discount={@discount}
        form={@changeset}
        save="save"
        change="change"
        live_action={@live_action}
        clear="clear"
      />
    </FormContainer.render>
    """
  end

  def handle_event("save", %{"discount" => params}, socket) do
    socket = clear_flash(socket)

    attrs = %{
      section_id:
        if(socket.assigns.live_action == :institution, do: nil, else: socket.assigns.product.id),
      institution_id:
        if(socket.assigns.live_action == :product_new,
          do: get_institution_id(params["institution_id"]),
          else: socket.assigns.institution.id
        ),
      percentage: params["percentage"],
      amount: params["amount"],
      type: params["type"]
    }

    case Paywall.create_or_update_discount(attrs) do
      {:ok, _discount} ->
        {:noreply,
         socket
         |> put_flash(:info, "Discount successfully created/updated.")
         |> push_navigate(to: index_view(socket.assigns))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Discount couldn't be created/updated. Please check the errors below."
         )
         |> assign(changeset: to_form(changeset))}
    end
  end

  def handle_event("clear", _params, socket) do
    socket = clear_flash(socket)

    case Paywall.delete_discount(socket.assigns.discount) do
      {:ok, _discount} ->
        {:noreply,
         socket
         |> put_flash(:info, "Discount successfully cleared.")
         |> assign(discount: nil, changeset: to_form(Paywall.change_discount(%Discount{})))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Discount couldn't be cleared.")
         |> assign(changeset: to_form(changeset))}
    end
  end

  def handle_event("change", %{"discount" => params}, socket) do
    params =
      params
      |> Map.put(
        "percentage",
        if(params["type"] == "percentage", do: params["percentage"], else: nil)
      )
      |> Map.put("amount", if(params["type"] == "fixed_amount", do: params["amount"], else: nil))

    {:noreply,
     assign(socket,
       changeset: Paywall.change_discount(socket.assigns.changeset.data, params) |> to_form()
     )}
  end

  defp get_institution_id(""), do: nil
  defp get_institution_id(id), do: id

  defp index_view(%{live_action: :institution} = assigns),
    do: Routes.institution_path(OliWeb.Endpoint, :show, assigns.institution.id)

  defp index_view(assigns),
    do:
      Routes.live_path(
        OliWeb.Endpoint,
        OliWeb.Products.Payments.Discounts.ProductsIndexView,
        assigns.product.slug
      )
end
