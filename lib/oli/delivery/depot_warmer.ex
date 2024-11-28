defmodule Oli.Delivery.DepotWarmer do
  use GenServer

  alias Oli.Delivery.DistributedDepotCoordinator
  alias Oli.Delivery.Sections.SectionResourceDepot

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  def init(_) do
    {:ok, [], {:continue, :init_depot_warmer}}
  end

  def handle_continue(:init_depot_warmer, state) do
    depot_desc = SectionResourceDepot.depot_desc()
    sections_ids = SectionResourceDepot.fetch_recently_active_sections()

    Enum.map(sections_ids, fn section_id ->
      DistributedDepotCoordinator.init_if_necessary(depot_desc, section_id, SectionResourceDepot)
    end)

    {:noreply, state}
  end
end
