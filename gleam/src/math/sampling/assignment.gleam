import gleam/list
import gleam/order
import gleam/result
import gleam/string
import math/sampling/types

/// Build an assignment with values sorted by variable name.
///
/// The sort happens at construction time so later evaluator, duplicate-sample,
/// and debug-formatting code can use one deterministic list order on both BEAM
/// and JavaScript instead of relying on map iteration.
pub fn new(
  values: List(types.VariableValue),
) -> Result(types.Assignment, types.SamplingError) {
  let sorted = list.sort(values, by: compare_variable_values)

  case first_duplicate_name(sorted) {
    Ok(name) ->
      Error(types.InvalidSamplingConfig(
        field: "assignment.values",
        reason: "duplicate variable name: " <> name,
      ))

    Error(_) -> Ok(types.Assignment(values: sorted))
  }
}

/// Return an assignment with the same values in deterministic variable-name
/// order. This is useful when callers already hold an `Assignment` value but
/// still need stable identity or formatting behavior.
pub fn normalize(
  assignment: types.Assignment,
) -> Result(types.Assignment, types.SamplingError) {
  let types.Assignment(values: values) = assignment
  new(values)
}

/// Look up a variable value for evaluation. Missing variables are runtime math
/// errors because the expression was syntactically valid but the concrete
/// assignment was incomplete.
pub fn lookup(
  assignment: types.Assignment,
  name: String,
) -> Result(Float, types.RuntimeMathError) {
  let types.Assignment(values: values) = assignment

  case list.find(in: values, one_that: fn(value) { value.name == name }) {
    Ok(value) -> Ok(value.value)
    Error(_) -> Error(types.MissingVariable(name: name))
  }
}

/// Compare two assignments after normalizing their value order. This gives
/// future duplicate-sample checks a target-stable identity without converting
/// floats into debug strings.
pub fn same(left: types.Assignment, right: types.Assignment) -> Bool {
  case normalize(left), normalize(right) {
    Ok(normal_left), Ok(normal_right) -> normal_left == normal_right
    _, _ -> False
  }
}

/// Extract variable names in the same deterministic order used by normalized
/// assignment values.
pub fn variable_names(
  assignment: types.Assignment,
) -> Result(List(String), types.SamplingError) {
  use normalized <- result.try(normalize(assignment))
  let types.Assignment(values: values) = normalized
  Ok(list.map(values, fn(value) { value.name }))
}

fn compare_variable_values(
  left: types.VariableValue,
  right: types.VariableValue,
) -> order.Order {
  string.compare(left.name, right.name)
}

/// Duplicate-name detection assumes values are already sorted. Keeping that
/// invariant local lets later callers avoid an accidental quadratic duplicate
/// scan when assignments grow beyond tiny examples.
fn first_duplicate_name(
  values: List(types.VariableValue),
) -> Result(String, Nil) {
  case values {
    [] | [_] -> Error(Nil)
    [first, second, ..rest] ->
      case first.name == second.name {
        True -> Ok(first.name)
        False -> first_duplicate_name([second, ..rest])
      }
  }
}
