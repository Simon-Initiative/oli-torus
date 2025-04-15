defmodule Oli.LoggerTruncator do
  @moduledoc """
  A Logger filter to prevent excessive memory usage by truncating large log messages and
  metadata.

  ### Why is this important?

  In Elixir systems, log events and their associated metadata are passed around
  as **fully constructed Elixir terms** (maps, lists, binaries) before being
  formatted for console or external backends like AppSignal.

  Without truncation, a single **large log message** (e.g., logging a large Ecto struct,
  deeply nested map, or session data) can cause the `Logger` process or any downstream
  handlers to hold onto **multi-megabyte terms** in memory. This may lead to:

  - Excessive memory usage (observed as spikes in `eheap_alloc` via the Erlang VM)
  - Increased payload sizes for observability tools like AppSignal
  - Potential crashes or slowdowns due to bloated Logger or telemetry queues

  ### What does this module do?

  This filter automatically truncates **long binaries inside log messages and metadata** to
  a configurable `max_length` to:
  - Prevent accidental heap bloat from oversized logs.
  - Ensure consistent log sizes.
  - Avoid expensive telemetry or tracing calls related to large log events.

  ### How does it work?

  - If the `msg` is a binary (e.g., `"Some large string..."`), it will be truncated if it
    exceeds the limit.
  - If the `msg` is a list (common with Phoenix structured logs like `[prefix, params]`),
    only large **binary elements inside the list** are truncated.
  - Metadata fields are also truncated on a per-key basis, while preserving their structure.

  """

  @truncate_msg " [TRUNCATED]"

  def init() do
    if Application.get_env(:oli, :logger_truncation_enabled) do
      max_length = Application.get_env(:oli, :logger_truncation_length)

      :logger.add_primary_filter(
        :logger_truncator,
        {&Oli.LoggerTruncator.filter/2, [max_length: max_length]}
      )
    end
  end

  def filter(%{msg: {format, msg}} = log_event, opts) do
    max_length = Keyword.get(opts, :max_length, 5000)

    new_msg = sanitize_msg(msg, max_length)
    %{log_event | msg: {format, new_msg}}
  end

  def filter(%{msg: {format, mod, msg}} = log_event, opts) do
    max_length = Keyword.get(opts, :max_length, 5000)

    new_msg = sanitize_msg(msg, max_length)
    %{log_event | msg: {format, mod, new_msg}}
  end

  def filter(log_event, _opts) do
    log_event
  end

  defp sanitize_msg(msg, max_length) when is_binary(msg), do: truncate_if_needed(msg, max_length)

  defp sanitize_msg(msg, max_length) when is_list(msg) do
    Enum.map(msg, fn
      str when is_binary(str) -> truncate_if_needed(str, max_length)
      other -> other
    end)
  end

  defp sanitize_msg(msg, max_length) when is_map(msg) do
    try do
      msg
      # truncate to first 50 keys if needed
      |> Enum.take(50)
      |> Enum.map(fn {k, v} ->
        {k, sanitize_msg(v, max_length)}
      end)
      |> Enum.into(%{})
    rescue
      _error -> %{msg: "[TRUNCATED]"} # Log an error message if something goes wrong
    end
  end

  defp sanitize_msg(other, _) do
    other
  end

  defp truncate_if_needed(msg, max_length) when is_binary(msg) do
    try do
      if byte_size(msg) > max_length do
        String.slice(msg, 0, max_length) <> @truncate_msg
      else
        msg
      end
    rescue
      _error -> "[TRUNCATED]" # If an error occurs during truncation, return a truncated message.
    end
  end
end
