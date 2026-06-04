import gleam/float
import gleam/int
import gleam/result
import math/ast
import math/normalization/types as normal_types
import math/sampling/assignment
import math/sampling/types

const euler = 2.718281828459045

const log_max_finite_float = 709.782712893384

const max_finite_float = 1.7976931348623157e308

const pi = 3.141592653589793

/// Evaluate a normalized expression into one finite real `Float`.
///
/// The evaluator deliberately accepts only `NormalExpr`, not raw strings or
/// parser AST values, so parsing, structural normalization, and runtime math
/// errors remain separate layers. Invalid math domains return structured
/// `RuntimeMathError` values instead of panicking or guessing at complex/unit
/// semantics.
pub fn evaluate_normal_expr(
  expression: normal_types.NormalExpr,
  assignment_values: types.Assignment,
  config: types.EvalConfig,
) -> Result(Float, types.RuntimeMathError) {
  evaluate(expression, assignment_values, config)
}

fn evaluate(
  expression: normal_types.NormalExpr,
  assignment_values: types.Assignment,
  config: types.EvalConfig,
) -> Result(Float, types.RuntimeMathError) {
  case expression {
    normal_types.NNumber(value, _, _) -> exact_number_to_float(value)
    normal_types.NVariable(name, _) ->
      assignment.lookup(assignment_values, name)
    normal_types.NConstant(constant, _) -> evaluate_constant(constant)
    normal_types.NSum(terms, _) ->
      evaluate_sum(terms, assignment_values, config, 0.0)
    normal_types.NProduct(factors, _) ->
      evaluate_product(factors, assignment_values, config, 1.0)
    normal_types.NPower(base, exponent, _) ->
      evaluate_power(base, exponent, assignment_values, config)
    normal_types.NCall(name, args, _) ->
      evaluate_call(name, args, assignment_values, config)
    normal_types.NAbs(arg, _) -> evaluate_abs(arg, assignment_values, config)
    normal_types.NFactorial(arg, _) ->
      evaluate_factorial(arg, assignment_values, config)
    normal_types.NNegate(arg, _) ->
      evaluate_negate(arg, assignment_values, config)
    normal_types.NDivide(left, right, _) ->
      evaluate_divide(left, right, assignment_values, config)
  }
}

fn exact_number_to_float(
  value: normal_types.ExactNumber,
) -> Result(Float, types.RuntimeMathError) {
  case value {
    normal_types.ExactInteger(value) -> Ok(int.to_float(value))
    normal_types.ExactRational(numerator, denominator) ->
      safe_divide(int.to_float(numerator), int.to_float(denominator))
    normal_types.ExactDecimal(_, numerator, denominator) ->
      safe_divide(int.to_float(numerator), int.to_float(denominator))
    normal_types.ApproximateFloat(_, value) -> finite_result(value)
    normal_types.LargeNumber(raw) ->
      case float.parse(raw) {
        Ok(value) -> finite_result(value)
        Error(_) -> Error(types.NonFiniteResult)
      }
  }
}

fn evaluate_constant(
  constant: ast.Constant,
) -> Result(Float, types.RuntimeMathError) {
  case constant {
    ast.Pi -> Ok(pi)
    ast.Euler -> Ok(euler)
  }
}

fn evaluate_sum(
  terms: List(normal_types.NormalExpr),
  assignment_values: types.Assignment,
  config: types.EvalConfig,
  total: Float,
) -> Result(Float, types.RuntimeMathError) {
  case terms {
    [] -> Ok(total)
    [term, ..rest] -> {
      use value <- result.try(evaluate(term, assignment_values, config))
      use next_total <- result.try(safe_add(total, value))
      evaluate_sum(rest, assignment_values, config, next_total)
    }
  }
}

