defmodule OliWeb.Products.ProductsView do
  use Surface.LiveView
  alias Oli.Repo
  alias OliWeb.Products.Create
  alias OliWeb.Products.Listing
  alias OliWeb.Common.Breadcrumb
  alias Oli.Authoring.Course
  alias Oli.Accounts.Author
  alias Oli.Delivery.Sections.Blueprint
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes

  prop is_admin_view, :boolean
  prop project, :any
  prop author, :any
  prop breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Course Products"})]
  data title, :string, default: "Course Products"

  data creation_title, :string, default: ""
  data products, :list, default: []
  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: 20

  def mount(%{"project_id" => project_slug}, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)
    project = Course.get_project_by_slug(project_slug)
    products = Blueprint.list_for_project(project)

    mount_as(author, false, products, project, socket)
  end

  def mount(_, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)

    products = Blueprint.list()
    mount_as(author, true, products, nil, socket)
  end

  defp mount_as(author, is_admin_view, products, project, socket) do
    total_count = length(products)

    {:ok, table_model} = OliWeb.Products.ProductsTableModel.new(products)

    {:ok,
     assign(socket,
       is_admin_view: is_admin_view,
       author: author,
       project: project,
       products: products,
       total_count: total_count,
       table_model: table_model
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

      <Listing
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
        sort="sort"
        page_change="page_change"/>

    </div>

    """
  end

  def handle_event("title", %{"value" => title}, socket) do
    {:noreply, assign(socket, creation_title: title)}
  end

  def handle_event("page_change", %{"offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           get_patch_params(socket.assigns.table_model, String.to_integer(offset))
         )
     )}
  end

  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    table_model =
      SortableTableModel.update_sort_params(
        socket.assigns.table_model,
        String.to_existing_atom(sort_by)
      )

    offset = socket.assigns.offset

    {:noreply,
     push_patch(socket,
       to: Routes.live_path(socket, __MODULE__, get_patch_params(table_model, offset))
     )}
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

  defp get_patch_params(table_model, offset) do
    Map.merge(%{offset: offset}, SortableTableModel.to_params(table_model))
  end

  def handle_params(params, _, socket) do
    offset =
      case params["offset"] do
        nil ->
          0

        offset ->
          case Integer.parse(offset) do
            {num, _} -> num
            _ -> 0
          end
      end

    tabel_model =
      Map.put(
        socket.assigns.table_model,
        :rows,
        Enum.slice(socket.assigns.products, offset, socket.assigns.limit)
      )
      |> SortableTableModel.update_from_params(params)

    {:noreply, assign(socket, table_model: tabel_model, offset: offset)}
  end
end
