import gleam/float
import gleeunit
import math/ast
import math/normalization/types as normal_types
import math/sampling/assignment
import math/sampling/evaluate
import math/sampling/types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn evaluates_numeric_literals_constants_and_variables_test() {
  let assert Ok(empty_assignment) = assignment.new([])
  assert_close(evaluate_source("2", empty_assignment), 2.0)
  assert_close(evaluate_source("2.5", empty_assignment), 2.5)
  assert_close(evaluate_source("1.25e2", empty_assignment), 125.0)
  assert_close(evaluate_source("pi", empty_assignment), 3.141592653589793)
  assert_close(evaluate_source("e", empty_assignment), 2.718281828459045)

  let assert Ok(variable_assignment) =
    assignment.new([
      types.VariableValue(name: "x", value: 3.0),
      types.VariableValue(name: "y", value: -2.0),
    ])

  assert_close(evaluate_source("2x + y", variable_assignment), 4.0)
  assert evaluate_source("z", variable_assignment)
    == Error(types.MissingVariable(name: "z"))
}

pub fn evaluates_arithmetic_powers_unary_abs_and_factorial_test() {
  let assert Ok(values) =
    assignment.new([
      types.VariableValue(name: "x", value: -3.0),
    ])

  assert_close(evaluate_source("2 + 3 * 4", values), 14.0)
  assert_close(evaluate_source("2^3", values), 8.0)
  assert_close(evaluate_source("+3", values), 3.0)
  assert_close(evaluate_source("-x", values), 3.0)
  assert_close(evaluate_source("abs(x)", values), 3.0)
  assert_close(evaluate_source("|x - 2|", values), 5.0)
  assert_close(evaluate_source("5!", values), 120.0)
}

pub fn evaluates_supported_functions_with_radians_test() {
  let assert Ok(empty_assignment) = assignment.new([])

  assert_close(evaluate_source("sin(pi / 2)", empty_assignment), 1.0)
  assert_close(evaluate_source("cos(0)", empty_assignment), 1.0)
  assert_close(evaluate_source("tan(0)", empty_assignment), 0.0)
  assert_close(evaluate_source("ln(e)", empty_assignment), 1.0)
  assert_close(evaluate_source("log(e)", empty_assignment), 1.0)
  assert_close(evaluate_source("log10(100)", empty_assignment), 2.0)
  assert_close(evaluate_source("log2(8)", empty_assignment), 3.0)
  assert_close(evaluate_source("sqrt(4)", empty_assignment), 2.0)
  assert_close(evaluate_source("exp(1)", empty_assignment), 2.718281828459045)
}

pub fn returns_structured_runtime_errors_test() {
  let assert Ok(empty_assignment) = assignment.new([])

  assert evaluate_source("1 / 0", empty_assignment)
    == Error(types.DivisionByZero)
  assert evaluate_source("sqrt(-1)", empty_assignment)
    == Error(types.InvalidRoot(value: -1.0))
  assert evaluate_source("ln(0)", empty_assignment)
    == Error(types.InvalidLogarithm(value: 0.0))
  assert evaluate_source("log(-1)", empty_assignment)
    == Error(types.InvalidLogarithm(value: -1.0))

  let assert Error(types.UndefinedTangent(_)) =
    evaluate_source("tan(pi / 2)", empty_assignment)

  assert evaluate_source("(-1)^0.5", empty_assignment)
    == Error(types.InvalidPower(base: -1.0, exponent: 0.5))
  assert evaluate_source("0^0", empty_assignment)
    == Error(types.InvalidPower(base: 0.0, exponent: 0.0))
  assert evaluate_source("0^-1", empty_assignment)
    == Error(types.InvalidPower(base: 0.0, exponent: -1.0))
  assert evaluate_source("(-1)!", empty_assignment)
    == Error(types.InvalidFactorial(value: -1.0))
  assert evaluate_source("2.5!", empty_assignment)
    == Error(types.InvalidFactorial(value: 2.5))
  assert evaluate_source("171!", empty_assignment)
    == Error(types.FactorialTooLarge(value: 171, max: 170))
  assert evaluate_source("exp(10000)", empty_assignment)
    == Error(types.Overflow)
  assert evaluate_source("1e308 * 10", empty_assignment)
    == Error(types.NonFiniteResult)
}

pub fn unsupported_evaluation_nodes_return_structured_error_test() {
  let assert Ok(empty_assignment) = assignment.new([])
  let unsupported =
    normal_types.NCall(
      name: ast.Sin,
      args: [],
      span: ast.Span(start: 0, end: 3),
    )

  assert evaluate.evaluate_normal_expr(
      unsupported,
      empty_assignment,
      types.default_eval_config(),
    )
    == Error(types.UnsupportedEvaluationNode(
      description: "function call with unsupported arity",
    ))
}

pub fn public_torus_math_evaluator_boundary_test() {
  let assert Ok(values) =
    assignment.new([
      types.VariableValue(name: "x", value: 3.0),
    ])
  let expression = normal_expr("2x")

  assert torus_math.evaluate_normal_expr(
      expression,
      values,
      torus_math.default_eval_config(),
    )
    == Ok(6.0)
}

fn evaluate_source(
  source: String,
  assignment_values: types.Assignment,
) -> Result(Float, types.RuntimeMathError) {
  evaluate.evaluate_normal_expr(
    normal_expr(source),
    assignment_values,
    types.default_eval_config(),
  )
}

fn normal_expr(source: String) -> normal_types.NormalExpr {
  let assert Ok(parsed) = torus_math.parse(source)
  let normalized = torus_math.structural_normalize(parsed)

  case normalized.normal {
    normal_types.NormalExpression(expression) -> expression
    normal_types.NormalQuantity(_, _) -> panic as "expected expression"
  }
}

fn assert_close(
  result: Result(Float, types.RuntimeMathError),
  expected: Float,
) {
  let assert Ok(actual) = result
  assert float.absolute_value(actual -. expected) <. 0.000000001
}
