import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import math/normalization/types as normal_types
import math/sampling/assignment
import math/sampling/domain
import math/sampling/evaluate
import math/sampling/prng
import math/sampling/types

const random_retry_limit = 64

type CandidateSource {
  PreferredCandidate(index: Int)
  SpecialCandidate(index: Int)
  RandomCandidate
}

type VariableState {
  VariableState(
    name: String,
    domain: types.VariableDomain,
    used_integers: List(Int),
  )
}

/// Generate deterministic raw sample assignments for the requested variables.
///
/// Preferred values are emitted first, filtered special points second, and
/// pseudo-random values last. All assignments are normalized by variable name,
/// use the pure Gleam PRNG, and avoid duplicate assignments so later evaluator
/// and equivalence layers receive stable, repeatable inputs.
pub fn sample_assignments(
  variables: List(String),
  domains: types.DomainConfig,
  config: types.SamplingConfig,
) -> Result(List(types.SampleAssignment), types.SamplingError) {
  use sorted_variables <- result.try(validate_variables(variables))
  use Nil <- result.try(validate_sampling_config(config))
  use variable_states <- result.try(variable_states(sorted_variables, domains))
  use Nil <- result.try(ensure_integer_capacity(
    variable_states,
    config.desired_count,
  ))
  use Nil <- result.try(ensure_domains_have_values(variable_states))

  generate_samples(
    variable_states: variable_states,
    config: config,
    prng_state: prng.new(config.seed),
    preferred_slots: preferred_slot_count(variable_states),
    special_slots: special_slot_count(
      variable_states,
      config.include_special_points,
    ),
    attempts: 0,
    samples: [],
  )
}

/// Generate valid samples for one normalized expression.
///
/// This executor uses the same raw candidate order as `sample_assignments`, but
/// evaluates each candidate before accepting it. Runtime-invalid assignments are
/// retried here because this layer is only finding valid points for the
/// expected expression; future expected-versus-candidate equivalence should
/// evaluate candidate answers at these accepted points rather than changing this
/// sampling policy.
pub fn valid_samples_for_expression(
  expression: normal_types.NormalExpr,
  variables: List(String),
  domains: types.DomainConfig,
  sampling_config: types.SamplingConfig,
  eval_config: types.EvalConfig,
) -> Result(types.ValidSampleBatch, types.SamplingError) {
  use sorted_variables <- result.try(validate_variables(variables))
  use Nil <- result.try(validate_sampling_config(sampling_config))
  use variable_states <- result.try(variable_states(sorted_variables, domains))
  use Nil <- result.try(ensure_integer_capacity(
    variable_states,
    sampling_config.desired_count,
  ))
  use Nil <- result.try(ensure_domains_have_values(variable_states))

  generate_valid_samples(
    expression: expression,
    variable_states: variable_states,
    sampling_config: sampling_config,
    eval_config: eval_config,
    prng_state: prng.new(sampling_config.seed),
    preferred_slots: preferred_slot_count(variable_states),
    special_slots: special_slot_count(
      variable_states,
      sampling_config.include_special_points,
    ),
    attempts: 0,
    samples: [],
    rejected: [],
  )
}

/// Validate sampling config bounds before any PRNG state is consumed.
///
/// This helper is public so orchestration layers can reject invalid config
/// during preparation instead of discovering it only after entering a sampling
/// loop.
pub fn validate_sampling_config(
  config: types.SamplingConfig,
) -> Result(Nil, types.SamplingError) {
  case config.desired_count < 0 {
    True ->
      Error(types.InvalidSamplingConfig(
        field: "sampling.desired_count",
        reason: "must be greater than or equal to 0",
      ))

    False ->
      case config.max_attempts < config.desired_count {
        True ->
          Error(types.InvalidSamplingConfig(
            field: "sampling.max_attempts",
            reason: "must be greater than or equal to desired_count",
          ))

        False -> Ok(Nil)
      }
  }
}

