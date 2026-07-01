defmodule Oli.Delivery.Evaluation.LegacyNumericRuleAdapter do
  @moduledoc """
  Compatibility adapter for old Number input rules.

  The adapter reads the existing parsed rule tree and translates only rule
  shapes that are semantically equivalent to one `matchConfig`. Compound rules
  and negated precision rules fall back to the existing rule evaluator.
  """

  alias Oli.Delivery.Evaluation.{EvaluationContext, LegacyInput, MathExpressionMatcher, Rule}

  @number_pattern ~r/^[+-]?(?:(?:\d+(?:\.\d*)?)|(?:\.\d+))(?:[eE][+-]?\d+)?$/
  @range_pattern ~r/^([[(])\s*([+-]?(?:(?:\d+(?:\.\d*)?)|(?:\.\d+))(?:[eE][+-]?\d+)?)\s*,\s*([+-]?(?:(?:\d+(?:\.\d*)?)|(?:\.\d+))(?:[eE][+-]?\d+)?)\s*([\]\)])#?(\d+)?$/
  @legacy_float_relative_tolerance 1.0e-10

  @spec match?(String.t(), EvaluationContext.t()) :: {:ok, boolean()} | :unsupported
  def match?(rule, %EvaluationContext{} = context) when is_binary(rule) do
    with {:ok, tree} <- Rule.parse(rule),
         {:ok, lhs, config} <- config_from_tree(tree) do
      config
      |> MathExpressionMatcher.evaluate(LegacyInput.submitted_value(lhs, context))
      |> case do
        {:ok, matched?} -> {:ok, matched?}
        {:error, _} -> :unsupported
      end
    else
      _ -> :unsupported
    end
  end

  defp config_from_tree({operator, lhs, raw}) when operator in [:eq, :gt, :lt] do
    case input_lhs?(lhs) do
      true -> numeric_config(operator, raw) |> wrap_config(lhs)
      false -> :unsupported
    end
  end

  defp config_from_tree({:!, {:eq, lhs, raw}}) do
    case input_lhs?(lhs) do
      false ->
        :unsupported

      true ->
        case parsed_numeric_input(raw) do
          {:ok, _value, precision} when not is_nil(precision) ->
            :unsupported

          {:ok, value, nil} ->
            wrap_config(numeric_mode("not_equal", "expected", value, nil), lhs)

          {:range, lower, upper, bounds, nil} ->
            wrap_config(range_mode("not_between", lower, upper, bounds, nil), lhs)

          {:range, _lower, _upper, _bounds, _precision} ->
            :unsupported

          :unsupported ->
            :unsupported
        end
    end
  end

  defp config_from_tree({:||, left, right}) do
    inclusive_config_from_or(left, right) || inclusive_config_from_or(right, left) || :unsupported
  end

  defp config_from_tree(_), do: :unsupported

  defp inclusive_config_from_or({:eq, lhs, raw}, {operator, rhs_lhs, rhs_raw})
       when operator in [:gt, :lt] and lhs == rhs_lhs do
    case input_lhs?(lhs) do
      false ->
        nil

      true ->
        with {:ok, value, precision} <- parsed_numeric_input(raw),
             {:ok, ^value, ^precision} <- parsed_numeric_input(rhs_raw) do
          inclusive_operator =
            case operator do
              :gt -> "greater_than_or_equal"
              :lt -> "less_than_or_equal"
            end

          wrap_config(numeric_mode(inclusive_operator, "threshold", value, precision), lhs)
        else
          _ -> nil
        end
    end
  end

  defp inclusive_config_from_or(_, _), do: nil

  defp numeric_config(:eq, raw) do
    case parsed_numeric_input(raw) do
      {:ok, value, precision} ->
        numeric_mode("equal", "expected", value, precision)

      {:range, lower, upper, bounds, precision} ->
        range_mode("between", lower, upper, bounds, precision)

      :unsupported ->
        :unsupported
    end
  end

  defp numeric_config(:gt, raw) do
    case parsed_numeric_input(raw) do
      {:ok, value, precision} -> numeric_mode("greater_than", "threshold", value, precision)
      _ -> :unsupported
    end
  end

  defp numeric_config(:lt, raw) do
    case parsed_numeric_input(raw) do
      {:ok, value, precision} -> numeric_mode("less_than", "threshold", value, precision)
      _ -> :unsupported
    end
  end

  defp wrap_config(:unsupported, _lhs), do: :unsupported

  defp wrap_config(math, lhs) do
    {:ok, lhs,
     %{
       "version" => 1,
       "type" => "math_expression",
       "math" => math
     }}
  end

  defp numeric_mode(operator, value_field, value, precision) do
    %{
      "mode" => "numeric",
      "operator" => operator,
      value_field => value
    }
    # Legacy numeric equality used a tiny relative tolerance when the authored
    # value was float-shaped. Preserve that only for old rule compatibility.
    |> maybe_put_legacy_float_tolerance(operator, value)
    |> maybe_put_precision(precision)
  end

  defp range_mode(operator, lower, upper, bounds, precision) do
    %{
      "mode" => "numeric",
      "operator" => operator,
      "lower" => lower,
      "upper" => upper,
      "bounds" => bounds
    }
    |> maybe_put_precision(precision)
  end

  defp maybe_put_precision(config, nil), do: config

  defp maybe_put_precision(config, count) do
    Map.put(config, "precision", %{"type" => "significant_figures", "count" => count})
  end

  defp maybe_put_legacy_float_tolerance(config, operator, value)
       when operator in ["equal", "not_equal"] do
    case float_literal?(value) do
      true ->
        Map.put(config, "tolerance", %{
          "type" => "relative",
          "value" => @legacy_float_relative_tolerance
        })

      false ->
        config
    end
  end

  defp maybe_put_legacy_float_tolerance(config, _operator, _value), do: config

  defp float_literal?(value), do: String.contains?(value, [".", "e", "E"])

  defp parsed_numeric_input(raw) do
    case Regex.run(@range_pattern, raw) do
      [_, left_bracket, lower, upper, right_bracket, precision] ->
        parsed_range(left_bracket, lower, upper, right_bracket, precision)

      [_, left_bracket, lower, upper, right_bracket] ->
        parsed_range(left_bracket, lower, upper, right_bracket, nil)

      _ ->
        parsed_scalar_input(raw)
    end
  end

  defp parsed_range(left_bracket, lower, upper, right_bracket, raw_precision) do
    precision = parse_optional_precision(raw_precision)

    case {range_bounds(left_bracket, right_bracket), precision} do
      {:unsupported, _} -> :unsupported
      {_, :unsupported} -> :unsupported
      {bounds, precision} -> {:range, lower, upper, bounds, precision}
    end
  end

  defp parsed_scalar_input(raw) do
    case String.split(raw, "#", parts: 2) do
      [value] -> parsed_scalar_value(value, nil)
      [value, precision] -> parsed_scalar_value(value, parse_optional_precision(precision))
    end
  end

  defp parsed_scalar_value(value, precision) do
    cond do
      precision == :unsupported -> :unsupported
      Regex.match?(@number_pattern, value) -> {:ok, value, precision}
      true -> :unsupported
    end
  end

  defp parse_optional_precision(nil), do: nil
  defp parse_optional_precision(""), do: nil

  defp parse_optional_precision(raw) do
    case Integer.parse(raw) do
      {count, ""} when count > 0 -> count
      _ -> :unsupported
    end
  end

  defp range_bounds("[", "]"), do: "inclusive"
  defp range_bounds("(", ")"), do: "exclusive"
  defp range_bounds(_, _), do: :unsupported

  defp input_lhs?(:input), do: true
  defp input_lhs?({:input, ref}) when is_binary(ref), do: true
  defp input_lhs?(_), do: false
end
