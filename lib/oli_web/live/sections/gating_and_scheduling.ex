defmodule OliWeb.Sections.GatingAndScheduling do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.Table.SortableTableModel
  alias Surface.Components.{Link}
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias Oli.Delivery.Gating
  alias OliWeb.Delivery.Sections.GatingAndScheduling.TableModel

  @limit 25

  def set_breadcrumbs(section) do
    OliWeb.Sections.SectionsView.set_breadcrumbs()
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: section.title,
          link: Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.OverviewView, section.slug)
        }),
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
        {:ok, assign_defaults(socket, section)}

      {:user, _current_user, section} ->
        {:ok, assign_defaults(socket, section)}
    end
  end

  def assign_defaults(socket, section) do
    rows =
      Gating.browse_gating_conditions(
        section,
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title}
      )

    total_count = determine_total(rows)

    {:ok, table_model} = TableModel.new(rows, section)

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

  defp determine_total(rows) do
    case(rows) do
      [] -> 0
      [hd | _] -> hd.total_count
    end
  end

  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)
    text_search = get_param(params, "text_search", "")

    rows =
      Gating.browse_gating_conditions(
        socket.assigns.section,
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        text_search
      )

    table_model = Map.put(table_model, :rows, rows)
    total_count = determine_total(rows)

    {:noreply,
     assign(socket,
       offset: offset,
       table_model: table_model,
       total_count: total_count,
       text_search: text_search
     )}
  end

  def render(assigns) do
    ~F"""
    <div class="container">
      <div class="d-flex">
        <TextSearch id="text-search"/>
        <div class="flex-grow-1"></div>
        <Link class="btn btn-primary ml-2" to={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.GatingAndScheduling.New, @section.slug)}>
          <i class="las la-plus"></i> New Gate
        </Link>
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
         Routes.live_path(
           socket,
           __MODULE__,
           socket.assigns.section.slug,
           Map.merge(
             %{
               sort_by: socket.assigns.table_model.sort_by_spec.name,
               sort_order: socket.assigns.table_model.sort_order,
               offset: socket.assigns.offset,
               text_search: socket.assigns.text_search
             },
             changes
           )
         ),
       replace: true
     )}
  end
end
