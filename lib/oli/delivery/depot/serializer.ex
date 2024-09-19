defmodule Oli.Delivery.Depot.Serializer do
  alias Oli.Delivery.Sections.SectionResource

  @doc """
  Serializes a struct into a tuple. It handles both fields and embedded schemas.
  """
  def serialize(%SectionResource{} = sr) do
    fields = SectionResource.__schema__(:fields)
    # Create a tuple of field values in the order they are defined in the schema
    fields
    |> Enum.map(&Map.get(sr, &1))
    |> List.to_tuple()
  end

  @doc """
  Unserializes a tuple back into a struct. Assumes the tuple has values in the same order
  as the schema fields.
  """
  def unserialize(tuple) when is_tuple(tuple) do
    fields = SectionResource.__schema__(:fields)

    # Convert tuple to list for easy manipulation
    values = Tuple.to_list(tuple)

    # Build the struct by matching the values to the schema fields
    fields
    |> Enum.zip(values)
    |> Enum.reduce(%SectionResource{}, fn {field, value}, acc ->
      Map.put(acc, field, value)
    end)
  end

  def index_map() do
    SectionResource.__schema__(:fields)
    |> Enum.with_index(1)
    |> Map.new()
  end
end
