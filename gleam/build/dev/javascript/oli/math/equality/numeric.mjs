/// <reference types="./numeric.d.mts" />
import * as $float from "../../../gleam_stdlib/gleam/float.mjs";
import * as $int from "../../../gleam_stdlib/gleam/int.mjs";
import * as $list from "../../../gleam_stdlib/gleam/list.mjs";
import * as $string from "../../../gleam_stdlib/gleam/string.mjs";
import { Ok, Error, toList, Empty as $Empty } from "../../gleam.mjs";
import * as $types from "../../math/equality/types.mjs";

/**
 * Convert collected diagnostics into the public equality outcome. A successful
 * result carries a stable numeric-match diagnostic so tests and preview tooling
 * can identify the evaluator layer that made the decision.
 * 
 * @ignore
 */
function finalize(diagnostics) {
  if (diagnostics instanceof $Empty) {
    return new $types.EqualityMatched(
      toList([new $types.NumericComparisonMatched()]),
    );
  } else {
    return new $types.EqualityNotMatched(diagnostics);
  }
}

/**
 * Scientific precision checks only look at the mantissa, matching the current
 * `#precision` behavior where exponent digits are not significant figures.
 * 
 * @ignore
 */
function mantissa_part(submitted) {
  let $ = $string.split_once($string.replace(submitted, "E", "e"), "e");
  if ($ instanceof Ok) {
    let mantissa = $[0][0];
    return mantissa;
  } else {
    return submitted;
  }
}

/**
 * Count decimal places from the mantissa so `1.20e3` has two decimal places.
 * 
 * @ignore
 */
function decimal_places(submitted) {
  let mantissa = mantissa_part(submitted);
  let $ = $string.split_once(mantissa, ".");
  if ($ instanceof Ok) {
    let fraction = $[0][1];
    return $string.length(fraction);
  } else {
    return 0;
  }
}

/**
 * Apply the new decimal-place rule family. Integers have zero decimal places,
 * while scientific notation counts places in the mantissa.
 * 
 * @ignore
 */
function decimal_place_rule_matches(actual, rule, expected) {
  if (rule instanceof $types.Exactly) {
    return actual === expected;
  } else if (rule instanceof $types.AtLeast) {
    return actual >= expected;
  } else {
    return actual <= expected;
  }
}

/**
 * ASCII digit checks are enough here because Number input rule parsing uses
 * ordinary ASCII numeric notation rather than localized digits.
 * 
 * @ignore
 */
function is_digit(char) {
  if (char === "0") {
    return true;
  } else if (char === "1") {
    return true;
  } else if (char === "2") {
    return true;
  } else if (char === "3") {
    return true;
  } else if (char === "4") {
    return true;
  } else if (char === "5") {
    return true;
  } else if (char === "6") {
    return true;
  } else if (char === "7") {
    return true;
  } else if (char === "8") {
    return true;
  } else if (char === "9") {
    return true;
  } else {
    return false;
  }
}

/**
 * Non-zero digits drive placeholder-zero stripping for significant figures.
 * 
 * @ignore
 */
function is_non_zero_digit(char) {
  if (char === "1") {
    return true;
  } else if (char === "2") {
    return true;
  } else if (char === "3") {
    return true;
  } else if (char === "4") {
    return true;
  } else if (char === "5") {
    return true;
  } else if (char === "6") {
    return true;
  } else if (char === "7") {
    return true;
  } else if (char === "8") {
    return true;
  } else if (char === "9") {
    return true;
  } else {
    return false;
  }
}

/**
 * Leading zeros before the first non-zero digit are placeholders. If the whole
 * mantissa is zero, keep the zeros so `0.0` still has two significant figures,
 * matching the legacy edge-case behavior.
 * 
 * @ignore
 */
function drop_leading_placeholder_zeros(loop$chars) {
  while (true) {
    let chars = loop$chars;
    if (chars instanceof $Empty) {
      return chars;
    } else {
      let $ = chars.head;
      if ($ === "0") {
        let rest = chars.tail;
        let $1 = $list.any(rest, is_non_zero_digit);
        if ($1) {
          loop$chars = rest;
        } else {
          return chars;
        }
      } else {
        return chars;
      }
    }
  }
}

