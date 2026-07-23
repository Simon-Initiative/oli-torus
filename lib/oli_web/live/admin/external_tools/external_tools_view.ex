defmodule OliWeb.Admin.ExternalTools.ExternalToolsView do
  use OliWeb, :live_view

  require Logger

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.Lti.PlatformExternalTools
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Admin.ExternalTools.TableModel
  alias OliWeb.Common.{Breadcrumb, Check, PagedTable, TextSearch}
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Icons

  @limit 25
  @default_options %PlatformExternalTools.BrowseOptions{
    text_search: "",
    include_disabled: true,
    include_deleted: false
  }

  on_mount OliWeb.LiveSessionPlugs.SetCtx

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "Manage LTI 1.3 External Tools"
        })
      ]
  end

  def mount(_, _session, socket) do
    {:ok, table_model} = TableModel.new([], socket.assigns.ctx)

    {:ok,
     assign(socket,
       title: "Manage LTI 1.3 External Tools",
       breadcrumbs: set_breadcrumbs(),
       total_count: 0,
       table_model: table_model,
       limit: @limit,
       offset: 0,
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

    options = %PlatformExternalTools.BrowseOptions{
      text_search: get_param(params, "text_search", ""),
      include_disabled: get_boolean_param(params, "include_disabled", true),
      include_deleted: get_boolean_param(params, "include_deleted", false)
    }

    tools =
      PlatformExternalTools.browse_platform_external_tools(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )
      |> Enum.map(&Map.put(&1, :usage_count, :loading))

    table_model = Map.put(table_model, :rows, tools)
    total_count = SortableTableModel.determine_total(tools)

    socket =
      assign(socket,
        offset: offset,
        options: options,
        table_model: table_model,
        total_count: total_count
      )
      |> load_usage_counts_async(tools)

    {:noreply, socket}
  end

  def handle_async(:usage_counts, {:ok, usage_counts}, socket) do
    {:noreply, put_usage_counts(socket, usage_counts)}
  end

  def handle_async(:usage_counts, {:exit, reason}, socket) do
    Logger.warning("Failed to load LTI external tool usage counts: #{inspect(reason)}")

    {:noreply, put_usage_counts(socket, :unknown)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col mt-4 space-y-4">
      <h1 class="text-2xl font-normal leading-9">LTI 1.3 External Tools</h1>
      <div class="flex flex-row items-center justify-between">
        <TextSearch.render
          id="text-search"
          class="lg:!max-w-[33%] w-full"
          text={@options.text_search}
          event_target={nil}
        />
        <.link
          id="button-new-tool"
          href={~p"/admin/external_tools/new"}
          class="h-8 w-32 px-5 py-3 hover:no-underline rounded-md justify-center items-center gap-2 inline-flex bg-[#0062F2] hover:bg-[#0075EB] dark:bg-[#0062F2] dark:hover:bg-[#0D70FF]"
        >
          <div class="w-3 h-5 relative">
            <Icons.plus
              class="w-5 h-5 left-[-8px] top-0 absolute font-semibold"
              path_class="stroke-white"
            />
          </div>
          <div class="text-center justify-center text-white text-sm font-semibold leading-none">
            Add Tool
          </div>
        </.link>
      </div>
    </div>
    <div class="mt-4">
      <Check.render
        class="mr-4"
        checked={@options.include_disabled}
        click="include_disabled"
        id="include_disabled"
      >
        Show tools that have been disabled
      </Check.render>
      <Check.render
        class="mr-4"
        checked={@options.include_deleted}
        click="include_deleted"
        id="include_deleted"
      >
        Show tools that have been deleted
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

  def handle_event("include_deleted", _, socket),
    do: patch_with(socket, %{include_deleted: !socket.assigns.options.include_deleted})

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
      include_disabled: socket.assigns.options.include_disabled,
      include_deleted: socket.assigns.options.include_deleted
    }

    {:noreply,
     push_patch(socket,
       to: ~p"/admin/external_tools?#{Map.merge(params, changes)}",
       replace: true
     )}
  end

  defp load_usage_counts_async(socket, tools) do
    platform_instance_ids = Enum.map(tools, & &1.id)
    socket = cancel_async(socket, :usage_counts)

    case platform_instance_ids do
      [] ->
        socket

      platform_instance_ids ->
        start_async(socket, :usage_counts, fn ->
          PlatformExternalTools.count_sections_by_platform_instance_ids(platform_instance_ids)
        end)
    end
  end

  defp put_usage_counts(socket, usage_counts) do
    table_model = socket.assigns.table_model

    rows =
      Enum.map(table_model.rows, fn tool ->
        usage_count =
          case usage_counts do
            %{} -> Map.get(usage_counts, tool.id, 0)
            :unknown -> :unknown
          end

        Map.put(tool, :usage_count, usage_count)
      end)

    table_model =
      table_model
      |> Map.put(:rows, rows)
      |> maybe_sort_by_usage_count()

    assign(socket, table_model: table_model)
  end

  defp maybe_sort_by_usage_count(
         %SortableTableModel{sort_by_spec: %{name: :usage_count}} = table_model
       ),
       do: SortableTableModel.sort(table_model)

  defp maybe_sort_by_usage_count(table_model), do: table_model
end
