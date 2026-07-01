import gleam/float
import gleeunit
import math/normalization/types as normal_types
import math/sampling/prng
import math/sampling/sample
import math/sampling/types
import torus_math

pub fn main() {
  gleeunit.main()
}

pub fn prng_sequence_is_exact_and_seed_normalization_is_stable_test() {
  assert prng.state_value(prng.new(0)) == 1
  assert prng.state_value(prng.new(-1)) == 2_147_483_646

  let #(first, state) = prng.next_int(prng.new(1))
  let #(second, state) = prng.next_int(state)
  let #(third, state) = prng.next_int(state)
  let #(fourth, state) = prng.next_int(state)
  let #(fifth, _) = prng.next_int(state)

  assert [first, second, third, fourth, fifth]
    == [48_271, 182_605_794, 1_291_394_886, 1_914_720_637, 2_078_669_041]
}

pub fn sampler_uses_filtered_special_points_with_variable_offsets_test() {
  let assert Ok(samples) =
    sample.sample_assignments(
      ["y", "x"],
      types.default_domain_config(),
      types.SamplingConfig(
        seed: 5,
        desired_count: 4,
        max_attempts: 10,
        include_special_points: True,
      ),
    )

  assert samples
    == [
      sample_assignment(0, types.SpecialPoint, [
        types.VariableValue(name: "x", value: 0.0),
        types.VariableValue(name: "y", value: 1.0),
      ]),
      sample_assignment(1, types.SpecialPoint, [
        types.VariableValue(name: "x", value: 1.0),
        types.VariableValue(name: "y", value: -1.0),
      ]),
      sample_assignment(2, types.SpecialPoint, [
        types.VariableValue(name: "x", value: -1.0),
        types.VariableValue(name: "y", value: -10.0),
      ]),
      sample_assignment(3, types.SpecialPoint, [
        types.VariableValue(name: "x", value: -10.0),
        types.VariableValue(name: "y", value: 10.0),
      ]),
    ]
}

pub fn sampler_is_repeated_run_deterministic_and_publicly_exposed_test() {
  let config =
    types.SamplingConfig(
      seed: 11,
      desired_count: 6,
      max_attempts: 12,
      include_special_points: True,
    )

  let assert Ok(first) =
    sample.sample_assignments(["x", "y"], types.default_domain_config(), config)
  let assert Ok(second) =
    sample.sample_assignments(["y", "x"], types.default_domain_config(), config)
  let assert Ok(public_samples) =
    torus_math.sample_assignments(
      ["x", "y"],
      types.default_domain_config(),
      config,
    )

  assert first == second
  assert first == public_samples
  assert list_sample_source(first, 5) == Ok(types.PseudoRandom)

  let assert Ok(random_values) = sample_values(first, 5)
  assert_close(variable_value(random_values, "x"), -9.995054854077779)
  assert_close(variable_value(random_values, "y"), 8.707138811567397)
}

pub fn sampler_filters_preferred_values_and_skips_duplicate_candidates_test() {
  let domains =
    types.DomainConfig(variables: [
      real_domain("x", 2.0, 4.0, [9.0, 3.0]),
      real_domain("y", 0.0, 2.0, []),
    ])

  let assert Ok(samples) =
    sample.sample_assignments(
      ["x", "y"],
      domains,
      types.SamplingConfig(
        seed: 3,
        desired_count: 2,
        max_attempts: 8,
        include_special_points: True,
      ),
    )

  assert samples
    == [
      sample_assignment(0, types.PreferredPoint, [
        types.VariableValue(name: "x", value: 3.0),
        types.VariableValue(name: "y", value: 1.0),
      ]),
      sample_assignment(1, types.SpecialPoint, [
        types.VariableValue(name: "x", value: 2.0),
        types.VariableValue(name: "y", value: 2.0),
      ]),
    ]
}

pub fn integer_only_domains_produce_unique_values_or_capacity_errors_test() {
  let integer_domain =
    types.VariableDomain(
      name: "n",
      lower: types.Inclusive(1.0),
      upper: types.Inclusive(3.0),
      exclusions: [],
      integer_only: True,
      preferred_values: [],
    )

  let assert Ok(samples) =
    sample.sample_assignments(
      ["n"],
      types.DomainConfig(variables: [integer_domain]),
      types.SamplingConfig(
        seed: 7,
        desired_count: 3,
        max_attempts: 6,
        include_special_points: True,
      ),
    )

  assert samples
    == [
      sample_assignment(0, types.SpecialPoint, [
        types.VariableValue(name: "n", value: 1.0),
      ]),
      sample_assignment(1, types.SpecialPoint, [
        types.VariableValue(name: "n", value: 2.0),
      ]),
      sample_assignment(2, types.SpecialPoint, [
        types.VariableValue(name: "n", value: 3.0),
      ]),
    ]

  assert sample.sample_assignments(
      ["n"],
      types.DomainConfig(variables: [
        types.VariableDomain(
          name: "n",
          lower: types.Inclusive(1.0),
          upper: types.Inclusive(2.0),
          exclusions: [],
          integer_only: True,
          preferred_values: [],
        ),
      ]),
      types.SamplingConfig(
        seed: 7,
        desired_count: 3,
        max_attempts: 6,
        include_special_points: True,
      ),
    )
    == Error(types.TooFewIntegerValues(
      variable: "n",
      requested: 3,
      available: 2,
    ))
}

