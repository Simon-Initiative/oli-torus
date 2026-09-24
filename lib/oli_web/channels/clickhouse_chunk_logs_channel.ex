defmodule OliWeb.ClickhouseChunkLogsChannel do
  @moduledoc """
  Channel that streams ClickHouse inventory chunk logs to connected clients.
  """

  use OliWeb, :channel

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Analytics.Backfill.Inventory

  @max_limit 200

  @impl true
  def join("clickhouse_chunk_logs:" <> batch_id, params, socket) do
    with {batch_id, ""} <- Integer.parse(batch_id),
         {:ok, socket} <- authorize(socket) do
      limit = params |> Map.get("limit", 10) |> parse_limit()

      %{entries: entries, total: total, offset: offset} =
        Inventory.fetch_chunk_logs(batch_id,
          limit: limit,
          include_total: true,
          direction: :latest
        )

      logs = Inventory.format_chunk_logs(entries, offset)

      payload = %{
        batch_id: batch_id,
        logs: logs,
        offset: offset,
        total: total,
        has_more: has_more?(entries, offset, total),
        limit: limit,
        direction: "latest"
      }

      :ok = Phoenix.PubSub.subscribe(Oli.PubSub, Inventory.chunk_logs_topic(batch_id))

      {:ok, payload, assign(socket, batch_id: batch_id, limit: limit)}
    else
      _ -> :error
    end
  end

  @impl true
  def handle_in("load", params, socket) do
    direction = Map.get(params, "direction", "next")
    offset = params |> Map.get("offset", 0) |> parse_offset()
    limit = params |> Map.get("limit", socket.assigns.limit) |> parse_limit()

    %{entries: entries, total: total, offset: effective_offset} =
      Inventory.fetch_chunk_logs(socket.assigns.batch_id,
        offset: offset,
        limit: limit,
        include_total: true,
        direction: normalize_direction(direction)
      )

    logs = Inventory.format_chunk_logs(entries, effective_offset)

    payload = %{
      batch_id: socket.assigns.batch_id,
      logs: logs,
      offset: effective_offset,
      total: total,
      direction: direction,
      has_more: has_more?(entries, effective_offset, total)
    }

    {:reply, {:ok, payload}, assign(socket, :limit, limit)}
  end

  @impl true
  def handle_info({:chunk_log_appended, payload}, socket) do
    push(socket, "new_logs", payload)
    {:noreply, socket}
  end

  defp authorize(%{assigns: %{user: author_id}} = socket) when is_integer(author_id) do
    case Accounts.get_author(author_id) do
      %Author{} = author -> {:ok, assign(socket, :author, author)}
      _ -> :error
    end
  end

  defp authorize(_), do: :error

  defp normalize_direction(direction) when direction in ["prev", "previous"], do: :previous
  defp normalize_direction(direction) when direction in ["refresh"], do: :refresh
  defp normalize_direction(direction) when direction in ["latest"], do: :latest
  defp normalize_direction(_), do: :forward

  defp parse_limit(value) when is_integer(value) and value > 0 do
    min(value, @max_limit)
  end

  defp parse_limit(value) when is_binary(value) do
    value
    |> String.trim()
    |> Integer.parse()
    |> case do
      {int, ""} -> parse_limit(int)
      {int, nil} -> parse_limit(int)
      _ -> parse_limit(10)
    end
  end

  defp parse_limit(_), do: 10

  defp parse_offset(value) when is_integer(value) and value >= 0, do: value

  defp parse_offset(value) when is_binary(value) do
    value
    |> String.trim()
    |> Integer.parse()
    |> case do
      {int, ""} when int >= 0 -> int
      {int, nil} when int >= 0 -> int
      _ -> 0
    end
  end

  defp parse_offset(_), do: 0

  defp has_more?(entries, offset, total) when is_integer(total) do
    offset + length(entries) < total
  end

  defp has_more?(_entries, _offset, _total), do: false
end
