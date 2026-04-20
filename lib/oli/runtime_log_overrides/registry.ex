defmodule Oli.RuntimeLogOverrides.Registry do
  @moduledoc false

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  def list_overrides do
    GenServer.call(__MODULE__, :list_overrides)
  end

  def put_module_override(module, level) do
    GenServer.call(__MODULE__, {:put_module_override, module, level})
  end

  def delete_module_override(module) do
    GenServer.call(__MODULE__, {:delete_module_override, module})
  end

  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(:ok) do
    {:ok, %{modules: %{}}}
  end

  @impl true
  def handle_call(:list_overrides, _from, state) do
    overrides = %{
      modules:
        state.modules
        |> Map.values()
        |> Enum.sort_by(& &1.target_label),
      processes: []
    }

    {:reply, overrides, state}
  end

  def handle_call({:put_module_override, module, level}, _from, state) do
    module_override = %{
      type: :module,
      target: module,
      target_label: Atom.to_string(module),
      level: level,
      updated_at: DateTime.utc_now()
    }

    next_state = put_in(state, [:modules, module], module_override)

    {:reply, {:ok, module_override}, next_state}
  end

  def handle_call({:delete_module_override, module}, _from, state) do
    {_deleted, modules} = Map.pop(state.modules, module)
    next_state = %{state | modules: modules}

    {:reply, :ok, next_state}
  end

  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{modules: %{}}}
  end
end