pub fn valid_sampler_retries_runtime_invalid_expected_points_test() {
  let assert Ok(batch) =
    sample.valid_samples_for_expression(
      normal_expr("1 / x"),
      ["x"],
      types.default_domain_config(),
      types.SamplingConfig(
        seed: 9,
        desired_count: 2,
        max_attempts: 4,
        include_special_points: True,
      ),
      types.default_eval_config(),
    )

  assert batch
    == types.ValidSampleBatch(
      attempts: 3,
      rejected: [
        types.RejectedSampleSummary(
          reason: types.RuntimeRejected(types.DivisionByZero),
          count: 1,
        ),
      ],
      samples: [
        sample_assignment(0, types.SpecialPoint, [
          types.VariableValue(name: "x", value: 1.0),
        ]),
        sample_assignment(1, types.SpecialPoint, [
          types.VariableValue(name: "x", value: -1.0),
        ]),
      ],
    )
}

pub fn valid_sampler_reports_insufficient_samples_with_runtime_summary_test() {
  let zero_only_domain =
    types.DomainConfig(variables: [real_domain("x", 0.0, 0.0, [])])

  assert sample.valid_samples_for_expression(
      normal_expr("1 / x"),
      ["x"],
      zero_only_domain,
      types.SamplingConfig(
        seed: 13,
        desired_count: 1,
        max_attempts: 3,
        include_special_points: True,
      ),
      types.default_eval_config(),
    )
    == Error(
      types.InsufficientValidSamples(
        requested: 1,
        found: 0,
        attempts: 3,
        rejected: [
          types.RejectedSampleSummary(
            reason: types.RuntimeRejected(types.DivisionByZero),
            count: 3,
          ),
        ],
      ),
    )
}

pub fn valid_sampler_summarizes_duplicate_accepted_assignments_test() {
  let zero_only_domain =
    types.DomainConfig(variables: [real_domain("x", 0.0, 0.0, [])])

  assert sample.valid_samples_for_expression(
      normal_expr("x"),
      ["x"],
      zero_only_domain,
      types.SamplingConfig(
        seed: 17,
        desired_count: 2,
        max_attempts: 3,
        include_special_points: True,
      ),
      types.default_eval_config(),
    )
    == Error(
      types.InsufficientValidSamples(
        requested: 2,
        found: 1,
        attempts: 3,
        rejected: [
          types.RejectedSampleSummary(
            reason: types.DuplicateAssignment,
            count: 2,
          ),
        ],
      ),
    )
}

pub fn public_valid_sampler_boundary_returns_same_batch_test() {
  let expression = normal_expr("x + y")
  let sampling_config =
    types.SamplingConfig(
      seed: 19,
      desired_count: 3,
      max_attempts: 6,
      include_special_points: True,
    )

  let assert Ok(internal_batch) =
    sample.valid_samples_for_expression(
      expression,
      ["x", "y"],
      types.default_domain_config(),
      sampling_config,
      types.default_eval_config(),
    )
  let assert Ok(public_batch) =
    torus_math.valid_samples_for_expression(
      expression,
      ["y", "x"],
      types.default_domain_config(),
      sampling_config,
      torus_math.default_eval_config(),
    )

  assert internal_batch == public_batch
  assert internal_batch.attempts == 3
  assert internal_batch.rejected == []
}

fn sample_assignment(
  index: Int,
  source: types.SampleSource,
  values: List(types.VariableValue),
) -> types.SampleAssignment {
  types.SampleAssignment(
    index: index,
    source: source,
    assignment: types.Assignment(values: values),
  )
}

fn real_domain(
  name: String,
  lower: Float,
  upper: Float,
  preferred_values: List(Float),
) -> types.VariableDomain {
  types.VariableDomain(
    name: name,
    lower: types.Inclusive(lower),
    upper: types.Inclusive(upper),
    exclusions: [],
    integer_only: False,
    preferred_values: preferred_values,
  )
}

fn list_sample_source(
  samples: List(types.SampleAssignment),
  index: Int,
) -> Result(types.SampleSource, Nil) {
  case samples, index {
    [], _ -> Error(Nil)
    [sample, ..], 0 -> Ok(sample.source)
    [_, ..rest], _ -> list_sample_source(rest, index - 1)
  }
}

fn sample_values(
  samples: List(types.SampleAssignment),
  index: Int,
) -> Result(List(types.VariableValue), Nil) {
  case samples, index {
    [], _ -> Error(Nil)
    [sample, ..], 0 -> {
      let types.Assignment(values: values) = sample.assignment
      Ok(values)
    }
    [_, ..rest], _ -> sample_values(rest, index - 1)
  }
}

fn variable_value(values: List(types.VariableValue), name: String) -> Float {
  case values {
    [] -> 0.0
    [value, ..rest] ->
      case value.name == name {
        True -> value.value
        False -> variable_value(rest, name)
      }
  }
}

fn assert_close(actual: Float, expected: Float) {
  assert float.absolute_value(actual -. expected) <. 0.000000001
}

fn normal_expr(source: String) -> normal_types.NormalExpr {
  let assert Ok(parsed) = torus_math.parse(source)
  let normalized = torus_math.structural_normalize(parsed)

  case normalized.normal {
    normal_types.NormalExpression(expression) -> expression
    normal_types.NormalQuantity(_, _) -> panic as "expected expression"
  }
}
