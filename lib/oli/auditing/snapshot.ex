defmodule Oli.Auditing.Snapshot do
  @moduledoc """
  Immutable identity snapshots stored with each audit event.

  A snapshot keeps only allowlisted identity fields (`id`, `name`, `email`, `title`, `slug`,
  `type`, `label`, `key`) so an event stays readable after its target is renamed or deleted,
  without copying arbitrary record state. `search_text/1` is derived from snapshots and
  reference labels only; it never reads current records.
  """

  @fields ~w(id name email title slug type label key)a
  @field_strings Enum.map(@fields, &Atom.to_string/1)
  @search_fields ~w(name email title slug label key)
  @max_value_length 255

  @doc """
  Projects a struct or map into a string-keyed snapshot with allowlisted identity fields.
  `nil` values are dropped; strings longer than #{@max_value_length} characters are truncated.
  """
  @spec of(struct() | map() | nil) :: map()
  def of(nil), do: %{}

  def of(%_{} = struct), do: struct |> Map.from_struct() |> of()

  def of(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      with true <- is_atom(key) or is_binary(key),
           key = to_string(key),
           true <- key in @field_strings,
           value when not is_nil(value) <- snapshot_value(value) do
        Map.put(acc, key, value)
      else
        _ -> acc
      end
    end)
  end

  @doc """
  Validates a stored snapshot: only allowlisted keys with scalar values. Strings must be valid
  UTF-8 and at most #{@max_value_length} characters.
  """
  @spec validate(term()) :: :ok | {:error, String.t()}
  def validate(snapshot) when is_map(snapshot) and not is_struct(snapshot) do
    Enum.reduce_while(snapshot, :ok, fn {key, value}, :ok ->
      case is_binary(key) and key in @field_strings and scalar?(value) do
        true -> {:cont, :ok}
        false -> {:halt, {:error, "unsupported snapshot field #{inspect(key)}"}}
      end
    end)
  end

  def validate(_), do: {:error, "snapshot must be a map"}

  @doc """
  Builds the text indexed for search from snapshots and reference labels.

      iex> Oli.Auditing.Snapshot.search_text([%{"name" => "Ada", "email" => "ada@example.edu"}, %{"title" => "Biology"}])
      "Ada ada@example.edu Biology"
  """
  @spec search_text([map()]) :: String.t()
  def search_text(snapshots) when is_list(snapshots) do
    snapshots
    |> Enum.flat_map(fn snapshot ->
      Enum.flat_map(@search_fields, fn field ->
        case Map.get(snapshot, field) do
          value when is_binary(value) and value != "" -> [value]
          _ -> []
        end
      end)
    end)
    |> Enum.uniq()
    |> Enum.join(" ")
  end

  defp snapshot_value(value) when is_binary(value), do: String.slice(value, 0, @max_value_length)
  defp snapshot_value(value) when is_atom(value) and not is_nil(value), do: Atom.to_string(value)
  defp snapshot_value(value) when is_integer(value), do: value
  defp snapshot_value(_), do: nil

  @doc """
  Returns true for a valid UTF-8 string of at most #{@max_value_length} characters, the limit for
  snapshot values and reference labels.
  """
  @spec valid_text?(term()) :: boolean()
  def valid_text?(value) when is_binary(value),
    do: String.valid?(value) and String.length(value) <= @max_value_length

  def valid_text?(_value), do: false

  defp scalar?(value), do: valid_text?(value) or is_integer(value) or is_boolean(value)
end
