defmodule Oli.Delivery.Gating.GatingConditionEvaluator do
  @moduledoc """
  Behavior for Gating Condition Evaluators to implement
  """
  alias Oli.Delivery.Gating.GatingCondition

  @callback unlocked?(GatingCondition.t()) :: Boolean.t()
end
