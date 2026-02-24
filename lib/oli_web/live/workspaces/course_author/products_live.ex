defmodule OliWeb.Workspaces.CourseAuthor.ProductsLive do
  use OliWeb, :live_view
  use OliWeb, :verified_routes
  use OliWeb.Common.Modal

  import Phoenix.Component
  import OliWeb.DelegatedEvents

  alias __MODULE__
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Publishing
  alias Oli.Repo.Paging
  alias Oli.Repo.Sorting
  alias OliWeb.Components.Delivery.Utils, as: DeliveryUtils
  alias OliWeb.Common.Check
  alias OliWeb.Common.Params
  alias OliWeb.Common.StripedPagedTable
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Products.CreateTemplateModal
  alias OliWeb.Products.ProductsTableModel

  @max_items_per_page 20
  @initial_offset 0
  @initial_create_form to_form(%{"product_title" => ""}, as: :create_product_form)

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    project = socket.assigns.project
    include_archived = Params.get_boolean_param(params, "include_archived", false)
    text_search = params |> Params.get_param("text_search", "") |> String.trim()

    products =
      get_products(
        socket.assigns
        |> Map.put(:include_archived, include_archived)
        |> Map.put(:text_search, text_search)
      )

    ctx = socket.assigns.ctx

    {:ok, table_model} =
      ProductsTableModel.new(products, ctx, project.slug,
        sort_by_spec: :inserted_at,
        sort_order: :desc,
        is_admin: false,
        current_author: socket.assigns.current_author
      )

    published? = Publishing.project_published?(project.slug)

    {:ok,
     assign(socket,
       resource_slug: project.slug,
       resource_title: project.title,
       published?: published?,
       is_admin_view: false,
       include_archived: include_archived,
       text_search: text_search,
       limit: @max_items_per_page,
       offset: @initial_offset,
       total_count: determine_total(products),
       params: %{offset: @initial_offset, limit: @max_items_per_page},
       table_model: table_model,
       create_product_form: @initial_create_form
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    table_model = SortableTableModel.update_from_params(socket.assigns.table_model, params)
    offset = Params.get_int_param(params, "offset", @initial_offset)
    limit = Params.get_int_param(params, "limit", @max_items_per_page)
    include_archived = Params.get_boolean_param(params, "include_archived", false)
    text_search = params |> Params.get_param("text_search", "") |> String.trim()

    products =
      Blueprint.browse(
        %Paging{offset: offset, limit: limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        include_archived: include_archived,
        text_search: text_search,
        project_id: socket.assigns.project.id
      )

    table_model = Map.put(table_model, :rows, products)

    socket =
      assign(socket,
        table_model: table_model,
        offset: offset,
        limit: limit,
        total_count: determine_total(products),
        include_archived: include_archived,
        text_search: text_search,
        params: %{offset: offset, limit: limit}
      )

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    {render_modal(assigns)}
    <h2 id="header_id" class="pb-2 text-Text-text-high text-2xl font-bold leading-8">
      Course Section Templates
    </h2>
    <p class="pb-3 text-Text-text-high text-base font-medium leading-6">
      Building a course section template allows you to rearrange content and customize settings to match the unique requirements of institutions and communities. The course sections you create from a template will follow to the template's predefined settings.
    </p>
    <%= if @published? do %>
      <div class="mb-2 flex items-center gap-3">
        <DeliveryUtils.search_box
          class="w-full max-w-[350px]"
          search_term={@text_search}
          on_search="search_template"
          on_change="search_template"
          on_clear_search="clear_template_search"
        />
        <button
          id="button-new-template"
          class="ml-auto px-4 py-2 bg-Fill-Buttons-fill-primary rounded-md shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)] inline-flex justify-center items-center gap-2 overflow-hidden text-Text-text-white text-sm font-semibold"
          phx-click="show_create_template_modal"
        >
          <i class="fa fa-plus pr-2"></i> New Template
        </button>
      </div>

      <Check.render checked={@include_archived} click="include_archived">
        Include archived Templates
      </Check.render>

      <div class="mb-3" />

      <StripedPagedTable.render
        page_change="paged_table_page_change"
        sort="paged_table_sort"
        total_count={@total_count}
        limit={@limit}
        offset={@offset}
        table_model={@table_model}
        render_top_info={false}
        additional_table_class="instructor_dashboard_table"
        limit_change="paged_table_limit_change"
        show_limit_change={true}
        table_container_class="mx-0"
      />
    <% else %>
      <div>Templates cannot be created until project is published.</div>
    <% end %>
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
      {:ok, blueprint} ->
        {:noreply,
         socket
         |> put_flash(:info, "Template successfully created.")
         |> redirect(to: ~p"/workspaces/course_author/#{project_slug}/products/#{blueprint.slug}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create template")}
    end
  end

  def handle_event("show_create_template_modal", _, socket) do
    modal_assigns = %{
      id: "create_template_modal",
      form: @initial_create_form
    }

    modal = fn assigns ->
      ~H"""
      <CreateTemplateModal.render {@modal_assigns} submit_event="create" />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event("validate_create_template", _, socket) do
    {:noreply, socket}
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
        text_search: socket.assigns.text_search,
        project_id: project_id
      )

    table_model = Map.put(table_model, :rows, products)

    socket =
      assign(socket,
        include_archived: include_archived,
        products: products,
        total_count: determine_total(products),
        table_model: table_model
      )

    patch_with(socket, %{include_archived: include_archived})
  end

  def handle_event("search_template", %{"search_term" => search_term}, socket) do
    patch_with(socket, %{text_search: String.trim(search_term), offset: 0})
  end

  def handle_event("clear_template_search", _params, socket) do
    patch_with(socket, %{text_search: "", offset: 0})
  end

  def handle_event("hide_overview", _, socket) do
    {:noreply, assign(socket, show_feature_overview: false)}
  end

  def handle_event(event, params, socket) do
    delegate_to({event, params, socket, &ProductsLive.patch_with/2}, [
      &StripedPagedTable.handle_delegated/4
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
      limit: assigns.limit,
      include_archived: assigns.include_archived,
      text_search: assigns.text_search,
      sidebar_expanded: assigns.sidebar_expanded
    }
  end

  defp get_products(assigns) do
    offset = assigns[:offset] || @initial_offset
    limit = assigns[:limit] || @max_items_per_page

    table_model = assigns[:table_model]
    direction = if table_model, do: assigns.table_model.sort_order, else: :desc
    field = if table_model, do: assigns.table_model.sort_by_spec.name, else: :inserted_at

    include_archived = get_in(assigns, [:include_archived]) || false
    text_search = get_in(assigns, [:text_search])

    Blueprint.browse(
      %Paging{offset: offset, limit: limit},
      %Sorting{direction: direction, field: field},
      include_archived: include_archived,
      text_search: text_search,
      project_id: assigns.project.id
    )
  end

  defp determine_total(products) do
    case products do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end
end
