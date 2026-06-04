defmodule Oli.MathTest do
  use ExUnit.Case, async: true

  describe "parse/1" do
    test "returns the public Gleam AST term and debug string on success" do
      assert {:ok, %{ast: ast, debug: debug}} = Oli.Math.parse("2(x+3)")

      assert debug == "Expression(Mul[implicit](Num(\"2\"), Add(Var(\"x\"), Num(\"3\"))))"

      assert {:expression,
              {:expr, {:binary, {:multiply, :implicit_multiply}, _left, _right}, {:span, 0, 6}}} =
               ast
    end

    test "returns structured Gleam errors and debug strings on failure" do
      assert {:error, %{error: error, debug: debug}} = Oli.Math.parse("tan x")

      assert error == {:function_requires_parentheses, {:span, 0, 3}, "tan"}
      assert debug == "FunctionRequiresParentheses(Span(0,3), name=\"tan\")"
    end
  end
end
