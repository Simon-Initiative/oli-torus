defmodule Oli.Delivery.Attempts.ActivityLifecycle.NodeEvaluator do
  alias Oli.Delivery.Attempts.ActivityLifecycle.RuleEvaluator

  require Logger

  @behaviour RuleEvaluator

  @impl RuleEvaluator
  def evaluate(state, rules, scoring_context) do
    Logger.debug("Sending State to Node #{Jason.encode!(state)}")

    case NodeJS.call({"rules", :check}, [state, rules, scoring_context, true]) do
      {:ok, check_results} ->
        case Base.decode64(check_results) do
          {:ok, decoded} -> {:ok, Poison.decode!(decoded)}
          _ -> {:error, "Error when base64 decoding rule eval results"}
        end

      e ->
        e
    end
  end
end
