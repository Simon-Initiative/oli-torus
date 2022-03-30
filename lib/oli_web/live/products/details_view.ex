defmodule OliWeb.Products.DetailsView do
  use Surface.LiveView

  alias Oli.Repo
  alias OliWeb.Common.Breadcrumb
  alias Oli.Accounts.Author
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Branding
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Common.Confirm
  alias OliWeb.Sections.Mount
  alias OliWeb.Products.Details.{Actions, Edit, Content}

  data breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Course Product"})]
  data product, :any, default: nil
  data show_confirm, :boolean, default: false
  prop author, :any
  prop is_admin, :boolean

  def set_breadcrumbs(section),
    do: [Breadcrumb.new(%{
      full_title: section.title,
      link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
    })]

  def mount(
        %{"product_id" => product_slug},
        %{"current_author_id" => author_id} = session,
        socket
      ) do
    case Mount.for(product_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {_, _, product} ->
        author = Repo.get(Author, author_id)

        available_brands =
          Branding.list_brands()
          |> Enum.map(fn brand -> {brand.name, brand.id} end)

        {:ok,
         assign(socket,
           available_brands: available_brands,
           updates: Sections.check_for_available_publication_updates(product),
           author: author,
           product: product,
           is_admin: Oli.Accounts.is_admin?(author),
           changeset: Section.changeset(product, %{}),
           title: "Edit Product"
         )}
    end
  end

  def render(assigns) do
    ~F"""
    <div class="overview container">
      <div class="row py-5 border-bottom">
        <div class="col-md-4">
          <h4>Details</h4>
          <div class="text-muted">
            The Product title and description will be shown
            to instructors when they create their course section.
          </div>
        </div>
        <div class="col-md-8">
          <Edit product={@product} changeset={@changeset} available_brands={@available_brands} is_admin={@is_admin}/>
        </div>
      </div>
      <div class="row py-5 border-bottom">
        <div class="col-md-4">
          <h4>Content</h4>
          <div class="text-muted">
            Manage and customize the presentation of content in this product.
          </div>
        </div>
        <div class="col-md-8">
          <Content product={@product} updates={@updates}/>
        </div>
      </div>
      <div class="row py-5">
        <div class="col-md-4">
          <h4>Actions</h4>
        </div>
        <div class="col-md-8">
          <Actions product={@product} is_admin={@is_admin}/>
        </div>
      </div>
      {#if @show_confirm}
        <Confirm title="Confirm Duplication" id="dialog" ok="duplicate" cancel="cancel_modal">
          Are you sure that you wish to duplicate this product?
        </Confirm>
      {/if}
    </div>
    """
  end

  def handle_event("validate", %{"section" => params}, socket) do
    changeset =
      socket.assigns.product
      |> Sections.change_section(params)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("request_duplicate", _, socket) do
    {:noreply, assign(socket, show_confirm: true)}
  end

  def handle_event("cancel_modal", _, socket) do
    {:noreply, socket}
  end

  def handle_event("_bsmodal.unmount", _, socket) do
    {:noreply, assign(socket, show_confirm: false)}
  end

  def handle_event("duplicate", _, socket) do
    case Blueprint.duplicate(socket.assigns.product) do
      {:ok, duplicate} ->
        {:noreply,
         redirect(socket,
           to: Routes.live_path(socket, OliWeb.Products.DetailsView, duplicate.slug)
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not duplicate product")}
    end
  end

  def handle_event("save", %{"section" => params}, socket) do
    case Sections.update_section(socket.assigns.product, params) do
      {:ok, section} ->
        socket = put_flash(socket, :info, "Product changes saved")

        {:noreply, assign(socket, product: section, changeset: Section.changeset(section, %{}))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