/// Sort and deduplicate variable names before domain lookup.
///
/// Assignment construction also sorts values, but doing it here keeps sampling
/// sequence decisions independent from caller order and makes duplicate symbols
/// a configuration error before any PRNG state is consumed.
fn validate_variables(
  variables: List(String),
) -> Result(List(String), types.SamplingError) {
  let sorted = list.sort(variables, by: string.compare)

  case sorted {
    [] -> Error(types.NoVariablesButVariablesRequired)
    _ ->
      case first_duplicate_string(sorted) {
        Ok(name) ->
          Error(types.InvalidSamplingConfig(
            field: "variables",
            reason: "duplicate variable name: " <> name,
          ))

        Error(_) -> Ok(sorted)
      }
  }
}

fn variable_states(
  variables: List(String),
  domains: types.DomainConfig,
) -> Result(List(VariableState), types.SamplingError) {
  build_variable_states(variables, domains, [])
}

fn build_variable_states(
  variables: List(String),
  domains: types.DomainConfig,
  states: List(VariableState),
) -> Result(List(VariableState), types.SamplingError) {
  case variables {
    [] -> Ok(list.reverse(states))
    [name, ..rest] -> {
      use variable_domain <- result.try(domain.effective_variable_domain(
        domains,
        name,
      ))
      build_variable_states(rest, domains, [
        VariableState(name: name, domain: variable_domain, used_integers: []),
        ..states
      ])
    }
  }
}

fn ensure_integer_capacity(
  variable_states: List(VariableState),
  requested: Int,
) -> Result(Nil, types.SamplingError) {
  case variable_states {
    [] -> Ok(Nil)
    [VariableState(domain: variable_domain, ..), ..rest] -> {
      use Nil <- result.try(domain.ensure_unique_integer_capacity(
        variable_domain,
        requested,
      ))
      ensure_integer_capacity(rest, requested)
    }
  }
}

fn ensure_domains_have_values(
  variable_states: List(VariableState),
) -> Result(Nil, types.SamplingError) {
  case variable_states {
    [] -> Ok(Nil)
    [VariableState(name: name, domain: variable_domain, ..), ..rest] -> {
      case has_known_value(variable_domain) {
        True -> ensure_domains_have_values(rest)
        False -> Error(types.AllSamplesExcluded(variable: name))
      }
    }
  }
}

