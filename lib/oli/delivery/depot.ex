defmodule Oli.Delivery.Depot do

  alias Oli.Delivery.Depot.DepotDesc
  alias Oli.Delivery.Depot.Serializer
  alias Oli.Delivery.Depot.Retrieval

  alias Oli.Delivery.Sections.SectionResource

  @depots %{
    SectionResource: %DepotDesc{
      name: "SectionResource",
      schema: SectionResource,
      table: :section_resources,
      key_field: :section_id
    }
  }

  def update(schema, entry) do

    depot_desc = get_registered_depot_spec(schema)

    item = Serializer.serialize(entry, depot_desc)
    :ets.insert(depot_desc.table, item)

  end

  def update_all(schema, entries) do

    depot_desc = get_registered_depot_spec(schema)

    items = Enum.map(entries, fn entry -> Serializer.serialize(entry, depot_desc) end)
    :ets.insert(depot_desc.table, items)

  end

  def clear_and_set(schema, entries) do

    depot_desc = get_registered_depot_spec(schema)

    [first | _rest] = entries

    :ets.delete(depot_desc.table, first[depot_desc.key_field])

    Enum.map(entries, fn entry -> Serializer.serialize(entry, depot_desc) end)
    |> :ets.insert(depot_desc.table)

  end

  def all(schema, key_value) do

    depot_desc = get_registered_depot_spec(schema)

    Retrieval.all(depot_desc, key_value)
    |> Serializer.unserialize(depot_desc)

  end

  def query(schema, key_value, conditions, fields) do

    depot_desc = get_registered_depot_spec(schema)

    Retrieval.query(depot_desc, key_value, conditions, fields)
    |> Serializer.unserialize(depot_desc)

  end

  defp get_registered_depot_spec(schema) do
    case Map.get(@depots, schema) do
      nil -> raise "Schema not registered"
      depot_desc -> depot_desc
    end
  end

end