fn evaluate_product(
  factors: List(normal_types.NormalExpr),
  assignment_values: types.Assignment,
  config: types.EvalConfig,
  total: Float,
) -> Result(Float, types.RuntimeMathError) {
  case factors {
    [] -> Ok(total)
    [factor, ..rest] -> {
      use value <- result.try(evaluate(factor, assignment_values, config))
      use next_total <- result.try(safe_multiply(total, value))
      evaluate_product(rest, assignment_values, config, next_total)
    }
  }
}

fn evaluate_divide(
  left: normal_types.NormalExpr,
  right: normal_types.NormalExpr,
  assignment_values: types.Assignment,
  config: types.EvalConfig,
) -> Result(Float, types.RuntimeMathError) {
  use numerator <- result.try(evaluate(left, assignment_values, config))
  use denominator <- result.try(evaluate(right, assignment_values, config))

  // Division by zero is checked before using the float operator so both targets
  // return the same domain error instead of target-specific infinity behavior.
  case denominator == 0.0 {
    True -> Error(types.DivisionByZero)
    False -> safe_divide(numerator, denominator)
  }
}

fn evaluate_negate(
  arg: normal_types.NormalExpr,
  assignment_values: types.Assignment,
  config: types.EvalConfig,
) -> Result(Float, types.RuntimeMathError) {
  use value <- result.try(evaluate(arg, assignment_values, config))
  finite_result(0.0 -. value)
}

fn evaluate_abs(
  arg: normal_types.NormalExpr,
  assignment_values: types.Assignment,
  config: types.EvalConfig,
) -> Result(Float, types.RuntimeMathError) {
  use value <- result.try(evaluate(arg, assignment_values, config))
  finite_result(float.absolute_value(value))
}

fn evaluate_power(
  base_expr: normal_types.NormalExpr,
  exponent_expr: normal_types.NormalExpr,
  assignment_values: types.Assignment,
  config: types.EvalConfig,
) -> Result(Float, types.RuntimeMathError) {
  use base <- result.try(evaluate(base_expr, assignment_values, config))
  use exponent <- result.try(evaluate(exponent_expr, assignment_values, config))

  // Power keeps calculator-like real semantics only where the result is a
  // finite real number. `0^0`, zero to a negative power, and negative bases with
  // non-integer exponents are all rejected before target math libraries run.
  case is_invalid_power(base, exponent) {
    True -> Error(types.InvalidPower(base: base, exponent: exponent))
    False ->
      case will_power_overflow(base, exponent) {
        True -> Error(types.Overflow)
        False -> evaluate_valid_power(base, exponent)
      }
  }
}

fn evaluate_valid_power(
  base: Float,
  exponent: Float,
) -> Result(Float, types.RuntimeMathError) {
  case base <. 0.0 && is_integer_float(exponent) {
    True -> evaluate_negative_integer_power(base, exponent)
    False ->
      case float.power(base, of: exponent) {
        Ok(value) -> finite_result(value)
        Error(_) -> Error(types.InvalidPower(base: base, exponent: exponent))
      }
  }
}

fn evaluate_negative_integer_power(
  base: Float,
  exponent: Float,
) -> Result(Float, types.RuntimeMathError) {
  let exponent_int = float.truncate(exponent)

  case float.power(float.absolute_value(base), of: exponent) {
    Ok(value) ->
      case is_odd_integer(exponent_int) {
        True -> finite_result(0.0 -. value)
        False -> finite_result(value)
      }
    Error(_) -> Error(types.InvalidPower(base: base, exponent: exponent))
  }
}

fn evaluate_call(
  name: ast.FunctionName,
  args: List(normal_types.NormalExpr),
  assignment_values: types.Assignment,
  config: types.EvalConfig,
) -> Result(Float, types.RuntimeMathError) {
  case args {
    [arg] -> evaluate_unary_call(name, arg, assignment_values, config)
    _ ->
      Error(types.UnsupportedEvaluationNode(
        description: "function call with unsupported arity",
      ))
  }
}

