defmodule OliWeb.Workspaces.CourseAuthor.ProductsLive do
  use OliWeb, :live_view
  use OliWeb, :verified_routes

  import Phoenix.Component
  import OliWeb.DelegatedEvents

  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Publishing
  alias Oli.Repo.Paging
  alias Oli.Repo.Sorting
  alias OliWeb.Common.Check
  alias OliWeb.Common.PagedTable
  alias OliWeb.Common.Params
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Common.TextSearch
  alias OliWeb.Products.ProductsTableModel

  @limit 20

  @impl Phoenix.LiveView
  def mount(params, session, socket) do
    project = socket.assigns.project
    include_archived = Params.get_boolean_param(params, "include_archived", false)

    products =
      Blueprint.browse(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title},
        text_search: Params.get_param(params, "text_search", ""),
        include_archived: include_archived,
        project_id: project.id
      )

    total_count = determine_total(products)
    ctx = SessionContext.init(socket, session)

    {:ok, table_model} = ProductsTableModel.new(products, ctx, project.slug)

    published? =
      case project do
        nil -> true
        _ -> Publishing.project_published?(project.slug)
      end

    create_product_form = to_form(%{"product_title" => ""}, as: "product_title")

    {:ok,
     assign(socket,
       resource_slug: project.slug,
       resource_title: project.title,
       active_workspace: :course_author,
       active_view: :products,
       published?: published?,
       is_admin_view: false,
       include_archived: include_archived,
       total_count: total_count,
       text_search: "",
       limit: @limit,
       offset: 0,
       table_model: table_model,
       creation_title: "",
       create_product_form: create_product_form,
       ctx: ctx
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(socket.assigns.table_model, params)

    offset = Params.get_int_param(params, "offset", 0)
    text_search = Params.get_param(params, "text_search", "")
    include_archived = Params.get_boolean_param(params, "include_archived", false)

    products =
      Blueprint.browse(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        text_search: text_search,
        include_archived: include_archived,
        project_id: socket.assigns.project && socket.assigns.project.id
      )

    table_model = Map.put(table_model, :rows, products)

    total_count = determine_total(products)

    {:noreply,
     assign(socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count,
       text_search: text_search,
       include_archived: include_archived
     )}
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
          total_count={@total_count}
          filter={@text_search}
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

    case Blueprint.create_blueprint(project_slug, product_title, customizations) do
      {:ok, blueprint} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product successfully created.")
         |> redirect(to: ~p"/workspaces/course_author/#{project_slug}/products/#{blueprint.slug}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create product")}
    end
  end

  def handle_event("include_archived", __params, socket) do
    project_id = if socket.assigns.project === nil, do: nil, else: socket.assigns.project.id

    include_archived = !socket.assigns.include_archived

    %{offset: offset, limit: limit, table_model: table_model, text_search: text_search} =
      socket.assigns

    products =
      Blueprint.browse(
        %Paging{offset: offset, limit: limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        text_search: text_search,
        include_archived: include_archived,
        project_id: project_id
      )

    total_count = length(products)
    table_model = Map.put(table_model, :rows, products)

    socket =
      assign(socket,
        include_archived: include_archived,
        products: products,
        total_count: total_count,
        table_model: table_model
      )

    patch_with(socket, %{include_archived: include_archived})
  end

  def handle_event("hide_overview", _, socket) do
    {:noreply, assign(socket, show_feature_overview: false)}
  end

  def handle_event(event, params, socket) do
    delegate_to({event, params, socket, &__MODULE__.patch_with/2}, [
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  def live_path(socket, params) do
    ~p"/workspaces/course_author/#{socket.assigns.project.slug}/products?#{params}"
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
               text_search: socket.assigns.text_search,
               include_archived: socket.assigns.include_archived
             },
             changes
           )
         ),
       replace: true
     )}
  end

  defp determine_total([]), do: 0
  defp determine_total([hd | _]), do: hd.total_count
end
