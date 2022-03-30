defmodule OliWeb.Sections.GatingAndScheduling do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  use OliWeb.Common.Modal
  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.Table.SortableTableModel
  alias Surface.Components.{Link}
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias Oli.Delivery.Gating
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Delivery.Sections.GatingAndScheduling.TableModel
  alias Oli.Delivery.Gating.GatingCondition
  alias OliWeb.Common.SessionContext

  @limit 25

  def set_breadcrumbs(section, parent_gate, user_type) do
    first = case section do
      %Section{type: :blueprint} ->
        [
          Breadcrumb.new(%{
            full_title: "Products"
          })
        ]

      _ -> []
    end

    user_type
    |> intermediate_breadcrumb(first, section)
    |> breadcrumb(section)
    |> breadcrumb_exceptions(section, parent_gate)
  end

  def intermediate_breadcrumb(_user_type, previous, %Section{type: :blueprint} = section),
    do: previous ++ OliWeb.Products.DetailsView.set_breadcrumbs(section)

  def intermediate_breadcrumb(user_type, previous, section),
    do: previous ++  OliWeb.Sections.OverviewView.set_breadcrumbs(user_type, section)

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Gating and Scheduling",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def breadcrumb_exceptions(previous, _, nil), do: previous

  def breadcrumb_exceptions(previous, section, parent_gate) do
    %{title: resource_title} =
      Oli.Publishing.DeliveryResolver.from_resource_id(section.slug, parent_gate.resource_id)

    previous ++
      [
        Breadcrumb.new(%{
          full_title: resource_title,
          link:
            Routes.live_path(
              OliWeb.Endpoint,
              OliWeb.Sections.GatingAndScheduling.Edit,
              section.slug,
              parent_gate.id
            )
        }),
        Breadcrumb.new(%{
          full_title: "Student Exceptions",
          link:
            Routes.live_path(
              OliWeb.Endpoint,
              __MODULE__,
              section.slug,
              parent_gate.id
            )
        })
      ]
  end

  def mount(
        params,
        %{"section_slug" => section_slug} = session,
        socket
      ) do
    {parent_gate, title} =
      case Map.get(params, "parent_gate_id") do
        nil ->
          {nil, "Gating and Scheduling"}

        id ->
          {int_id, _} = Integer.parse(id)
          {Gating.get_gating_condition!(int_id), "Student Exceptions"}
      end

    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {user_type, _user, section} ->
        {:ok, assign_defaults(socket, section, session, parent_gate, title, user_type)}
    end
  end

  def assign_defaults(socket, section, session, parent_gate, title, user_type) do
    context = SessionContext.init(session)

    rows =
      Gating.browse_gating_conditions(
        section,
        %Paging{offset: 0, limit: @limit},
        %Sorting{direction: :asc, field: :title},
        if is_nil(parent_gate) do
          nil
        else
          parent_gate.id
        end
      )

    total_count = determine_total(rows)

    {:ok, table_model} = TableModel.new(context, rows, section, is_nil(parent_gate))

    socket
    |> assign(
      title: title,
      context: context,
      section: section,
      delivery_breadcrumb: true,
      breadcrumbs: set_breadcrumbs(section, parent_gate, user_type),
      table_model: table_model,
      total_count: total_count,
      parent_gate: parent_gate,
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
        if is_nil(socket.assigns.parent_gate) do
          nil
        else
          socket.assigns.parent_gate.id
        end,
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
        <Link class="btn btn-primary ml-2" to={link_new(assigns)}>
          <i class="las la-plus"></i> New {render_type(assigns)}
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

  defp render_type(assigns) do
    if is_nil(assigns.parent_gate) do
      "Gate"
    else
      "Student Exception"
    end
  end

  defp link_new(assigns) do
    case assigns.parent_gate do
      nil ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Sections.GatingAndScheduling.New,
          assigns.section.slug
        )

      %GatingCondition{id: id} ->
        Routes.live_path(
          OliWeb.Endpoint,
          OliWeb.Sections.GatingAndScheduling.New,
          assigns.section.slug,
          id
        )
    end
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  def patch_with(socket, changes) do
    params =
      Map.merge(
        %{
          sort_by: socket.assigns.table_model.sort_by_spec.name,
          sort_order: socket.assigns.table_model.sort_order,
          offset: socket.assigns.offset,
          text_search: socket.assigns.text_search
        },
        changes
      )

    path =
      if is_nil(socket.assigns.parent_gate) do
        Routes.live_path(
          socket,
          __MODULE__,
          socket.assigns.section.slug,
          params
        )
      else
        Routes.live_path(
          socket,
          __MODULE__,
          socket.assigns.section.slug,
          socket.assigns.parent_gate.id,
          params
        )
      end

    {:noreply,
     push_patch(socket,
       to: path,
       replace: true
     )}
  end
end
