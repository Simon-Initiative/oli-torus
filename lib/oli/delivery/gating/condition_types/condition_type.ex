defmodule Oli.Delivery.Gating.ConditionTypes.ConditionType do
  @moduledoc """
  Behavior a gating condition type must implement
  """
  alias Oli.Delivery.Gating.GatingCondition

  @doc """
  Returns the condition type identifier
  """
  @callback type() :: Atom.t()

  @doc """
  Returns true if the condition evaluation determines that the resource can be accessed.
  This function call is inteded to be as efficient as possible for the common case when
  a resource is accessible. Use the `details` callback to get more details as to
  why a resource is inaccessible.
  """
  @callback open?(GatingCondition.t()) :: Boolean.t()

  @doc """
  Returns a human readable message as to why a resource access has been blocked.
  Takes the GatingCondition and any additional opts that may be utilized by certain
  strategies, such as formatting helpers or data providers.
  """
  @callback details(GatingCondition.t(), Keyword.t() | nil) :: String.t()
end
