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

  def init_if_necessary(%DepotDesc{} = depot_desc, table_id, caller_module),
    do: GenServer.call(__MODULE__, {:init_if_necessary, depot_desc, table_id, caller_module})

  def init(_) do
    PubSub.subscribe(Oli.PubSub, topic())
    {:ok, []}
  end

  def handle_info({:clear, depot_desc, table_id}, state) do
    if Depot.table_exists?(depot_desc, table_id) do
      Depot.clear(depot_desc, table_id)
    end

    {:noreply, state}
  end

  def handle_info({:update_all, depot_desc, entries}, state) do
    [first | _rest] = entries
    table_id = Map.get(first, depot_desc.table_id_field)

    if Depot.table_exists?(depot_desc, table_id) do
      Depot.update_all(depot_desc, entries)
    end

    {:noreply, state}
  end

  def handle_call({:init_if_necessary, depot_desc, table_id, caller_module}, _from, state) do
    result =
      if Depot.table_exists?(depot_desc, table_id) do
        {:ok, :exists}
      else
        caller_module.process_table_creation(table_id)
        {:ok, :created}
      end

    {:reply, result, state}
  end

  defp topic,
    do: "DepotCoordinator"
end