/**
 * Drop zeros from the reversed integer until doing so would remove all
 * significant digits. This preserves `0` as one significant figure.
 * 
 * @ignore
 */
function drop_trailing_integer_zeroes(loop$chars) {
  while (true) {
    let chars = loop$chars;
    if (chars instanceof $Empty) {
      return chars;
    } else {
      let $ = chars.head;
      if ($ === "0") {
        let rest = chars.tail;
        let $1 = $list.any(rest, is_non_zero_digit);
        if ($1) {
          loop$chars = rest;
        } else {
          return chars;
        }
      } else {
        return chars;
      }
    }
  }
}

/**
 * Integer trailing zeros after a non-zero digit are placeholders in legacy
 * significant-figure mode, so `1200` has two significant figures.
 * 
 * @ignore
 */
function strip_integer_trailing_zeros(mantissa) {
  let _block;
  let _pipe = mantissa;
  let _pipe$1 = $string.to_graphemes(_pipe);
  let _pipe$2 = $list.reverse(_pipe$1);
  let _pipe$3 = drop_trailing_integer_zeroes(_pipe$2);
  _block = $list.reverse(_pipe$3);
  let reversed = _block;
  return $string.join(reversed, "");
}

/**
 * Remove an optional sign before representation or precision checks so signs do
 * not count as digits and do not block leading-zero normalization.
 * 
 * @ignore
 */
function strip_sign(submitted) {
  let $ = $string.starts_with(submitted, "-") || $string.starts_with(
    submitted,
    "+",
  );
  if ($) {
    return $string.drop_start(submitted, 1);
  } else {
    return submitted;
  }
}

/**
 * Count significant figures using the legacy Torus intent: ignore exponent,
 * ignore a sign, ignore leading placeholder zeros, and ignore trailing integer
 * zeros unless a decimal point makes them significant.
 * 
 * @ignore
 */
function significant_figures(submitted) {
  let _block;
  let _pipe = submitted;
  let _pipe$1 = mantissa_part(_pipe);
  _block = strip_sign(_pipe$1);
  let mantissa = _block;
  let _block$1;
  let $ = $string.contains(mantissa, ".");
  if ($) {
    _block$1 = mantissa;
  } else {
    _block$1 = strip_integer_trailing_zeros(mantissa);
  }
  let normalized = _block$1;
  let _pipe$2 = normalized;
  let _pipe$3 = $string.replace(_pipe$2, ".", "");
  let _pipe$4 = $string.to_graphemes(_pipe$3);
  let _pipe$5 = drop_leading_placeholder_zeros(_pipe$4);
  return $list.count(_pipe$5, is_digit);
}

/**
 * Dispatch precision families without conflating them. This is deliberately
 * not inferred from representation because scientific notation and decimals can
 * both carry either significant figures or decimal-place requirements.
 * 
 * @ignore
 */
function precision_matches(submitted, precision) {
  if (precision instanceof $types.NoPrecision) {
    return true;
  } else if (precision instanceof $types.LegacySignificantFigures) {
    let count = precision.count;
    return significant_figures(submitted) === count;
  } else {
    let rule = precision.rule;
    let count = precision.count;
    return decimal_place_rule_matches(decimal_places(submitted), rule, count);
  }
}

/**
 * Precision constraints are submitted-form checks. Significant figures preserve
 * legacy `#precision` intent, while decimal places are the new explicit author
 * control and must remain separate.
 * 
 * @ignore
 */
function precision_diagnostics(submitted, precision) {
  let $ = precision_matches($string.trim(submitted), precision);
  if ($) {
    return toList([]);
  } else {
    return toList([new $types.NumericPrecisionMismatch()]);
  }
}

/**
 * Scientific representation is intentionally marker-based after parse success:
 * both `e` and `E` are accepted because current Number input parsing accepts
 * both forms.
 * 
 * @ignore
 */
function is_scientific_form(submitted) {
  return $string.contains(submitted, "e") || $string.contains(submitted, "E");
}

