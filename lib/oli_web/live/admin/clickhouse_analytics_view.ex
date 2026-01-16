defmodule OliWeb.Admin.ClickHouseAnalyticsView do
  use OliWeb, :live_view

  alias Oli.Analytics.ClickhouseAnalytics
  alias Oli.Features
  alias OliWeb.Common.Breadcrumb

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(_, _, socket) do
    if Features.enabled?("clickhouse-olap") do
      {:ok,
       assign(socket,
         title: "ClickHouse Analytics",
         breadcrumbs: breadcrumbs()
       )
       |> assign_async(:health_summary, fn ->
         case ClickhouseAnalytics.health_summary() do
           {:ok, summary} -> {:ok, %{health_summary: summary}}
           {:error, reason} -> {:error, reason}
         end
       end)}
    else
      {:ok,
       socket
       |> put_flash(:error, "ClickHouse analytics is not enabled.")
       |> redirect(to: ~p"/admin")}
    end
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
                ClickHouse health check failed: {inspect(reason)}
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
      </div>
    </div>
    """
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

  defp format_uptime_unit(0, _unit), do: nil
  defp format_uptime_unit(value, unit), do: "#{format_number(value)}#{unit}"
end
