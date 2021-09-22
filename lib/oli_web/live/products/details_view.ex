defmodule OliWeb.Products.DetailsView do
  use Surface.LiveView

  alias Oli.Repo
  alias OliWeb.Common.Breadcrumb
  alias Oli.Accounts.Author
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Branding
  alias OliWeb.Products.Details.{Actions, Edit, Content}

  data breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Course Product"})]
  data product, :any, default: nil
  prop author, :any

  def mount(%{"product_id" => product_slug}, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)
    product = Blueprint.get_blueprint(product_slug)

    available_brands =
      Branding.list_brands()
      |> Enum.map(fn brand -> {brand.name, brand.id} end)

    {:ok,
     assign(socket,
       available_brands: available_brands,
       updates: Sections.check_for_available_publication_updates(product),
       author: author,
       product: product,
       changeset: Section.changeset(product, %{}),
       title: "Edit Product"
     )}
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
          <Edit product={@product} changeset={@changeset} available_brands={@available_brands}/>
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
          <Actions product={@product}/>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("validate", %{"section" => params}, socket) do
    changeset =
      socket.assigns.product
      |> Sections.change_section(params)

    {:noreply, assign(socket, changeset: changeset)}
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
