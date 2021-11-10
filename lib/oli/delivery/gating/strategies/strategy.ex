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
  Returns true if the condition evaluation determines that the resource is unlocked.
  This function call is inteded to be as efficient as possible for the ideal case when
  a resource is accessible. Use the `reason` callback to generate a more detailed
  message as to why a resource is locked.
  """
  @callback check(GatingCondition.t()) :: Boolean.t()

  @doc """
  Returns a human readable (and html renderable) message as to why a resource is locked.
  Takes the GatingCondition and any additional opts that may be utilized by certain
  strategies, such as formatting helpers or data providers.
  """
  @callback reason(GatingCondition.t(), Keyword.t() | nil) :: String.t()
end
