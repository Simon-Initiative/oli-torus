import gleeunit
import math/sampling/assignment
import math/sampling/domain
import math/sampling/types

pub fn main() {
  gleeunit.main()
}

pub fn assignment_construction_sorts_values_and_rejects_duplicates_test() {
  let assert Ok(sorted) =
    assignment.new([
      types.VariableValue(name: "y", value: -1.0),
      types.VariableValue(name: "x", value: 2.5),
    ])

  assert sorted
    == types.Assignment(values: [
      types.VariableValue(name: "x", value: 2.5),
      types.VariableValue(name: "y", value: -1.0),
    ])

  assert assignment.new([
      types.VariableValue(name: "x", value: 1.0),
      types.VariableValue(name: "x", value: 2.0),
    ])
    == Error(types.InvalidSamplingConfig(
      field: "assignment.values",
      reason: "duplicate variable name: x",
    ))
}

pub fn assignment_lookup_and_identity_are_stable_test() {
  let assert Ok(first) =
    assignment.new([
      types.VariableValue(name: "y", value: -1.0),
      types.VariableValue(name: "x", value: 2.5),
    ])
  let assert Ok(second) =
    assignment.new([
      types.VariableValue(name: "x", value: 2.5),
      types.VariableValue(name: "y", value: -1.0),
    ])

  assert assignment.lookup(first, "x") == Ok(2.5)
  assert assignment.lookup(first, "z")
    == Error(types.MissingVariable(name: "z"))
  assert assignment.same(first, second)
  assert assignment.variable_names(first) == Ok(["x", "y"])
}

pub fn domain_validation_sorts_domains_and_rejects_invalid_config_test() {
  let y_domain = real_domain("y", types.Inclusive(0.0), types.Exclusive(1.0))
  let x_domain = real_domain("x", types.Inclusive(-5.0), types.Inclusive(5.0))

  assert domain.validate_domain_config(
      types.DomainConfig(variables: [
        y_domain,
        x_domain,
      ]),
    )
    == Ok(types.DomainConfig(variables: [x_domain, y_domain]))

  assert domain.validate_domain_config(
      types.DomainConfig(variables: [
        x_domain,
        x_domain,
      ]),
    )
    == Error(types.InvalidDomainConfig(
      variable: "x",
      reason: "duplicate variable domain",
    ))

  assert domain.validate_domain_config(
      types.DomainConfig(variables: [
        real_domain("z", types.Exclusive(2.0), types.Exclusive(2.0)),
      ]),
    )
    == Error(types.InvalidDomainConfig(
      variable: "z",
      reason: "domain bounds contain no values",
    ))
}

pub fn domain_lookup_uses_default_finite_range_test() {
  let assert Ok(default_x) =
    domain.effective_variable_domain(types.DomainConfig(variables: []), "x")

  assert default_x == domain.default_variable_domain("x")
  assert domain.contains(default_x, -10.0)
  assert domain.contains(default_x, 10.0)
  assert !domain.contains(default_x, -10.5)
}

pub fn domain_contains_respects_bounds_exclusions_and_integer_only_test() {
  let inclusive = real_domain("x", types.Inclusive(-5.0), types.Inclusive(5.0))
  let exclusive = real_domain("x", types.Exclusive(-5.0), types.Exclusive(5.0))
  let excluded =
    types.VariableDomain(
      name: "x",
      lower: types.Inclusive(-5.0),
      upper: types.Inclusive(5.0),
      exclusions: [0.0],
      integer_only: False,
      preferred_values: [0.0, 1.0],
    )
  let integer_only =
    types.VariableDomain(
      name: "n",
      lower: types.Inclusive(1.0),
      upper: types.Inclusive(3.0),
      exclusions: [],
      integer_only: True,
      preferred_values: [1.0, 2.5, 3.0],
    )

  assert domain.contains(inclusive, -5.0)
  assert domain.contains(inclusive, 5.0)
  assert !domain.contains(exclusive, -5.0)
  assert !domain.contains(exclusive, 5.0)
  assert !domain.contains(excluded, 0.0)
  assert domain.valid_preferred_values(excluded) == [1.0]
  assert domain.contains(integer_only, 2.0)
  assert !domain.contains(integer_only, 2.5)
  assert domain.valid_preferred_values(integer_only) == [1.0, 3.0]
}

pub fn integer_capacity_counts_unique_values_after_bounds_and_exclusions_test() {
  let integer_domain =
    types.VariableDomain(
      name: "n",
      lower: types.Inclusive(1.0),
      upper: types.Exclusive(5.0),
      exclusions: [2.0, 2.0, 4.5, 9.0],
      integer_only: True,
      preferred_values: [],
    )

  assert domain.unique_integer_capacity(integer_domain) == Ok(3)
  assert domain.ensure_unique_integer_capacity(integer_domain, 3) == Ok(Nil)
  assert domain.ensure_unique_integer_capacity(integer_domain, 4)
    == Error(types.TooFewIntegerValues(
      variable: "n",
      requested: 4,
      available: 3,
    ))
}

fn real_domain(
  name: String,
  lower: types.Bound,
  upper: types.Bound,
) -> types.VariableDomain {
  types.VariableDomain(
    name: name,
    lower: lower,
    upper: upper,
    exclusions: [],
    integer_only: False,
    preferred_values: [],
  )
}
