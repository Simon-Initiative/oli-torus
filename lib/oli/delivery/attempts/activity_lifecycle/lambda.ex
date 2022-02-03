defmodule Oli.Delivery.Attempts.ActivityLifecycle.AWSLambdaEvaluator do
  alias Oli.Delivery.Attempts.ActivityLifecycle.RuleEvaluator

  require Logger

  @behaviour RuleEvaluator

  @impl RuleEvaluator
  def evaluate(state, rules, scoring_context) do
    payload = %{
      state: state,
      rules: rules,
      scoringContext: scoring_context
    }

    fn_name = Application.fetch_env!(:oli, :rule_evaluator)[:aws_fn_name]
    region = Application.fetch_env!(:oli, :rule_evaluator)[:aws_region]

    Logger.debug("Sending State to AWS Lambda function #{fn_name} #{Jason.encode!(state)}")

    ExAws.Lambda.invoke(fn_name, payload, "no_context")
    |> ExAws.request(region: region)
  end
end
