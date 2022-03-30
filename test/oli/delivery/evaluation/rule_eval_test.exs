defmodule Oli.Delivery.Evaluation.RuleEvalTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Evaluation.Rule
  alias Oli.Delivery.Evaluation.EvaluationContext

  defp eval(rule, input) do
    context = %EvaluationContext{
      resource_attempt_number: 1,
      activity_attempt_number: 1,
      part_attempt_number: 1,
      part_attempt_guid: "1",
      input: input
    }

    {:ok, tree} = Rule.parse(rule)

    case Rule.evaluate(tree, context) do
      {:ok, result} -> result
      {:error, e} -> {:error, e}
    end
  end

  test "evaluating integers" do
    assert eval("attemptNumber = {1} && input = {3}", "3")
    refute eval("attemptNumber = {1} && input = {3}", "4")
    refute eval("attemptNumber = {1} && input = {3}", "33")
    refute eval("attemptNumber = {1} && input = {3}", "3.3")
    assert eval("attemptNumber = {1} && input > {2}", "3")
    assert eval("attemptNumber = {1} && input < {4}", "3")
    refute eval("attemptNumber = {1} && input > {3}", "3")
    refute eval("attemptNumber = {1} && input < {3}", "3")
  end

  test "evaluating floats" do
    assert eval("attemptNumber = {1} && input = {3.1}", "3.1")
    refute eval("attemptNumber = {1} && input = {3.1}", "3.2")
    refute eval("attemptNumber = {1} && input = {3.1}", "4")
    refute eval("attemptNumber = {1} && input = {3.1}", "31")
    assert eval("attemptNumber = {1} && input > {2}", "3.2")
    assert eval("attemptNumber = {1} && input < {4}", "3.1")
    refute eval("attemptNumber = {1} && input > {3}", "3.0")
    refute eval("attemptNumber = {1} && input < {3}", "3.0")
  end

  test "evaluating like" do
    assert eval("input like {cat}", "cat")
    refute eval("input like {cat}", "caaat")
    refute eval("input like {cat}", "ct")
    assert eval("input like {c.*?t}", "construct")
    refute eval("input like {c.*?t}", "apple")
  end

  test "evaluating numeric groupings" do
    assert eval("input = {1} || input > {1}", "1.5")
    assert eval("input = {1} || input > {1}", "1")
    refute eval("input = {1} || input > {1}", "0.1")
    refute eval("input = {11} || input > {11}", "1")

    assert eval("input = {1} || input < {1}", "0")
    assert eval("input = {1} || input < {1}", "1")
    refute eval("input = {1} || input < {1}", "1.5")
    refute eval("input = {1} || input < {1}", "1.1")
  end

  test "evaluating string groupings" do
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

  test "evaluating string contains" do
    assert eval("input contains {cat}", "the cat in the hat")
    assert eval("input contains {cat}", "the CaT in the hat")
    assert eval("input contains {CaT}", "the cat in the hat")
    refute eval("input contains {cat}", "the bat in the hat")

    assert eval("!(input contains {cat})", "the bat in the hat")
    refute eval("!(input contains {cat})", "the cat in the hat")
  end

  test "evaluating strings with a numeric operator results in error" do
    {:error, _} = eval("input < {3}", "*50")
    {:error, _} = eval("input < {3}", "cat")
    {:error, _} = eval("input = {apple}", "apple")
  end
end
