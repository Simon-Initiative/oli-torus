defmodule Oli.Delivery.Depot.Serializer do

  alias Oli.Delivery.Depot.DepotDesc

  @doc """
  Serializes a struct into a tuple. It handles both fields and embedded schemas.
  """
  def serialize(instance, %DepotDesc{} = depot_desc) do

    list = fields(depot_desc)
    |> Enum.map(fn field ->

      data_type = type(depot_desc, field)

      Map.get(instance, field)
      |> encode_by_type(data_type)
    end)

    List.to_tuple([Map.get(instance, depot_desc.key_field) | list])
  end

  def serialize(section_id, key_values, %DepotDesc{} = depot_desc) do
    # take the keyword list key_values and turn it into a map
    map = Enum.into(key_values, %{})

    list = fields(depot_desc)
    |> Enum.map(fn field -> Map.get(map, field, :_) end)

    List.to_tuple([section_id | list])
  end

  def unserialize(list, %DepotDesc{} = depot_desc) when is_list(list) do
    Enum.map(list, fn item -> unserialize(item, depot_desc) end)
  end

  @doc """
  Unserializes a tuple back into a struct. Assumes the tuple has values in the same order
  as the schema fields.
  """
  def unserialize(tuple, %DepotDesc{} = depot_desc) when is_tuple(tuple) do
    fields = fields(depot_desc)

    # Convert tuple to list for easy manipulation, but drop the section_id
    # as it is duplicated within the other portion of the list, anyways.
    [_section_id | values] = Tuple.to_list(tuple)

    # Build the struct by matching the values to the schema fields
    fields
    |> Enum.zip(values)
    |> Enum.reduce(build(depot_desc), fn {field, value}, acc ->

      value = decode_by_type(value, type(depot_desc, field))
      Map.put(acc, field, value)
    end)
  end

  # We special case encode date times to unix time in milliseconds
  # so that we can easily to equality and range queries on them.
  defp encode_by_type(value, :utc_datetime) do
    case value do
      nil -> nil
      _ -> DateTime.to_unix(value, :second)
    end
  end

  defp encode_by_type(value, _), do: value

  defp decode_by_type(value, :utc_datetime) do
    case value do
      nil -> nil
      _ ->
        {:ok, value} = DateTime.from_unix(value, :second)
        value
    end
  end

  defp decode_by_type(value, _), do: value

  defp fields(%DepotDesc{schema: schema}), do: apply(schema, :__schema__, [:fields])

  defp type(%DepotDesc{schema: schema}, field), do: apply(schema, :__schema__, [:type, field])

  defp build(%DepotDesc{schema: schema}), do: struct(schema)

end
