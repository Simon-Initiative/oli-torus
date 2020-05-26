defmodule Oli.Delivery.Evaluation.RuleTest do

  use ExUnit.Case

  defp parse(input), do: input |> Oli.Delivery.Evaluation.Rule.rule() |> unwrap
  defp unwrap({:ok, [acc], "", _, _, _}), do: acc
  defp unwrap({:ok, _, rest, _, _, _}), do: {:error, "could not parse" <> rest}
  defp unwrap({:error, reason, _rest, _, _, _}), do: {:error, reason}

  test "parses conjunction" do
    assert {:&&, {:gt, :attempt_number, {:eval, :numeric, "1"}}, {:eq, :input, {:eval, :regex, "some string here"}}}
      == parse("attemptNumber > numeric{1} && input = regex{some string here}")
  end

  test "parses disjunction" do
    assert {:||, {:gt, :attempt_number, {:eval, :numeric, "1"}}, {:eq, :input, {:eval, :regex, "some string here"}}}
      == parse("attemptNumber > numeric{1} || input = regex{some string here}")
  end

  test "parses grouping" do

    output = parse("attemptNumber > numeric{1} && (input = regex{some string here} || input = regex{other})")

    assert {:&&,
      {:gt, :attempt_number, {:eval, :numeric, "1"}},
      {:||,
        {:eq, :input, {:eval, :regex, "some string here"}},
        {:eq, :input, {:eval, :regex, "other"}}
      }}
      == output
  end

  test "parses negation" do
    assert {:!, {:gt, :attempt_number, {:eval, :numeric, "1"}}}
      == parse("!attemptNumber > numeric{1}")
  end

end
