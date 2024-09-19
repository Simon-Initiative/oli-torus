defmodule OliWeb.Workspaces.CourseAuthor.ProductsLive do
  use OliWeb, :live_view
  use OliWeb, :verified_routes

  import Phoenix.Component
  import OliWeb.DelegatedEvents

  alias __MODULE__
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Publishing
  alias Oli.Repo.Paging
  alias Oli.Repo.Sorting
  alias OliWeb.Common.Check
  alias OliWeb.Common.PagedTable
  alias OliWeb.Common.Params
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Products.ProductsTableModel

  @max_items_per_page 20
  @initial_offset 0
  @initial_create_form to_form(%{"product_title" => ""}, as: "product_form")

  @impl Phoenix.LiveView
  def mount(params, session, socket) do
    project = socket.assigns.project
    include_archived = Params.get_boolean_param(params, "include_archived", false)

    products = get_products(socket.assigns)

    ctx = SessionContext.init(socket, session)
    {:ok, table_model} = ProductsTableModel.new(products, ctx, project.slug)
    published? = Publishing.project_published?(project.slug)

    {:ok,
     assign(socket,
       resource_slug: project.slug,
       resource_title: project.title,
       published?: published?,
       is_admin_view: false,
       include_archived: include_archived,
       limit: @max_items_per_page,
       offset: @initial_offset,
       table_model: table_model,
       create_product_form: @initial_create_form,
       ctx: ctx
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    table_model = SortableTableModel.update_from_params(socket.assigns.table_model, params)
    table_model = Map.put(table_model, :rows, table_model.rows)
    socket = assign(socket, table_model: table_model)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div>
      <%= if @published? do %>
        <.form
          :let={f}
          for={@create_product_form}
          as={:create_product_form}
          class="full flex items-end w-full gap-1"
          phx-submit="create"
        >
          <div class="flex flex-col-reverse phx-no-feedback w-[40%]">
            <.input
              class="full"
              field={f[:product_title]}
              label="Create a new product with title:"
              required
            />
          </div>
          <button class="btn btn-primary">
            Create Product
          </button>
        </.form>

        <Check.render checked={@include_archived} click="include_archived">
          Include archived Products
        </Check.render>

        <div class="mb-3" />

        <PagedTable.render
          page_change="paged_table_page_change"
          sort="paged_table_sort"
          total_count={Enum.count(@table_model.rows)}
          limit={@limit}
          offset={@offset}
          table_model={@table_model}
        />
      <% else %>
        <div>Products cannot be created until project is published.</div>
      <% end %>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event(
        "create",
        %{"create_product_form" => %{"product_title" => product_title}},
        socket
      ) do
    %{customizations: customizations, slug: project_slug} = socket.assigns.project

    customizations =
      case customizations do
        nil -> nil
        labels -> Map.from_struct(labels)
      end

    blueprint = Blueprint.create_blueprint(project_slug, product_title, customizations)

    case blueprint do
      {:ok, _blueprint} ->
        products = get_products(socket.assigns)

        {:ok, table_model} = ProductsTableModel.new(products, socket.assigns.ctx, project_slug)

        {:noreply,
         socket
         |> put_flash(:info, "Product successfully created.")
         |> assign(table_model: table_model)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create product")}
    end
  end

  def handle_event("include_archived", __params, socket) do
    project_id = if socket.assigns.project === nil, do: nil, else: socket.assigns.project.id

    include_archived = !socket.assigns.include_archived

    %{offset: offset, limit: limit, table_model: table_model} = socket.assigns

    products =
      Blueprint.browse(
        %Paging{offset: offset, limit: limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        include_archived: include_archived,
        project_id: project_id
      )

    table_model = Map.put(table_model, :rows, products)

    socket =
      assign(socket,
        include_archived: include_archived,
        products: products,
        table_model: table_model
      )

    patch_with(socket, %{include_archived: include_archived})
  end

  def handle_event("hide_overview", _, socket) do
    {:noreply, assign(socket, show_feature_overview: false)}
  end

  def handle_event(event, params, socket) do
    delegate_to({event, params, socket, &ProductsLive.patch_with/2}, [
      &PagedTable.handle_delegated/4
    ])
  end

  def live_path(socket, params) do
    ~p"/workspaces/course_author/#{socket.assigns.project.slug}/products?#{params}"
  end

  def patch_with(socket, changes) do
    path = live_path(socket, Map.merge(url_params(socket.assigns), changes))

    {:noreply, push_patch(socket, to: path, replace: true)}
  end

  defp url_params(assigns) do
    %{
      sort_by: assigns.table_model.sort_by_spec.name,
      sort_order: assigns.table_model.sort_order,
      offset: assigns.offset,
      include_archived: assigns.include_archived,
      sidebar_expanded: assigns.sidebar_expanded
    }
  end

  defp get_products(assigns) do
    offset = assigns[:offset] || @initial_offset
    limit = assigns[:limit] || @max_items_per_page

    table_model = assigns[:table_model]
    direction = if table_model, do: assigns.table_model.sort_order, else: :asc
    field = if table_model, do: assigns.table_model.sort_by_spec.name, else: :title

    include_archived = get_in(assigns, [:include_archived]) || false

    Blueprint.browse(
      %Paging{offset: offset, limit: limit},
      %Sorting{direction: direction, field: field},
      include_archived: include_archived,
      project_id: assigns.project.id
    )
  end
end
