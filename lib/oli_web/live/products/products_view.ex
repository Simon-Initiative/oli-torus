defmodule OliWeb.Products.ProductsView do
  use OliWeb, :live_view

  import OliWeb.DelegatedEvents

  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Publishing
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Admin.AdminView
  alias OliWeb.Common.{Breadcrumb, Check, PagingParams, StripedPagedTable, Params, SearchInput}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Icons
  alias OliWeb.Products.{Create, DetailsView, ProductsTableModel}
  alias OliWeb.Router.Helpers, as: Routes

  @limit 20
  @text_search_tooltip """
    Search by section title, amount or base project title.
  """

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def live_path(socket, params) do
    if socket.assigns.is_admin_view,
      do: ~p"/admin/products",
      else: ~p"/authoring/project/#{socket.assigns.project.slug}/products?#{params}"
  end

  defp admin_breadcrumbs() do
    AdminView.breadcrumb()
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
        %{"project_id" => project_slug} = params,
        _session,
        socket
      ) do
    author = socket.assigns.current_author

    project = Course.get_project_by_slug(project_slug)

    mount_as(
      params,
      author,
      false,
      project,
      breadcrumb([]),
      "Products | " <> project.title,
      socket
    )
  end

  def mount(params, _session, socket) do
    author = socket.assigns.current_author

    mount_as(params, author, true, nil, admin_breadcrumbs(), "Products", socket)
  end

  defp mount_as(params, author, is_admin_view, project, breadcrumbs, title, socket) do
    project_id = if project === nil, do: nil, else: project.id

    products =
      Blueprint.browse(
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title},
        text_search: Params.get_param(params, "text_search", ""),
        include_archived: Params.get_boolean_param(params, "include_archived", false),
        project_id: project_id
      )

    total_count = determine_total(products)

    ctx = socket.assigns.ctx
    {:ok, table_model} = ProductsTableModel.new(products, ctx)

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
       include_archived: Params.get_boolean_param(params, "include_archived", false),
       title: title,
       offset: 0,
       limit: @limit,
       query: "",
       text_search: "",
       text_search_tooltip: @text_search_tooltip,
       creation_title: ""
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <%= if @published? do %>
        <div class="px-4 text-[#353740] dark:text-[#EEEBF5] text-2xl font-bold leading-loose">
          Browse Products
        </div>
        <div>
          <Check.render
            checked={@include_archived}
            click="include_archived"
            class="text-[#353740] dark:text-[#EEEBF5] px-4 mt-2"
          >
            Include Archived Products
          </Check.render>
          <%= if @is_admin_view do %>
            <div class="flex w-fit gap-4 p-2 pr-8 mx-4 mt-3 mb-2 shadow-[0px_2px_6.099999904632568px_0px_rgba(0,0,0,0.10)] border border-[#ced1d9] dark:border-[#3B3740] dark:bg-[#000000]">
              <.form for={%{}} phx-change="text_search_change" class="w-56">
                <SearchInput.render id="text-search" name="product_name" text={@text_search} />
              </.form>

              <button class="ml-2 text-center text-[#353740] dark:text-[#EEEBF5] text-sm font-normal leading-none flex items-center gap-x-1">
                <Icons.filter class="stroke-[#353740] dark:stroke-[#EEEBF5]" /> Filter
              </button>

              <button
                class="ml-2 mr-4 text-center text-[#353740] dark:text-[#EEEBF5] text-sm font-normal leading-none flex items-center gap-x-1"
                phx-click="clear_all_filters"
              >
                <Icons.trash class="stroke-[#353740] dark:stroke-[#EEEBF5]" /> Clear All Filters
              </button>
            </div>
          <% else %>
            <Create.render title={@creation_title} change="title" click="create" />
          <% end %>
        </div>

        <StripedPagedTable.render
          table_model={@table_model}
          total_count={@total_count}
          offset={@offset}
          limit={@limit}
          render_top_info={false}
          additional_table_class="instructor_dashboard_table"
          sort="paged_table_sort"
          page_change="paged_table_page_change"
          limit_change="paged_table_limit_change"
          show_limit_change={true}
        />
      <% else %>
        <div>Products cannot be created until project is published.</div>
      <% end %>
    </div>
    """
  end

  def handle_params(params, _, socket) do
    offset = Params.get_int_param(params, "offset", 0)
    text_search = Params.get_param(params, "text_search", "")
    include_archived = Params.get_boolean_param(params, "include_archived", false)
    limit = Params.get_int_param(params, "limit", @limit)

    products =
      Blueprint.browse(
        %Paging{offset: offset, limit: limit},
        %Sorting{
          direction: socket.assigns.table_model.sort_order,
          field: socket.assigns.table_model.sort_by_spec.name
        },
        text_search: text_search,
        include_archived: include_archived,
        project_id: socket.assigns.project && socket.assigns.project.id
      )

    table_model =
      socket.assigns.table_model
      |> Map.put(:rows, products)
      |> SortableTableModel.update_from_params(params)

    total_count = determine_total(products)

    {:noreply,
     assign(socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count,
       text_search: text_search,
       include_archived: include_archived,
       limit: limit
     )}
  end

  def handle_event("include_archived", __params, socket) do
    include_archived = !socket.assigns.include_archived
    patch_with(socket, %{include_archived: include_archived})
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
         |> redirect(to: Routes.live_path(socket, DetailsView, blueprint.slug))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create product")}
    end
  end

  def handle_event("hide_overview", _, socket) do
    {:noreply, assign(socket, show_feature_overview: false)}
  end

  def handle_event("text_search_change", %{"product_name" => product_name}, socket) do
    patch_with(socket, %{text_search: product_name})
  end

  def handle_event("paged_table_sort", %{"sort_by" => sort_by_str}, socket) do
    current_sort_by = socket.assigns.table_model.sort_by_spec.name
    current_sort_order = socket.assigns.table_model.sort_order
    new_sort_by = String.to_existing_atom(sort_by_str)

    sort_order =
      if new_sort_by == current_sort_by, do: toggle_sort_order(current_sort_order), else: :asc

    patch_with(socket, %{sort_by: new_sort_by, sort_order: sort_order})
  end

  def handle_event("paged_table_page_change", %{"limit" => limit, "offset" => offset}, socket) do
    patch_with(socket, %{limit: limit, offset: offset})
  end

  def handle_event(
        "paged_table_limit_change",
        params,
        socket
      ) do
    new_limit = Params.get_int_param(params, "limit", 20)

    new_offset =
      PagingParams.calculate_new_offset(
        socket.assigns.offset,
        new_limit,
        socket.assigns.total_count
      )

    socket =
      socket
      |> assign(:limit, new_limit)
      |> assign(:offset, new_offset)

    patch_with(socket, %{limit: new_limit, offset: new_offset})
  end

  def handle_event("clear_all_filters", _params, socket) do
    {:noreply, push_patch(socket, to: live_path(socket, %{}))}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([&StripedPagedTable.handle_delegated/4])
  end

  def patch_with(socket, changes) do
    {:noreply,
     push_patch(socket,
       to: Routes.live_path(socket, __MODULE__, Map.merge(current_params(socket), changes)),
       replace: true
     )}
  end

  defp current_params(socket) do
    %{
      sort_by: socket.assigns.table_model.sort_by_spec.name,
      sort_order: socket.assigns.table_model.sort_order,
      offset: socket.assigns.offset,
      limit: socket.assigns.limit,
      include_archived: socket.assigns.include_archived,
      text_search: socket.assigns.text_search
    }
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(_), do: :asc

  defp determine_total(products) do
    case products do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end
end
