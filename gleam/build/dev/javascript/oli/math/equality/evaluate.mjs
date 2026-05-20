/// <reference types="./evaluate.d.mts" />
import { Ok, Error } from "../../gleam.mjs";
import * as $numeric from "../../math/equality/numeric.mjs";
import * as $types from "../../math/equality/types.mjs";

/**
 * Validate only the root contract invariants that Phase 1 owns. Deeper JSON
 * and numeric validation are intentionally deferred to later phases so this
 * function stays aligned with the current type-contract milestone.
 */
export function validate_spec(spec) {
  let $ = spec.version;
  if ($ === 1) {
    return new Ok(spec);
  } else {
    let version = $;
    return new Error(new $types.UnsupportedVersion(version));
  }
}

/**
 * Keep mode dispatch in one place so unsupported future families and supported
 * numeric behavior are visible at the public equality boundary.
 * 
 * @ignore
 */
function evaluate_mode(mode, submitted) {
  if (mode instanceof $types.Numeric) {
    let spec = mode[0];
    return $numeric.evaluate(spec, submitted);
  } else if (mode instanceof $types.Expression) {
    return new $types.UnsupportedMode(new $types.ExpressionEvaluation());
  } else {
    return new $types.UnsupportedMode(new $types.UnitAwareEvaluation());
  }
}

/**
 * Evaluate keeps the root-version guard in front of all executable behavior so
 * callers get config failures before mode failures. Numeric mode now delegates
 * to the standard/basic page scalar evaluator; future expression and unit-aware
 * modes remain explicit unsupported results.
 */
export function evaluate(spec, submitted) {
  let $ = validate_spec(spec);
  if ($ instanceof Ok) {
    let valid_spec = $[0];
    return evaluate_mode(valid_spec.mode, submitted);
  } else {
    let error = $[0];
    return new $types.InvalidConfig(error);
  }
}
