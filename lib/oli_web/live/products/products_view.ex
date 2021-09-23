defmodule OliWeb.Products.ProductsView do
  use Surface.LiveView
  alias Oli.Repo
  alias OliWeb.Products.Create
  alias OliWeb.Products.Listing
  alias OliWeb.Common.Breadcrumb
  alias Oli.Authoring.Course
  alias Oli.Accounts.Author
  alias Oli.Delivery.Sections.Blueprint

  data creation_title, :string, default: ""
  data breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Course Products"})]
  data products, :list, default: []
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: 20
  prop is_admin_view, :boolean
  prop project, :any
  prop author, :any
  data title, :string, default: "Course Products"

  def mount(%{"project_id" => project_slug}, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)
    project = Course.get_project_by_slug(project_slug)

    products = Blueprint.list_for_project(project)
    total_count = length(products)

    {:ok,
     assign(socket,
       is_admin_view: false,
       author: author,
       project: project,
       products: products,
       total_count: total_count
     )}
  end

  def mount(_, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)

    products = Blueprint.list()
    total_count = length(products)

    {:ok,
     assign(socket,
       is_admin_view: true,
       author: author,
       project: nil,
       products: products,
       total_count: total_count
     )}
  end

  def render(assigns) do
    ~F"""
    <div>
      <h3>Course Products</h3>

      {#if @is_admin_view == false}
        <Create id="creation" title={@creation_title} change="title" click="create"/>
        <hr/>
      {/if}

      <Listing id="listing" products={@products} total_count={@total_count} offset={@offset} limit={@limit} page_change="page_change"/>

    </div>

    """
  end

  def handle_event("title", %{"value" => title}, socket) do
    {:noreply, assign(socket, creation_title: title)}
  end

  def handle_event("page_change", %{"offset" => offset, "limit" => limit}, socket) do
    {:noreply, assign(socket, offset: String.to_integer(offset), limit: String.to_integer(limit))}
  end

  def handle_event("create", _, socket) do
    case Blueprint.create_blueprint(socket.assigns.project.slug, socket.assigns.creation_title) do
      {:ok, blueprint} ->
        blueprint = Repo.preload(blueprint, :base_project)

        {:noreply,
         assign(socket,
           products: List.insert_at(socket.assigns.products, socket.assigns.offset, blueprint),
           total_count: socket.assigns.total_count + 1
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create product")}
    end
  end
end
