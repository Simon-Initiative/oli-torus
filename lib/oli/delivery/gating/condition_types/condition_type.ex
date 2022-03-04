defmodule Oli.Delivery.Gating.ConditionTypes.ConditionType do
  @moduledoc """
  Behavior a gating condition type must implement
  """
  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Gating.ConditionTypes.ConditionContext

  @doc """
  Returns the condition type identifier
  """
  @callback type() :: Atom.t()

  @doc """
  Returns a two element tuple. The first element is a boolean indicating whether this resource
  can be accessed strictly based on this gating condition.  The second element is the gating condition
  evaluation context, which may or may not have been mutated during this evaluation.
  """
  @callback evaluate(GatingCondition.t(), ConditionContext.t()) ::
              {Boolean.t(), ConditionContext.t()}

  @doc """
  Returns a human readable message as to why a resource access has been blocked.
  Takes the GatingCondition and any additional opts that may be utilized by certain
  strategies, such as formatting helpers or data providers.
  """
  @callback details(GatingCondition.t(), Keyword.t() | nil) :: String.t()
end
