defmodule Oli.Delivery.DepotCoordinator do
  alias Oli.Delivery.Depot.DepotDesc

  def get() do
    Application.get_env(:oli, :depot_coordinator)
  end

  def update_all(%DepotDesc{} = depot_desc, entries), do: get().update_all(depot_desc, entries)
  def clear(%DepotDesc{} = depot_desc, table_id), do: get().clear(depot_desc, table_id)
end
