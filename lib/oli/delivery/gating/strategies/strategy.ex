defmodule Oli.Delivery.Gating.Strategies.Strategy do
  @moduledoc """
  Behavior a gating strategy must implement
  """
  alias Oli.Delivery.Gating.GatingCondition

  @doc """
  Returns the condition type identifier
  """
  @callback type() :: Atom.t()

  @doc """
  Returns true if the condition evaluates that the resource is available
  """
  @callback check(GatingCondition.t()) :: Boolean.t()
end
