defmodule Oli.Delivery.Depot do

  alias Oli.Delivery.Depot.DepotDesc
  alias Oli.Delivery.Depot.Serializer
  alias Oli.Delivery.Depot.MatchSpecTranslator

  def table_exists?(%DepotDesc{} = depot_desc, table_id) do
    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.info() != :undefined
  end

  def create_table(%DepotDesc{} = depot_desc, table_id) do
    :ets.new(DepotDesc.table_name(depot_desc, table_id), [:set, :named_table, :public])
  end

  def update(%DepotDesc{} = depot_desc, entry) do

    table_id = Map.get(entry, depot_desc.table_id_field)

    item = Serializer.serialize(entry, depot_desc)
    :ets.insert(DepotDesc.table_name(depot_desc, table_id), item)

  end

  def update_all(%DepotDesc{} = depot_desc, entries) do

    [first | _rest] = entries
    table_id = Map.get(first, depot_desc.table_id_field)

    items = Enum.map(entries, fn entry -> Serializer.serialize(entry, depot_desc) end)
    :ets.insert(DepotDesc.table_name(depot_desc, table_id), items)

  end

  def clear_and_set(%DepotDesc{} = depot_desc, table_id, entries) do

    items = Enum.map(entries, fn entry -> Serializer.serialize(entry, depot_desc) end)

    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.delete_all_objects()

    :ets.insert(DepotDesc.table_name(depot_desc, table_id), items)

  end

  def clear(%DepotDesc{} = depot_desc, table_id) do

    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.delete()
  end

  def all(%DepotDesc{} = depot_desc, table_id) do

    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.tab2list()
    |> Serializer.unserialize(depot_desc)

  end

  def get(%DepotDesc{} = depot_desc, table_id, key) do

    item = DepotDesc.table_name(depot_desc, table_id)
    |> :ets.lookup(key)
    |> Serializer.unserialize(depot_desc)

    case item do
      [] -> nil
      [item] -> item
    end

  end

  def query(%DepotDesc{} = depot_desc, table_id, conditions, fields \\ []) do

    match_spec = MatchSpecTranslator.translate(depot_desc, conditions, fields)

    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.select([match_spec])
    |> Serializer.unserialize(depot_desc)

  end

end
