import gleam/float
import gleam/result
import math/sampling/types

const max_finite_float = 1.7976931348623157e308

/// Compare two finite numeric results using an explicit tolerance policy.
///
/// This helper is a numeric primitive for future equivalence work. It does not
/// decide whether two expressions are algebraically equivalent; it only reports
/// whether the supplied numbers pass the requested exact, absolute, relative, or
/// absolute-or-relative tolerance check.
pub fn compare_numbers(
  expected: Float,
  actual: Float,
  tolerance: types.Tolerance,
) -> Result(types.ComparisonResult, types.ComparisonError) {
  case is_finite(expected) && is_finite(actual) {
    False -> Error(types.NonFiniteComparisonInput)
    True -> compare_finite_numbers(expected, actual, tolerance)
  }
}

fn compare_finite_numbers(
  expected: Float,
  actual: Float,
  tolerance: types.Tolerance,
) -> Result(types.ComparisonResult, types.ComparisonError) {
  let difference = float.absolute_value(expected -. actual)

  case tolerance {
    types.NoTolerance -> {
      let exact = difference == 0.0
      Ok(comparison_result(
        passed: exact,
        expected: expected,
        actual: actual,
        difference: difference,
        absolute_passed: exact,
        relative_passed: exact,
      ))
    }

    types.AbsoluteTolerance(abs) -> {
      use Nil <- result.try(validate_non_negative("abs", abs))
      let absolute_passed = difference <=. abs
      Ok(comparison_result(
        passed: absolute_passed,
        expected: expected,
        actual: actual,
        difference: difference,
        absolute_passed: absolute_passed,
        relative_passed: False,
      ))
    }

    types.RelativeTolerance(rel, epsilon) -> {
      use Nil <- result.try(validate_non_negative("rel", rel))
      use Nil <- result.try(validate_non_negative("epsilon", epsilon))
      let relative_passed = relative_check(difference, expected, rel, epsilon)
      Ok(comparison_result(
        passed: relative_passed,
        expected: expected,
        actual: actual,
        difference: difference,
        absolute_passed: False,
        relative_passed: relative_passed,
      ))
    }

    types.AbsoluteOrRelativeTolerance(abs, rel, epsilon) -> {
      use Nil <- result.try(validate_non_negative("abs", abs))
      use Nil <- result.try(validate_non_negative("rel", rel))
      use Nil <- result.try(validate_non_negative("epsilon", epsilon))
      let absolute_passed = difference <=. abs
      let relative_passed = relative_check(difference, expected, rel, epsilon)
      Ok(comparison_result(
        passed: absolute_passed || relative_passed,
        expected: expected,
        actual: actual,
        difference: difference,
        absolute_passed: absolute_passed,
        relative_passed: relative_passed,
      ))
    }
  }
}

fn validate_non_negative(
  field: String,
  value: Float,
) -> Result(Nil, types.ComparisonError) {
  case value <. 0.0 {
    True ->
      Error(types.InvalidTolerance(
        field: field,
        reason: "must be greater than or equal to 0",
      ))

    False -> Ok(Nil)
  }
}

/// Relative tolerance uses an epsilon floor so comparisons near zero do not
/// divide the tolerance window down to an unusable value. The scale is based on
/// the expected value because future equivalence checks will compare candidate
/// answers against expected-expression results at sampled points.
fn relative_check(
  difference: Float,
  expected: Float,
  rel: Float,
  epsilon: Float,
) -> Bool {
  difference <=. rel *. float.max(float.absolute_value(expected), epsilon)
}

fn comparison_result(
  passed passed: Bool,
  expected expected: Float,
  actual actual: Float,
  difference difference: Float,
  absolute_passed absolute_passed: Bool,
  relative_passed relative_passed: Bool,
) -> types.ComparisonResult {
  types.ComparisonResult(
    passed: passed,
    expected: expected,
    actual: actual,
    difference: difference,
    absolute_passed: absolute_passed,
    relative_passed: relative_passed,
  )
}

fn is_finite(value: Float) -> Bool {
  float.absolute_value(value) <=. max_finite_float
}
