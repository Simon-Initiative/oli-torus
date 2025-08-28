defmodule Oli.GenAI.Agent.Policy do
  @moduledoc "Policy callbacks to constrain tools, budgets, and termination."
  @callback allowed_action?(decision :: map(), state :: map()) :: true | {false, String.t()}
  @callback stop_reason?(state :: map()) :: nil | {:done, String.t()}
  @callback redact(log_payload :: map()) :: map()
end
