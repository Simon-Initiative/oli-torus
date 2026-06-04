import gleam/option
import gleeunit
import math/equality/algebraic
import math/equality/algebraic_format
import math/equality/algebraic_types
import math/sampling/types as sampling_types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn equivalent_result_debug_string_is_stable_cross_target_fixture_test() {
  let config = algebraic_types.default_algebraic_equivalence_config()
  let result = algebraic.check_algebraic_equivalence("1", "1", config)

  assert algebraic_format.result_to_debug_string(result)
    == equivalent_result_fixture()
  assert torus_math.algebraic_equivalence_result_to_debug_string(result)
    == equivalent_result_fixture()
}

pub fn debug_formatting_covers_value_mismatch_details_test() {
  let config = algebraic_types.default_algebraic_equivalence_config()
  let result = algebraic.check_algebraic_equivalence("1", "2", config)

  assert algebraic_format.outcome_to_debug_string(result.outcome)
    == "NotEquivalent(reason=ValueMismatch(first_failure=SampleComparison(index=0,source=ConstantExpression,assignment=Assignment(),expected_value=1.0,candidate_value=2.0,comparison=ComparisonResult(passed=false,expected=1.0,actual=2.0,difference=1.0,absolute_passed=false,relative_passed=false))))"
  assert algebraic_format.summary_to_debug_string(result.summary)
    == "EquivalenceSummary(outcome_category=NotEquivalent,requested_sample_count=8,valid_sample_count=1,attempts=1,rejected_sample_count=0,first_failure_index=Some(0),variables_sampled=[])"
}

pub fn debug_formatting_covers_candidate_undefined_details_test() {
  let config =
    config_with_sampling(sampling_types.SamplingConfig(
      seed: 1,
      desired_count: 3,
      max_attempts: 4,
      include_special_points: True,
    ))
  let result = algebraic.check_algebraic_equivalence("x", "1 / x", config)

  assert algebraic_format.outcome_to_debug_string(result.outcome)
    == "NotEquivalent(reason=CandidateUndefined(first_failure=CandidateRuntimeFailure(index=0,source=SampledPoint(SpecialPoint),assignment=Assignment(x=0.0),expected_value=0.0,error=DivisionByZero)))"
  assert algebraic_format.config_summary_to_debug_string(result.config_summary)
    == "EquivalenceConfigSummary(allowed_variables=[x],sampled_variables=[x],domain_policy=ExpectedDefinedDomain,requested_sample_count=3,max_attempts=4,tolerance=AbsoluteOrRelativeTolerance(abs=0.0001,rel=0.0001,epsilon=1.0e-12),diagnostics=DetailedDiagnostics)"
}

pub fn debug_formatting_covers_parse_failure_test() {
  let config = algebraic_types.default_algebraic_equivalence_config()
  let result = algebraic.check_algebraic_equivalence("", "x", config)

  assert algebraic_format.outcome_to_debug_string(result.outcome)
    == "ExpectedParseFailed(error=UnexpectedEnd(expected=[expression]))"
  assert algebraic_format.summary_to_debug_string(result.summary)
    == "EquivalenceSummary(outcome_category=ParseFailure,requested_sample_count=8,valid_sample_count=0,attempts=0,rejected_sample_count=0,first_failure_index=None,variables_sampled=[])"
}

pub fn debug_formatting_covers_validation_failure_test() {
  let config = algebraic_types.default_algebraic_equivalence_config()
  let result = algebraic.check_algebraic_equivalence("x", "x + y", config)

  assert algebraic_format.outcome_to_debug_string(result.outcome)
    == "ValidationFailed(errors=[UnexpectedVariable(side=Candidate,name=y)])"
}

pub fn debug_formatting_covers_insufficient_samples_and_rejections_test() {
  let config =
    config_with_sampling_and_domains(
      sampling_types.SamplingConfig(
        seed: 13,
        desired_count: 1,
        max_attempts: 3,
        include_special_points: True,
      ),
      sampling_types.DomainConfig(variables: [
        real_domain("x", 0.0, 0.0),
      ]),
    )
  let result = algebraic.check_algebraic_equivalence("1 / x", "1 / x", config)

  assert algebraic_format.outcome_to_debug_string(result.outcome)
    == "InsufficientValidSamples(error=InsufficientValidSamples(requested=1,found=0,attempts=3,rejected=[Rejected(reason=RuntimeRejected(DivisionByZero),count=3)]))"
  assert result.samples == []
  assert result.rejected_samples
    == [
      sampling_types.RejectedSampleSummary(
        reason: sampling_types.RuntimeRejected(sampling_types.DivisionByZero),
        count: 3,
      ),
    ]
  assert result.summary.valid_sample_count == 0
  assert result.summary.rejected_sample_count == 3
  assert algebraic_format.rejected_sample_summary_to_debug_string(
      sampling_types.RejectedSampleSummary(
        reason: sampling_types.RuntimeRejected(sampling_types.DivisionByZero),
        count: 3,
      ),
    )
    == "Rejected(reason=RuntimeRejected(DivisionByZero),count=3)"
}

