import math/equality/numeric
import math/equality/types

/// Validate only the root contract invariants that Phase 1 owns. Deeper JSON
/// and numeric validation are intentionally deferred to later phases so this
/// function stays aligned with the current type-contract milestone.
pub fn validate_spec(
  spec: types.EqualitySpec,
) -> Result(types.EqualitySpec, types.EqualityConfigError) {
  case spec.version {
    1 -> Ok(spec)
    version -> Error(types.UnsupportedVersion(version: version))
  }
}

/// Evaluate keeps the root-version guard in front of all executable behavior so
/// callers get config failures before mode failures. Numeric mode now delegates
/// to the standard/basic page scalar evaluator; future expression and unit-aware
/// modes remain explicit unsupported results.
pub fn evaluate(
  spec: types.EqualitySpec,
  submitted: String,
) -> types.EqualityResult {
  case validate_spec(spec) {
    Error(error) -> types.InvalidConfig(error: error)
    Ok(valid_spec) -> evaluate_mode(valid_spec.mode, submitted)
  }
}

/// Keep mode dispatch in one place so unsupported future families and supported
/// numeric behavior are visible at the public equality boundary.
fn evaluate_mode(
  mode: types.EqualityMode,
  submitted: String,
) -> types.EqualityResult {
  case mode {
    types.Numeric(spec) -> numeric.evaluate(spec, submitted)
    types.Expression(_) ->
      types.UnsupportedMode(mode: types.ExpressionEvaluation)
    types.UnitAware(_) -> types.UnsupportedMode(mode: types.UnitAwareEvaluation)
  }
}
