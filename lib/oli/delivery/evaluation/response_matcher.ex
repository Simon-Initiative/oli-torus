defmodule Oli.Delivery.Evaluation.ResponseMatcher do
  @moduledoc """
  Evaluator-facing response matching boundary.

  This module deliberately answers only whether a response matches the submitted
  input. Scoring, feedback, triggers, and response selection stay in
  `Oli.Delivery.Evaluation.Evaluator`.
  """

  alias Oli.Activities.Model.{Part, Response}

  alias Oli.Delivery.Evaluation.{
    EvaluationContext,
    LegacyMathRuleAdapter,
    LegacyNumericRuleAdapter,
    MathExpressionMatcher,
    Rule
  }

  @spec match?(Response.t(), EvaluationContext.t(), Part.t()) ::
          {:ok, boolean()} | {:error, term()}
  def match?(
        %Response{match_config: match_config},
        %EvaluationContext{} = context,
        %Part{} = part
      )
      when not is_nil(match_config) do
    MathExpressionMatcher.match?(match_config, context, part)
  end

  def match?(%Response{rule: rule}, %EvaluationContext{} = context, %Part{input_type: "numeric"}) do
    case LegacyNumericRuleAdapter.match?(rule, context) do
      {:ok, result} -> {:ok, result}
      :unsupported -> Rule.parse_and_evaluate(rule, context)
    end
  end

  def match?(%Response{rule: rule}, %EvaluationContext{} = context, %Part{input_type: "math"}) do
    case LegacyMathRuleAdapter.match?(rule, context) do
      {:ok, result} -> {:ok, result}
      :unsupported -> Rule.parse_and_evaluate(rule, context)
    end
  end

  def match?(%Response{rule: rule}, %EvaluationContext{} = context, %Part{}) do
    Rule.parse_and_evaluate(rule, context)
  end
end