fn generate_valid_samples(
  expression expression: normal_types.NormalExpr,
  variable_states variable_states: List(VariableState),
  sampling_config sampling_config: types.SamplingConfig,
  eval_config eval_config: types.EvalConfig,
  prng_state prng_state: prng.State,
  preferred_slots preferred_slots: Int,
  special_slots special_slots: Int,
  attempts attempts: Int,
  samples samples: List(types.SampleAssignment),
  rejected rejected: List(types.RejectedSampleSummary),
) -> Result(types.ValidSampleBatch, types.SamplingError) {
  let accepted_count = list.length(samples)

  case accepted_count >= sampling_config.desired_count {
    True ->
      Ok(types.ValidSampleBatch(
        samples: list.reverse(samples),
        attempts: attempts,
        rejected: rejected,
      ))

    False ->
      case attempts >= sampling_config.max_attempts {
        True ->
          Error(types.InsufficientValidSamples(
            requested: sampling_config.desired_count,
            found: accepted_count,
            attempts: attempts,
            rejected: rejected,
          ))

        False -> {
          let source =
            candidate_source(
              attempts,
              preferred_slots: preferred_slots,
              special_slots: special_slots,
            )

          case build_candidate(variable_states, source, prng_state) {
            Error(error) ->
              generate_valid_samples(
                expression: expression,
                variable_states: variable_states,
                sampling_config: sampling_config,
                eval_config: eval_config,
                prng_state: prng_state,
                preferred_slots: preferred_slots,
                special_slots: special_slots,
                attempts: attempts + 1,
                samples: samples,
                rejected: add_rejection(
                  rejected,
                  types.DomainRejected(sampling_error_reason(error)),
                ),
              )

            Ok(#(candidate, next_variable_states, next_prng_state)) ->
              classify_valid_candidate(
                expression,
                candidate,
                source,
                next_variable_states,
                next_prng_state,
                sampling_config,
                eval_config,
                preferred_slots,
                special_slots,
                attempts,
                samples,
                rejected,
              )
          }
        }
      }
  }
}

fn classify_valid_candidate(
  expression: normal_types.NormalExpr,
  candidate: types.Assignment,
  source: CandidateSource,
  next_variable_states: List(VariableState),
  next_prng_state: prng.State,
  sampling_config: types.SamplingConfig,
  eval_config: types.EvalConfig,
  preferred_slots: Int,
  special_slots: Int,
  attempts: Int,
  samples: List(types.SampleAssignment),
  rejected: List(types.RejectedSampleSummary),
) -> Result(types.ValidSampleBatch, types.SamplingError) {
  case sample_contains(samples, candidate) {
    True ->
      generate_valid_samples(
        expression: expression,
        variable_states: next_variable_states,
        sampling_config: sampling_config,
        eval_config: eval_config,
        prng_state: next_prng_state,
        preferred_slots: preferred_slots,
        special_slots: special_slots,
        attempts: attempts + 1,
        samples: samples,
        rejected: add_rejection(rejected, types.DuplicateAssignment),
      )

    False ->
      case evaluate.evaluate_normal_expr(expression, candidate, eval_config) {
        Error(error) ->
          generate_valid_samples(
            expression: expression,
            variable_states: next_variable_states,
            sampling_config: sampling_config,
            eval_config: eval_config,
            prng_state: next_prng_state,
            preferred_slots: preferred_slots,
            special_slots: special_slots,
            attempts: attempts + 1,
            samples: samples,
            rejected: add_rejection(rejected, types.RuntimeRejected(error)),
          )

        Ok(_) -> {
          let sample =
            types.SampleAssignment(
              index: list.length(samples),
              assignment: candidate,
              source: sample_source(source),
            )

          generate_valid_samples(
            expression: expression,
            variable_states: next_variable_states,
            sampling_config: sampling_config,
            eval_config: eval_config,
            prng_state: next_prng_state,
            preferred_slots: preferred_slots,
            special_slots: special_slots,
            attempts: attempts + 1,
            samples: [sample, ..samples],
            rejected: rejected,
          )
        }
      }
  }
}

/// Aggregate rejection categories rather than storing every rejected assignment.
///
/// The summaries are stable, bounded diagnostics for tests and future preview or
/// telemetry layers. They intentionally avoid retaining raw sampled values or
/// learner expressions.
fn add_rejection(
  rejected: List(types.RejectedSampleSummary),
  reason: types.RejectedSampleReason,
) -> List(types.RejectedSampleSummary) {
  case rejected {
    [] -> [types.RejectedSampleSummary(reason: reason, count: 1)]
    [summary, ..rest] ->
      case summary.reason == reason {
        True -> [
          types.RejectedSampleSummary(reason: reason, count: summary.count + 1),
          ..rest
        ]

        False -> [summary, ..add_rejection(rest, reason)]
      }
  }
}

fn sampling_error_reason(error: types.SamplingError) -> String {
  case error {
    types.InvalidSamplingConfig(field, reason) -> field <> ": " <> reason
    types.InvalidDomainConfig(variable, reason) -> variable <> ": " <> reason
    types.NoVariablesButVariablesRequired -> "no variables"
    types.TooFewIntegerValues(variable, _, _) ->
      variable <> ": too few integer values"
    types.AllSamplesExcluded(variable) -> variable <> ": all samples excluded"
    types.InsufficientValidSamples(_, _, _, _) -> "insufficient valid samples"
  }
}

/// Walk candidate sources until the requested number of unique assignments is
/// accepted or `max_attempts` is exhausted.
///
/// Duplicate rejected candidates still consume an attempt and any PRNG draws,
/// which keeps repeated runs deterministic while bounding pathological domains.
fn generate_samples(
  variable_states variable_states: List(VariableState),
  config config: types.SamplingConfig,
  prng_state prng_state: prng.State,
  preferred_slots preferred_slots: Int,
  special_slots special_slots: Int,
  attempts attempts: Int,
  samples samples: List(types.SampleAssignment),
) -> Result(List(types.SampleAssignment), types.SamplingError) {
  let accepted_count = list.length(samples)

  case accepted_count >= config.desired_count {
    True -> Ok(list.reverse(samples))
    False ->
      case attempts >= config.max_attempts {
        True ->
          Error(types.InvalidSamplingConfig(
            field: "sampling.max_attempts",
            reason: "could not generate requested unique assignments",
          ))

        False -> {
          let source =
            candidate_source(
              attempts,
              preferred_slots: preferred_slots,
              special_slots: special_slots,
            )
          let assignment_source = sample_source(source)

          use #(candidate, next_variable_states, next_prng_state) <- result.try(
            build_candidate(variable_states, source, prng_state),
          )

          case sample_contains(samples, candidate) {
            True ->
              generate_samples(
                variable_states: variable_states,
                config: config,
                prng_state: next_prng_state,
                preferred_slots: preferred_slots,
                special_slots: special_slots,
                attempts: attempts + 1,
                samples: samples,
              )

            False -> {
              let sample =
                types.SampleAssignment(
                  index: accepted_count,
                  assignment: candidate,
                  source: assignment_source,
                )

              generate_samples(
                variable_states: next_variable_states,
                config: config,
                prng_state: next_prng_state,
                preferred_slots: preferred_slots,
                special_slots: special_slots,
                attempts: attempts + 1,
                samples: [sample, ..samples],
              )
            }
          }
        }
      }
  }
}

