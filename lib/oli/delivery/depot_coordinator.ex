defmodule Oli.Delivery.DepotCoordinator do
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

  def init(_) do
    PubSub.subscribe(Oli.PubSub, topic())
    {:ok, []}
  end

  def handle_info({:clear, depot_desc, table_id}, state) do
    Depot.clear(depot_desc, table_id)
    {:noreply, state}
  end

  def handle_info({:update_all, depot_desc, entries}, state) do
    Depot.update_all(depot_desc, entries)
    {:noreply, state}
  end

  defp topic,
    do: "DepotCoordinator"
end
