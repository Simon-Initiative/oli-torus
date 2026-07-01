import math/equality/algebraic_types
import math/sampling/types as sampling_types

pub type GoldenOutcome {
  ExpectEquivalent
  ExpectNotEquivalent
  ExpectValidationFailure
  ExpectCandidateUndefined
  ExpectInsufficientSamples
}

pub type GoldenCase {
  GoldenCase(
    name: String,
    expected: String,
    candidate: String,
    config: algebraic_types.AlgebraicEquivalenceConfig,
    outcome: GoldenOutcome,
  )
}

pub fn cases() -> List(GoldenCase) {
  [
    GoldenCase(
      name: "basic commutative equivalent",
      expected: "x + 1",
      candidate: "1 + x",
      config: default_config(),
      outcome: ExpectEquivalent,
    ),
    GoldenCase(
      name: "expansion equivalent",
      expected: "2(x+3)",
      candidate: "2x+6",
      config: default_config(),
      outcome: ExpectEquivalent,
    ),
    GoldenCase(
      name: "factoring equivalent",
      expected: "(x+1)(x-1)",
      candidate: "x^2-1",
      config: default_config(),
      outcome: ExpectEquivalent,
    ),
    GoldenCase(
      name: "constant function equivalent",
      expected: "sqrt(4)",
      candidate: "2",
      config: default_config(),
      outcome: ExpectEquivalent,
    ),
    GoldenCase(
      name: "near miss",
      expected: "2(x+3)",
      candidate: "2x+7",
      config: default_config(),
      outcome: ExpectNotEquivalent,
    ),
    GoldenCase(
      name: "validation failure",
      expected: "x",
      candidate: "x + y",
      config: default_config(),
      outcome: ExpectValidationFailure,
    ),
    GoldenCase(
      name: "candidate undefined on expected-valid sample",
      expected: "x",
      candidate: "1 / x",
      config: sampling_config(sampling_types.SamplingConfig(
        seed: 1,
        desired_count: 3,
        max_attempts: 4,
        include_special_points: True,
      )),
      outcome: ExpectCandidateUndefined,
    ),
    GoldenCase(
      name: "insufficient expected-valid samples",
      expected: "1 / x",
      candidate: "1 / x",
      config: sampling_and_domain_config(
        sampling_types.SamplingConfig(
          seed: 13,
          desired_count: 1,
          max_attempts: 3,
          include_special_points: True,
        ),
        sampling_types.DomainConfig(variables: [
          sampling_types.VariableDomain(
            name: "x",
            lower: sampling_types.Inclusive(0.0),
            upper: sampling_types.Inclusive(0.0),
            exclusions: [],
            integer_only: False,
            preferred_values: [],
          ),
        ]),
      ),
      outcome: ExpectInsufficientSamples,
    ),
  ]
}

fn default_config() -> algebraic_types.AlgebraicEquivalenceConfig {
  algebraic_types.default_algebraic_equivalence_config()
}

fn sampling_config(
  sampling: sampling_types.SamplingConfig,
) -> algebraic_types.AlgebraicEquivalenceConfig {
  let base = default_config()

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

fn sampling_and_domain_config(
  sampling: sampling_types.SamplingConfig,
  domains: sampling_types.DomainConfig,
) -> algebraic_types.AlgebraicEquivalenceConfig {
  let base = default_config()

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
