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
  Parses a rule and returns `{:ok, tree}` when successful, where `tree`
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

  defp eval({:contains, lhs, rhs}, context) do
    String.contains?(
      String.downcase(eval(lhs, context)),
      String.downcase(rhs)
    )
  end

  defp eval({:equals, lhs, rhs}, context) do
    String.equivalent?(
      eval(lhs, context),
      rhs
    )
  end

  defp eval({:iequals, lhs, rhs}, context) do
    String.equivalent?(
      String.downcase(eval(lhs, context)),
      String.downcase(rhs)
    )
  end

  defp eval(:attempt_number, context), do: context.activity_attempt_number |> Integer.to_string()
  defp eval(:input, context), do: context.input
  defp eval(:input_length, context), do: String.length(context.input) |> Integer.to_string()

  defp eval({:lt, lhs, rhs}, context) do
    left = eval(lhs, context)
    right = eval(rhs, context)
    l_value = parse_number(left)
    {r_value, r_precision} = parse_number_with_precision(right)

    l_value < r_value &&
      check_precision(left, r_precision)
  end

  defp eval({:gt, lhs, rhs}, context) do
    left = eval(lhs, context)
    right = eval(rhs, context)
    l_value = parse_number(left)
    {r_value, r_precision} = parse_number_with_precision(right)

    l_value > r_value &&
      check_precision(left, r_precision)
  end

  defp eval({:eq, lhs, rhs}, context) do
    left = eval(lhs, context)
    right = eval(rhs, context)

    # This code assumes that the left value is the input and right value
    # is the rule. We only care that the precision specified in the rule
    # matches the precision of the input and not the other way around.
    cond do
      is_range?(right) ->
        l_value = parse_number(left)

        case parse_range(right) do
          {:inclusive, lower, upper, precision} ->
            lower <= l_value && l_value <= upper &&
              check_precision(left, precision)

          {:exclusive, lower, upper, precision} ->
            lower < l_value && l_value < upper &&
              check_precision(left, precision)
        end

      is_float?(left) or is_float?(right) ->
        l_value = parse_number(left)
        {r_value, r_precision} = parse_number_with_precision(right)

        abs(l_value - r_value) < 0.00001 &&
          check_precision(left, r_precision)

      true ->
        l_value = parse_number(left)
        {r_value, r_precision} = parse_number_with_precision(right)

        l_value == r_value &&
          check_precision(left, r_precision)
    end
  end

  defp eval(value, _) when is_binary(value), do: value

  # if a precision is not specified (nil) then always evaluate to true
  defp check_precision(_value, nil), do: true

  # checks the precision
  defp check_precision(str, count) when is_binary(str) do
    digit_count =
      str
      |> String.split("")
      |> Enum.filter(&is_digit?/1)
      |> Enum.count()

    digit_count == count
  end

  defp is_range?(str), do: String.starts_with?(str, ["[", "("])

  defp is_float?(str),
    do: String.contains?(str, ".") or (String.contains?(str, "e") and String.contains?(str, "."))

  defp parse_range(range_str) do
    case Regex.run(
           ~r/([[(])\s*(-?[-01234567890e.]+)\s*,\s*(-?[-01234567890e.]+)\s*[\])]#?(\d+)?/,
           range_str
         ) do
      [_, "[", lower, upper | maybe_precision] ->
        {:inclusive, parse_number(lower), parse_number(upper), parse_precision(maybe_precision)}

      [_, "(", lower, upper | maybe_precision] ->
        {:exclusive, parse_number(lower), parse_number(upper), parse_precision(maybe_precision)}
    end
  end

  @digits %{
    "0" => true,
    "1" => true,
    "2" => true,
    "3" => true,
    "4" => true,
    "5" => true,
    "6" => true,
    "7" => true,
    "8" => true,
    "9" => true
  }
  defp is_digit?(c), do: Map.has_key?(@digits, c)

  defp parse_number_with_precision(str) when is_binary(str) do
    case String.split(str, "#") do
      [value] -> {parse_number(value), nil}
      [v, p] -> {parse_number(v), parse_precision(p)}
    end
  end

  defp parse_number(str) when is_binary(str) do
    if is_float?(str) do
      str
      |> Float.parse()
      |> drop_remainder()
    else
      str
      |> Integer.parse()
      |> drop_remainder()
    end
  end

  defp parse_precision([]), do: nil
  defp parse_precision([str]) when is_binary(str), do: parse_precision(str)

  defp parse_precision(str) when is_binary(str) do
    str
    |> Integer.parse()
    |> drop_remainder()
  end

  defp drop_remainder({val, _rem}), do: val
end
