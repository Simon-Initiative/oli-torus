defmodule Oli.Delivery.Evaluation.LegacyRuleAdapterTest do
  use ExUnit.Case, async: true

  alias Oli.Activities.Model.{Part, Response}

  alias Oli.Delivery.Evaluation.{
    EvaluationContext,
    LegacyMathRuleAdapter,
    LegacyNumericRuleAdapter,
    ResponseMatcher,
    Rule
  }

  defp context(input, activity_attempt_number) do
    %EvaluationContext{
      resource_attempt_number: 1,
      activity_attempt_number: activity_attempt_number,
      activity_attempt_guid: "activity-guid",
      part_attempt_number: 1,
      part_attempt_guid: "part-guid",
      page_id: 1,
      input: input
    }
  end

  defp response(rule), do: %Response{id: "response-1", rule: rule, score: 1}
  defp numeric_part, do: %Part{id: "part-1", input_type: "numeric"}
  defp math_part, do: %Part{id: "part-1", input_type: "math"}

  defp rule_boolean(rule, context) do
    case Rule.parse_and_evaluate(rule, context) do
      {:ok, result} -> result
      {:error, _} -> false
    end
  end

  defp matcher_boolean(rule, context, part) do
    case ResponseMatcher.match?(response(rule), context, part) do
      {:ok, result} -> result
      {:error, _} -> false
    end
  end

  defp assert_parity(rule, input, part, activity_attempt_number \\ 1) do
    context = context(input, activity_attempt_number)

    assert matcher_boolean(rule, context, part) == rule_boolean(rule, context)
  end

  test "legacy numeric adapter preserves scalar operator behavior" do
    cases = [
      {"input = {3}", "3"},
      {"input = {3}", "4"},
      {"(!(input = {3}))", "4"},
      {"(!(input = {3}))", "3"},
      {"input > {3}", "4"},
      {"input > {3}", "3"},
      {"input = {3} || (input > {3})", "3"},
      {"input = {3} || (input > {3})", "4"},
      {"input < {3}", "2"},
      {"input < {3}", "3"},
      {"input = {3} || (input < {3})", "3"},
      {"input = {3} || (input < {3})", "2"}
    ]

    Enum.each(cases, fn {rule, input} ->
      assert_parity(rule, input, numeric_part())
    end)
  end

  test "legacy numeric adapter directly handles supported rule shapes" do
    assert LegacyNumericRuleAdapter.match?("input = {3}", context("3", 1)) == {:ok, true}

    assert LegacyNumericRuleAdapter.match?("input = {3} || (input > {3})", context("4", 1)) ==
             {:ok, true}

    assert LegacyNumericRuleAdapter.match?("input = {[1,3]}", context("2", 1)) == {:ok, true}
    assert LegacyNumericRuleAdapter.match?("(!(input = {3}))", context("4", 1)) == {:ok, true}
  end

  test "legacy numeric adapter preserves range and significant-figure behavior" do
    cases = [
      {"input = {[1,3]}", "2"},
      {"input = {[1,3]}", "4"},
      {"input = {(1,3)}", "1"},
      {"(!(input = {[1,3]}))", "4"},
      {"(!(input = {[1,3]}))", "2"},
      {"input = {3.20#3}", "3.20"},
      {"input = {3.20#3}", "3.2"},
      {"input = {[1,3]#2}", "2.0"},
      {"input = {[1,3]#2}", "2"}
    ]

    Enum.each(cases, fn {rule, input} ->
      assert_parity(rule, input, numeric_part())
    end)
  end

  test "legacy numeric adapter preserves float equality tolerance" do
    cases = [
      {"input = {3.20}", "3.2000000001"},
      {"input = {3.20}", "3.20001"},
      {"(!(input = {3.20}))", "3.2000000001"},
      {"(!(input = {3.20}))", "3.20001"}
    ]

    Enum.each(cases, fn {rule, input} ->
      assert_parity(rule, input, numeric_part())
    end)
  end

  test "legacy numeric adapter supports input_ref rules" do
    rule = "input_ref_answer = {3}"

    assert_parity(rule, Poison.encode!(%{"answer" => "3"}), numeric_part())
    assert_parity(rule, Poison.encode!(%{"answer" => "4"}), numeric_part())
  end

  test "legacy input_ref rules do not match malformed structured submissions" do
    assert LegacyNumericRuleAdapter.match?("input_ref_answer = {3}", context("3", 1)) ==
             {:ok, false}

    assert LegacyMathRuleAdapter.match?("input_ref_answer equals {x}", context("x", 1)) ==
             {:ok, false}
  end

  test "legacy numeric adapter falls back for unsupported compound and negated precision rules" do
    assert LegacyNumericRuleAdapter.match?("attemptNumber = {2} && input = {3}", context("3", 1)) ==
             :unsupported

    assert LegacyNumericRuleAdapter.match?("(!(input = {3.20#3}))", context("3.2", 1)) ==
             :unsupported

    assert_parity("attemptNumber = {2} && input = {3}", "3", numeric_part())
    assert_parity("(!(input = {3.20#3}))", "3.2", numeric_part())
  end

  test "legacy math adapter preserves direct LaTeX equality and whitespace normalization" do
    assert LegacyMathRuleAdapter.match?("input equals {my cat}", context("my     cat   ", 1)) ==
             {:ok, true}

    cases = [
      {"input equals {\\frac\\{1\\}\\{2\\}}", "\\frac{1}{2}"},
      {"input equals {\\frac\\{1\\}\\{2\\}}", "1/2"},
      {"input equals {my cat}", "my     cat   "}
    ]

    Enum.each(cases, fn {rule, input} ->
      assert_parity(rule, input, math_part())
    end)
  end

  test "legacy math adapter preserves parser unescaping for braces and backslashes" do
    rule =
      "input equals {\\\\frac\\{1\\}\\{\\\\lambda\\}\\\\left(\\\\left\\\\lbrace x\\\\right\\\\rbrace\\\\right)^2}"

    input = "\\frac{1}{\\lambda}\\left(\\left\\lbrace x\\right\\rbrace\\right)^2"

    assert_parity(rule, input, math_part())
  end

  test "legacy math adapter supports input_ref equality and falls back for unsupported text rules" do
    assert_parity(
      "input_ref_answer equals {\\frac\\{1\\}\\{2\\}}",
      Poison.encode!(%{"answer" => "\\frac{1}{2}"}),
      math_part()
    )

    assert LegacyMathRuleAdapter.match?("input iequals {CAT}", context("cat", 1)) == :unsupported

    assert_parity("input iequals {CAT}", "cat", math_part())
  end
end
