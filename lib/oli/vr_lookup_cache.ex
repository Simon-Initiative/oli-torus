defmodule Oli.VrLookupCache do
  use Agent
  alias Oli.VrUserAgents

  def start_link(_init_args) do
    Agent.start_link(fn -> VrUserAgents.all() end, name: __MODULE__)
  end

  def exists(value) do
    Agent.get(__MODULE__, fn state -> exists_user_agent_in_cache(state, value) end)
  end

  def reload() do
    Agent.update(__MODULE__, fn _state -> VrUserAgents.all() end)
  end

  defp exists_user_agent_in_cache(state, value) do
    Enum.reduce_while(state, false, fn %{user_agent: user_agent}, acc ->
      if user_agent == value, do: {:halt, true}, else: {:cont, acc}
    end)
  end
end
