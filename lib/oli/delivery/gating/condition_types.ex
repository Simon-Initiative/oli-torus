defmodule Oli.Delivery.Gating.ConditionTypes do
  @moduledoc """
  Gating Condition Types
  """

  def types() do
    [
      {"Schedule", Oli.Delivery.Gating.ConditionTypes.Schedule},
      {"AlwaysOpen", Oli.Delivery.Gating.ConditionTypes.AlwaysOpen}
    ]
  end
end
