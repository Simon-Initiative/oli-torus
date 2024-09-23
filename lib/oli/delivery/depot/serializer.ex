defmodule Oli.Delivery.Depot.Serializer do
  alias Oli.Delivery.Sections.SectionResource

  @doc """
  Serializes a struct into a tuple. It handles both fields and embedded schemas.
  """
  def serialize(%SectionResource{} = sr) do
    list = SectionResource.__schema__(:fields)
    |> Enum.map(fn field ->

      data_type = SectionResource.__schema__(:type, field)

      Map.get(sr, field)
      |> encode_by_type(data_type)
    end)

    List.to_tuple([sr.section_id | list])
  end

  def serialize(section_id, key_values) do
    # take the keyword list key_values and turn it into a map
    map = Enum.into(key_values, %{})

    list = SectionResource.__schema__(:fields)
    |> Enum.map(fn field -> Map.get(map, field, :_) end)

    List.to_tuple([section_id | list])
  end

  def unserialize(list) when is_list(list), do: Enum.map(list, &unserialize/1)

  @doc """
  Unserializes a tuple back into a struct. Assumes the tuple has values in the same order
  as the schema fields.
  """
  def unserialize(tuple) when is_tuple(tuple) do
    fields = SectionResource.__schema__(:fields)

    # Convert tuple to list for easy manipulation, but drop the section_id
    # as it is duplicated within the other portion of the list, anyways.
    [_section_id | values] = Tuple.to_list(tuple)

    # Build the struct by matching the values to the schema fields
    fields
    |> Enum.zip(values)
    |> Enum.reduce(%SectionResource{}, fn {field, value}, acc ->

      value = decode_by_type(value, SectionResource.__schema__(:type, field))
      Map.put(acc, field, value)
    end)
  end

  defp encode_by_type(value, :utc_datetime) do
    DateTime.to_unix(value, :millisecond)
  end

  defp encode_by_type(value, _), do: value

  defp decode_by_type(value, :utc_datetime) do
    DateTime.from_unix(value, :millisecond)
  end

  defp decode_by_type(value, _), do: value

end
