defmodule Oli.Delivery.Evaluation.LegacyMathRuleAdapter do
  @moduledoc """
  Compatibility adapter for old Math input rules.

  Legacy Math used the text-rule grammar over a LaTeX string. Only simple
  equality rules can be represented as direct LaTeX `matchConfig`; everything
  else falls back to the existing rule evaluator.
  """

  alias Oli.Delivery.Evaluation.{EvaluationContext, LegacyInput, MathExpressionMatcher, Rule}

  @spec match?(String.t(), EvaluationContext.t()) :: {:ok, boolean()} | :unsupported
  def match?(rule, %EvaluationContext{} = context) when is_binary(rule) do
    with {:ok, tree} <- Rule.parse(rule),
         {:ok, lhs, expected} <- equality_tree(tree) do
      expected
      |> latex_direct_config()
      |> MathExpressionMatcher.evaluate(LegacyInput.submitted_value(lhs, context))
      |> case do
        {:ok, matched?} -> {:ok, matched?}
        {:error, _} -> :unsupported
      end
    else
      _ -> :unsupported
    end
  end

  defp equality_tree({:equals, lhs, expected}) when lhs in [:input] do
    {:ok, lhs, expected}
  end

  defp equality_tree({:equals, {:input, _ref} = lhs, expected}) do
    {:ok, lhs, expected}
  end

  defp equality_tree(_), do: :unsupported

  defp latex_direct_config(expected) do
    %{
      "version" => 1,
      "type" => "math_expression",
      "math" => %{
        "mode" => "latex_direct",
        "expected" => expected
      }
    }
  end
end
