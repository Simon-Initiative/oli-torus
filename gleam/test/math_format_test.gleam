import gleam/list
import gleeunit
import math/ast
import math_test/corpus
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn rejected_corpus_scaffold_test() {
  assert list.length(corpus.rejected_parser_inputs()) == 7
}

pub fn formats_representative_ast_debug_strings_test() {
  let assert Ok(parsed) = torus_math.parse("2(x+3)")

  assert torus_math.to_debug_string(parsed)
    == "Expression(Mul[implicit](Num(\"2\"), Add(Var(\"x\"), Num(\"3\"))))"
}

pub fn formats_functions_absolute_and_factorial_debug_strings_test() {
  let assert Ok(function_parsed) = torus_math.parse("sqrt(2)/2")
  let assert Ok(abs_parsed) = torus_math.parse("|x-2|")
  let assert Ok(factorial_parsed) = torus_math.parse("n!")

  assert torus_math.to_debug_string(function_parsed)
    == "Expression(Divide(Call(Sqrt, [Num(\"2\")]), Num(\"2\")))"

  assert torus_math.to_debug_string(abs_parsed)
    == "Expression(Call(Abs, [Subtract(Var(\"x\"), Num(\"2\"))]))"

  assert torus_math.to_debug_string(factorial_parsed)
    == "Expression(Factorial(Var(\"n\")))"
}

pub fn formats_parse_errors_debug_strings_test() {
  assert torus_math.parse_error_to_debug_string(
      ast.UnclosedParenthesis(opened_at: ast.Span(start: 0, end: 1)),
    )
    == "UnclosedParenthesis(opened_at=Span(0,1))"

  assert torus_math.parse_error_to_debug_string(ast.FunctionRequiresParentheses(
      span: ast.Span(start: 0, end: 3),
      name: "tan",
    ))
    == "FunctionRequiresParentheses(Span(0,3), name=\"tan\")"
}
