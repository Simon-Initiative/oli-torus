defmodule Oli.Delivery.Evaluation.ParserTest do
  use ExUnit.Case, async: true

  defp parse(input), do: Oli.Delivery.Evaluation.Rule.parse(input)

  test "parses scientific with +" do
    assert {:ok, {:eq, :input, "[3.0e+5,4.0e+5]"}} ==
             parse("input = {[3.0e+5,4.0e+5]}")
  end

  test "parses conjunction" do
    assert {:ok, {:&&, {:gt, :attempt_number, "1"}, {:like, :input, "cat.*"}}} ==
             parse("attemptNumber > {1} && input like {cat.*}")
  end

  test "parses disjunction" do
    assert {:ok, {:||, {:gt, :attempt_number, "1"}, {:like, :input, "some string here"}}} ==
             parse("attemptNumber > {1} || input like {some string here}")
  end

  test "parses grouping" do
    output = parse("attemptNumber > {1} && (input like {some string here} || input like {other})")

    assert {:ok,
            {:&&, {:gt, :attempt_number, "1"},
             {:||, {:like, :input, "some string here"}, {:like, :input, "other"}}}} ==
             output
  end

  test "parses negation" do
    assert {:ok, {:!, {:gt, :attempt_number, "1"}}} ==
             parse("!attemptNumber > {1}")
  end

  test "fails on unknown function" do
    assert {:error, _} = parse("!attemptNumber > 1")
  end

  test "parses equals operator and processes escaped curly brackets" do
    assert {:ok, {:equals, :input, "some string with escaped curly brackets here } and here { "}} ==
             parse(
               "input equals {some string with escaped curly brackets here \\} and here \\{ }"
             )
  end

  test "parses math equation with escaped characters" do
    assert {:ok,
            {:equals, :input,
             "\\frac{1}{\\lambda}\\left(\\left\\lbrace x\\right\\rbrace\\right)^2"}} ==
             parse(
               "input equals {\\\\frac\\{1\\}\\{\\\\lambda\\}\\\\left(\\\\left\\\\lbrace x\\\\right\\\\rbrace\\\\right)^2}"
             )
  end

  test "parses existing content backslashes that are followed by a non-escape char" do
    assert {:ok, {:like, :input, "(Plus\\s*\\[\\s*2\\s*,\\s*3\\s*,\\s*4\\s*\\])"}} ==
             parse("input like {(Plus\\s*\\[\\s*2\\s*,\\s*3\\s*,\\s*4\\s*\\])}")
  end
end
