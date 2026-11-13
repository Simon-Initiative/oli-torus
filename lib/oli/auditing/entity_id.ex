defmodule Oli.Auditing.EntityId do
  @moduledoc """
  Composite audit entity identifiers.

  Entities without a single stable ID, such as a per-student exception, are identified by an
  ordered list of `type:id` segments: `section:12/resource:34/user:56`. Composite IDs are
  produced only by `compose/1`, so the same entity always yields the same text.
  """

  @segment ~r/^[a-z][a-z0-9_]{0,62}$/
  @value ~r/^[A-Za-z0-9_\-]+$/

  @doc """
  Composes an entity ID from ordered `{type, id}` segments.

      iex> Oli.Auditing.EntityId.compose(section: 12, resource: 34, user: 56)
      "section:12/resource:34/user:56"
  """
  @spec compose([{atom(), term()}, ...]) :: String.t()
  def compose([_ | _] = segments) do
    Enum.map_join(segments, "/", fn {type, id} ->
      type = Atom.to_string(type)
      id = to_string(id)

      case Regex.match?(@segment, type) and Regex.match?(@value, id) do
        true -> "#{type}:#{id}"
        false -> raise ArgumentError, "invalid entity ID segment #{inspect({type, id})}"
      end
    end)
  end

  @doc """
  Parses a composite ID back into `{type, id}` string pairs.

      iex> Oli.Auditing.EntityId.parse("section:12/user:56")
      {:ok, [{"section", "12"}, {"user", "56"}]}
  """
  @spec parse(String.t()) :: {:ok, [{String.t(), String.t()}]} | :error
  def parse(entity_id) when is_binary(entity_id) do
    entity_id
    |> String.split("/")
    |> Enum.reduce_while({:ok, []}, fn segment, {:ok, acc} ->
      case String.split(segment, ":", parts: 2) do
        [type, id] ->
          case Regex.match?(@segment, type) and Regex.match?(@value, id) do
            true -> {:cont, {:ok, [{type, id} | acc]}}
            false -> {:halt, :error}
          end

        _ ->
          {:halt, :error}
      end
    end)
    |> case do
      {:ok, segments} -> {:ok, Enum.reverse(segments)}
      :error -> :error
    end
  end
end