fn evaluate_unary_call(
  name: ast.FunctionName,
  arg: normal_types.NormalExpr,
  assignment_values: types.Assignment,
  config: types.EvalConfig,
) -> Result(Float, types.RuntimeMathError) {
  use value <- result.try(evaluate(arg, assignment_values, config))

  case name {
    ast.Sin -> evaluate_trig(value, sin)
    ast.Cos -> evaluate_trig(value, cos)
    ast.Tan -> evaluate_tangent(value, config)
    ast.Ln | ast.Log -> evaluate_log(value)
    ast.Log10 -> evaluate_log_base(value, 10.0)
    ast.Log2 -> evaluate_log_base(value, 2.0)
    ast.Sqrt -> evaluate_square_root(value)
    ast.Abs -> finite_result(float.absolute_value(value))
    ast.Exp ->
      // Very large exponentials overflow double precision; expose that as a
      // structured result instead of letting infinity pass to later comparison.
      case value >. log_max_finite_float {
        True -> Error(types.Overflow)
        False ->
          finite_result_with_error(float.exponential(value), types.Overflow)
      }
  }
}

fn evaluate_trig(
  value: Float,
  operation: fn(Float) -> Float,
) -> Result(Float, types.RuntimeMathError) {
  finite_result(operation(value))
}

fn evaluate_tangent(
  value: Float,
  config: types.EvalConfig,
) -> Result(Float, types.RuntimeMathError) {
  let types.EvalConfig(angle_mode: angle_mode, tangent_epsilon: epsilon, ..) =
    config

  case angle_mode {
    types.Radians -> {
      // Tangent is undefined where cosine is effectively zero. The configurable
      // epsilon keeps `tan(pi / 2)` target-stable despite floating-point
      // approximation of `pi`.
      case float.absolute_value(cos(value)) <. epsilon {
        True -> Error(types.UndefinedTangent(value: value))
        False -> finite_result(tan(value))
      }
    }
  }
}

fn evaluate_log(value: Float) -> Result(Float, types.RuntimeMathError) {
  // `log` and `ln` are natural logarithms for this MVP. Non-positive inputs are
  // runtime domain errors because real evaluation cannot produce a finite value.
  case value <=. 0.0 {
    True -> Error(types.InvalidLogarithm(value: value))
    False ->
      case float.logarithm(value) {
        Ok(value) -> finite_result(value)
        Error(_) -> Error(types.InvalidLogarithm(value: value))
      }
  }
}

fn evaluate_log_base(
  value: Float,
  base: Float,
) -> Result(Float, types.RuntimeMathError) {
  use numerator <- result.try(evaluate_log(value))
  use denominator <- result.try(evaluate_log(base))
  finite_result(numerator /. denominator)
}

fn evaluate_square_root(value: Float) -> Result(Float, types.RuntimeMathError) {
  // Square root is real-valued only for non-negative inputs in this evaluator;
  // complex-number support is intentionally outside the sampling work item.
  case value <. 0.0 {
    True -> Error(types.InvalidRoot(value: value))
    False ->
      case float.square_root(value) {
        Ok(value) -> finite_result(value)
        Error(_) -> Error(types.InvalidRoot(value: value))
      }
  }
}

fn evaluate_factorial(
  arg: normal_types.NormalExpr,
  assignment_values: types.Assignment,
  config: types.EvalConfig,
) -> Result(Float, types.RuntimeMathError) {
  use value <- result.try(evaluate(arg, assignment_values, config))
  let types.EvalConfig(factorial_max: factorial_max, ..) = config

  // Factorial accepts only non-negative integers. The configurable maximum
  // defaults to 170 because `171!` overflows IEEE-754 double precision on both
  // supported targets.
  case value <. 0.0 || !is_integer_float(value) {
    True -> Error(types.InvalidFactorial(value: value))
    False -> {
      let integer_value = float.truncate(value)

      case integer_value > factorial_max {
        True ->
          Error(types.FactorialTooLarge(
            value: integer_value,
            max: factorial_max,
          ))

        False -> Ok(factorial(integer_value, 1.0))
      }
    }
  }
}

