defmodule Oli.Delivery.Depot do

  alias Oli.Delivery.Depot.DepotDesc
  alias Oli.Delivery.Depot.Serializer
  alias Oli.Delivery.Depot.MatchSpecTranslator

  alias Oli.Delivery.Sections.SectionResource

  @depots %{
    SectionResource: %DepotDesc{
      name: "SectionResource",
      schema: SectionResource,
      table_name_prefix: :section_resources,
      key_field: :resource_id,
      table_id_field: :section_id
    }
  }

  def table_exists?(schema, table_id) do
    depot_desc = get_registered_depot_spec(schema)

    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.info() != :undefined
  end

  def create_table(schema, table_id) do
    depot_desc = get_registered_depot_spec(schema)
    :ets.new(DepotDesc.table_name(depot_desc, table_id), [:set, :named_table])
  end

  def update(schema, entry) do

    depot_desc = get_registered_depot_spec(schema)
    table_id = entry[depot_desc.table_id_field]

    item = Serializer.serialize(entry, depot_desc)
    :ets.insert(DepotDesc.table_name(depot_desc, table_id), item)

  end

  def update_all(schema, entries) do

    depot_desc = get_registered_depot_spec(schema)

    [first | _rest] = entries
    table_id = first[depot_desc.table_id_field]

    items = Enum.map(entries, fn entry -> Serializer.serialize(entry, depot_desc) end)
    :ets.insert(DepotDesc.table_name(depot_desc, table_id), items)

  end

  def clear_and_set(schema, entries) do

    depot_desc = get_registered_depot_spec(schema)

    [first | _rest] = entries
    table_id = first[depot_desc.table_id_field]

    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.delete(first[depot_desc.key_field])

    Enum.map(entries, fn entry -> Serializer.serialize(entry, depot_desc) end)
    |> :ets.insert(DepotDesc.table_name(depot_desc, table_id))

  end

  def all(schema, table_id) do

    depot_desc = get_registered_depot_spec(schema)

    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.tab2list()
    |> Serializer.unserialize(depot_desc)

  end

  def get(schema, table_id, key) do

    depot_desc = get_registered_depot_spec(schema)

    item = DepotDesc.table_name(depot_desc, table_id)
    |> :ets.lookup(key)
    |> Serializer.unserialize(depot_desc)

    case item do
      [] -> nil
      [item] -> item
    end

  end

  def query(schema, table_id, conditions, fields \\ []) do

    depot_desc = get_registered_depot_spec(schema)
    match_spec = MatchSpecTranslator.translate(depot_desc, conditions, fields)

    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.select([match_spec])
    |> Serializer.unserialize(depot_desc)

  end

  defp get_registered_depot_spec(schema) do
    case Map.get(@depots, schema) do
      nil -> raise "Schema not registered"
      depot_desc -> depot_desc
    end
  end


end
