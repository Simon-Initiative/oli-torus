defmodule Oli.GenAI.RoutingPlan do
  @moduledoc """
  Represents a routing decision for a single GenAI request.
  """

  defstruct [
    :selected_model,
    :tier,
    :fallback_models,
    :reason,
    :admission,
    :request_type,
    :pool_name
  ]
end
