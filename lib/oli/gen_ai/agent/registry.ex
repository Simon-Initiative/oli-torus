defmodule Oli.GenAI.Agent.Registry do
  @moduledoc """
  Registry for agent server processes.
  """

  def child_spec(_opts) do
    Registry.child_spec(
      keys: :unique,
      name: __MODULE__
    )
  end
end