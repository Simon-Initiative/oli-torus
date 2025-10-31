defmodule OliWeb.Products.Payments.Discounts.ProductsIndexView do
  use OliWeb, :live_view
  use OliWeb.Common.SortableTable.TableHandlers

  alias Oli.Accounts
  alias Oli.Authoring.Course
  alias Oli.Delivery.{Sections, Paywall}
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Common.{Breadcrumb, Listing}
  alias OliWeb.Products.Payments.Discounts.TableModel
  alias OliWeb.Workspaces.CourseAuthor.Products.DetailsLive

  @table_filter_fn &__MODULE__.filter_rows/3
  @table_push_patch_path &__MODULE__.live_path/2

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def filter_rows(socket, _, _), do: socket.assigns.discounts

  def live_path(socket, params) do
    project_slug = socket.assigns.project_slug
    product_slug = socket.assigns.product.slug

    base = ~p"/workspaces/course_author/#{project_slug}/products/#{product_slug}/discounts"

    filtered =
      params
      |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
      |> Enum.reject(fn {_k, v} -> is_map(v) end)

    case filtered do
      [] ->
        base

      filtered ->
        query = filtered |> Map.new() |> URI.encode_query()
        base <> "?" <> query
    end
  end

  def set_breadcrumbs(product, project) do
    DetailsLive.set_breadcrumbs(product, project) ++
      [
        Breadcrumb.new(%{
          full_title: "Discounts",
          link: ~p"/workspaces/course_author/#{project.slug}/products/#{product.slug}/discounts"
        })
      ]
  end

  def mount(%{"project_id" => project_slug, "product_id" => product_slug}, _session, socket) do
    author = socket.assigns.ctx.author

    unless Accounts.has_admin_role?(author, :content_admin) do
      {:ok,
       socket
       |> put_flash(:error, "You do not have access to product discounts.")
       |> redirect(to: ~p"/workspaces/course_author/#{project_slug}/products/#{product_slug}")}
    else
      with %Section{type: :blueprint} = product <- Sections.get_section_by_slug(product_slug),
           %Oli.Authoring.Course.Project{} = project <-
             Course.get_project_by_slug(project_slug),
           true <- product.base_project_id == project.id do
        discounts = Paywall.get_product_discounts(product.id)
        ctx = socket.assigns.ctx

        {:ok, table_model} = TableModel.new(discounts, ctx, project_slug: project.slug)

        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(product, project),
           discounts: discounts,
           table_model: table_model,
           total_count: length(discounts),
           product: product,
           project: project,
           project_slug: project.slug,
           title: "Discounts",
           query: "",
           offset: 0,
           limit: 20
         )}
      else
        _ ->
          {:ok,
           socket
           |> put_flash(:error, "Discounts are unavailable for this product.")
           |> redirect(to: ~p"/workspaces/course_author/#{project_slug}/products/#{product_slug}")}
      end
    end
  end

  def render(assigns) do
    ~H"""
    <.link
      href={~p"/workspaces/course_author/#{@project_slug}/products/#{@product.slug}/discounts/new"}
      class="btn btn-outline-primary float-right"
    >
      Create Discount
    </.link>

    <div id="discounts-table" class="p-4">
      <Listing.render
        filter={@query}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
        sort="sort"
        page_change="page_change"
        show_bottom_paging={false}
      />
    </div>
    """
  end

  def handle_event("remove", %{"id" => id}, socket) do
    socket = clear_flash(socket)

    discount = Paywall.get_discount_by!(%{id: String.to_integer(id)})

    case Paywall.delete_discount(discount) do
      {:ok, _discount} ->
        discounts = Paywall.get_product_discounts(socket.assigns.product.id)

        {:ok, table_model} =
          TableModel.new(discounts, socket.assigns.ctx, project_slug: socket.assigns.project_slug)

        {:noreply,
         socket
         |> put_flash(:info, "Discount successfully removed.")
         |> assign(discounts: discounts, table_model: table_model, total_count: length(discounts))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Discount couldn't be removed.")}
    end
  end
end