fn candidate_source(
  attempt: Int,
  preferred_slots preferred_slots: Int,
  special_slots special_slots: Int,
) -> CandidateSource {
  case attempt < preferred_slots {
    True -> PreferredCandidate(index: attempt)
    False ->
      case attempt < preferred_slots + special_slots {
        True -> SpecialCandidate(index: attempt - preferred_slots)
        False -> RandomCandidate
      }
  }
}

fn sample_source(source: CandidateSource) -> types.SampleSource {
  case source {
    PreferredCandidate(_) -> types.PreferredPoint
    SpecialCandidate(_) -> types.SpecialPoint
    RandomCandidate -> types.PseudoRandom
  }
}

fn build_candidate(
  variable_states: List(VariableState),
  source: CandidateSource,
  prng_state: prng.State,
) -> Result(
  #(types.Assignment, List(VariableState), prng.State),
  types.SamplingError,
) {
  case
    build_values(
      variable_states,
      source,
      prng_state,
      index: 0,
      values: [],
      states: [],
    )
  {
    Error(error) -> Error(error)
    Ok(#(values, next_states, next_prng_state)) -> {
      use built_assignment <- result.try(assignment.new(values))
      Ok(#(built_assignment, next_states, next_prng_state))
    }
  }
}

fn build_values(
  variable_states: List(VariableState),
  source: CandidateSource,
  prng_state: prng.State,
  index index: Int,
  values values: List(types.VariableValue),
  states states: List(VariableState),
) -> Result(
  #(List(types.VariableValue), List(VariableState), prng.State),
  types.SamplingError,
) {
  case variable_states {
    [] -> Ok(#(list.reverse(values), list.reverse(states), prng_state))
    [state, ..rest] -> {
      use #(value, next_state, next_prng_state) <- result.try(
        value_for_variable(state, source, index, prng_state),
      )
      build_values(
        rest,
        source,
        next_prng_state,
        index: index + 1,
        values: [types.VariableValue(name: state.name, value: value), ..values],
        states: [next_state, ..states],
      )
    }
  }
}

fn value_for_variable(
  variable_state: VariableState,
  source: CandidateSource,
  variable_index: Int,
  prng_state: prng.State,
) -> Result(#(Float, VariableState, prng.State), types.SamplingError) {
  let VariableState(domain: variable_domain, ..) = variable_state

  case source {
    PreferredCandidate(index) ->
      case
        cycle_value(
          valid_preferred_values(variable_domain),
          index + variable_index,
        )
      {
        Ok(value) -> reserve_value(variable_state, value, prng_state)
        Error(_) ->
          value_from_special_or_random(
            variable_state,
            index,
            variable_index,
            prng_state,
          )
      }

    SpecialCandidate(index) ->
      value_from_special_or_random(
        variable_state,
        index,
        variable_index,
        prng_state,
      )

    RandomCandidate -> random_value(variable_state, prng_state)
  }
}

fn value_from_special_or_random(
  variable_state: VariableState,
  source_index: Int,
  variable_index: Int,
  prng_state: prng.State,
) -> Result(#(Float, VariableState, prng.State), types.SamplingError) {
  let VariableState(domain: variable_domain, ..) = variable_state

  case
    cycle_value(special_values(variable_domain), source_index + variable_index)
  {
    Ok(value) -> reserve_value(variable_state, value, prng_state)
    Error(_) -> random_value(variable_state, prng_state)
  }
}

fn reserve_value(
  variable_state: VariableState,
  value: Float,
  prng_state: prng.State,
) -> Result(#(Float, VariableState, prng.State), types.SamplingError) {
  let VariableState(name: name, domain: variable_domain, used_integers: used) =
    variable_state

  case variable_domain.integer_only {
    False -> Ok(#(value, variable_state, prng_state))
    True -> {
      let integer_value = float.truncate(value)

      case list.contains(used, any: integer_value) {
        False ->
          Ok(#(
            int.to_float(integer_value),
            VariableState(name: name, domain: variable_domain, used_integers: [
              integer_value,
              ..used
            ]),
            prng_state,
          ))

        True -> {
          use next_integer <- result.try(next_available_integer(
            variable_domain,
            used,
          ))
          Ok(#(
            int.to_float(next_integer),
            VariableState(name: name, domain: variable_domain, used_integers: [
              next_integer,
              ..used
            ]),
            prng_state,
          ))
        }
      }
    }
  }
}

