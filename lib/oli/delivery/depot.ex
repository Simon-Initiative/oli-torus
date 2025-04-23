defmodule Oli.Delivery.Depot do
  @moduledoc """
  This module provides a generic interface to an ETS table based data store
  of Ecto schemas. This interface is not intended to be used directly, but
  rather to be used as a base for more specific data store implementations
  (for example, the SectionResourceDepot module).
  """

  alias Oli.Delivery.Depot.DepotDesc
  alias Oli.Delivery.Depot.Serializer
  alias Oli.Delivery.Depot.MatchSpecTranslator

  @doc """
  Returns true if the table exists in the depot.
  """
  def table_exists?(%DepotDesc{} = depot_desc, table_id) do
    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.info() != :undefined
  end

  @doc """
  Creates a new table in the depot.
  """
  def create_table(%DepotDesc{} = depot_desc, table_id) do
    :ets.new(DepotDesc.table_name(depot_desc, table_id), [:set, :named_table, :public])
  end

  @doc """
  Updates an entry in a depot table.
  """
  def update(%DepotDesc{} = depot_desc, entry) do
    table_id = Map.get(entry, depot_desc.table_id_field)

    item = Serializer.serialize(entry, depot_desc)
    :ets.insert(DepotDesc.table_name(depot_desc, table_id), item)
  end

  @doc """
  Updates a colleciton of entries in a depot table.
  """
  def update_all(%DepotDesc{} = depot_desc, entries) do
    [first | _rest] = entries
    table_id = Map.get(first, depot_desc.table_id_field)

    items = Enum.map(entries, fn entry -> Serializer.serialize(entry, depot_desc) end)
    :ets.insert(DepotDesc.table_name(depot_desc, table_id), items)
  end

  @doc """
  Clears the table and sets the entries as the new contents.
  """
  def clear_and_set(%DepotDesc{} = depot_desc, table_id, entries) do
    items = Enum.map(entries, fn entry -> Serializer.serialize(entry, depot_desc) end)

    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.delete_all_objects()

    :ets.insert(DepotDesc.table_name(depot_desc, table_id), items)
  end

  @doc """
  Clears the table by deleting it.
  """
  def clear(%DepotDesc{} = depot_desc, table_id) do
    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.delete()
  end

  @doc """
  Returns all entries in the table.
  """
  def all(%DepotDesc{} = depot_desc, table_id) do
    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.tab2list()
    |> Serializer.unserialize(depot_desc)
  end

  @doc """
  Returns the entry with the given key, nil if no entry is found.
  """
  def get(%DepotDesc{} = depot_desc, table_id, key) do
    item =
      DepotDesc.table_name(depot_desc, table_id)
      |> :ets.lookup(key)
      |> Serializer.unserialize(depot_desc)

    case item do
      [] -> nil
      [item] -> item
    end
  end

  @doc """
  Returns a collection of entries that match the given conditions. Optionally,
  a subset of fields can be returned.

  Full details on the supported conditions can be found in the MatchSpecTranslator
  module, but the basic idea is that you can pass a list of conditions to match on.

  The list can be a simple keyword list of field values to match on as an AND:

  [resource_type_id: 3, graded: false]

  or a list of tuples with the field name, operator, and value (all of which are
  ANDed together):

  [{:duration, {:between, 5, 10}}, {:graded, {:=, true}}]
  """
  def query(%DepotDesc{} = depot_desc, table_id, conditions, fields \\ []) do
    match_spec = MatchSpecTranslator.translate(depot_desc, conditions, fields)

    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.select([match_spec])
    |> Serializer.unserialize(depot_desc)
  end

  @doc """
  count/2 :: Returns the number of objects inserted in the table.

  count/3 :: Returns the count of entries that match the given conditions.

  Full details on the supported conditions can be found in the MatchSpecTranslator
  module, but the basic idea is that you can pass a list of conditions to match on.

  The list can be a simple keyword list of field values to match on as an AND:

  [resource_type_id: 3, graded: false]

  or a list of tuples with the field name, operator, and value (all of which are
  ANDed together):

  [{:duration, {:between, 5, 10}}, {:graded, {:=, true}}]
  """

  def count(%DepotDesc{} = depot_desc, table_id) do
    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.info(:size)
  end

  def count(%DepotDesc{} = depot_desc, table_id, conditions) do
    {match_head, guards, _return_fields} =
      MatchSpecTranslator.translate(depot_desc, conditions)

    match_spec = {match_head, guards, [true]}

    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.select_count([match_spec])
  end

  @doc """
  Returns true if any entries match the given conditions.

  AND semantics:
    Pass a single keyword list of filters, all of which must hold.
    Example: `exists?(desc, table_id, [start_date: {:!=, nil}, hidden: false])`
    Equivalent to the expression:
      start_date != nil and hidden == false

  OR semantics:
    Pass a list of keyword lists. Each inner list is AND'ed, and groups are OR'ed.
    Example:
      exists?(desc, table_id, [
        [start_date: {:!=, nil}, hidden: false],
        [end_date:   {:!=, nil}]
      ])

    Equivalent to the expression:
      (start_date != nil and hidden == false) or (end_date != nil)
  """
  def exists?(%DepotDesc{} = depot_desc, table_id, filters) when is_list(filters) do
    groups =
      if Keyword.keyword?(filters) do
        # AND-case
        [filters]
      else
        if Enum.all?(filters, &Keyword.keyword?(&1)) do
          # OR-case
          filters
        else
          raise ArgumentError,
                "exists?/3 expects a keyword list or a list of keyword lists, got: #{inspect(filters)}"
        end
      end

    # Translate each group into an ETS match spec
    specs =
      Enum.map(groups, fn conds ->
        conditions = Enum.map(conds, fn {field, value} -> {field, value} end)
        {mh, gs, _} = MatchSpecTranslator.translate(depot_desc, conditions)
        {mh, gs, [true]}
      end)

    DepotDesc.table_name(depot_desc, table_id)
    |> :ets.select(specs, 1)
    |> case do
      :"$end_of_table" -> false
      _ -> true
    end
  end
end
