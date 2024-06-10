defmodule Oli.NavigationDataForStudentsTab do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    :ets.new(:navigation_data, [:named_table, :public, :set])
    {:ok, %{}}
  end

  def set_data(key, data) do
    :ets.insert(:navigation_data, {key, data})
  end

  def get_data(key) do
    case :ets.lookup(:navigation_data, key) do
      [{^key, data}] -> {:ok, data}
      _ -> :error
    end
  end
end
