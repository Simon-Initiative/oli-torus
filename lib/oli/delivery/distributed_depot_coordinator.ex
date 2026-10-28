defmodule Oli.Delivery.DistributedDepotCoordinator do
  @moduledoc """
  This module is responsible for coordinating updates to the depot across the cluster.
  """

  use GenServer

  alias Phoenix.PubSub
  alias Oli.Delivery.Depot
  alias Oli.Delivery.Depot.DepotDesc

  def start_link(init_args),
    do: GenServer.start_link(__MODULE__, init_args, name: __MODULE__)

  def update_all(%DepotDesc{} = depot_desc, entries),
    do: PubSub.broadcast(Oli.PubSub, topic(), {:update_all, depot_desc, entries})

  def clear(%DepotDesc{} = depot_desc, table_id),
    do: PubSub.broadcast(Oli.PubSub, topic(), {:clear, depot_desc, table_id})

  @doc "Synchronously clears a depot snapshot on every reachable node with a bounded wait."
  def clear_synchronously(%DepotDesc{} = depot_desc, table_id),
    do: on_all_nodes(:clear_local, [depot_desc, table_id], 5_000)

  def init_if_necessary(%DepotDesc{} = depot_desc, table_id, caller_module) do
    # The cluster-wide lock coalesces first access without making the coordinator
    # GenServer execute database work for unrelated Sections serially.
    :global.trans({{__MODULE__, depot_desc.name, table_id}, self()}, fn ->
      if Depot.table_exists?(depot_desc, table_id) do
        {:ok, :exists}
      else
        case caller_module.process_table_creation(table_id) do
          result when result in [:ok, true] -> {:ok, :created}
          {:error, _reason} = error -> error
        end
      end
    end)
  end

  def update_all_local(depot_desc, entries) do
    [first | _rest] = entries
    table_id = Map.get(first, depot_desc.table_id_field)

    if Depot.table_exists?(depot_desc, table_id), do: Depot.update_all(depot_desc, entries)
    :ok
  end

  def clear_local(depot_desc, table_id) do
    if Depot.table_exists?(depot_desc, table_id), do: Depot.clear(depot_desc, table_id)
    :ok
  end

  def init(_) do
    PubSub.subscribe(Oli.PubSub, topic())
    {:ok, []}
  end

  def handle_info({:clear, depot_desc, table_id}, state) do
    clear_local(depot_desc, table_id)
    {:noreply, state}
  end

  def handle_info({:update_all, depot_desc, entries}, state) do
    update_all_local(depot_desc, entries)
    {:noreply, state}
  end

  defp on_all_nodes(function, args, timeout) do
    {_results, failed_nodes} =
      :rpc.multicall([node() | Node.list()], __MODULE__, function, args, timeout)

    case failed_nodes do
      [] -> :ok
      nodes -> {:error, {:unreachable_depot_nodes, nodes}}
    end
  end

  defp topic, do: "DepotCoordinator"
end
