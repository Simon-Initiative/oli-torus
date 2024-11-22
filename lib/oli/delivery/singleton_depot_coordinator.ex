defmodule Oli.Delivery.SingletonDepotCoordinator do
  @moduledoc """
  This module is responsible for coordinating updates to the depot across the cluster.
  """

  alias Oli.Delivery.Depot
  alias Oli.Delivery.Depot.DepotDesc

  def update_all(%DepotDesc{} = depot_desc, entries) do
    [first | _rest] = entries
    table_id = Map.get(first, depot_desc.table_id_field)

    if Depot.table_exists?(depot_desc, table_id) do
      Depot.update_all(depot_desc, entries)
    end
  end

  def clear(%DepotDesc{} = depot_desc, table_id) do
    if Depot.table_exists?(depot_desc, table_id) do
      Depot.clear(depot_desc, table_id)
    end
  end

  def init_if_necessary(%DepotDesc{} = depot_desc, table_id, caller_module) do
    if Depot.table_exists?(depot_desc, table_id) do
      {:ok, :exists}
    else
      caller_module.process_table_creation(table_id)
      {:ok, :created}
    end
  end
end
