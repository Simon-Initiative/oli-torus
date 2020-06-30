defmodule Oli.Delivery.Evaluation.ParserTest do

  use ExUnit.Case, async: true

  defp parse(input), do: Oli.Delivery.Evaluation.Rule.parse(input)

  test "parses conjunction" do
    assert {:ok, {:&&, {:gt, :attempt_number, "1"}, {:like, :input, "cat.*"}}}
      == parse("attemptNumber > {1} && input like {cat.*}")
  end

  test "parses disjunction" do
    assert {:ok, {:||, {:gt, :attempt_number, "1"}, {:like, :input, "some string here"}}}
      == parse("attemptNumber > {1} || input like {some string here}")
  end

  test "parses grouping" do

    output = parse("attemptNumber > {1} && (input like {some string here} || input like {other})")

    assert {:ok, {:&&,
      {:gt, :attempt_number, "1"},
      {:||,
        {:like, :input, "some string here"},
        {:like, :input, "other"}
      }}}
      == output
  end

  test "parses negation" do
    assert {:ok, {:!, {:gt, :attempt_number, "1"}}}
      == parse("!attemptNumber > {1}")
  end

  test "fails on unknown function" do
    assert {:error, _} = parse("!attemptNumber > 1")
  end


end
