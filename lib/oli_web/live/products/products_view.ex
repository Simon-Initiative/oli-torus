defmodule OliWeb.Products.ProductsView do
  use OliWeb, :live_view
  alias Oli.Repo
  alias OliWeb.Common.{Breadcrumb, Filter, Listing, SessionContext}
  alias OliWeb.Products.Create
  alias Oli.Authoring.Course
  alias Oli.Accounts.Author
  alias Oli.Delivery.Sections.Blueprint
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Publishing

  @table_filter_fn &OliWeb.Products.ProductsView.filter_rows/3
  @table_push_patch_path &OliWeb.Products.ProductsView.live_path/2

  def filter_rows(socket, query, _filter) do
    case String.downcase(query) do
      "" ->
        socket.assigns.products

      str ->
        Enum.filter(socket.assigns.products, fn p ->
          amount_str =
            if p.requires_payment do
              case Money.to_string(p.amount) do
                {:ok, money} -> String.downcase(money)
                _ -> ""
              end
            else
              "none"
            end

          String.contains?(String.downcase(p.title), str) or
            String.contains?(String.downcase(p.base_project.title), str) or
            String.contains?(amount_str, str)
        end)
    end
  end

  def live_path(socket, params) do
    if socket.assigns.is_admin_view do
      Routes.live_path(socket, OliWeb.Products.ProductsView, params)
    else
      Routes.live_path(socket, OliWeb.Products.ProductsView, socket.assigns.project.slug, params)
    end
  end

  defp admin_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Products",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def mount(
        %{"project_id" => project_slug},
        %{"current_author_id" => author_id} = session,
        socket
      ) do
    author = Repo.get(Author, author_id)
    project = Course.get_project_by_slug(project_slug)
    products = Blueprint.list_for_project(project)

    mount_as(
      author,
      false,
      products,
      project,
      breadcrumb([]),
      "Products | " <> project.title,
      socket,
      session
    )
  end

  def mount(_, %{"current_author_id" => author_id} = session, socket) do
    author = Repo.get(Author, author_id)

    products = Blueprint.list()
    mount_as(author, true, products, nil, admin_breadcrumbs(), "Products", socket, session)
  end

  defp mount_as(author, is_admin_view, products, project, breadcrumbs, title, socket, session) do
    total_count = length(products)

    ctx = SessionContext.init(socket, session)
    {:ok, table_model} = OliWeb.Products.ProductsTableModel.new(products, ctx)

    published? =
      case project do
        nil -> true
        _ -> Publishing.project_published?(project.slug)
      end

    {:ok,
     assign(socket,
       breadcrumbs: breadcrumbs,
       is_admin_view: is_admin_view,
       author: author,
       project: project,
       published?: published?,
       products: products,
       total_count: total_count,
       table_model: table_model,
       title: title,
       offset: 0,
       limit: 20,
       query: "",
       applied_query: "",
       creation_title: ""
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <%= if @published? do %>
        <%= if @is_admin_view == false do %>
          <Create.render title={@creation_title} change="title" click="create" />
        <% else %>
          <Filter.render change="change_search" reset="reset_search" apply="apply_search" />
        <% end %>

        <div class="mb-3" />

        <Listing.render
          filter={@query}
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          sort="sort"
          page_change="page_change"
        />
      <% else %>
        <div>Products cannot be created until project is published.</div>
      <% end %>
    </div>
    """
  end

  def handle_event("title", %{"value" => title}, socket) do
    {:noreply, assign(socket, creation_title: title)}
  end

  def handle_event("create", _, socket) do
    customizations =
      case socket.assigns.project.customizations do
        nil -> nil
        labels -> Map.from_struct(labels)
      end

    case Blueprint.create_blueprint(
           socket.assigns.project.slug,
           socket.assigns.creation_title,
           customizations
         ) do
      {:ok, blueprint} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product successfully created.")
         |> redirect(to: Routes.live_path(socket, OliWeb.Products.DetailsView, blueprint.slug))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create product")}
    end
  end

  def handle_event("hide_overview", _, socket) do
    {:noreply, assign(socket, show_feature_overview: false)}
  end

  use OliWeb.Common.SortableTable.TableHandlers
end
