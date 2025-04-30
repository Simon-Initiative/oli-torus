defmodule OliWeb.Admin.ExternalToolsView do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Lti.PlatformInstances
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Admin.ExternalTools.TableModel
  alias OliWeb.Common.{Breadcrumb, Check, PagedTable, TextSearch}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Router.Helpers, as: Routes

  @limit 25
  @sort_by :name
  @sort_order :asc
  @default_options %PlatformInstances.BrowseOptions{text_search: "", include_disabled: true}

  on_mount OliWeb.LiveSessionPlugs.SetCtx

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Manage LTI 1.3 External Tools",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def mount(_, _session, socket) do
    tools =
      PlatformInstances.browse_platform_instances(
        %Paging{offset: 0, limit: @limit},
        %Sorting{field: @sort_by, direction: @sort_order},
        @default_options
      )

    total_count = SortableTableModel.determine_total(tools)

    {:ok, table_model} = TableModel.new(tools, socket.assigns.ctx)

    {:ok,
     assign(socket,
       title: "Manage LTI 1.3 External Tools",
       breadcrumbs: set_breadcrumbs(),
       total_count: total_count,
       table_model: table_model,
       limit: @limit,
       options: @default_options
     )}
  end

  def handle_params(params, _, socket) do
    table_model =
      SortableTableModel.update_from_params(
        socket.assigns.table_model,
        params
      )

    offset = get_int_param(params, "offset", 0)

    options = %PlatformInstances.BrowseOptions{
      text_search: get_param(params, "text_search", ""),
      include_disabled: get_boolean_param(params, "include_disabled", true)
    }

    tools =
      PlatformInstances.browse_platform_instances(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, tools)
    total_count = SortableTableModel.determine_total(tools)

    {:noreply,
     assign(socket,
       offset: offset,
       options: options,
       table_model: table_model,
       total_count: total_count
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <TextSearch.render
        id="text-search"
        class="lg:!max-w-[33%]"
        text={@options.text_search}
        event_target={nil}
      />

      <Check.render class="mr-4" checked={@options.include_disabled} click="include_disabled">
        Show tools that have been disabled
      </Check.render>

      <PagedTable.render
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        limit={@limit}
        offset={@offset}
      />
    </div>
    """
  end

  def handle_event("include_disabled", _, socket),
    do: patch_with(socket, %{include_disabled: !socket.assigns.options.include_disabled})

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch_with/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  def patch_with(socket, changes) do
    params = %{
      sort_by: socket.assigns.table_model.sort_by_spec.name,
      sort_order: socket.assigns.table_model.sort_order,
      offset: socket.assigns.offset,
      text_search: socket.assigns.options.text_search,
      include_disabled: socket.assigns.options.include_disabled
    }

    {:noreply,
     push_patch(socket,
       to: ~p"/admin/external_tools?#{Map.merge(params, changes)}",
       replace: true
     )}
  end
end
