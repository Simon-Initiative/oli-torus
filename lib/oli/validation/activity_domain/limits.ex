defmodule Oli.Validation.ActivityDomain.Limits do
  @moduledoc "Bounds untrusted activity input before schema and domain processing."
  alias Oli.Validation.ActivityDomain.Issue

  @max_bytes 4 * 1024 * 1024
  @max_depth 128
  @max_nodes 100_000

  @doc "Decodes a bounded JSON string, checking nesting before JSON decoding."
  def decode(json) when is_binary(json) and byte_size(json) <= @max_bytes do
    with :ok <- depth(json, 0, false, false),
         {:ok, model} <- Jason.decode(json),
         :ok <- check(model) do
      {:ok, model}
    else
      {:error, %Jason.DecodeError{}} -> {:error, [Issue.new("invalid_json", [], "Invalid JSON")]}
      error -> error
    end
  end

  def decode(_), do: exceeded()

  @doc "Checks a decoded JSON value's depth and node budget without changing it."
  def check(model) do
    case nodes([{model, 0}], 0, 0) do
      :ok -> :ok
      _ -> exceeded()
    end
  end

  defp nodes(_, _, bytes) when bytes > @max_bytes, do: :error
  defp nodes([], _, _), do: :ok
  defp nodes(_, count, _) when count >= @max_nodes, do: :error
  defp nodes([{_, depth} | _], _, _) when depth > @max_depth, do: :error

  defp nodes([{value, depth} | rest], count, bytes) when is_map(value) do
    case Enum.all?(Map.keys(value), &is_binary/1) do
      true ->
        key_bytes = Enum.reduce(Map.keys(value), 0, fn key, acc -> acc + byte_size(key) end)

        nodes(
          Enum.reduce(value, rest, fn {_, child}, acc -> [{child, depth + 1} | acc] end),
          count + 1,
          bytes + key_bytes
        )

      false ->
        :error
    end
  end

  defp nodes([{value, depth} | rest], count, bytes) when is_list(value),
    do:
      nodes(
        Enum.reduce(value, rest, fn child, acc -> [{child, depth + 1} | acc] end),
        count + 1,
        bytes
      )

  defp nodes([{value, _} | rest], count, bytes) when is_binary(value),
    do: nodes(rest, count + 1, bytes + byte_size(value))

  defp nodes([{value, _} | rest], count, bytes)
       when is_number(value) or is_boolean(value) or is_nil(value),
       do: nodes(rest, count + 1, bytes)

  defp nodes(_, _, _), do: :error

  defp depth(_, n, _, _) when n > @max_depth or n < 0, do: exceeded()
  defp depth(<<>>, _, _, _), do: :ok
  defp depth(<<_, rest::binary>>, n, true, true), do: depth(rest, n, true, false)
  defp depth(<<?\\, rest::binary>>, n, true, false), do: depth(rest, n, true, true)
  defp depth(<<?", rest::binary>>, n, quoted, false), do: depth(rest, n, not quoted, false)
  defp depth(<<_, rest::binary>>, n, true, false), do: depth(rest, n, true, false)

  defp depth(<<c, rest::binary>>, n, false, false) when c in [?{, ?[],
    do: depth(rest, n + 1, false, false)

  defp depth(<<c, rest::binary>>, n, false, false) when c in [?}, ?]],
    do: depth(rest, n - 1, false, false)

  defp depth(<<_, rest::binary>>, n, false, false), do: depth(rest, n, false, false)

  defp exceeded,
    do:
      {:error,
       [
         Issue.new(
           "input_limit_exceeded",
           [],
           "Activity exceeds JSON size, depth, or node limits"
         )
       ]}
end
