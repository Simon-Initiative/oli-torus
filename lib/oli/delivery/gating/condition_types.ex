defmodule Oli.Delivery.Gating.ConditionTypes do
  @moduledoc """
  Gating Condition Types
  """

  def types() do
    [
      {"Schedule", Oli.Delivery.Gating.ConditionTypes.Schedule},
      {"AlwaysOpen", Oli.Delivery.Gating.ConditionTypes.AlwaysOpen},
      {"Started", Oli.Delivery.Gating.ConditionTypes.Started},
      {"Finished", Oli.Delivery.Gating.ConditionTypes.Finished},
      {"Progress", Oli.Delivery.Gating.ConditionTypes.Progress}
    ]
  end
end