/**
 * Decimal representation requires a decimal point in the mantissa and excludes
 * scientific notation so authors can distinguish `42.0` from `4.20e1`.
 * 
 * @ignore
 */
function is_decimal_form(submitted) {
  return ($string.contains(submitted, ".") && !$string.contains(submitted, "e")) && !$string.contains(
    submitted,
    "E",
  );
}

/**
 * Check a sign-stripped string for ordinary integer digits.
 * 
 * @ignore
 */
function all_digits(value) {
  let $ = $string.to_graphemes(value);
  if ($ instanceof $Empty) {
    return false;
  } else {
    let chars = $;
    return $list.all(chars, is_digit);
  }
}

/**
 * Decide whether to parse through the float parser. Scientific notation routes
 * here even when the mantissa is an integer because the BEAM parser needs a
 * lowercase `e` and decimal point normalization before it accepts the value.
 * 
 * @ignore
 */
function looks_float_like(raw) {
  return ($string.contains(raw, ".") || $string.contains(raw, "e")) || $string.contains(
    raw,
    "E",
  );
}

/**
 * Integer representation means ordinary signed digits with no decimal point or
 * exponent marker. A value like `42.0` can parse to the same number but remains
 * a decimal form for authoring purposes.
 * 
 * @ignore
 */
function is_integer_form(submitted) {
  return !looks_float_like(submitted) && all_digits(strip_sign(submitted));
}

/**
 * Match only broad Number-input forms here. Parser-level syntax rules stay in
 * the parser; this function answers the authoring question "what form did the
 * learner use for this scalar value?"
 * 
 * @ignore
 */
function representation_matches(submitted, representation) {
  if (representation instanceof $types.AnyRepresentation) {
    return true;
  } else if (representation instanceof $types.IntegerRepresentation) {
    return is_integer_form(submitted);
  } else if (representation instanceof $types.DecimalRepresentation) {
    return is_decimal_form(submitted);
  } else {
    return is_scientific_form(submitted);
  }
}

/**
 * Representation constraints check the submitted text form after numeric parse
 * succeeds. They are intentionally independent from value comparison so `42.0`
 * can be a right value but wrong integer representation.
 * 
 * @ignore
 */
function representation_diagnostics(submitted, representation) {
  let normalized = $string.trim(submitted);
  let $ = representation_matches(normalized, representation);
  if ($) {
    return toList([]);
  } else {
    return toList([new $types.NumericRepresentationMismatch()]);
  }
}

/**
 * Keep inversion explicit so `not between` remains the exact complement of the
 * configured range, including boundary behavior chosen by the author.
 * 
 * @ignore
 */
function apply_range_inversion(inside, inverted) {
  if (inverted) {
    if (inside) {
      return false;
    } else {
      return true;
    }
  } else {
    return inside;
  }
}

/**
 * Apply the author-selected boundary policy. Inclusive and exclusive are typed
 * because the legacy rule string encoded this with brackets, which would be too
 * easy to lose in a free-form string config.
 * 
 * @ignore
 */
function within_bounds(value, lower, upper, bounds) {
  if (bounds instanceof $types.Inclusive) {
    return (lower <= value) && (value <= upper);
  } else {
    return (lower < value) && (value < upper);
  }
}

/**
 * Normalize only the parse input for runtime compatibility. Raw authored and
 * submitted strings stay internal to representation and precision checks rather
 * than being emitted in public diagnostics.
 * 
 * @ignore
 */
function normalize_scientific(raw) {
  let normalized_marker = $string.replace(raw, "E", "e");
  let $ = $string.contains(normalized_marker, "e");
  if ($) {
    let $1 = $string.contains(normalized_marker, ".");
    if ($1) {
      return normalized_marker;
    } else {
      let $2 = $string.split_once(normalized_marker, "e");
      if ($2 instanceof Ok) {
        let mantissa = $2[0][0];
        let exponent = $2[0][1];
        return (mantissa + ".0e") + exponent;
      } else {
        return normalized_marker;
      }
    }
  } else {
    return normalized_marker;
  }
}

/**
 * Leading decimals such as `.5` and `-.5` are accepted by current Number input
 * comparison rules even though the expression lexer rejects them today. Keep
 * that compatibility at the numeric evaluator boundary.
 * 
 * @ignore
 */
