defmodule OliWeb.Products.ProductsView do
  use Surface.LiveView
  alias Oli.Repo
  alias OliWeb.Products.Create
  alias OliWeb.Products.Filter
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
  data breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Course Products"})]
  data title, :string, default: "Course Products"

  data creation_title, :string, default: ""
  data products, :list, default: []
  data tabel_model, :struct
  data total_count, :integer, default: 0
  data offset, :integer, default: 0
  data limit, :integer, default: 20
  data fitler, :string, default: ""
  data show_feature_overview, :boolean, default: true

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

      {#if @is_admin_view == false}
        {#if @show_feature_overview}
          <div class="alert alert-dismissable alert-info" role="alert" style="max-width: 800px;">

            <button type="button" class="close" data-dismiss="alert" aria-label="Close" :on-click="hide_overview">
              <span aria-hidden="true">&times;</span>
            </button>
            <p><strong>Course Products</strong> are a new concept and feature that will allow a project author to: </p>

            <ul>
            <li>Provide alternate arrangements of their project content.</li>
            <li>Incorporate content from other projects.</li>
            <li>Associate a required a payment for content.</li>
            </ul>

            <hr>
            <p class="mb-0">
              Not all of these features are available right now, but feel free to begin experimenting with creating products
              for your course.
            </p>

          </div>
        {/if}

        <Create id="creation" title={@creation_title} change="title" click="create"/>
      {#else}
        <Filter id="filter" change={"change_filter"} reset="reset_filter"/>
      {/if}

      <div class="mb-3"/>

      <Listing
        filter={@filter}
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

  def handle_event("change_filter", %{"text" => filter}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           get_patch_params(
             socket.assigns.table_model,
             socket.assigns.offset,
             filter
           )
         )
     )}
  end

  def handle_event("reset_filter", _, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           get_patch_params(
             socket.assigns.table_model,
             socket.assigns.offset,
             ""
           )
         )
     )}
  end

  def handle_event("page_change", %{"offset" => offset}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           get_patch_params(
             socket.assigns.table_model,
             String.to_integer(offset),
             socket.assigns.filter
           )
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
       to:
         Routes.live_path(
           socket,
           __MODULE__,
           get_patch_params(table_model, offset, socket.assigns.filter)
         )
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

  def handle_event("hide_overview", _, socket) do
    {:noreply, assign(socket, show_feature_overview: false)}
  end

  defp get_patch_params(table_model, offset, filter) do
    Map.merge(%{offset: offset, filter: filter}, SortableTableModel.to_params(table_model))
  end

  def handle_params(params, _, socket) do
    offset = get_int_param(params, "offset", 0)

    # Ensure that the offset is 0 or one minus a factor of the limit. So for a
    # limit of 20, valid offsets or 0, 20, 40, etc.  This logic overrides any attempt
    # to manually change URL offset param.
    offset =
      case rem(offset, socket.assigns.limit) do
        0 -> offset
        _ -> 0
      end

    filter = get_str_param(params, "filter", "")

    # First update the rows of the sortable table model to be all products, then apply the sort,
    # then slice the model rows according to the paging settings

    filtered =
      case String.downcase(filter) do
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

            String.contains?(String.downcase(p.title), str) or String.contains?(amount_str, str)
          end)
      end

    table_model =
      Map.put(socket.assigns.table_model, :rows, filtered)
      |> SortableTableModel.update_from_params(params)
      |> then(fn table_model ->
        Map.put(table_model, :rows, Enum.slice(table_model.rows, offset, socket.assigns.limit))
      end)

    {:noreply,
     assign(socket,
       table_model: table_model,
       offset: offset,
       filter: filter,
       total_count: length(filtered)
     )}
  end

  defp get_int_param(params, name, default_value) do
    case params[name] do
      nil ->
        default_value

      value ->
        case Integer.parse(value) do
          {num, _} -> num
          _ -> default_value
        end
    end
  end

  defp get_str_param(params, name, default_value) do
    case params[name] do
      nil ->
        default_value

      value ->
        value
    end
  end
end
