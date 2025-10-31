defmodule OliWeb.Products.Payments.Discounts.ShowView do
  use OliWeb, :live_view
  alias Oli.Accounts
  alias Oli.Authoring.Course
  alias Oli.Delivery.{Paywall, Sections}
  alias Oli.Delivery.Paywall.Discount
  alias Oli.Delivery.Sections.Section
  alias Oli.Institutions
  alias Oli.Institutions.Institution
  alias OliWeb.Common.{Breadcrumb, FormContainer}
  alias OliWeb.Products.Payments.Discounts.{Form, ProductsIndexView}
  alias OliWeb.InstitutionController

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  defp set_breadcrumbs(:product, product, discount_id, project) do
    ProductsIndexView.set_breadcrumbs(product, project) ++
      [
        Breadcrumb.new(%{
          full_title: "Manage Discount",
          link:
            ~p"/workspaces/course_author/#{project.slug}/products/#{product.slug}/discounts/#{discount_id}"
        })
      ]
  end

  defp set_breadcrumbs(:product_new, product, project) do
    ProductsIndexView.set_breadcrumbs(product, project) ++
      [Breadcrumb.new(%{full_title: "New Discount"})]
  end

  defp set_breadcrumbs(:institution, institution) do
    InstitutionController.root_breadcrumbs() ++
      [
        Breadcrumb.new(%{
          full_title: "#{institution.name}",
          link: ~p"/admin/institutions/#{institution.id}"
        })
      ] ++
      [
        Breadcrumb.new(%{
          full_title: "Discount",
          link: ~p"/admin/institutions/#{institution.id}/discount"
        })
      ]
  end

  defp mount_for(:product_new = live_action, %{"project_id" => project_slug, "product_id" => product_slug}, socket) do
    case fetch_project_and_product(project_slug, product_slug) do
      {:ok, project, product} ->
        institutions = Institutions.list_institutions()

        {:ok,
         assign(socket,
           title: "New Discount",
           breadcrumbs: set_breadcrumbs(live_action, product, project),
           institutions: institutions,
           institution_name: "",
           product: product,
           project: project,
           project_slug: project.slug,
           discount: nil,
           changeset: to_form(Paywall.change_discount(%Discount{})),
           live_action: live_action
         )}

      :error ->
        {:ok, redirect(socket, to: ~p"/not_found")}
    end
  end

  defp mount_for(
         :product = live_action,
         %{"project_id" => project_slug, "product_id" => product_slug, "discount_id" => discount_id},
         socket
       ) do
    with {:ok, project, product} <- fetch_project_and_product(project_slug, product_slug),
         %Discount{} = discount <- Paywall.get_discount_by!(%{id: discount_id}) do
      {:ok,
       assign(socket,
         title: "Manage Discount",
         institutions: [],
         breadcrumbs: set_breadcrumbs(live_action, product, discount.id, project),
         institution: discount.institution,
         institution_name: discount.institution && discount.institution.name,
         product: product,
         project: project,
         project_slug: project.slug,
         discount: discount,
         changeset: to_form(Paywall.change_discount(discount)),
         live_action: live_action
       )}
    else
      _ ->
        {:ok, redirect(socket, to: ~p"/not_found")}
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
        {:ok, redirect(socket, to: ~p"/not_found")}
    end
  end

  def mount(params, _session, socket) do
    # Discounts show view used in three routes.
    # live_action is :institution, :product or :product_new
    live_action = socket.assigns.live_action
    author = socket.assigns.ctx.author

    case live_action do
      action when action in [:product, :product_new] ->
        project_slug = Map.get(params, "project_id")
        product_slug = Map.get(params, "product_id")

        if Accounts.has_admin_role?(author, :content_admin) do
          mount_for(live_action, params, socket)
        else
          {:ok,
           socket
           |> put_flash(:error, "You do not have access to product discounts.")
           |> redirect(to: ~p"/workspaces/course_author/#{project_slug}/products/#{product_slug}")}
        end

      _other ->
        mount_for(live_action, params, socket)
    end
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
      type: params["type"],
      bypass_paywall: params["bypass_paywall"] == "true"
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
        if(params["type"] == "percentage" and params["bypass_paywall"] != "true",
          do: params["percentage"],
          else: nil
        )
      )
      |> Map.put(
        "amount",
        if(params["type"] == "fixed_amount" and params["bypass_paywall"] != "true",
          do: params["amount"],
          else: nil
        )
      )

    {:noreply,
     assign(socket,
       changeset: Paywall.change_discount(socket.assigns.changeset.data, params) |> to_form()
     )}
  end

  defp get_institution_id(""), do: nil
  defp get_institution_id(id), do: id

  defp fetch_project_and_product(project_slug, product_slug) do
    with %{} = project <- Course.get_project_by_slug(project_slug),
         %Section{type: :blueprint} = product <- Sections.get_section_by_slug(product_slug),
         true <- product.base_project_id == project.id do
      {:ok, project, product}
    else
      _ -> :error
    end
  end

  defp index_view(%{live_action: :institution, institution: institution}),
    do: ~p"/admin/institutions/#{institution.id}"

  defp index_view(%{project_slug: project_slug, product: product}),
    do: ~p"/workspaces/course_author/#{project_slug}/products/#{product.slug}/discounts"
end
