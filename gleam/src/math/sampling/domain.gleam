import gleam/float
import gleam/int
import gleam/list
import gleam/order
import gleam/result
import gleam/string
import math/sampling/types

/// Build the finite MVP domain used when an author/config does not specify a
/// variable domain. Sampling stays bounded even when the mathematical domain is
/// conceptually unbounded.
pub fn default_variable_domain(name: String) -> types.VariableDomain {
  types.VariableDomain(
    name: name,
    lower: types.Inclusive(-10.0),
    upper: types.Inclusive(10.0),
    exclusions: [],
    integer_only: False,
    preferred_values: [],
  )
}

/// Validate and sort a domain config by variable name. The sorted result keeps
/// later lookup, sampling, and debug behavior independent from caller-provided
/// ordering and target-specific map behavior.
pub fn validate_domain_config(
  config: types.DomainConfig,
) -> Result(types.DomainConfig, types.SamplingError) {
  let types.DomainConfig(variables: variables) = config
  let sorted = list.sort(variables, by: compare_variable_domains)

  case first_duplicate_name(sorted) {
    Ok(name) ->
      Error(types.InvalidDomainConfig(
        variable: name,
        reason: "duplicate variable domain",
      ))

    Error(_) -> validate_domains(sorted, [])
  }
}

/// Resolve the effective domain for a variable. Missing domains deliberately
/// fall back to `[-10, 10]`; this layer does not infer symbolic restrictions
/// such as `ln(x - 2)` requiring `x > 2`.
pub fn effective_variable_domain(
  config: types.DomainConfig,
  name: String,
) -> Result(types.VariableDomain, types.SamplingError) {
  use valid_config <- result.try(validate_domain_config(config))
  let types.DomainConfig(variables: variables) = valid_config

  case list.find(in: variables, one_that: fn(domain) { domain.name == name }) {
    Ok(domain) -> Ok(domain)
    Error(_) -> Ok(default_variable_domain(name))
  }
}

/// Check whether a concrete value satisfies one variable domain. Exclusions are
/// exact float matches in the MVP; pseudo-random real samples are unlikely to
/// hit them, but exact checks are important for preferred and special points.
pub fn contains(domain: types.VariableDomain, value: Float) -> Bool {
  lower_allows(domain.lower, value)
  && upper_allows(domain.upper, value)
  && !list.contains(domain.exclusions, any: value)
  && case domain.integer_only {
    True -> is_integer_float(value)
    False -> True
  }
}

/// Return preferred values that are actually legal for the domain. Filtering at
/// this boundary keeps later sampler code from treating author hints as stronger
/// than domain constraints.
pub fn valid_preferred_values(domain: types.VariableDomain) -> List(Float) {
  list.filter(domain.preferred_values, keeping: fn(value) {
    contains(domain, value)
  })
}

/// Count unique integer values available in a domain. The result is meaningful
/// for integer-only sampling, but it is also useful in tests to prove exclusion
/// and bound handling before the raw sampler exists.
pub fn unique_integer_capacity(
  domain: types.VariableDomain,
) -> Result(Int, types.SamplingError) {
  case validate_domain(domain) {
    Error(error) -> Error(error)
    Ok(valid_domain) -> {
      let lower = lower_integer(valid_domain.lower)
      let upper = upper_integer(valid_domain.upper)

      case upper < lower {
        True -> Ok(0)
        False -> {
          let raw_count = upper - lower + 1
          let excluded_count =
            valid_domain.exclusions
            |> list.fold(from: [], with: collect_excluded_integer(lower, upper))
            |> list.length

          Ok(raw_count - excluded_count)
        }
      }
    }
  }
}

/// Validate that an integer-only domain can satisfy a unique sample request.
/// Returning `TooFewIntegerValues` here prevents later sampling code from
/// silently reusing duplicate integer assignments.
pub fn ensure_unique_integer_capacity(
  domain: types.VariableDomain,
  requested: Int,
) -> Result(Nil, types.SamplingError) {
  case domain.integer_only {
    False -> Ok(Nil)
    True ->
      case unique_integer_capacity(domain) {
        Error(error) -> Error(error)
        Ok(available) ->
          case available >= requested {
            True -> Ok(Nil)
            False ->
              Error(types.TooFewIntegerValues(
                variable: domain.name,
                requested: requested,
                available: available,
              ))
          }
      }
  }
}

fn validate_domains(
  domains: List(types.VariableDomain),
  validated: List(types.VariableDomain),
) -> Result(types.DomainConfig, types.SamplingError) {
  case domains {
    [] -> Ok(types.DomainConfig(variables: list.reverse(validated)))
    [domain, ..rest] ->
      case validate_domain(domain) {
        Ok(valid_domain) -> validate_domains(rest, [valid_domain, ..validated])
        Error(error) -> Error(error)
      }
  }
}

/// Domain validation is intentionally syntactic and finite. It proves that a
/// configured interval can contain at least one value, but it does not try to
/// derive expression-specific validity rules.
fn validate_domain(
  domain: types.VariableDomain,
) -> Result(types.VariableDomain, types.SamplingError) {
  case bounds_allow_value(domain.lower, domain.upper) {
    True -> Ok(domain)
    False ->
      Error(types.InvalidDomainConfig(
        variable: domain.name,
        reason: "domain bounds contain no values",
      ))
  }
}

fn compare_variable_domains(
  left: types.VariableDomain,
  right: types.VariableDomain,
) -> order.Order {
  string.compare(left.name, right.name)
}

fn first_duplicate_name(
  domains: List(types.VariableDomain),
) -> Result(String, Nil) {
  case domains {
    [] | [_] -> Error(Nil)
    [first, second, ..rest] ->
      case first.name == second.name {
        True -> Ok(first.name)
        False -> first_duplicate_name([second, ..rest])
      }
  }
}

fn bounds_allow_value(lower: types.Bound, upper: types.Bound) -> Bool {
  let lower_value = bound_value(lower)
  let upper_value = bound_value(upper)

  lower_value <. upper_value
  || { lower_value == upper_value && both_bounds_inclusive(lower, upper) }
}

fn both_bounds_inclusive(lower: types.Bound, upper: types.Bound) -> Bool {
  case lower, upper {
    types.Inclusive(_), types.Inclusive(_) -> True
    _, _ -> False
  }
}

fn bound_value(bound: types.Bound) -> Float {
  case bound {
    types.Inclusive(value) | types.Exclusive(value) -> value
  }
}

fn lower_allows(bound: types.Bound, value: Float) -> Bool {
  case bound {
    types.Inclusive(lower) -> value >=. lower
    types.Exclusive(lower) -> value >. lower
  }
}

fn upper_allows(bound: types.Bound, value: Float) -> Bool {
  case bound {
    types.Inclusive(upper) -> value <=. upper
    types.Exclusive(upper) -> value <. upper
  }
}

fn is_integer_float(value: Float) -> Bool {
  value == int.to_float(float.truncate(value))
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

fn collect_excluded_integer(
  lower: Int,
  upper: Int,
) -> fn(List(Int), Float) -> List(Int) {
  fn(excluded, value) {
    case is_integer_float(value) {
      False -> excluded
      True -> {
        let integer = float.truncate(value)

        case integer >= lower && integer <= upper {
          False -> excluded
          True ->
            case list.contains(excluded, any: integer) {
              True -> excluded
              False -> [integer, ..excluded]
            }
        }
      }
    }
  }
}

fn add_one(value: Int) -> Int {
  value + 1
}

fn subtract_one(value: Int) -> Int {
  value - 1
}
