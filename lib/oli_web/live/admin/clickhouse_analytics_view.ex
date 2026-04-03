defmodule OliWeb.Admin.ClickHouseAnalyticsView do
  use OliWeb, :live_view

  alias Oli.Analytics.ClickhouseAnalytics
  alias Oli.Clickhouse.AdminOperations
  alias Oli.Features
  import OliWeb.Components.Modal
  alias OliWeb.Common.Breadcrumb

  @max_operation_events 200

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(_, _, socket) do
    if Features.enabled?("clickhouse-olap") do
      socket =
        socket
        |> assign(
          title: gettext("ClickHouse Analytics"),
          breadcrumbs: breadcrumbs(),
          current_operation: nil,
          pending_confirmation: nil
        )
        |> load_dashboard_async()

      if connected?(socket) do
        AdminOperations.subscribe()
      end

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, gettext("ClickHouse analytics is not enabled."))
       |> redirect(to: ~p"/admin")}
    end
  end

  def handle_event("run_clickhouse_operation", %{"kind" => kind}, socket) do
    case parse_operation_kind(kind) do
      {:ok, operation_kind} when operation_kind in [:migrate_up, :migrate_down] ->
        {:noreply, assign(socket, pending_confirmation: operation_kind)}

      {:ok, operation_kind} ->
        {:noreply, run_clickhouse_operation(socket, operation_kind)}

      :error ->
        {:noreply, put_flash(socket, :error, gettext("Unsupported ClickHouse operation."))}
    end
  end

  def handle_event(
        "confirm_clickhouse_operation",
        _params,
        %{assigns: %{pending_confirmation: nil}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event(
        "confirm_clickhouse_operation",
        _params,
        %{assigns: %{pending_confirmation: operation_kind}} = socket
      ) do
    {:noreply,
     socket
     |> assign(pending_confirmation: nil)
     |> run_clickhouse_operation(operation_kind)}
  end

  def handle_event("cancel_clickhouse_operation", _params, socket) do
    {:noreply, assign(socket, pending_confirmation: nil)}
  end

  defp run_clickhouse_operation(socket, operation_kind) do
    case AdminOperations.start(operation_kind, socket.assigns.current_author) do
      {:ok, operation} ->
        socket
        |> put_flash(:info, operation_started_message(operation_kind))
        |> assign(current_operation: operation)
        |> load_dashboard_async()

      {:error, :setup_not_available} ->
        put_flash(socket, :error, gettext("Setup database is not currently available."))

      {:error, :clickhouse_unreachable} ->
        put_flash(
          socket,
          :error,
          gettext("ClickHouse must be reachable before running migrations.")
        )

      {:error, :migrate_up_not_available} ->
        put_flash(socket, :error, gettext("There are no pending ClickHouse migrations."))

      {:error, :unauthorized} ->
        put_flash(
          socket,
          :error,
          gettext("You are not authorized to run ClickHouse admin operations.")
        )

      {:error, :operation_in_progress} ->
        put_flash(socket, :error, gettext("A ClickHouse admin operation is already running."))

      {:error, reason} ->
        put_flash(socket, :error, format_error(reason))
    end
  end

  def handle_info({:clickhouse_admin_operation_started, _operation}, socket),
    do: {:noreply, socket}

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
        <h1 class="text-3xl font-bold mb-6">{gettext("ClickHouse Dashboard")}</h1>
        <div class="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg mb-6">
          <h2 class="text-xl font-semibold mb-2">{gettext("Health")}</h2>
          <p class="text-gray-600 dark:text-gray-400 mb-4">
            {gettext(
              "Live health and metadata metrics for the ClickHouse connection and raw events storage."
            )}
          </p>

          <.async_result :let={summary} assign={@health_summary}>
            <:loading>
              <div class="text-gray-500 dark:text-gray-400">
                {gettext("Loading health metrics...")}
              </div>
            </:loading>
            <:failed :let={reason}>
              <div class="text-red-600 dark:text-red-400">
                {gettext("ClickHouse health check failed: %{reason}",
                  reason: format_error(reason)
                )}
              </div>
            </:failed>
            <% raw_events = Map.get(summary, :raw_events, %{}) %>
            <% raw_events_parts = Map.get(summary, :raw_events_parts, %{}) %>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4">
                <h3 class="text-lg font-semibold">{gettext("Connection")}</h3>
                <div class="mt-3 text-sm text-gray-700 dark:text-gray-300 space-y-1">
                  <div>
                    {gettext("Status")}:
                    <span class="text-green-600 dark:text-green-400">{gettext("Healthy")}</span>
                  </div>
                  <div>{gettext("Host")}: {summary["hostname"] || gettext("unknown")}</div>
                  <div>{gettext("Version")}: {summary["version"] || gettext("unknown")}</div>
                  <div>{gettext("Timezone")}: {summary["timezone"] || gettext("unknown")}</div>
                  <div>{gettext("Server time")}: {summary["server_time"] || gettext("unknown")}</div>
                  <div>{gettext("Uptime")}: {format_uptime(summary["uptime_seconds"])}</div>
                </div>
              </div>
              <div class="bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4">
                <h3 class="text-lg font-semibold">{gettext("Database")}</h3>
                <div class="mt-3 text-sm text-gray-700 dark:text-gray-300 space-y-1">
                  <div>
                    {gettext("Configured DB")}: {summary["configured_database"] || gettext("unknown")}
                  </div>
                  <div>
                    {gettext("Current DB")}: {summary["current_database"] || gettext("unknown")}
                  </div>
                </div>
              </div>
              <div class="bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4 md:col-span-2">
                <h3 class="text-lg font-semibold">raw_events</h3>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-3">
                  <div>
                    <h4 class="text-sm font-semibold text-gray-700 dark:text-gray-300">
                      {gettext("Table")}
                    </h4>
                    <div class="mt-2 text-sm text-gray-700 dark:text-gray-300 space-y-1">
                      <div>{gettext("Engine")}: {raw_events["engine"] || gettext("unknown")}</div>
                      <div>{gettext("Total rows")}: {format_int(raw_events["total_rows"])}</div>
                      <div>{gettext("Total bytes")}: {format_bytes(raw_events["total_bytes"])}</div>
                      <div>
                        {gettext("Metadata updated")}: {raw_events["metadata_modification_time"] ||
                          gettext("unknown")}
                      </div>
                    </div>
                  </div>
                  <div>
                    <h4 class="text-sm font-semibold text-gray-700 dark:text-gray-300">
                      {gettext("Parts")}
                    </h4>
                    <div class="mt-2 text-sm text-gray-700 dark:text-gray-300 space-y-1">
                      <div>
                        {gettext("Active parts")}: {format_int(raw_events_parts["active_parts"])}
                      </div>
                      <div>
                        {gettext("Rows on disk")}: {format_int(raw_events_parts["rows_on_disk"])}
                      </div>
                      <div>
                        {gettext("Bytes on disk")}: {format_bytes(raw_events_parts["bytes_on_disk"])}
                      </div>
                      <div>
                        {gettext("Last part modification")}: {raw_events_parts[
                          "last_part_modification"
                        ] ||
                          gettext("unknown")}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </.async_result>
        </div>

        <div class="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg">
          <h2 class="text-xl font-semibold mb-2">{gettext("Database Operations")}</h2>
          <p class="text-gray-600 dark:text-gray-400 mb-4">
            {gettext(
              "Admin database operations. Create, drop, and reset operations must be performed in the iex shell"
            )}
          </p>

          <.async_result :let={capabilities} assign={@clickhouse_capabilities}>
            <:loading>
              <div class="text-gray-500 dark:text-gray-400">
                {gettext("Loading operation capabilities...")}
              </div>
            </:loading>
            <:failed :let={reason}>
              <div class="text-red-600 dark:text-red-400">
                {gettext("ClickHouse capability check failed: %{reason}",
                  reason: format_error(reason)
                )}
              </div>
            </:failed>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div class="flex h-full flex-col bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4">
                <h3 class="text-lg font-semibold">{gettext("Setup Database")}</h3>
                <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
                  {gettext("Required before torus analytics can use this ClickHouse database.")}
                </p>
                <div class="mt-2 flex flex-col items-start gap-1 text-xs text-gray-500 dark:text-gray-400">
                  <span class={status_indicator_class(capabilities.reachable)}>
                    {status_indicator_icon(capabilities.reachable)} {gettext("Reachable")}
                  </span>
                  <span class={status_indicator_class(capabilities.database_exists)}>
                    {status_indicator_icon(capabilities.database_exists)} {gettext("Database exists")}
                  </span>
                  <span class={status_indicator_class(capabilities.table_exists)}>
                    {status_indicator_icon(capabilities.table_exists)} {gettext("Table exists")}
                  </span>
                </div>
                <button
                  type="button"
                  phx-click="run_clickhouse_operation"
                  phx-value-kind="setup"
                  class="mt-4 self-start inline-flex items-center rounded bg-blue-700 px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={!capabilities.setup_enabled}
                >
                  {gettext("Setup Database")}
                </button>
              </div>

              <div class="flex h-full flex-col bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4">
                <h3 class="text-lg font-semibold">{gettext("Migrate Up")}</h3>
                <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
                  {gettext("Apply pending ClickHouse migrations.")}
                </p>
                <p class="mt-2 text-xs text-gray-500 dark:text-gray-400">
                  {pending_migrations_label(capabilities.pending_migration_count)}
                </p>
                <button
                  type="button"
                  phx-click="run_clickhouse_operation"
                  phx-value-kind="migrate_up"
                  class="mt-auto self-start inline-flex items-center rounded bg-amber-600 px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={!capabilities.migrate_up_enabled}
                >
                  {gettext("Migrate Up")}
                </button>
              </div>

              <div class="flex h-full flex-col bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4">
                <h3 class="text-lg font-semibold">{gettext("Migrate Down")}</h3>
                <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
                  {gettext("Roll back the most recent ClickHouse migration.")}
                </p>
                <button
                  type="button"
                  phx-click="run_clickhouse_operation"
                  phx-value-kind="migrate_down"
                  class="mt-auto self-start inline-flex items-center rounded bg-amber-600 px-4 py-2 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
                  disabled={!capabilities.reachable}
                >
                  {gettext("Migrate Down")}
                </button>
              </div>
            </div>
          </.async_result>

          <%= if @current_operation do %>
            <div class="mt-6">
              <h3 class="text-lg font-semibold mb-3">{gettext("Current Operation")}</h3>
              <div class="bg-white dark:bg-gray-900 border dark:border-gray-700 rounded-lg p-4">
                <div class="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
                  <div>
                    <div class="font-semibold">{operation_title(@current_operation.kind)}</div>
                    <div class="text-sm text-gray-500 dark:text-gray-400">
                      {gettext("Status")}: {@current_operation.status} | {gettext("Started")}: {format_timestamp(
                        @current_operation.started_at
                      )}
                      <%= if @current_operation.finished_at do %>
                        | {gettext("Finished")}: {format_timestamp(@current_operation.finished_at)}
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
                  <div class="text-sm font-semibold mb-2">{gettext("Progress")}</div>
                  <ul class="space-y-2 text-sm">
                    <%= for event <- events_for_display(@current_operation.events) do %>
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

        <.modal
          :if={@pending_confirmation in [:migrate_up, :migrate_down]}
          id="clickhouse-operation-confirmation"
          show
          on_cancel={JS.push("cancel_clickhouse_operation")}
        >
          <div class="space-y-4">
            <div>
              <h3 class="text-lg font-semibold">
                {gettext("Confirm %{operation}", operation: operation_title(@pending_confirmation))}
              </h3>
              <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
                {confirmation_message(@pending_confirmation)}
              </p>
            </div>
            <div class="flex items-center justify-end gap-3">
              <button
                type="button"
                phx-click="cancel_clickhouse_operation"
                class="inline-flex items-center rounded border border-gray-300 px-4 py-2 text-sm font-semibold text-gray-700 dark:border-gray-600 dark:text-gray-200"
              >
                {gettext("Cancel")}
              </button>
              <button
                type="button"
                phx-click="confirm_clickhouse_operation"
                class="inline-flex items-center rounded bg-amber-600 px-4 py-2 text-sm font-semibold text-white"
              >
                {gettext("Confirm")}
              </button>
            </div>
          </div>
        </.modal>
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
          full_title: gettext("ClickHouse Dashboard"),
          link: ~p"/admin/clickhouse"
        })
      ]
  end

  defp format_int(nil), do: gettext("n/a")
  defp format_int(value) when is_integer(value), do: format_number(value)
  defp format_int(value) when is_float(value), do: :erlang.float_to_binary(value, [:compact])
  defp format_int(value) when is_binary(value), do: value
  defp format_int(_), do: gettext("n/a")

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
      [] -> gettext("0s")
      parts -> Enum.join(parts, " ")
    end
  end

  defp format_uptime(value), do: format_int(value)

  defp format_bytes(nil), do: gettext("n/a")

  defp format_bytes(value) when is_integer(value) and value >= 0 do
    units = ["B", "KB", "MB", "GB", "TB"]
    {scaled, unit} = scale_bytes(value, units)
    "#{scaled} #{unit}"
  end

  defp format_bytes(value) when is_binary(value), do: value
  defp format_bytes(_), do: gettext("n/a")

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

  defp operation_started_message(:setup), do: gettext("ClickHouse database setup started.")
  defp operation_started_message(:migrate_up), do: gettext("ClickHouse migrate up started.")
  defp operation_started_message(:migrate_down), do: gettext("ClickHouse migrate down started.")

  defp operation_title(:setup), do: gettext("Setup Database")
  defp operation_title(:migrate_up), do: gettext("Migrate Up")
  defp operation_title(:migrate_down), do: gettext("Migrate Down")

  defp confirmation_message(:migrate_up),
    do: gettext("This will apply all pending ClickHouse migrations.")

  defp confirmation_message(:migrate_down),
    do:
      gettext(
        "This will roll back the most recent ClickHouse migration which may result in data loss."
      )

  defp pending_migrations_label(1),
    do: ngettext("%{count} pending migration", "%{count} pending migrations", 1, count: 1)

  defp pending_migrations_label(count) when is_integer(count) and count > 1,
    do: ngettext("%{count} pending migration", "%{count} pending migrations", count, count: count)

  defp pending_migrations_label(_), do: gettext("No pending migrations")

  defp format_timestamp(nil), do: gettext("n/a")

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
        assign(socket,
          current_operation: %{
            operation
            | events:
                [event | operation.events]
                |> Enum.take(@max_operation_events)
          }
        )

      _ ->
        socket
    end
  end

  defp merge_finished_operation(%{id: id, events: events} = _current, %{id: id} = operation) do
    merged =
      Enum.reject(operation.events, &(&1 in events))
      |> Kernel.++(events)
      |> Enum.take(@max_operation_events)

    %{operation | events: merged}
  end

  defp merge_finished_operation(_current, operation), do: operation

  defp events_for_display(events) when is_list(events), do: Enum.reverse(events)
  defp events_for_display(_), do: []

  defp status_indicator_icon(true), do: "✓"
  defp status_indicator_icon(false), do: "✗"

  defp status_indicator_class(true),
    do: "inline-flex items-center gap-1 font-medium text-green-700 dark:text-green-400"

  defp status_indicator_class(false),
    do: "inline-flex items-center gap-1 font-medium text-red-700 dark:text-red-400"

  defp format_uptime_unit(0, _unit), do: nil
  defp format_uptime_unit(value, unit), do: "#{format_number(value)}#{unit}"
end
