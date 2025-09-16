defmodule OliWeb.Sections.GatingAndScheduling do
  use OliWeb, :live_view

  import OliWeb.DelegatedEvents
  import OliWeb.Common.Params

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Sections.Mount
  alias OliWeb.Common.{TextSearch, PagedTable, Breadcrumb}
  alias Oli.Delivery.Gating
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Delivery.Sections.GatingAndScheduling.TableModel
  alias Oli.Delivery.Gating.GatingCondition

  @default_params %{sort_by: "numbering_index", limit: 25}

  def set_breadcrumbs(section, parent_gate, user_type) do
    first =
      case section do
        %Section{type: :blueprint} ->
          [
            Breadcrumb.new(%{
              full_title: "Products"
            })
          ]

        _ ->
          []
      end

    user_type
    |> intermediate_breadcrumb(first, section)
    |> breadcrumb(section)
    |> breadcrumb_exceptions(section, parent_gate)
  end

  def intermediate_breadcrumb(_user_type, previous, %Section{type: :blueprint} = section),
    do: previous ++ OliWeb.Products.DetailsView.set_breadcrumbs(section)

  def intermediate_breadcrumb(user_type, previous, section),
    do: previous ++ OliWeb.Sections.OverviewView.set_breadcrumbs(user_type, section)

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Advanced Gating",
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
        %{"section_slug" => section_slug} = params,
        _session,
        socket
      ) do
    {parent_gate, title} =
      case Map.get(params, "parent_gate_id") do
        nil ->
          {nil, "Advanced Gating"}

        id ->
          {int_id, _} = Integer.parse(id)
          {Gating.get_gating_condition!(int_id), "Student Exceptions"}
      end

    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {user_type, _user, section} ->
        {:ok, assign_defaults(socket, section, parent_gate, title, user_type)}
    end
  end

  def assign_defaults(socket, section, parent_gate, title, user_type) do
    ctx = socket.assigns.ctx

    rows =
      Gating.browse_gating_conditions(
        section,
        %Paging{offset: 0, limit: @default_params.limit},
        %Sorting{direction: :asc, field: String.to_atom(@default_params.sort_by)},
        if(is_nil(parent_gate), do: nil, else: parent_gate.id)
      )

    total_count = determine_total(rows)

    {:ok, table_model} = TableModel.new(ctx, rows, section, is_nil(parent_gate))

    socket
    |> assign(
      title: title,
      section: section,
      breadcrumbs: set_breadcrumbs(section, parent_gate, user_type),
      table_model: table_model,
      total_count: total_count,
      parent_gate: parent_gate,
      text_search: "",
      offset: 0,
      limit: @default_params.limit,
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
    sort_by = get_param(params, "sort_by", @default_params.sort_by)
    limit = get_int_param(params, "limit", @default_params.limit)

    rows =
      Gating.browse_gating_conditions(
        socket.assigns.section,
        %Paging{offset: offset, limit: limit},
        %Sorting{direction: table_model.sort_order, field: String.to_atom(sort_by)},
        if(is_nil(socket.assigns.parent_gate), do: nil, else: socket.assigns.parent_gate.id),
        text_search
      )

    table_model = Map.put(table_model, :rows, rows)
    total_count = determine_total(rows)

    {:noreply,
     assign(socket,
       offset: offset,
       limit: limit,
       table_model: table_model,
       total_count: total_count,
       text_search: text_search
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="container flex flex-col">
      <div class="d-flex mb-3">
        <TextSearch.render id="text-search" />
        <div class="flex-grow-1"></div>
        <.link class="btn btn-primary ml-2" href={link_new(assigns)}>
          <i class="fas fa-plus"></i> New {render_type(assigns)}
        </.link>
      </div>

      <PagedTable.render
        filter={@text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={@offset}
        limit={@limit}
        no_records_message="There are no gating conditions to show"
      />

      <div class="alert bg-gray-100 border-gray-400 dark:bg-gray-600">
        <div class="grid gap-y-3 text-xs text-gray-600 dark:text-delivery-body-color-dark">
          <p>
            Advanced Gating is specifically designed for instructors who require a higher level of control over their course material accessibility. Please review the following intended use cases to ensure this feature meets your needs:
          </p>
          <ul class="grid gap-y-1 ml-6 list-disc">
            <li>
              <strong>Time-Based Restrictions for Units/Modules:</strong>
              This advanced feature allows instructors to block access to entire units or modules for a specified time period. For instance, if you wish to make Unit 3 available only from March 1st to March 15th, you can set that up here. However, if your intention is to make a single graded page available for a specific duration, we recommend using the "Availability Date" and "Due Date" options found in the simpler "Assessment Settings" feature.
            </li>
            <li>
              <strong>Conditional Accessibility Based on Student Performance:</strong>
              One of the primary use cases of this feature is to conditionally grant access to course materials based on student achievements. For example, if you want to ensure that students only access Unit 2 after scoring 80% or higher on the quiz at the end of Unit 1, you can configure such requirements here.
            </li>
          </ul>
          <p>
            For all other scheduling and assessment-related configurations, please refer to the "Assessment Settings / Scheduler" features. These features offer a more straightforward and intuitive interface suitable for most common use cases.
          </p>
        </div>
      </div>
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
          text_search: socket.assigns.text_search,
          limit: socket.assigns.limit
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
