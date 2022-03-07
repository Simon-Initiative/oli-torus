defmodule Oli.Delivery.Gating.ConditionTypes.AlwaysOpen do
  @moduledoc """
  Always strategy provides a gating condition that always evaluates to be open.

  This is the underlying mechanism that allows student-specific overrides to existing
  student-wide gates, in a way that provides no new (or different) gating condition.
  """

  @behaviour Oli.Delivery.Gating.ConditionTypes.ConditionType

  def type do
    :always_open
  end

  def evaluate(_, context), do: {true, context}

  def details(
        _,
        _ \\ []
      ),
      do: nil
end
