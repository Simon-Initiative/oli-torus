defmodule Oli.Delivery.Attempts.ActivityLifecycle.RuleEvaluator do
  @doc """
  Evaluates a state, given a collection of rules and a scoring context.
  """
  @callback evaluate(map(), [map()], map()) :: {:ok, map()} | {:error, term()}

  @doc """
  Does the dynamic dispatch based on configured provider.
  """
  def do_eval(state, rules, scoring_context) do
    module = Application.fetch_env!(:oli, :rule_evaluator)[:dispatcher]
    apply(module, :evaluate, [state, rules, scoring_context])
  end
end
