defmodule Oli.Delivery.DepotCoordinator do
  alias Oli.Delivery.Depot.DepotDesc

  def get() do
    Application.get_env(:oli, :depot_coordinator)
  end

  def update_all(%DepotDesc{} = depot_desc, entries), do: get().update_all(depot_desc, entries)
  def clear(%DepotDesc{} = depot_desc, table_id), do: get().clear(depot_desc, table_id)

  def clear_synchronously(%DepotDesc{} = depot_desc, table_id) do
    coordinator = get()

    case function_exported?(coordinator, :clear_synchronously, 2) do
      true -> coordinator.clear_synchronously(depot_desc, table_id)
      false -> coordinator.clear(depot_desc, table_id)
    end
  end

  def init_if_necessary(%DepotDesc{} = depot_desc, table_id, caller_module),
    do: get().init_if_necessary(depot_desc, table_id, caller_module)
end
