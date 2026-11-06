defmodule Oli.Resources.ObjectiveIds do
  @moduledoc "Validates objective bindings and safely reads IDs from legacy revision JSON."

  @max_id 9_223_372_036_854_775_807
  @decimal_id ~r/\A[1-9][0-9]{0,18}\z/

  @doc "Checks that each binding contains a list of positive bigint objective IDs."
  def valid_bindings?(nil), do: true

  def valid_bindings?(bindings) when is_map(bindings) do
    Enum.all?(bindings, fn
      {_part, ids} when is_list(ids) -> Enum.all?(ids, &valid_id?/1)
      _ -> false
    end)
  end

  def valid_bindings?(_), do: false

  defp valid_id?(id) when is_integer(id), do: id > 0 and id <= @max_id

  defp valid_id?(id) when is_binary(id) and byte_size(id) <= 19 do
    Regex.match?(@decimal_id, id) and String.to_integer(id) <= @max_id
  end

  defp valid_id?(_), do: false

  @doc "Returns an Ecto expression yielding a positive bigint ID or NULL for invalid JSON text."
  defmacro safe_id(value) do
    quote do
      fragment(
        "CASE WHEN ? ~ '^[1-9][0-9]{0,18}$' AND (length(?) < 19 OR ? COLLATE \"C\" <= '9223372036854775807') THEN ?::bigint END",
        unquote(value),
        unquote(value),
        unquote(value),
        unquote(value)
      )
    end
  end
end