/// Dispatch random generation by domain kind.
///
/// Integer domains track per-variable used values so every emitted integer
/// point is unique across samples; real domains rely on assignment-level
/// uniqueness because their finite PRNG draws are already deterministic.
fn random_value(
  variable_state: VariableState,
  prng_state: prng.State,
) -> Result(#(Float, VariableState, prng.State), types.SamplingError) {
  let VariableState(domain: variable_domain, ..) = variable_state

  case variable_domain.integer_only {
    True -> random_integer_value(variable_state, prng_state, attempts: 0)
    False -> random_real_value(variable_state, prng_state, attempts: 0)
  }
}

fn random_real_value(
  variable_state: VariableState,
  prng_state: prng.State,
  attempts attempts: Int,
) -> Result(#(Float, VariableState, prng.State), types.SamplingError) {
  let VariableState(name: name, domain: variable_domain, ..) = variable_state
  let #(ratio, next_prng_state) = prng.next_float(prng_state)
  let value =
    lower_value(variable_domain.lower)
    +. ratio
    *. {
      upper_value(variable_domain.upper) -. lower_value(variable_domain.lower)
    }

  case domain.contains(variable_domain, value) {
    True -> Ok(#(value, variable_state, next_prng_state))
    False ->
      case attempts >= random_retry_limit {
        True -> Error(types.AllSamplesExcluded(variable: name))
        False ->
          random_real_value(
            variable_state,
            next_prng_state,
            attempts: attempts + 1,
          )
      }
  }
}

/// Draw integer candidates with bounded retries before scanning for the next
/// available value. This avoids correlated duplicates in small integer domains
/// without looping forever when exclusions consume many PRNG hits.
fn random_integer_value(
  variable_state: VariableState,
  prng_state: prng.State,
  attempts attempts: Int,
) -> Result(#(Float, VariableState, prng.State), types.SamplingError) {
  let VariableState(name: name, domain: variable_domain, used_integers: used) =
    variable_state
  let lower = lower_integer(variable_domain.lower)
  let upper = upper_integer(variable_domain.upper)
  let count = upper - lower + 1

  case count <= 0 {
    True -> Error(types.AllSamplesExcluded(variable: name))
    False -> {
      let #(raw, next_prng_state) = prng.next_int(prng_state)
      let offset = case int.modulo(raw, by: count) {
        Ok(value) -> value
        Error(_) -> 0
      }
      let candidate = lower + offset

      case int_candidate_allowed(variable_domain, used, candidate) {
        True ->
          Ok(#(
            int.to_float(candidate),
            VariableState(name: name, domain: variable_domain, used_integers: [
              candidate,
              ..used
            ]),
            next_prng_state,
          ))

        False ->
          case attempts >= random_retry_limit {
            True -> {
              use next_integer <- result.try(next_available_integer(
                variable_domain,
                used,
              ))
              Ok(#(
                int.to_float(next_integer),
                VariableState(
                  name: name,
                  domain: variable_domain,
                  used_integers: [next_integer, ..used],
                ),
                next_prng_state,
              ))
            }

            False ->
              random_integer_value(
                variable_state,
                next_prng_state,
                attempts: attempts + 1,
              )
          }
      }
    }
  }
}

