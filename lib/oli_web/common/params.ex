defmodule OliWeb.Common.Params do
  def get_int_param(params, name, default_value) do
    case params[name] do
      nil ->
        default_value

      value ->
        case Integer.parse(value) do
          {num, _} -> num
          _ -> default_value
        end
    end
  end

  def get_param(params, name, default_value) do
    case params[name] do
      nil ->
        default_value

      value ->
        value
    end
  end

  def get_boolean_param(params, name, default_value) do
    case params[name] do
      nil ->
        default_value

      "false" ->
        false

      "true" ->
        true

      _ ->
        default_value
    end
  end

  def get_atom_param(params, name, valid, default_value)
      when is_list(valid) and is_binary(name) do
    case params[name] do
      nil ->
        default_value

      value ->
        value = String.to_existing_atom(value)

        case MapSet.new(valid) |> MapSet.member?(value) do
          true -> value
          _ -> default_value
        end
    end
  end

  def trim(params) do
    Enum.reduce(params, %{}, fn {field, value}, acc ->
      Map.put(acc, field, String.trim(value))
    end)
  end
end
