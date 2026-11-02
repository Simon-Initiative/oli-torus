defmodule Oli.Auditing.Changes do
  @moduledoc """
  Per-field change records stored in an audit event's `changes` map.

  `changes` is a map from field name to a record. Record keys:

    * `"operation"` (required) - `"set"`, `"reset"`, `"added"`, or `"removed"`
    * `"before"` / `"after"` - persisted values before and after the change
    * `"effective_before"` / `"effective_after"` - resolved values when a reset falls back to
      an inherited setting
    * `"result_source"` - where the effective value comes from after a reset
    * `"unit"`, `"currency"` - qualifiers for numeric values
    * `"redacted"`, `"changed"` - used only by secret fields

  A missing key means "not applicable"; an explicit `nil` means the value was null. Creates
  and deletes are one-sided (`after` only or `before` only).

  Fields declared `:secret` in the contract are always recorded as
  `%{"operation" => "set", "redacted" => true, "changed" => true}` and never carry values.

  Record values are JSON-native terms: strings, numbers, booleans, `nil`, lists, and maps with
  string keys. `diff/3` converts dates, decimals, atoms, and embedded schemas to that form.
  """

  alias Oli.Auditing.Sensitive

  @operations ~w(set reset added removed)
  @record_keys ~w(operation before after effective_before effective_after result_source unit currency redacted changed)
  @secret_record %{"operation" => "set", "redacted" => true, "changed" => true}

  @type field_spec :: %{optional(atom()) => :value | :secret}

  @doc "Returns the record stored for a changed secret field."
  @spec secret_record() :: map()
  def secret_record, do: @secret_record

  @doc """
  Builds change records for the fields of `spec` whose values differ between `before` and
  `after`. Both arguments are persisted states (structs or maps); `nil` means the record did
  not exist, which produces one-sided records.

      iex> Oli.Auditing.Changes.diff(%{max_attempts: 1}, %{max_attempts: 3}, %{max_attempts: :value})
      %{"max_attempts" => %{"operation" => "set", "before" => 1, "after" => 3}}
  """
  @spec diff(map() | struct() | nil, map() | struct() | nil, field_spec()) :: map()
  def diff(before, after_state, spec) do
    before = to_plain_map(before)
    after_state = to_plain_map(after_state)

    Enum.reduce(spec, %{}, fn {field, kind}, acc ->
      old = fetch(before, field)
      new = fetch(after_state, field)

      case same?(old, new) do
        true -> acc
        false -> Map.put(acc, Atom.to_string(field), record(kind, old, new))
      end
    end)
  end

  @doc """
  Validates a `changes` map against a contract field spec. Returns `:ok` or
  `{:error, message}`; messages name fields, never values.
  """
  @spec validate(term(), field_spec()) :: :ok | {:error, String.t()}
  def validate(changes, spec) when is_map(changes) and not is_struct(changes) do
    allowed = Map.new(spec, fn {field, kind} -> {Atom.to_string(field), kind} end)

    Enum.reduce_while(changes, :ok, fn
      {field, record}, :ok when is_binary(field) ->
        case validate_record(field, record, Map.get(allowed, field)) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end

      _entry, :ok ->
        {:halt, {:error, "change fields must be strings"}}
    end)
  end

  def validate(_changes, _spec), do: {:error, "changes must be a map"}

  defp validate_record(field, _record, nil), do: {:error, "unknown change field #{field}"}
  defp validate_record(_field, record, :secret) when record == @secret_record, do: :ok

  defp validate_record(field, _record, :secret),
    do: {:error, "change field #{field} is secret and may only record a redaction marker"}

  defp validate_record(field, record, :value) when is_map(record) do
    keys = Map.keys(record)

    cond do
      not Enum.all?(keys, &(&1 in @record_keys)) ->
        {:error, "change field #{field} has unsupported record keys"}

      Map.get(record, "operation") not in @operations ->
        {:error, "change field #{field} needs a valid operation"}

      Map.has_key?(record, "redacted") or Map.has_key?(record, "changed") ->
        {:error, "change field #{field} is not secret and cannot be redacted"}

      record["operation"] != "reset" and not Map.has_key?(record, "before") and
          not Map.has_key?(record, "after") ->
        {:error, "change field #{field} needs a before or after value"}

      not json_native?(record) ->
        {:error, "change field #{field} has values that are not JSON-native"}

      Sensitive.find_key(record) != nil ->
        {:error, "change field #{field} contains a secret-looking key"}

      true ->
        :ok
    end
  end

  defp validate_record(field, _record, :value),
    do: {:error, "change field #{field} must be a record map"}

  defp record(:secret, _old, _new), do: @secret_record

  defp record(:value, old, new) do
    %{"operation" => "set"}
    |> put_side("before", old)
    |> put_side("after", new)
  end

  defp put_side(record, _key, :missing), do: record
  defp put_side(record, key, value), do: Map.put(record, key, normalize(value))

  defp fetch(nil, _field), do: :missing

  defp fetch(map, field) do
    with :error <- Map.fetch(map, field),
         :error <- Map.fetch(map, Atom.to_string(field)) do
      :missing
    else
      {:ok, value} -> value
    end
  end

  defp normalize(%module{} = value) when module in [DateTime, NaiveDateTime, Date, Time],
    do: module.to_iso8601(value)

  defp normalize(%Decimal{} = value), do: Decimal.to_string(value)

  defp normalize(%_{} = struct),
    do: struct |> Map.from_struct() |> Map.delete(:__meta__) |> normalize()

  defp normalize(map) when is_map(map),
    do: Map.new(map, fn {key, value} -> {normalize_key(key), normalize(value)} end)

  defp normalize(list) when is_list(list), do: Enum.map(list, &normalize/1)

  defp normalize(atom) when is_atom(atom) and not is_boolean(atom) and not is_nil(atom),
    do: Atom.to_string(atom)

  defp normalize(value), do: value

  defp normalize_key(key) when is_binary(key), do: key
  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key), do: inspect(key)

  # Decimals with different scales (1.0 and 1.00) hold the same value.
  defp same?(%Decimal{} = old, %Decimal{} = new), do: Decimal.equal?(old, new)
  defp same?(old, new), do: old == new

  defp json_native?(value) when is_binary(value), do: String.valid?(value)

  defp json_native?(value) when is_number(value) or is_boolean(value) or is_nil(value),
    do: true

  defp json_native?(list) when is_list(list), do: native_list?(list)

  defp json_native?(map) when is_map(map) and not is_struct(map),
    do: Enum.all?(map, fn {key, value} -> is_binary(key) and json_native?(value) end)

  defp json_native?(_value), do: false

  defp native_list?([]), do: true
  defp native_list?([head | tail]), do: json_native?(head) and native_list?(tail)
  defp native_list?(_improper_tail), do: false

  defp to_plain_map(nil), do: nil
  defp to_plain_map(%_{} = struct), do: Map.from_struct(struct)
  defp to_plain_map(map) when is_map(map), do: map
end