function normalize_leading_decimal(raw) {
  let $ = $string.starts_with(raw, ".");
  if ($) {
    return "0" + raw;
  } else {
    let $1 = $string.starts_with(raw, "-.");
    if ($1) {
      return "-0." + $string.drop_start(raw, 2);
    } else {
      let $2 = $string.starts_with(raw, "+.");
      if ($2) {
        return "+0." + $string.drop_start(raw, 2);
      } else {
        return raw;
      }
    }
  }
}

/**
 * Parse numeric strings in the same scalar family as Number input response
 * rules: integers, decimals, leading-decimal values, negatives, and scientific
 * notation. This intentionally does not call the expression parser, because
 * `2+2` should not become a Number input scalar.
 * 
 * @ignore
 */
function parse_number(raw) {
  let _block;
  let _pipe = raw;
  let _pipe$1 = $string.trim(_pipe);
  _block = normalize_leading_decimal(_pipe$1);
  let normalized = _block;
  let $ = looks_float_like(normalized);
  if ($) {
    let _pipe$2 = normalized;
    let _pipe$3 = normalize_scientific(_pipe$2);
    return $float.parse(_pipe$3);
  } else {
    let $1 = $int.parse(normalized);
    if ($1 instanceof Ok) {
      let value = $1[0];
      return new Ok($int.to_float(value));
    } else {
      return $1;
    }
  }
}

/**
 * Parse configured numeric values with field-specific errors so JSON configs
 * can point authors and migration tooling at the exact invalid parameter.
 * 
 * @ignore
 */
function parse_config_number(input, field) {
  let raw = input.raw;
  let $ = parse_number(raw);
  if ($ instanceof Ok) {
    return $;
  } else {
    return new Error(new $types.InvalidField(field, "expected numeric string"));
  }
}

/**
 * Evaluate inclusive or exclusive ranges after normalizing bound order. Current
 * standard numeric rules allow dynamic values to arrive in either order, so the
 * new contract preserves that min/max behavior instead of making authors sort
 * bounds themselves.
 * 
 * @ignore
 */
function evaluate_range(
  submitted_value,
  lower_input,
  upper_input,
  bounds,
  inverted
) {
  let $ = parse_config_number(lower_input, "comparison.lower");
  if ($ instanceof Ok) {
    let lower = $[0];
    let $1 = parse_config_number(upper_input, "comparison.upper");
    if ($1 instanceof Ok) {
      let upper = $1[0];
      let lower_bound = $float.min(lower, upper);
      let upper_bound = $float.max(lower, upper);
      let inside = within_bounds(
        submitted_value,
        lower_bound,
        upper_bound,
        bounds,
      );
      let $2 = apply_range_inversion(inside, inverted);
      if ($2) {
        return new Ok(toList([]));
      } else {
        return new Ok(toList([new $types.NumericRangeMismatch()]));
      }
    } else {
      return $1;
    }
  } else {
    return $;
  }
}

/**
 * Ordered comparisons parse their configured threshold and return scalar value
 * mismatch diagnostics. Tolerance is intentionally not read here because there
 * is no legacy standard-rule meaning for "greater than within tolerance".
 * 
 * @ignore
 */
function evaluate_ordered_scalar(submitted_value, threshold_input, predicate) {
  let $ = parse_config_number(threshold_input, "comparison.threshold");
  if ($ instanceof Ok) {
    let threshold_value = $[0];
    let $1 = predicate(submitted_value, threshold_value);
    if ($1) {
      return new Ok(toList([]));
    } else {
      return new Ok(toList([new $types.NumericValueMismatch()]));
    }
  } else {
    return $;
  }
}

/**
 * Use the tolerance diagnostic only when a tolerance was part of the author
 * config; otherwise a failed equality is an ordinary value mismatch.
 * 
 * @ignore
 */
function equality_mismatch_diagnostic(tolerance) {
  if (tolerance instanceof $types.NoTolerance) {
    return new $types.NumericValueMismatch();
  } else {
    return new $types.NumericToleranceMismatch();
  }
}

