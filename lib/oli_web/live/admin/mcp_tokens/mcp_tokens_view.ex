defmodule OliWeb.Admin.MCPTokens.MCPTokensView do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.MCP.Auth
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Admin.MCPTokens.TableModel
  alias OliWeb.Common.{Breadcrumb, PagedTable, TextSearch}
  alias OliWeb.Common.Table.SortableTableModel

  @limit 25
  @sort_by :inserted_at
  @sort_order :desc
  @default_options %Auth.BrowseOptions{
    text_search: "",
    include_disabled: true
  }

  on_mount OliWeb.LiveSessionPlugs.SetCtx

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "MCP Bearer Tokens"
        })
      ]
  end

  def mount(_, _session, socket) do
    tokens =
      Auth.browse_tokens_with_usage(
        %Paging{offset: 0, limit: @limit},
        %Sorting{field: @sort_by, direction: @sort_order},
        @default_options
      )

    total_count = SortableTableModel.determine_total(tokens)

    {:ok, table_model} = TableModel.new(tokens, socket.assigns.ctx)

    {:ok,
     assign(socket,
       title: "MCP Bearer Tokens",
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

    options = %Auth.BrowseOptions{
      text_search: get_param(params, "text_search", ""),
      include_disabled: get_boolean_param(params, "include_disabled", true)
    }

    tokens =
      Auth.browse_tokens_with_usage(
        %Paging{offset: offset, limit: @limit},
        %Sorting{direction: table_model.sort_order, field: table_model.sort_by_spec.name},
        options
      )

    table_model = Map.put(table_model, :rows, tokens)
    total_count = SortableTableModel.determine_total(tokens)

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
    <div class="flex flex-col mt-4 space-y-4">
      <h1 class="text-2xl font-normal leading-9">MCP Bearer Tokens</h1>
      <div class="flex flex-row items-center justify-between">
        <TextSearch.render
          id="text-search"
          class="lg:!max-w-[33%] w-full"
          text={@options.text_search}
          event_target={nil}
        />
        <div class="flex items-center space-x-2">
          <label class="flex items-center space-x-2">
            <input
              type="checkbox"
              checked={@options.include_disabled}
              phx-click="toggle_include_disabled"
              class="rounded"
            />
            <span class="text-sm">Include disabled tokens</span>
          </label>
        </div>
      </div>
    </div>
    <div class="mt-4">
      <PagedTable.render
        filter={@options.text_search}
        table_model={@table_model}
        total_count={@total_count}
        offset={Map.get(assigns, :offset, 0)}
        limit={@limit}
      />
    </div>
    """
  end

  def handle_event("toggle_include_disabled", _params, socket) do
    current_value = socket.assigns.options.include_disabled

    {:noreply,
     push_patch(socket,
       to: ~p"/admin/mcp_tokens?#{%{include_disabled: !current_value}}"
     )}
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch/2}
    |> delegate_to([
      &TextSearch.handle_delegated/4,
      &PagedTable.handle_delegated/4
    ])
  end

  def patch(socket, changes) do
    {:noreply, push_patch(socket, to: build_url(socket, changes))}
  end

  defp build_url(socket, changes) do
    current_params = %{
      "offset" => socket.assigns[:offset] || 0,
      "sort_by" => socket.assigns.table_model.sort_by_spec.name,
      "sort_order" => socket.assigns.table_model.sort_order,
      "text_search" => socket.assigns.options.text_search,
      "include_disabled" => socket.assigns.options.include_disabled
    }

    updated_params = Map.merge(current_params, Enum.into(changes, %{}))
    ~p"/admin/mcp_tokens?#{updated_params}"
  end
end