fn next_available_integer(
  variable_domain: types.VariableDomain,
  used: List(Int),
) -> Result(Int, types.SamplingError) {
  find_available_integer(
    variable_domain,
    used,
    current: lower_integer(variable_domain.lower),
    upper: upper_integer(variable_domain.upper),
  )
}

fn find_available_integer(
  variable_domain: types.VariableDomain,
  used: List(Int),
  current current: Int,
  upper upper: Int,
) -> Result(Int, types.SamplingError) {
  case current > upper {
    True ->
      Error(types.TooFewIntegerValues(
        variable: variable_domain.name,
        requested: list.length(used) + 1,
        available: list.length(used),
      ))

    False ->
      case int_candidate_allowed(variable_domain, used, current) {
        True -> Ok(current)
        False ->
          find_available_integer(
            variable_domain,
            used,
            current: current + 1,
            upper: upper,
          )
      }
  }
}

fn int_candidate_allowed(
  variable_domain: types.VariableDomain,
  used: List(Int),
  value: Int,
) -> Bool {
  domain.contains(variable_domain, int.to_float(value))
  && !list.contains(used, any: value)
}

fn sample_contains(
  samples: List(types.SampleAssignment),
  candidate: types.Assignment,
) -> Bool {
  case samples {
    [] -> False
    [sample, ..rest] ->
      case assignment.same(sample.assignment, candidate) {
        True -> True
        False -> sample_contains(rest, candidate)
      }
  }
}

fn preferred_slot_count(variable_states: List(VariableState)) -> Int {
  variable_states
  |> list.map(fn(state) { valid_preferred_values(state.domain) |> list.length })
  |> max_int(0)
}

fn special_slot_count(
  variable_states: List(VariableState),
  include_special_points: Bool,
) -> Int {
  case include_special_points {
    False -> 0
    True ->
      variable_states
      |> list.map(fn(state) { special_values(state.domain) |> list.length })
      |> max_int(0)
  }
}

fn valid_preferred_values(
  variable_domain: types.VariableDomain,
) -> List(Float) {
  variable_domain
  |> domain.valid_preferred_values
  |> unique_floats([])
}

