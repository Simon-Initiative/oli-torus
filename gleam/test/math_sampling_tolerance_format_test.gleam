import gleam/float
import gleeunit
import math/sampling/format
import math/sampling/tolerance
import math/sampling/types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn compare_numbers_supports_no_absolute_relative_and_combined_tolerance_test() {
  assert tolerance.compare_numbers(4.0, 4.0, types.NoTolerance)
    == Ok(types.ComparisonResult(
      passed: True,
      expected: 4.0,
      actual: 4.0,
      difference: 0.0,
      absolute_passed: True,
      relative_passed: True,
    ))

  assert tolerance.compare_numbers(4.0, 4.1, types.NoTolerance)
    == Ok(types.ComparisonResult(
      passed: False,
      expected: 4.0,
      actual: 4.1,
      difference: float.absolute_value(4.0 -. 4.1),
      absolute_passed: False,
      relative_passed: False,
    ))

  assert tolerance.compare_numbers(10.0, 11.0, types.AbsoluteTolerance(1.0))
    == Ok(types.ComparisonResult(
      passed: True,
      expected: 10.0,
      actual: 11.0,
      difference: 1.0,
      absolute_passed: True,
      relative_passed: False,
    ))

  assert tolerance.compare_numbers(
      100.0,
      102.0,
      types.RelativeTolerance(0.03, 0.000000000001),
    )
    == Ok(types.ComparisonResult(
      passed: True,
      expected: 100.0,
      actual: 102.0,
      difference: 2.0,
      absolute_passed: False,
      relative_passed: True,
    ))

  assert tolerance.compare_numbers(
      1000.0,
      1005.0,
      types.AbsoluteOrRelativeTolerance(0.1, 0.01, 0.000000000001),
    )
    == Ok(types.ComparisonResult(
      passed: True,
      expected: 1000.0,
      actual: 1005.0,
      difference: 5.0,
      absolute_passed: False,
      relative_passed: True,
    ))
}

pub fn relative_tolerance_uses_epsilon_floor_near_zero_test() {
  assert tolerance.compare_numbers(
      0.0,
      0.00000005,
      types.RelativeTolerance(0.1, 0.000001),
    )
    == Ok(types.ComparisonResult(
      passed: True,
      expected: 0.0,
      actual: 0.00000005,
      difference: 0.00000005,
      absolute_passed: False,
      relative_passed: True,
    ))

  assert tolerance.compare_numbers(
      0.0,
      0.0000002,
      types.RelativeTolerance(0.1, 0.000001),
    )
    == Ok(types.ComparisonResult(
      passed: False,
      expected: 0.0,
      actual: 0.0000002,
      difference: 0.0000002,
      absolute_passed: False,
      relative_passed: False,
    ))
}

pub fn compare_numbers_rejects_negative_tolerances_test() {
  assert tolerance.compare_numbers(1.0, 1.0, types.AbsoluteTolerance(-0.1))
    == Error(types.InvalidTolerance(
      field: "abs",
      reason: "must be greater than or equal to 0",
    ))

  assert tolerance.compare_numbers(1.0, 1.0, types.RelativeTolerance(-0.1, 0.0))
    == Error(types.InvalidTolerance(
      field: "rel",
      reason: "must be greater than or equal to 0",
    ))

  assert tolerance.compare_numbers(1.0, 1.0, types.RelativeTolerance(0.1, -0.1))
    == Error(types.InvalidTolerance(
      field: "epsilon",
      reason: "must be greater than or equal to 0",
    ))
}

pub fn public_compare_numbers_uses_shared_tolerance_logic_test() {
  assert torus_math.compare_numbers(
      0.0,
      0.00000005,
      torus_math.default_expression_tolerance(),
    )
    == Ok(types.ComparisonResult(
      passed: True,
      expected: 0.0,
      actual: 0.00000005,
      difference: 0.00000005,
      absolute_passed: True,
      relative_passed: False,
    ))
}

pub fn stable_debug_strings_cover_sampling_results_test() {
  let assignment =
    types.Assignment(values: [
      types.VariableValue(name: "y", value: -2.25),
      types.VariableValue(name: "x", value: 1.5),
    ])
  let batch =
    types.ValidSampleBatch(
      attempts: 2,
      rejected: [
        types.RejectedSampleSummary(
          reason: types.RuntimeRejected(types.DivisionByZero),
          count: 1,
        ),
      ],
      samples: [
        types.SampleAssignment(
          index: 0,
          source: types.SpecialPoint,
          assignment: types.Assignment(values: [
            types.VariableValue(name: "x", value: 1.5),
          ]),
        ),
      ],
    )

  assert format.assignment_to_debug_string(assignment)
    == "Assignment(x=1.5,y=-2.25)"
  assert format.runtime_error_to_debug_string(types.InvalidPower(-1.0, 0.5))
    == "InvalidPower(base=-1.0,exponent=0.5)"
  assert format.sampling_error_to_debug_string(types.InsufficientValidSamples(
      requested: 2,
      found: 1,
      attempts: 3,
      rejected: batch.rejected,
    ))
    == "InsufficientValidSamples(requested=2,found=1,attempts=3,rejected=[Rejected(reason=RuntimeRejected(DivisionByZero),count=1)])"
  assert format.sample_batch_to_debug_string(batch)
    == "ValidSampleBatch(samples=[Sample(index=0,source=SpecialPoint,Assignment(x=1.5))],attempts=2,rejected=[Rejected(reason=RuntimeRejected(DivisionByZero),count=1)])"
}

pub fn stable_debug_strings_cover_comparisons_and_public_api_test() {
  let comparison =
    types.ComparisonResult(
      passed: True,
      expected: 10.0,
      actual: 11.0,
      difference: 1.0,
      absolute_passed: True,
      relative_passed: False,
    )

  assert format.comparison_to_debug_string(comparison)
    == "ComparisonResult(passed=true,expected=10.0,actual=11.0,difference=1.0,absolute_passed=true,relative_passed=false)"
  assert torus_math.comparison_to_debug_string(comparison)
    == "ComparisonResult(passed=true,expected=10.0,actual=11.0,difference=1.0,absolute_passed=true,relative_passed=false)"
  assert torus_math.assignment_to_debug_string(
      types.Assignment(values: [
        types.VariableValue(name: "x", value: 1.5),
      ]),
    )
    == "Assignment(x=1.5)"
  assert torus_math.runtime_error_to_debug_string(types.DivisionByZero)
    == "DivisionByZero"
}
