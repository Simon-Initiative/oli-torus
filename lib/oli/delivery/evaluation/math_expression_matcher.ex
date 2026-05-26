defmodule Oli.Delivery.Evaluation.MathExpressionMatcher do
  @moduledoc """
  Normalizes Gleam `matchConfig` evaluation into the standard evaluator's
  boolean match boundary.
  """

  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Evaluation.EvaluationContext
  alias Oli.Math.Match

  @spec match?(map(), EvaluationContext.t(), Part.t()) :: {:ok, boolean()} | {:error, term()}
  def match?(match_config, %EvaluationContext{input: submitted}, %Part{}) do
    evaluate(match_config, submitted)
  end

  @spec evaluate(map() | String.t(), String.t()) :: {:ok, boolean()} | {:error, term()}
  def evaluate(match_config, submitted) when is_binary(submitted) do
    case Match.evaluate_json(match_config, submitted) do
      {:ok, result} -> normalize_result(result)
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_result({:match_matched, _diagnostics}), do: {:ok, true}
  defp normalize_result({:match_not_matched, _diagnostics}), do: {:ok, false}
  defp normalize_result({:match_invalid_submission, _diagnostics}), do: {:ok, false}
  defp normalize_result({:match_invalid_config, error}), do: {:error, error}
end
