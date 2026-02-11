defmodule Oli.GenAI.BreakerSupervisor do
  @moduledoc """
  Dynamic supervisor for per-RegisteredModel breaker processes.
  """

  use DynamicSupervisor

  @doc "Starts the breaker supervisor."
  def start_link(opts \\ []) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  @doc "DynamicSupervisor init callback."
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc "Starts a breaker process for the given RegisteredModel id."
  def start_breaker(registered_model_id) do
    spec = {Oli.GenAI.Breaker, registered_model_id}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
