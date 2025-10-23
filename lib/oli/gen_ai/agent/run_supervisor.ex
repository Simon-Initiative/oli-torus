defmodule Oli.GenAI.Agent.RunSupervisor do
  @moduledoc "Dynamic supervisor: spawns one Server per agent run."
  use DynamicSupervisor
  alias Oli.GenAI.Agent.Server

  def start_link(opts \\ []),
    do: DynamicSupervisor.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))

  @impl true
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  @spec start_run(map) :: {:ok, pid} | {:error, term}
  def start_run(%{} = args) do
    child = %{
      id: {Server, Map.get(args, :run_id) || Ecto.UUID.generate()},
      start: {Server, :start_link, [args]},
      restart: :temporary
    }

    DynamicSupervisor.start_child(__MODULE__, child)
  end

  def which_children, do: DynamicSupervisor.which_children(__MODULE__)
end