/**
 * Relative tolerance uses the larger magnitude as the reference, matching the
 * current Elixir rule behavior for standard Number input equality.
 * 
 * @ignore
 */
function relative_window(left, right, relative) {
  return relative * $float.max(
    $float.absolute_value(left),
    $float.absolute_value(right),
  );
}

/**
 * Keep absolute-difference math in one helper so future target-specific float
 * decisions have one place to change.
 * 
 * @ignore
 */
function absolute_difference(left, right) {
  return $float.absolute_value(left - right);
}

/**
 * Apply the configured equality tolerance. Relative tolerance follows the
 * legacy Torus rule of scaling by the larger magnitude so near-zero values do
 * not get a large implicit window.
 * 
 * @ignore
 */
function values_equal(submitted_value, expected_value, tolerance) {
  if (tolerance instanceof $types.NoTolerance) {
    return submitted_value === expected_value;
  } else if (tolerance instanceof $types.AbsoluteTolerance) {
    let value = tolerance.value;
    return absolute_difference(submitted_value, expected_value) <= value;
  } else if (tolerance instanceof $types.RelativeTolerance) {
    let value = tolerance.value;
    return absolute_difference(submitted_value, expected_value) <= relative_window(
      submitted_value,
      expected_value,
      value,
    );
  } else {
    let absolute = tolerance.absolute;
    let relative = tolerance.relative;
    return (absolute_difference(submitted_value, expected_value) <= absolute) || (absolute_difference(
      submitted_value,
      expected_value,
    ) <= relative_window(submitted_value, expected_value, relative));
  }
}

/**
 * Equality-style scalar comparisons are the only Phase 4 operators where
 * tolerance changes value equality. Ordered and range comparisons keep their
 * threshold semantics while still allowing representation and precision checks.
 * 
 * @ignore
 */
function evaluate_equality_scalar(
  submitted_value,
  expected_input,
  tolerance,
  inverted
) {
  let $ = parse_config_number(expected_input, "comparison.expected");
  if ($ instanceof Ok) {
    let expected_value = $[0];
    let equal = values_equal(submitted_value, expected_value, tolerance);
    let $1 = apply_range_inversion(equal, inverted);
    if ($1) {
      return new Ok(toList([]));
    } else {
      return new Ok(toList([equality_mismatch_diagnostic(tolerance)]));
    }
  } else {
    return $;
  }
}

/**
 * Dispatch each standard numeric operator to a small comparison helper. The
 * variants mirror the current response-rule operators and deliberately exclude
 * adaptive-page numeric cases, which continue through AdaptivePartEvaluation.
 * 
 * @ignore
 */
function comparison_diagnostics(comparison, submitted_value, tolerance) {
  if (comparison instanceof $types.Equal) {
    let expected = comparison.expected;
    return evaluate_equality_scalar(submitted_value, expected, tolerance, false);
  } else if (comparison instanceof $types.NotEqual) {
    let expected = comparison.expected;
    return evaluate_equality_scalar(submitted_value, expected, tolerance, true);
  } else if (comparison instanceof $types.GreaterThan) {
    let threshold = comparison.threshold;
    return evaluate_ordered_scalar(
      submitted_value,
      threshold,
      (value, threshold) => { return value > threshold; },
    );
  } else if (comparison instanceof $types.GreaterThanOrEqual) {
    let threshold = comparison.threshold;
    return evaluate_ordered_scalar(
      submitted_value,
      threshold,
      (value, threshold) => { return value >= threshold; },
    );
  } else if (comparison instanceof $types.LessThan) {
    let threshold = comparison.threshold;
    return evaluate_ordered_scalar(
      submitted_value,
      threshold,
      (value, threshold) => { return value < threshold; },
    );
  } else if (comparison instanceof $types.LessThanOrEqual) {
    let threshold = comparison.threshold;
    return evaluate_ordered_scalar(
      submitted_value,
      threshold,
      (value, threshold) => { return value <= threshold; },
    );
  } else if (comparison instanceof $types.Between) {
    let lower = comparison.lower;
    let upper = comparison.upper;
    let bounds = comparison.bounds;
    return evaluate_range(submitted_value, lower, upper, bounds, false);
  } else {
    let lower = comparison.lower;
    let upper = comparison.upper;
    let bounds = comparison.bounds;
    return evaluate_range(submitted_value, lower, upper, bounds, true);
  }
}

