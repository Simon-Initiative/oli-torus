defmodule Oli.GenAI.RoutingPlan do
  @moduledoc """
  Represents a routing decision for a single GenAI request.
  """

  defstruct [
    :selected_model,
    :fallback_models,
    :reason,
    :admission,
    :timeouts,
    :counts,
    :request_type
  ]
end
