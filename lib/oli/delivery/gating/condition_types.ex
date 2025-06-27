defmodule Oli.Delivery.Gating.ConditionTypes do
  @moduledoc """
  Gating Condition Types
  """

  def types() do
    [
      {"Between scheduled dates", Oli.Delivery.Gating.ConditionTypes.Schedule},
      {"Always available", Oli.Delivery.Gating.ConditionTypes.AlwaysOpen},
      {"When another resource is started", Oli.Delivery.Gating.ConditionTypes.Started},
      {"When another resource is finished", Oli.Delivery.Gating.ConditionTypes.Finished},
      {"When another resource reaches a progress milestone",
       Oli.Delivery.Gating.ConditionTypes.Progress}
    ]
  end
end