/**
 * Evaluate the operator layer and the independent form constraints, preserving
 * separate diagnostics so callers can distinguish "wrong value" from "right
 * value, wrong form" without involving feedback selection.
 * 
 * @ignore
 */
function evaluate_supported_spec(spec, submitted, submitted_value) {
  let $ = comparison_diagnostics(
    spec.comparison,
    submitted_value,
    spec.tolerance,
  );
  if ($ instanceof Ok) {
    let comparison_diagnostics$1 = $[0];
    let _block;
    let _pipe = submitted;
    let _pipe$1 = representation_diagnostics(_pipe, spec.representation);
    _block = $list.append(
      _pipe$1,
      precision_diagnostics(submitted, spec.precision),
    );
    let constraint_diagnostics = _block;
    return finalize(
      $list.append(comparison_diagnostics$1, constraint_diagnostics),
    );
  } else {
    let error = $[0];
    return new $types.InvalidConfig(error);
  }
}

/**
 * Precision counts are authored parameters. Significant figures cannot be zero,
 * while decimal-place rules can validly require exactly zero places.
 * 
 * @ignore
 */
function validate_precision(precision) {
  if (precision instanceof $types.NoPrecision) {
    return new Ok(undefined);
  } else if (precision instanceof $types.LegacySignificantFigures) {
    let count = precision.count;
    let $ = count > 0;
    if ($) {
      return new Ok(undefined);
    } else {
      return new Error(
        new $types.InvalidField("precision.count", "expected positive integer"),
      );
    }
  } else {
    let count = precision.count;
    let $ = count >= 0;
    if ($) {
      return new Ok(undefined);
    } else {
      return new Error(
        new $types.InvalidField(
          "precision.count",
          "expected non-negative integer",
        ),
      );
    }
  }
}

/**
 * Validate option parameters before reading the submitted answer so malformed
 * author configuration always reports as config failure, not learner failure.
 * JSON decoding catches shape errors; this protects hand-built Gleam specs too.
 * 
 * @ignore
 */
function validate_numeric_options(spec) {
  let $ = spec.tolerance;
  if ($ instanceof $types.NoTolerance) {
    return validate_precision(spec.precision);
  } else if ($ instanceof $types.AbsoluteTolerance) {
    let value = $.value;
    let $1 = value >= 0.0;
    if ($1) {
      return validate_precision(spec.precision);
    } else {
      return new Error(
        new $types.InvalidField(
          "tolerance.value",
          "expected non-negative float",
        ),
      );
    }
  } else if ($ instanceof $types.RelativeTolerance) {
    let value = $.value;
    let $1 = value >= 0.0;
    if ($1) {
      return validate_precision(spec.precision);
    } else {
      return new Error(
        new $types.InvalidField(
          "tolerance.value",
          "expected non-negative float",
        ),
      );
    }
  } else {
    let absolute = $.absolute;
    let relative = $.relative;
    let $1 = (absolute >= 0.0) && (relative >= 0.0);
    if ($1) {
      return validate_precision(spec.precision);
    } else {
      return new Error(
        new $types.InvalidField(
          "tolerance",
          "expected non-negative float values",
        ),
      );
    }
  }
}

/**
 * Evaluate the standard/basic page numeric comparison family. This is kept out
 * of the expression parser because Number inputs historically accept scalar
 * numeric answers, not full math expressions with variables or operators.
 */
export function evaluate(spec, submitted) {
  let $ = validate_numeric_options(spec);
  if ($ instanceof Ok) {
    let $1 = parse_number(submitted);
    if ($1 instanceof Ok) {
      let submitted_value = $1[0];
      return evaluate_supported_spec(spec, submitted, submitted_value);
    } else {
      return new $types.InvalidSubmittedAnswer(
        toList([new $types.NumericParseFailure()]),
      );
    }
  } else {
    let error = $[0];
    return new $types.InvalidConfig(error);
  }
}
