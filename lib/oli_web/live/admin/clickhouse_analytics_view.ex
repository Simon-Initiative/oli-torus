defmodule OliWeb.Admin.ClickHouseAnalyticsView do
  use OliWeb, :live_view

  alias Oli.Analytics.ClickhouseAnalytics
  alias Oli.Clickhouse.AdminOperations
  alias Oli.Features
  alias OliWeb.Common.Breadcrumb

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(_, _, socket) do
    if Features.enabled?("clickhouse-olap") do
      socket =
        socket
        |> assign(
          title: "ClickHouse Analytics",
          breadcrumbs: breadcrumbs(),
          current_operation: nil
        )
        |> load_dashboard_async()

      if connected?(socket) do
        AdminOperations.subscribe()
      end

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "ClickHouse analytics is not enabled.")
       |> redirect(to: ~p"/admin")}
    end
  end

  def handle_event("run_clickhouse_operation", %{"kind" => kind}, socket) do
    case parse_operation_kind(kind) do
      {:ok, operation_kind} ->
        case AdminOperations.start(operation_kind, socket.assigns.current_author) do
          {:ok, operation} ->
            {:noreply,
             socket
             |> put_flash(:info, operation_started_message(operation_kind))
             |> assign(current_operation: operation)
             |> load_dashboard_async()}

          {:error, :setup_not_available} ->
            {:noreply,
             put_flash(socket, :error, "Setup database is not currently available.")}

          {:error, :clickhouse_unreachable} ->
            {:noreply,
             put_flash(socket, :error, "ClickHouse must be reachable before running migrations.")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, format_error(reason))}
        end

      :error ->
        {:noreply, put_flash(socket, :error, "Unsupported ClickHouse operation.")}
    end
  end

  def handle_info({:clickhouse_admin_operation_started, _operation}, socket), do: {:noreply, socket}

  def handle_info(
        {:clickhouse_admin_operation_progress, %{operation_id: operation_id, event: event}},
        socket
      ) do
    {:noreply,
     socket
     |> maybe_append_current_operation_event(operation_id, event)}
  end

  def handle_info({:clickhouse_admin_operation_finished, operation}, socket) do
    {:noreply,
     socket
     |> assign(
       current_operation: merge_finished_operation(socket.assigns[:current_operation], operation)
     )
     |> load_dashboard_async()}
  end

  def render(assigns) do
    ~H"""
    <div class="w-full bg-white dark:bg-gray-900 dark:text-white p-6">
      <div class="max-w-6xl mx-auto">
        <h1 class="text-3xl font-bold mb-6">ClickHouse Analytics Dashboard</h1>
        <div class="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg mb-6">
          <h2 class="text-xl font-semibold mb-2">ClickHouse Health</h2>
          <p class="text-gray-600 dark:text-gray-400 mb-4">
            Live health and metadata metrics for the ClickHouse connection and raw events storage.
          </p>

          <.async_result :let={summary} assign={@health_summary}>
            <:loading>
              <div class="text-gray-500 dark:text-gray-400">Loading health metrics...</div>
            </:loading>
            <:failed :let={reason}>
              <div class="text-red-600 dark:text-red-400">
                ClickHouse health check failed: {format_error(reason)}
              </div>
            </:failed>
            <% raw_events = Map.get(summary, :raw_events, %{}) %>
            <% raw_events_parts = Map.get(summary, :raw_events_parts, %{}) %>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4">
                <h3 class="text-lg font-semibold">Connection</h3>
                <div class="mt-3 text-sm text-gray-700 dark:text-gray-300 space-y-1">
                  <div>Status: <span class="text-green-600 dark:text-green-400">Healthy</span></div>
                  <div>Host: {summary["hostname"] || "unknown"}</div>
                  <div>Version: {summary["version"] || "unknown"}</div>
                  <div>Timezone: {summary["timezone"] || "unknown"}</div>
                  <div>Server time: {summary["server_time"] || "unknown"}</div>
                  <div>Uptime: {format_uptime(summary["uptime_seconds"])}</div>
                </div>
              </div>
              <div class="bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4">
                <h3 class="text-lg font-semibold">Database</h3>
                <div class="mt-3 text-sm text-gray-700 dark:text-gray-300 space-y-1">
                  <div>Configured DB: {summary["configured_database"] || "unknown"}</div>
                  <div>Current DB: {summary["current_database"] || "unknown"}</div>
                </div>
              </div>
              <div class="bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4 md:col-span-2">
                <h3 class="text-lg font-semibold">raw_events</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-3">
                  <div>
                    <h4 class="text-sm font-semibold text-gray-700 dark:text-gray-300">
                      Table
                    </h4>
                    <div class="mt-2 text-sm text-gray-700 dark:text-gray-300 space-y-1">
                      <div>Engine: {raw_events["engine"] || "unknown"}</div>
                      <div>Total rows: {format_int(raw_events["total_rows"])}</div>
                      <div>Total bytes: {format_bytes(raw_events["total_bytes"])}</div>
                      <div>
                        Metadata updated: {raw_events["metadata_modification_time"] || "unknown"}
                      </div>
                    </div>
                  </div>
                  <div>
                    <h4 class="text-sm font-semibold text-gray-700 dark:text-gray-300">
                      Parts
                    </h4>
                    <div class="mt-2 text-sm text-gray-700 dark:text-gray-300 space-y-1">
                      <div>Active parts: {format_int(raw_events_parts["active_parts"])}</div>
                      <div>Rows on disk: {format_int(raw_events_parts["rows_on_disk"])}</div>
                      <div>Bytes on disk: {format_bytes(raw_events_parts["bytes_on_disk"])}</div>
                      <div>
                        Last part modification: {raw_events_parts["last_part_modification"] ||
                          "unknown"}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </.async_result>
        </div>

        <div class="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg">
          <h2 class="text-xl font-semibold mb-2">Database Operations</h2>
          <p class="text-gray-600 dark:text-gray-400 mb-4">
            Safe admin operations only. Create, drop, and reset remain shell-only workflows.
          </p>

          <.async_result :let={capabilities} assign={@clickhouse_capabilities}>
            <:loading>
              <div class="text-gray-500 dark:text-gray-400">Loading operation capabilities...</div>
            </:loading>
            <:failed :let={reason}>
              <div class="text-red-600 dark:text-red-400">
                ClickHouse capability check failed: {format_error(reason)}
              </div>
            </:failed>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div class="flex h-full flex-col bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4">
                <h3 class="text-lg font-semibold">Setup Database</h3>
                <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
                  Required before analytics writes can use this ClickHouse database.
                </p>
                <div class="mt-2 flex flex-col items-start gap-1 text-xs text-gray-500 dark:text-gray-400">
                  <span class={status_indicator_class(capabilities.reachable)}>
                    {status_indicator_icon(capabilities.reachable)} Reachable
                  </span>
                  <span class={status_indicator_class(capabilities.database_exists)}>
                    {status_indicator_icon(capabilities.database_exists)} Database exists
                  </span>
                  <span class={status_indicator_class(capabilities.table_exists)}>
                    {status_indicator_icon(capabilities.table_exists)} Table exists
                  </span>
                </div>
                <button
                  type="button"
                  phx-click="run_clickhouse_operation"
                  phx-value-kind="setup"
                  class="mt-auto self-start inline-flex items-center rounded bg-blue-700 px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={!capabilities.setup_enabled}
                >
                  Run Setup Database
                </button>
              </div>

              <div class="flex h-full flex-col bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4">
                <h3 class="text-lg font-semibold">Migrate Up</h3>
                <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
                  Apply pending ClickHouse migrations.
                </p>
                <button
                  type="button"
                  phx-click="run_clickhouse_operation"
                  phx-value-kind="migrate_up"
                  class="mt-auto self-start inline-flex items-center rounded bg-amber-600 px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={!capabilities.reachable}
                >
                  Run Migrate Up
                </button>
              </div>

              <div class="flex h-full flex-col bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4">
                <h3 class="text-lg font-semibold">Migrate Down</h3>
                <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
                  Roll back the most recent ClickHouse migration.
                </p>
                <button
                  type="button"
                  phx-click="run_clickhouse_operation"
                  phx-value-kind="migrate_down"
                  class="mt-auto self-start inline-flex items-center rounded bg-amber-600 px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={!capabilities.reachable}
                >
                  Run Migrate Down
                </button>
              </div>

            </div>
          </.async_result>

          <%= if @current_operation do %>
            <div class="mt-6">
              <h3 class="text-lg font-semibold mb-3">Current Operation</h3>
              <div class="bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4">
                <div class="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
                  <div>
                    <div class="font-semibold">{operation_title(@current_operation.kind)}</div>
                    <div class="text-sm text-gray-500 dark:text-gray-400">
                      Status: {@current_operation.status} | Started: {format_timestamp(
                        @current_operation.started_at
                      )}
                      <%= if @current_operation.finished_at do %>
                        | Finished: {format_timestamp(@current_operation.finished_at)}
                      <% end %>
                    </div>
                  </div>
                  <div class={operation_status_class(@current_operation.status)}>
                    {String.upcase(to_string(@current_operation.status))}
                  </div>
                </div>

                <%= if @current_operation.error do %>
                  <div class="mt-3 text-sm text-red-600 dark:text-red-400">
                    {@current_operation.error}
                  </div>
                <% end %>

                <div class="mt-3 rounded bg-gray-50 dark:bg-gray-800 p-3">
                  <div class="text-sm font-semibold mb-2">Progress</div>
                  <ul class="space-y-2 text-sm">
                    <%= for event <- @current_operation.events do %>
                      <li>
                        <span class="font-mono text-xs text-gray-500 dark:text-gray-400">
                          {Map.get(event, "ts")}
                        </span>
                        <span class="ml-2 font-semibold">
                          {String.upcase(Map.get(event, "level", "info"))}
                        </span>
                        <span class="ml-2">{Map.get(event, "message")}</span>
                        <%= if Map.get(event, "metadata", %{}) != %{} do %>
                          <span class="ml-2 text-gray-500 dark:text-gray-400">
                            {inspect(Map.get(event, "metadata"))}
                          </span>
                        <% end %>
                      </li>
                    <% end %>
                  </ul>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp load_dashboard_async(socket) do
    socket
    |> assign_async(:health_summary, fn ->
      case ClickhouseAnalytics.health_summary() do
        {:ok, summary} -> {:ok, %{health_summary: summary}}
        {:error, reason} -> {:error, reason}
      end
    end)
    |> assign_async(:clickhouse_capabilities, fn ->
      case ClickhouseAnalytics.admin_capabilities() do
        {:ok, capabilities} -> {:ok, %{clickhouse_capabilities: capabilities}}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp breadcrumbs do
    OliWeb.Admin.AdminView.breadcrumb() ++
      [
        Breadcrumb.new(%{
          full_title: "ClickHouse Analytics Dashboard",
          link: ~p"/admin/clickhouse"
        })
      ]
  end

  defp format_int(nil), do: "n/a"
  defp format_int(value) when is_integer(value), do: format_number(value)
  defp format_int(value) when is_float(value), do: :erlang.float_to_binary(value, [:compact])
  defp format_int(value) when is_binary(value), do: value
  defp format_int(_), do: "n/a"

  defp format_uptime(value) when is_binary(value) do
    case Integer.parse(value) do
      {seconds, _} -> format_uptime(seconds)
      _ -> value
    end
  end

  defp format_uptime(value) when is_integer(value) and value >= 0 do
    {days, rem} = div_rem(value, 86_400)
    {hours, rem} = div_rem(rem, 3600)
    {minutes, seconds} = div_rem(rem, 60)

    [
      format_uptime_unit(days, "d"),
      format_uptime_unit(hours, "h"),
      format_uptime_unit(minutes, "m"),
      format_uptime_unit(seconds, "s")
    ]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> "0s"
      parts -> Enum.join(parts, " ")
    end
  end

  defp format_uptime(value), do: format_int(value)

  defp format_bytes(nil), do: "n/a"

  defp format_bytes(value) when is_integer(value) and value >= 0 do
    units = ["B", "KB", "MB", "GB", "TB"]
    {scaled, unit} = scale_bytes(value, units)
    "#{scaled} #{unit}"
  end

  defp format_bytes(value) when is_binary(value), do: value
  defp format_bytes(_), do: "n/a"

  defp scale_bytes(bytes, [unit]) do
    {Integer.to_string(bytes), unit}
  end

  defp scale_bytes(bytes, [_unit | rest]) when bytes >= 1024 do
    scale_bytes(div(bytes, 1024), rest)
  end

  defp scale_bytes(bytes, [unit | _rest]) do
    {Integer.to_string(bytes), unit}
  end

  defp format_number(value) when is_integer(value) do
    value
    |> Integer.to_string()
    |> format_number_string()
  end

  defp format_number_string("-" <> digits), do: "-" <> format_number_string(digits)

  defp format_number_string(digits) do
    digits
    |> String.reverse()
    |> String.replace(~r/.{1,3}/, "\\0,")
    |> String.trim_trailing(",")
    |> String.reverse()
  end

  defp div_rem(value, divisor) do
    {div(value, divisor), rem(value, divisor)}
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp parse_operation_kind("setup"), do: {:ok, :setup}
  defp parse_operation_kind("migrate_up"), do: {:ok, :migrate_up}
  defp parse_operation_kind("migrate_down"), do: {:ok, :migrate_down}
  defp parse_operation_kind(_), do: :error

  defp operation_started_message(:setup), do: "ClickHouse database setup started."
  defp operation_started_message(:migrate_up), do: "ClickHouse migrate up started."
  defp operation_started_message(:migrate_down), do: "ClickHouse migrate down started."

  defp operation_title(:setup), do: "Setup Database"
  defp operation_title(:migrate_up), do: "Migrate Up"
  defp operation_title(:migrate_down), do: "Migrate Down"

  defp format_timestamp(nil), do: "n/a"

  defp format_timestamp(%DateTime{} = value),
    do: Calendar.strftime(value, "%Y-%m-%d %H:%M:%S UTC")

  defp format_timestamp(value), do: to_string(value)

  defp operation_status_class(:running),
    do: "inline-flex rounded bg-amber-100 px-2 py-1 text-xs font-semibold text-amber-800"

  defp operation_status_class(:completed),
    do: "inline-flex rounded bg-green-100 px-2 py-1 text-xs font-semibold text-green-800"

  defp operation_status_class(:failed),
    do: "inline-flex rounded bg-red-100 px-2 py-1 text-xs font-semibold text-red-800"

  defp operation_status_class(:initiated),
    do: "inline-flex rounded bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-800"

  defp maybe_append_current_operation_event(socket, operation_id, event) do
    case socket.assigns[:current_operation] do
      %{id: ^operation_id} = operation ->
        assign(socket, current_operation: %{operation | events: operation.events ++ [event]})

      _ ->
        socket
    end
  end

  defp merge_finished_operation(%{id: id, events: events} = _current, %{id: id} = operation) do
    merged = events ++ Enum.reject(operation.events, &(&1 in events))

    %{operation | events: merged}
  end

  defp merge_finished_operation(_current, operation), do: operation

  defp status_indicator_icon(true), do: "✓"
  defp status_indicator_icon(false), do: "✗"

  defp status_indicator_class(true),
    do: "inline-flex items-center gap-1 font-medium text-green-700 dark:text-green-400"

  defp status_indicator_class(false),
    do: "inline-flex items-center gap-1 font-medium text-red-700 dark:text-red-400"

  defp format_uptime_unit(0, _unit), do: nil
  defp format_uptime_unit(value, unit), do: "#{format_number(value)}#{unit}"
end