pub fn result_details_keep_sample_rows_and_summary_data_test() {
  let config = algebraic_types.default_algebraic_equivalence_config()
  let result = algebraic.check_algebraic_equivalence("x + 1", "1 + x", config)

  let assert algebraic_types.AlgebraicEquivalenceResult(
    samples: [
      algebraic_types.SampleComparison(
        index: 0,
        assignment: sampling_types.Assignment(values: [
          sampling_types.VariableValue(name: "x", value: 0.0),
        ]),
        comparison: sampling_types.ComparisonResult(passed: True, ..),
        ..,
      ),
      ..
    ],
    summary: algebraic_types.EquivalenceSummary(
      outcome_category: algebraic_types.EquivalentOutcome,
      valid_sample_count: 8,
      rejected_sample_count: 0,
      first_failure_index: option.None,
      variables_sampled: ["x"],
      ..,
    ),
    config_summary: algebraic_types.EquivalenceConfigSummary(
      allowed_variables: ["x"],
      sampled_variables: ["x"],
      ..,
    ),
    ..,
  ) = result
  assert algebraic_format.sample_comparison_to_debug_string(
      result.samples |> first_sample,
    )
    == "SampleComparison(index=0,source=SampledPoint(SpecialPoint),assignment=Assignment(x=0.0),expected_value=1.0,candidate_value=1.0,comparison=ComparisonResult(passed=true,expected=1.0,actual=1.0,difference=0.0,absolute_passed=true,relative_passed=true))"
}

fn equivalent_result_fixture() -> String {
  "AlgebraicEquivalenceResult("
  <> "outcome=Equivalent(valid_sample_count=1),"
  <> "expected_debug=Some(ExpressionDebug(parsed=\"Expression(Num(\"1\"))\",normalized=\"Normalized(Expression(Num(Integer(1))), warnings=[])\",variables=[])),"
  <> "candidate_debug=Some(ExpressionDebug(parsed=\"Expression(Num(\"1\"))\",normalized=\"Normalized(Expression(Num(Integer(1))), warnings=[])\",variables=[])),"
  <> "samples=[SampleComparison(index=0,source=ConstantExpression,assignment=Assignment(),expected_value=1.0,candidate_value=1.0,comparison=ComparisonResult(passed=true,expected=1.0,actual=1.0,difference=0.0,absolute_passed=true,relative_passed=true))],"
  <> "rejected_samples=[],"
  <> "summary=EquivalenceSummary(outcome_category=Equivalent,requested_sample_count=8,valid_sample_count=1,attempts=1,rejected_sample_count=0,first_failure_index=None,variables_sampled=[]),"
  <> "config_summary=EquivalenceConfigSummary(allowed_variables=[],sampled_variables=[],domain_policy=ExpectedDefinedDomain,requested_sample_count=8,max_attempts=64,tolerance=AbsoluteOrRelativeTolerance(abs=0.0001,rel=0.0001,epsilon=1.0e-12),diagnostics=DetailedDiagnostics)"
  <> ")"
}

fn config_with_sampling(
  sampling: sampling_types.SamplingConfig,
) -> algebraic_types.AlgebraicEquivalenceConfig {
  let base = algebraic_types.default_algebraic_equivalence_config()

  algebraic_types.AlgebraicEquivalenceConfig(
    allowed_variables: base.allowed_variables,
    allowed_functions: base.allowed_functions,
    domains: base.domains,
    sampling: sampling,
    eval: base.eval,
    tolerance: base.tolerance,
    domain_policy: base.domain_policy,
    diagnostics: base.diagnostics,
  )
}

fn config_with_sampling_and_domains(
  sampling: sampling_types.SamplingConfig,
  domains: sampling_types.DomainConfig,
) -> algebraic_types.AlgebraicEquivalenceConfig {
  let base = algebraic_types.default_algebraic_equivalence_config()

  algebraic_types.AlgebraicEquivalenceConfig(
    allowed_variables: base.allowed_variables,
    allowed_functions: base.allowed_functions,
    domains: domains,
    sampling: sampling,
    eval: base.eval,
    tolerance: base.tolerance,
    domain_policy: base.domain_policy,
    diagnostics: base.diagnostics,
  )
}

fn real_domain(
  name: String,
  lower: Float,
  upper: Float,
) -> sampling_types.VariableDomain {
  sampling_types.VariableDomain(
    name: name,
    lower: sampling_types.Inclusive(lower),
    upper: sampling_types.Inclusive(upper),
    exclusions: [],
    integer_only: False,
    preferred_values: [],
  )
}

fn first_sample(
  samples: List(algebraic_types.SampleComparison),
) -> algebraic_types.SampleComparison {
  let assert [sample, ..] = samples
  sample
}
