defmodule OliWeb.Workspaces.CourseAuthor.ProductsLive do
  use OliWeb, :live_view
  use OliWeb, :verified_routes

  import Phoenix.Component

  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Repo.Paging
  alias Oli.Repo.Sorting
  alias Oli.Publishing
  # alias OliWeb.Products.Create
  alias OliWeb.Common.Check
  alias OliWeb.Common.PagedTable
  alias OliWeb.Common.Params
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.TextSearch

  @limit 20
  # @text_search_tooltip "Search by section title, amount or base project title."

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

    {:ok, table_model} = OliWeb.Products.ProductsTableModel.new(products, ctx)

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
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div>
      <%= if @published? do %>
        <%= if @is_admin_view do %>
          <TextSearch.render
            id="text-search"
            reset="text_search_reset"
            change="text_search_change"
            text={@text_search}
            event_target={nil}
            tooltip={@text_search_tooltip}
          />
        <% else %>
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
        <% end %>

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
    %{id: project_id, customizations: customizations, slug: project_slug} = socket.assigns.project

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
         |> redirect(to: Routes.live_path(socket, OliWeb.Products.DetailsView, blueprint.slug))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create product")}
    end
  end

  defp determine_total([]), do: 0
  defp determine_total([hd | _]), do: hd.total_count
end
