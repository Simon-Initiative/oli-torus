defmodule OliWeb.Admin.MCPTokens.MCPTokensView do
  use OliWeb, :live_view

  import OliWeb.Common.Params
  import OliWeb.DelegatedEvents

  alias Oli.MCP.Auth
  alias Oli.Repo.{Paging, Sorting}
  alias OliWeb.Admin.MCPTokens.TableModel
  alias OliWeb.Common.{Breadcrumb, PagedTable}
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

    # Create table model without auto-sorting since we're sorting at database level
    {:ok, table_model} = TableModel.new([], socket.assigns.ctx)
    initial_sort_spec = Enum.find(table_model.column_specs, fn spec -> spec.name == @sort_by end)

    table_model = %{
      table_model
      | rows: tokens,
        sort_by_spec: initial_sort_spec,
        sort_order: @sort_order
    }

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
    IO.inspect(params)

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

    # Don't use Map.put which might trigger re-sorting, directly set the rows
    table_model = %{table_model | rows: tokens}
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

  def handle_event(
        "toggle_token_status",
        %{"token-id" => token_id, "current-status" => current_status},
        socket
      ) do
    token_id = String.to_integer(token_id)
    current_status = String.to_existing_atom(current_status)

    new_status =
      case current_status do
        :active -> :disabled
        :disabled -> :active
      end

    case Auth.update_token_status(token_id, new_status) do
      {:ok, _updated_token} ->
        # Refresh the table data
        tokens =
          Auth.browse_tokens_with_usage(
            %Paging{offset: socket.assigns[:offset] || 0, limit: @limit},
            %Sorting{
              direction: socket.assigns.table_model.sort_order,
              field: socket.assigns.table_model.sort_by_spec.name
            },
            socket.assigns.options
          )

        table_model = Map.put(socket.assigns.table_model, :rows, tokens)
        total_count = SortableTableModel.determine_total(tokens)

        {:noreply,
         socket
         |> assign(table_model: table_model, total_count: total_count)
         |> put_flash(:info, "Token status updated successfully.")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update token status. Please try again.")}
    end
  end

  def handle_event(event, params, socket) do
    {event, params, socket, &__MODULE__.patch/2}
    |> delegate_to([
      &PagedTable.handle_delegated/4
    ])
  end

  def patch(socket, changes) do
    {:noreply, push_patch(socket, to: build_url(socket, changes))}
  end

  defp build_url(socket, changes) do
    IO.inspect(changes)

    current_params = %{
      offset: socket.assigns[:offset] || 0,
      sort_by: socket.assigns.table_model.sort_by_spec.name,
      sort_order: socket.assigns.table_model.sort_order,
      text_search: socket.assigns.options.text_search,
      include_disabled: socket.assigns.options.include_disabled
    }

    updated_params = Map.merge(current_params, changes)
    IO.inspect(updated_params, label: "Updated Params")
    ~p"/admin/mcp_tokens?#{updated_params}"
  end
end
