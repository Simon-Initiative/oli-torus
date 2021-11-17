defmodule OliWeb.Sections.GatingAndScheduling do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal

  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Router.Helpers, as: Routes
  alias Surface.Components.{Link}
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}

  alias OliWeb.Delivery.Sections.{
    GatingConditionsTableModel
  }

  alias OliWeb.Sections.CreateGatingCondition
  alias Oli.Delivery.Gating
  alias Oli.Publishing.DeliveryResolver
  alias OliWeb.Common.Hierarchy.SelectResourceModal
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.Revision

  @limit 25

  def set_breadcrumbs(section) do
    OliWeb.Sections.SectionsView.set_breadcrumbs()
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Gating and Scheduling",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(
        _params,
        %{"section_slug" => section_slug} = session,
        socket
      ) do
    case Mount.for(section_slug, session) do
      {:admin, _author, section} ->
        {:ok, assign_default(socket, section)}

      {:user, _current_user, section} ->
        {:ok, assign_default(socket, section)}
    end
  end

  def assign_default(socket, section) do
    rows =
      Gating.browse_gating_conditions(
        section,
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title}
      )

    total_count = determine_total(rows)

    {:ok, table_model} = GatingConditionsTableModel.new(rows, section)

    socket
    |> assign(
      title: "Gating and Scheduling",
      section: section,
      breadcrumbs: set_breadcrumbs(section),
      table_model: table_model,
      total_count: total_count,
      text_search: "",
      offset: 0,
      limit: @limit,
      modal: nil,
      gating_condition: nil
    )
  end

  defp soft_reload(socket) do
    %{section: section} = socket.assigns

    assign_default(socket, section)
  end

  defp determine_total(rows) do
    case(rows) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def render(assigns) do
    ~F"""
    {render_modal(assigns)}
    <div class="container">
      {render_content(assigns)}
    </div>
    """
  end

  def render_content(%{gating_condition: %{} = gating_condition} = assigns) do
    ~F"""
    <CreateGatingCondition id="new-gating-condition" gating_condition={gating_condition} />
    """
  end

  def render_content(assigns) do
    ~F"""
    <div class="mb-2">
      <Link to={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, @section.slug)}>
          <i class="las la-arrow-left"></i> Back
      </Link>
    </div>

    <div>
      <div class="d-flex">
        <TextSearch id="text-search"/>
        <div class="flex-grow-1"></div>
        <button class="btn btn-primary ml-2" phx-click="show-create-gate"><i class="las la-plus"></i> New Gate</button>
      </div>

      <div class="mb-3"/>

      <PagedTable
        filter={@text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}/>
    </div>
    """
  end

  def handle_event("show-create-gate", _, socket) do
    %{section: section} = socket.assigns

    {:noreply, assign(socket, gating_condition: %{section_id: section.id})}
  end

  def handle_event("cancel-create-gate", _, socket) do
    {:noreply, assign(socket, gating_condition: nil)}
  end

  def handle_event("show-resource-picker", _, socket) do
    %{section: section} = socket.assigns

    hierarchy = DeliveryResolver.full_hierarchy(section.slug)
    root = hierarchy
    filter_items_fn = fn items -> Enum.filter(items, &(&1.uuid != root.uuid)) end

    modal_assigns = %{
      id: "select_resource",
      hierarchy: hierarchy,
      active: root,
      selection: nil,
      filter_items_fn: filter_items_fn
    }

    {:noreply,
     assign(socket,
       modal: %{component: SelectResourceModal, assigns: modal_assigns}
     )}
  end

  def handle_event("HierarchyPicker.update_active", %{"uuid" => uuid}, socket) do
    %{modal: %{assigns: %{hierarchy: hierarchy} = assigns} = modal} = socket.assigns

    active = Hierarchy.find_in_hierarchy(hierarchy, uuid)

    {:noreply,
     assign(socket,
       modal: %{modal | component: SelectResourceModal, assigns: %{assigns | active: active}}
     )}
  end

  def handle_event("HierarchyPicker.select", %{"uuid" => uuid}, socket) do
    %{modal: %{assigns: %{selection: selection} = assigns} = modal} = socket.assigns

    selection =
      if selection != uuid do
        uuid
      else
        nil
      end

    {:noreply,
     assign(socket,
       modal: %{
         modal
         | component: SelectResourceModal,
           assigns: %{assigns | selection: selection}
       }
     )}
  end

  def handle_event("SelectResourceModal.cancel", _, socket) do
    {:noreply, hide_modal(socket)}
  end

  def handle_event("SelectResourceModal.select", %{"selection" => selection}, socket) do
    %{
      gating_condition: gating_condition,
      modal: %{assigns: %{hierarchy: hierarchy}}
    } = socket.assigns

    %HierarchyNode{resource_id: resource_id, revision: %Revision{title: title}} =
      Hierarchy.find_in_hierarchy(hierarchy, selection)

    {:noreply,
     socket
     |> assign(
       gating_condition:
         gating_condition
         |> Map.put(:resource_id, resource_id)
         |> Map.put(:resource_title, title)
     )
     |> hide_modal()}
  end

  def handle_event("select-condition", %{"value" => value}, socket) do
    %{gating_condition: gating_condition} = socket.assigns

    {:noreply,
     assign(socket,
       gating_condition:
         gating_condition
         |> Map.put(:type, String.to_existing_atom(value))
         |> Map.put(:data, %{})
     )}
  end

  def handle_event("schedule_start_date_changed", %{"value" => value}, socket) do
    %{gating_condition: %{data: data} = gating_condition} = socket.assigns

    data = Map.put(data, :start_datetime, Timex.parse!(value, "{ISO:Extended}"))

    {:noreply, assign(socket, gating_condition: %{gating_condition | data: data})}
  end

  def handle_event("schedule_end_date_changed", %{"value" => value}, socket) do
    %{gating_condition: %{data: data} = gating_condition} = socket.assigns

    data = Map.put(data, :end_datetime, Timex.parse!(value, "{ISO:Extended}"))

    {:noreply, assign(socket, gating_condition: %{gating_condition | data: data})}
  end

  def handle_event("create_gate", _, socket) do
    %{gating_condition: gating_condition, section: section} = socket.assigns

    {:ok, _gc} = Gating.create_gating_condition(gating_condition)

    {:ok, _section} = Gating.update_resource_gating_index(section)

    {:noreply, soft_reload(socket)}
  end
end
