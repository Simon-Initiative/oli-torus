defmodule Oli.Delivery.Evaluation.RuleEvalTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Evaluation.Rule
  alias Oli.Delivery.Evaluation.EvaluationContext

  defp eval(rule, input) do
    context = %EvaluationContext{
      resource_attempt_number: 1,
      activity_attempt_number: 1,
      part_attempt_number: 1,
      input: input
    }

    {:ok, tree} = Rule.parse(rule)
    {:ok, result} = Rule.evaluate(tree, context)
    result
  end

  test "evaluating integers" do
    assert eval("attemptNumber = {1} && input = {3}", "3")
    assert eval("attemptNumber = {1} && input > {2}", "3")
    assert eval("attemptNumber = {1} && input < {4}", "3")
    refute eval("attemptNumber = {1} && input > {3}", "3")
    refute eval("attemptNumber = {1} && input < {3}", "3")
  end

  test "evaluating floats" do
    assert eval("attemptNumber = {1} && input = {3.1}", "3.1")
    assert eval("attemptNumber = {1} && input > {2}", "3.2")
    assert eval("attemptNumber = {1} && input < {4}", "3.1")
    refute eval("attemptNumber = {1} && input > {3}", "3.0")
    refute eval("attemptNumber = {1} && input < {3}", "3.0")
  end

  test "evaluating like" do
    assert eval("input like {cat}", "cat")
    assert eval("input like {c.*?t}", "construct")
    refute eval("input like {c.*?t}", "apple")
  end

  test "evaluating groupings" do
    assert eval("attemptNumber = {1} && (input like {cat} || input like {dog})", "cat")
    assert eval("attemptNumber = {1} && (input like {cat} || input like {dog})", "dog")
  end

  test "evaluating negation" do
    assert eval("!(input like {cat})", "dog")
    assert !eval("!(input like {cat})", "cat")
  end

  test "evaluating complex groupings" do
    assert eval("input like {1} && (input like {2} && (!(input like {3})))", "1 2")
    assert eval("!(input like {1} && (input like {2} && (!(input like {3}))))", "1 3")
    assert eval("!(input like {1} && (input like {2} && (!(input like {3}))))", "1 2 3")
    assert eval("(!(input like {1})) && (input like {2})", "2")
  end

  test "evaluating input length" do
    assert eval("length(input) = {1}", "A")
    assert eval("length(input) < {10}", "Apple")
    assert eval("length(input) > {2}", "Apple")
  end

  test "evaluating strings with a numeric operator results in error" do
    context = %EvaluationContext{
      resource_attempt_number: 1,
      activity_attempt_number: 1,
      part_attempt_number: 1,
      input: "apple"
    }

    {:ok, tree} = Rule.parse("input = {apple}")
    assert {:error, %ArgumentError{message: "errors were found at the given arguments:\n\n  * 1st argument: not a textual representation of an integer\n"}} == Rule.evaluate(tree, context)
  end
end
