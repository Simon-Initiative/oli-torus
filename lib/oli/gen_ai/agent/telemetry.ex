defmodule Oli.GenAI.Agent.Telemetry do
  @moduledoc "Telemetry helpers for standardized events."

  @spec step(String.t(), map) :: :ok
  def step(_run_id, _meta), do: raise("TODO")

  @spec decision(String.t(), map) :: :ok
  def decision(_run_id, _meta), do: raise("TODO")

  @spec tool(String.t(), String.t(), map) :: :ok
  def tool(_run_id, _tool_name, _meta), do: raise("TODO")
end
