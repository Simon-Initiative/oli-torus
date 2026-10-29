defmodule Oli.GenAI.RoutingPlan do
  @moduledoc "A non-reserving transport selection for one request attempt."
  defstruct [
    :selected_model,
    :provider,
    :service_config_id,
    :tier,
    :reason,
    :request_type,
    :pool,
    :pool_name,
    :signature
  ]
end