/// Special points use a stable order and are offset per variable. This prevents
/// common multi-variable samples from lining up as `(0, 0)`, `(1, 1)`, and so on,
/// while still exercising zero, small integers, midpoint, and boundaries when
/// the domain allows them.
fn special_values(variable_domain: types.VariableDomain) -> List(Float) {
  [
    0.0,
    1.0,
    -1.0,
    midpoint(variable_domain),
    lower_value(variable_domain.lower),
    upper_value(variable_domain.upper),
  ]
  |> list.filter(keeping: fn(value) { domain.contains(variable_domain, value) })
  |> unique_floats([])
}

fn has_known_value(variable_domain: types.VariableDomain) -> Bool {
  case special_values(variable_domain) {
    [_, ..] -> True
    [] ->
      case variable_domain.integer_only {
        True ->
          case domain.unique_integer_capacity(variable_domain) {
            Ok(count) -> count > 0
            Error(_) -> False
          }
        False ->
          case
            lower_value(variable_domain.lower)
            == upper_value(variable_domain.upper)
          {
            True ->
              domain.contains(
                variable_domain,
                lower_value(variable_domain.lower),
              )
            False -> True
          }
      }
  }
}

fn midpoint(variable_domain: types.VariableDomain) -> Float {
  lower_value(variable_domain.lower)
  +. {
    upper_value(variable_domain.upper) -. lower_value(variable_domain.lower)
  }
  /. 2.0
}

fn cycle_value(values: List(Float), index: Int) -> Result(Float, Nil) {
  let length = list.length(values)

  case length {
    0 -> Error(Nil)
    _ -> {
      let offset = case int.modulo(index, by: length) {
        Ok(value) -> value
        Error(_) -> 0
      }

      nth_float(values, offset)
    }
  }
}

fn nth_float(values: List(Float), index: Int) -> Result(Float, Nil) {
  case values, index {
    [], _ -> Error(Nil)
    [value, ..], 0 -> Ok(value)
    [_, ..rest], _ -> nth_float(rest, index - 1)
  }
}

fn max_int(values: List(Int), current: Int) -> Int {
  case values {
    [] -> current
    [value, ..rest] ->
      case value > current {
        True -> max_int(rest, value)
        False -> max_int(rest, current)
      }
  }
}

fn unique_floats(values: List(Float), seen: List(Float)) -> List(Float) {
  case values {
    [] -> list.reverse(seen)
    [value, ..rest] ->
      case list.contains(seen, any: value) {
        True -> unique_floats(rest, seen)
        False -> unique_floats(rest, [value, ..seen])
      }
  }
}

fn first_duplicate_string(values: List(String)) -> Result(String, Nil) {
  case values {
    [] | [_] -> Error(Nil)
    [first, second, ..rest] ->
      case first == second {
        True -> Ok(first)
        False -> first_duplicate_string([second, ..rest])
      }
  }
}

fn lower_value(bound: types.Bound) -> Float {
  case bound {
    types.Inclusive(value) | types.Exclusive(value) -> value
  }
}

fn upper_value(bound: types.Bound) -> Float {
  case bound {
    types.Inclusive(value) | types.Exclusive(value) -> value
  }
}

fn lower_integer(bound: types.Bound) -> Int {
  case bound {
    types.Inclusive(value) -> value |> float.ceiling |> float.truncate
    types.Exclusive(value) -> value |> float.floor |> float.truncate |> add_one
  }
}

fn upper_integer(bound: types.Bound) -> Int {
  case bound {
    types.Inclusive(value) -> value |> float.floor |> float.truncate
    types.Exclusive(value) ->
      value
      |> float.ceiling
      |> float.truncate
      |> subtract_one
  }
}

fn add_one(value: Int) -> Int {
  value + 1
}

fn subtract_one(value: Int) -> Int {
  value - 1
}
