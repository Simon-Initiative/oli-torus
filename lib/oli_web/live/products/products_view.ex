defmodule OliWeb.Products.ProductsView do
  use OliWeb, :live_view

  import OliWeb.DelegatedEvents

  alias Oli.Repo
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.{Breadcrumb, Check, PagedTable, Params, SessionContext, TextSearch}
  alias OliWeb.Products.Create
  alias Oli.Authoring.Course
  alias Oli.Accounts.Author
  alias Oli.Delivery.Sections.Blueprint
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Publishing

  @limit 20
  @text_search_tooltip """
    Search by section title, amount or base project title.
  """

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
        %{"project_id" => project_slug} = params,
        %{"current_author_id" => author_id} = session,
        socket
      ) do
    author = Repo.get(Author, author_id)

    project = Course.get_project_by_slug(project_slug)

    mount_as(
      params,
      author,
      false,
      project,
      breadcrumb([]),
      "Products | " <> project.title,
      socket,
      session
    )
  end

  def mount(params, %{"current_author_id" => author_id} = session, socket) do
    author = Repo.get(Author, author_id)

    mount_as(params, author, true, nil, admin_breadcrumbs(), "Products", socket, session)
  end

  defp mount_as(params, author, is_admin_view, project, breadcrumbs, title, socket, session) do
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
       include_archived: Params.get_boolean_param(params, "include_archived", false),
       title: title,
       offset: 0,
       limit: @limit,
       query: "",
       text_search: "",
       text_search_tooltip: @text_search_tooltip,
       creation_title: "",
       ctx: ctx
     )}
  end

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
          <Create.render title={@creation_title} change="title" click="create" />
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

  def handle_params(params, _, socket) do
    offset = Params.get_int_param(params, "offset", 0)
    text_search = Params.get_param(params, "text_search", "")
    include_archived = Params.get_boolean_param(params, "include_archived", false)

    products =
      Blueprint.browse(
        %Paging{offset: offset, limit: @limit},
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
       include_archived: include_archived
     )}
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

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
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

  defp determine_total(products) do
    case products do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end
end
