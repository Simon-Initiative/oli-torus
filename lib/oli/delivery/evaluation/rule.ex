defmodule Oli.Delivery.Evaluation.Rule do
  alias Oli.Delivery.Evaluation.EvaluationContext

  @doc """
  Parses and evaluates a rule and returns `{:ok, result}` when succesful, where `result`
  is is a boolean true or false indicating if the rule matched or not.

  Returns `{:error, reason}` when it fails to parse or evaluate
  """
  def parse_and_evaluate(rule_as_string, %EvaluationContext{} = context) do
    with {:ok, tree} <- parse(rule_as_string),
         {:ok, result} <- evaluate(tree, context) do
      {:ok, result}
    end
  end

  @doc """
  Parses a rule and returns `{:ok, tree}` when succesful, where `tree`
  is a series of nested tuples representing the parsed clauses in prefix notation, where
  the first tuple entry is the operation, the second is the left hand side
  operand and the third is the right hand side operand. An example:

  {:&&, {:gt, :attempt_number, "1"}, {:like, :input, "some string here"}}

  Returns `{:error, reason}` when it fails to parse
  """
  @spec parse(binary) :: {:error, <<_::64, _::_*8>>} | {:ok, any}
  def parse(rule_as_string), do: Oli.Delivery.Evaluation.Parser.rule(rule_as_string) |> unwrap()

  defp unwrap({:ok, [acc], "", _, _, _}), do: {:ok, acc}
  defp unwrap({:ok, _, rest, _, _, _}), do: {:error, "could not parse" <> rest}
  defp unwrap({:error, reason, _rest, _, _, _}), do: {:error, reason}

  def evaluate(tree, %EvaluationContext{} = context) do
    try do
      {:ok, eval(tree, context)}
    rescue
      e -> {:error, e}
    end
  end

  defp eval({:&&, lhs, rhs}, context), do: eval(lhs, context) and eval(rhs, context)
  defp eval({:||, lhs, rhs}, context), do: eval(lhs, context) or eval(rhs, context)
  defp eval({:!, rhs}, context), do: !eval(rhs, context)

  defp eval({:like, lhs, rhs}, context) do
    {:ok, regex} = Regex.compile(rhs)
    String.match?(eval(lhs, context), regex)
  end

  defp eval(:attempt_number, context), do: context.activity_attempt_number |> Integer.to_string()
  defp eval(:input, context), do: context.input
  defp eval(:input_length, context), do: String.length(context.input) |> Integer.to_string()

  defp eval({:lt, lhs, rhs}, context) do
    {left, _} = eval(lhs, context) |> Float.parse()
    {right, _} = eval(rhs, context) |> Float.parse()

    left < right
  end

  defp eval({:gt, lhs, rhs}, context) do
    {left, _} = eval(lhs, context) |> Float.parse()
    {right, _} = eval(rhs, context) |> Float.parse()

    left > right
  end

  defp eval({:eq, lhs, rhs}, context) do
    left = eval(lhs, context)
    right = eval(rhs, context)

    if is_float?(left) or is_float?(right) do
      {left, _} = Float.parse(left)
      {right, _} = Float.parse(right)

      abs(abs(left) - abs(right)) < 0.00001
    else
      eval(lhs, context) |> String.to_integer() ==
        eval(rhs, context) |> String.to_integer()
    end
  end

  defp eval(value, _) when is_binary(value), do: value

  defp is_float?(str), do: String.contains?(str, ".")
end
