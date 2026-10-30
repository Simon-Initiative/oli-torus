defmodule Oli.Auditing.Sensitive do
  @moduledoc """
  Detects key names that may carry credentials or secrets.

  Audit payloads never store values under these keys. Contract fields that are secret by
  design are declared as `:secret` in the event catalog and recorded only as a redaction
  marker; any other occurrence of a matching key is rejected.
  """

  @pattern ~r/pass(word|code|phrase)|secret|token|credential|(api|private|client|access|signing)_key|jwks?|bearer|authorization|cookie|(^|_)otp(_|$)/i

  @doc "Returns true when the key name looks like it holds a secret."
  @spec key?(atom() | String.t()) :: boolean()
  def key?(key) when is_atom(key), do: key |> Atom.to_string() |> key?()
  def key?(key) when is_binary(key), do: Regex.match?(@pattern, key)

  @doc """
  Returns the path of the first secret-looking key nested anywhere in `value`, or `nil`.
  """
  @spec find_key(term()) :: [String.t()] | nil
  def find_key(value), do: find_key(value, [])

  defp find_key(%module{}, _path) when module in [DateTime, NaiveDateTime, Date, Time, Decimal],
    do: nil

  defp find_key(%_{} = struct, path), do: struct |> Map.from_struct() |> find_key(path)

  defp find_key(map, path) when is_map(map) do
    Enum.find_value(map, fn
      {key, value} when is_binary(key) or is_atom(key) ->
        key = to_string(key)

        case key?(key) do
          true -> Enum.reverse([key | path])
          false -> find_key(value, [key | path])
        end

      {_key, value} ->
        find_key(value, path)
    end)
  end

  # Walks the list by hand so an improper tail is ignored here and rejected by the caller.
  defp find_key([head | tail], path), do: find_key(head, path) || find_key(tail, path)
  defp find_key(_value, _path), do: nil
end