fn factorial(value: Int, accumulator: Float) -> Float {
  case value <= 1 {
    True -> accumulator
    False -> factorial(value - 1, accumulator *. int.to_float(value))
  }
}

fn is_invalid_power(base: Float, exponent: Float) -> Bool {
  base == 0.0 && exponent <=. 0.0 || base <. 0.0 && !is_integer_float(exponent)
}

fn is_integer_float(value: Float) -> Bool {
  value == int.to_float(float.truncate(value))
}

fn is_odd_integer(value: Int) -> Bool {
  case int.modulo(int.absolute_value(value), by: 2) {
    Ok(1) -> True
    _ -> False
  }
}

fn safe_add(
  left: Float,
  right: Float,
) -> Result(Float, types.RuntimeMathError) {
  case
    same_sign(left, right)
    && float.absolute_value(left)
    >. max_finite_float -. float.absolute_value(right)
  {
    True -> Error(types.Overflow)
    False -> finite_result(left +. right)
  }
}

fn safe_multiply(
  left: Float,
  right: Float,
) -> Result(Float, types.RuntimeMathError) {
  case left == 0.0 || right == 0.0 {
    True -> Ok(0.0)
    False -> {
      let abs_left = float.absolute_value(left)
      let abs_right = float.absolute_value(right)

      case abs_right >=. 1.0 && abs_left >. max_finite_float /. abs_right {
        True -> Error(types.NonFiniteResult)
        False -> finite_result(left *. right)
      }
    }
  }
}

fn safe_divide(
  numerator: Float,
  denominator: Float,
) -> Result(Float, types.RuntimeMathError) {
  case denominator == 0.0 {
    True -> Error(types.DivisionByZero)
    False -> {
      let abs_denominator = float.absolute_value(denominator)

      case
        abs_denominator <. 1.0
        && float.absolute_value(numerator)
        >. max_finite_float *. abs_denominator
      {
        True -> Error(types.Overflow)
        False -> finite_result(numerator /. denominator)
      }
    }
  }
}

fn same_sign(left: Float, right: Float) -> Bool {
  left >. 0.0 && right >. 0.0 || left <. 0.0 && right <. 0.0
}

fn will_power_overflow(base: Float, exponent: Float) -> Bool {
  case base == 0.0 || exponent <=. 0.0 {
    True -> False
    False -> {
      case float.logarithm(float.absolute_value(base)) {
        Ok(log_base) ->
          case log_base <=. 0.0 {
            True -> False
            False -> exponent >. log_max_finite_float /. log_base
          }
        Error(_) -> False
      }
    }
  }
}

/// Non-finite checks are centralized so every operation boundary rejects NaN or
/// infinity before later sampling or comparison layers can treat them as valid
/// numeric results.
fn finite_result(value: Float) -> Result(Float, types.RuntimeMathError) {
  finite_result_with_error(value, types.NonFiniteResult)
}

fn finite_result_with_error(
  value: Float,
  error: types.RuntimeMathError,
) -> Result(Float, types.RuntimeMathError) {
  case is_finite(value) {
    True -> Ok(value)
    False -> Error(error)
  }
}

fn is_finite(value: Float) -> Bool {
  float.absolute_value(value) <=. max_finite_float
}

@external(erlang, "math", "sin")
@external(javascript, "./evaluate_ffi.mjs", "sin")
fn sin(value: Float) -> Float

@external(erlang, "math", "cos")
@external(javascript, "./evaluate_ffi.mjs", "cos")
fn cos(value: Float) -> Float

@external(erlang, "math", "tan")
@external(javascript, "./evaluate_ffi.mjs", "tan")
fn tan(value: Float) -> Float
