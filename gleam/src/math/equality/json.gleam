import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json as gleam_json
import gleam/list
import math/ast
import math/equality/evaluate
import math/equality/types

/// Decode the future `equalityConfig` JSON shape into the typed contract.
/// `gleam_json` owns JSON parsing here; this module owns only the Torus
/// equality-config semantics layered on top of that package.
pub fn decode_equality_config(
  source: String,
) -> Result(types.EqualitySpec, types.EqualityConfigError) {
  case gleam_json.parse(source, using: decode.dynamic) {
    Ok(dynamic) -> decode_spec(dynamic)
    Error(_) -> Error(types.InvalidJson(reason: "could not parse JSON"))
  }
}

/// Encode the typed equality config into the stable JSON field names that later
/// Response storage and cross-target fixtures will treat as the public contract.
pub fn encode_equality_config(spec: types.EqualitySpec) -> String {
  spec_to_json(spec)
  |> gleam_json.to_string
}

fn spec_to_json(spec: types.EqualitySpec) -> gleam_json.Json {
  case spec.mode {
    types.Numeric(numeric) ->
      gleam_json.object([
        #("version", gleam_json.int(spec.version)),
        #("mode", gleam_json.string("numeric")),
        #("comparison", numeric_comparison_to_json(numeric.comparison)),
        #("tolerance", tolerance_to_json(numeric.tolerance)),
        #("representation", representation_to_json(numeric.representation)),
        #("precision", precision_to_json(numeric.precision)),
      ])

    types.Expression(expression) ->
      gleam_json.object([
        #("version", gleam_json.int(spec.version)),
        #("mode", gleam_json.string("expression")),
        #("comparison", expression_comparison_to_json(expression.comparison)),
        #("validation", expression_validation_to_json(expression.validation)),
      ])

    types.UnitAware(unit) ->
      gleam_json.object([
        #("version", gleam_json.int(spec.version)),
        #("mode", gleam_json.string("unit_aware")),
        #("comparison", unit_comparison_to_json(unit.comparison)),
        #("policy", unit_policy_to_json(unit.policy)),
      ])
  }
}

fn numeric_comparison_to_json(
  comparison: types.NumericComparison,
) -> gleam_json.Json {
  case comparison {
    types.Equal(expected) ->
      gleam_json.object([
        #("type", gleam_json.string("equal")),
        #("expected", numeric_to_json(expected)),
      ])
    types.NotEqual(expected) ->
      gleam_json.object([
        #("type", gleam_json.string("not_equal")),
        #("expected", numeric_to_json(expected)),
      ])
    types.GreaterThan(threshold) ->
      gleam_json.object([
        #("type", gleam_json.string("greater_than")),
        #("threshold", numeric_to_json(threshold)),
      ])
    types.GreaterThanOrEqual(threshold) ->
      gleam_json.object([
        #("type", gleam_json.string("greater_than_or_equal")),
        #("threshold", numeric_to_json(threshold)),
      ])
    types.LessThan(threshold) ->
      gleam_json.object([
        #("type", gleam_json.string("less_than")),
        #("threshold", numeric_to_json(threshold)),
      ])
    types.LessThanOrEqual(threshold) ->
      gleam_json.object([
        #("type", gleam_json.string("less_than_or_equal")),
        #("threshold", numeric_to_json(threshold)),
      ])
    types.Between(lower, upper, bounds) ->
      range_json("between", lower, upper, bounds)
    types.NotBetween(lower, upper, bounds) ->
      range_json("not_between", lower, upper, bounds)
  }
}

fn range_json(
  kind: String,
  lower: types.NumericInput,
  upper: types.NumericInput,
  bounds: types.RangeBounds,
) -> gleam_json.Json {
  gleam_json.object([
    #("type", gleam_json.string(kind)),
    #("lower", numeric_to_json(lower)),
    #("upper", numeric_to_json(upper)),
    #("bounds", gleam_json.string(bounds_to_string(bounds))),
  ])
}

fn tolerance_to_json(tolerance: types.NumericTolerance) -> gleam_json.Json {
  case tolerance {
    types.NoTolerance ->
      gleam_json.object([#("type", gleam_json.string("none"))])
    types.AbsoluteTolerance(value) ->
      gleam_json.object([
        #("type", gleam_json.string("absolute")),
        #("value", gleam_json.float(value)),
      ])
    types.RelativeTolerance(value) ->
      gleam_json.object([
        #("type", gleam_json.string("relative")),
        #("value", gleam_json.float(value)),
      ])
    types.AbsoluteOrRelativeTolerance(absolute, relative) ->
      gleam_json.object([
        #("type", gleam_json.string("absolute_or_relative")),
        #("absolute", gleam_json.float(absolute)),
        #("relative", gleam_json.float(relative)),
      ])
  }
}

fn representation_to_json(
  representation: types.NumericRepresentation,
) -> gleam_json.Json {
  case representation {
    types.AnyRepresentation ->
      gleam_json.object([#("type", gleam_json.string("any"))])
    types.IntegerRepresentation ->
      gleam_json.object([#("type", gleam_json.string("integer"))])
    types.DecimalRepresentation ->
      gleam_json.object([#("type", gleam_json.string("decimal"))])
    types.ScientificRepresentation ->
      gleam_json.object([#("type", gleam_json.string("scientific"))])
  }
}

fn precision_to_json(precision: types.NumericPrecision) -> gleam_json.Json {
  case precision {
    types.NoPrecision ->
      gleam_json.object([#("type", gleam_json.string("none"))])
    types.LegacySignificantFigures(count) ->
      gleam_json.object([
        #("type", gleam_json.string("legacy_significant_figures")),
        #("count", gleam_json.int(count)),
      ])
    types.DecimalPlaces(rule, count) ->
      gleam_json.object([
        #("type", gleam_json.string("decimal_places")),
        #("rule", gleam_json.string(decimal_rule_to_string(rule))),
        #("count", gleam_json.int(count)),
      ])
  }
}

fn expression_comparison_to_json(
  comparison: types.ExpressionComparison,
) -> gleam_json.Json {
  case comparison {
    types.ExactExpression(expected) ->
      gleam_json.object([
        #("type", gleam_json.string("exact_expression")),
        #("expected", gleam_json.string(expected)),
      ])
    types.AlgebraicEquivalence(expected, sampling) ->
      gleam_json.object([
        #("type", gleam_json.string("algebraic_equivalence")),
        #("expected", gleam_json.string(expected)),
        #("sampling", sampling_to_json(sampling)),
      ])
  }
}

fn sampling_to_json(sampling: types.SamplingConfig) -> gleam_json.Json {
  gleam_json.object([
    #("seed", gleam_json.int(sampling.seed)),
    #("sampleCount", gleam_json.int(sampling.sample_count)),
  ])
}

fn expression_validation_to_json(
  validation: types.ExpressionValidation,
) -> gleam_json.Json {
  gleam_json.object([
    #("allowedVariables", string_array(validation.allowed_variables)),
    #(
      "allowedFunctions",
      string_array(list.map(validation.allowed_functions, function_to_string)),
    ),
    #("domains", json_array(validation.domains, domain_to_json)),
  ])
}

fn domain_to_json(domain: types.VariableDomain) -> gleam_json.Json {
  gleam_json.object([
    #("name", gleam_json.string(domain.name)),
    #("lower", gleam_json.float(domain.lower)),
    #("upper", gleam_json.float(domain.upper)),
  ])
}

fn unit_comparison_to_json(
  comparison: types.UnitComparison,
) -> gleam_json.Json {
  case comparison {
    types.UnitNumeric(expected_value, expected_unit) ->
      gleam_json.object([
        #("type", gleam_json.string("unit_numeric")),
        #("expectedValue", numeric_to_json(expected_value)),
        #("expectedUnit", gleam_json.string(expected_unit)),
      ])
    types.UnitExpression(expected_expression, expected_unit) ->
      gleam_json.object([
        #("type", gleam_json.string("unit_expression")),
        #("expectedExpression", gleam_json.string(expected_expression)),
        #("expectedUnit", gleam_json.string(expected_unit)),
      ])
  }
}

fn unit_policy_to_json(policy: types.UnitPolicy) -> gleam_json.Json {
  case policy {
    types.UnitsIgnored ->
      gleam_json.object([#("type", gleam_json.string("ignored"))])
    types.UnitsRequired ->
      gleam_json.object([#("type", gleam_json.string("required"))])
    types.AcceptedUnits(units) ->
      gleam_json.object([
        #("type", gleam_json.string("accepted_units")),
        #("units", string_array(units)),
      ])
    types.StrictUnit(unit) ->
      gleam_json.object([
        #("type", gleam_json.string("strict_unit")),
        #("unit", gleam_json.string(unit)),
      ])
    types.ConvertibleUnits(units) ->
      gleam_json.object([
        #("type", gleam_json.string("convertible_units")),
        #("units", string_array(units)),
      ])
  }
}

fn numeric_to_json(input: types.NumericInput) -> gleam_json.Json {
  gleam_json.string(input.raw)
}

fn string_array(values: List(String)) -> gleam_json.Json {
  gleam_json.array(values, of: gleam_json.string)
}

fn json_array(
  values: List(a),
  encoder: fn(a) -> gleam_json.Json,
) -> gleam_json.Json {
  gleam_json.preprocessed_array(list.map(values, encoder))
}

fn decode_spec(
  dynamic: Dynamic,
) -> Result(types.EqualitySpec, types.EqualityConfigError) {
  case read_int(dynamic, "version") {
    Error(error) -> Error(error)
    Ok(version) ->
      case evaluate.validate_spec(default_version_probe(version)) {
        Error(error) -> Error(error)
        Ok(_) -> decode_supported_spec(dynamic, version)
      }
  }
}

fn default_version_probe(version: Int) -> types.EqualitySpec {
  types.EqualitySpec(
    version: version,
    mode: types.Numeric(
      types.default_numeric_options(types.Equal(types.numeric_input("0"))),
    ),
  )
}

fn decode_supported_spec(
  dynamic: Dynamic,
  version: Int,
) -> Result(types.EqualitySpec, types.EqualityConfigError) {
  case read_string(dynamic, "mode") {
    Error(error) -> Error(error)
    Ok(mode) ->
      case mode {
        "numeric" -> decode_numeric_spec(dynamic, version)
        "expression" -> decode_expression_spec(dynamic, version)
        "unit_aware" -> decode_unit_spec(dynamic, version)
        other -> Error(types.UnknownDiscriminator(field: "mode", value: other))
      }
  }
}

fn decode_numeric_spec(
  dynamic: Dynamic,
  version: Int,
) -> Result(types.EqualitySpec, types.EqualityConfigError) {
  case read_dynamic(dynamic, "comparison") {
    Error(error) -> Error(error)
    Ok(comparison_dynamic) ->
      case decode_numeric_comparison(comparison_dynamic) {
        Error(error) -> Error(error)
        Ok(comparison) ->
          case decode_tolerance(dynamic) {
            Error(error) -> Error(error)
            Ok(tolerance) ->
              case decode_representation(dynamic) {
                Error(error) -> Error(error)
                Ok(representation) ->
                  case decode_precision(dynamic) {
                    Error(error) -> Error(error)
                    Ok(precision) ->
                      Ok(types.EqualitySpec(
                        version: version,
                        mode: types.Numeric(types.NumericSpec(
                          comparison: comparison,
                          tolerance: tolerance,
                          representation: representation,
                          precision: precision,
                        )),
                      ))
                  }
              }
          }
      }
  }
}

fn decode_numeric_comparison(
  dynamic: Dynamic,
) -> Result(types.NumericComparison, types.EqualityConfigError) {
  case read_string(dynamic, "type") {
    Error(error) -> Error(error)
    Ok(kind) ->
      case kind {
        "equal" -> decode_expected(dynamic, types.Equal)
        "not_equal" -> decode_expected(dynamic, types.NotEqual)
        "greater_than" -> decode_threshold(dynamic, types.GreaterThan)
        "greater_than_or_equal" ->
          decode_threshold(dynamic, types.GreaterThanOrEqual)
        "less_than" -> decode_threshold(dynamic, types.LessThan)
        "less_than_or_equal" -> decode_threshold(dynamic, types.LessThanOrEqual)
        "between" -> decode_range(dynamic, types.Between)
        "not_between" -> decode_range(dynamic, types.NotBetween)
        other ->
          Error(types.UnknownDiscriminator(
            field: "comparison.type",
            value: other,
          ))
      }
  }
}

fn decode_expected(
  dynamic: Dynamic,
  constructor: fn(types.NumericInput) -> types.NumericComparison,
) -> Result(types.NumericComparison, types.EqualityConfigError) {
  case read_string(dynamic, "expected") {
    Ok(raw) -> Ok(constructor(types.numeric_input(raw)))
    Error(error) -> Error(error)
  }
}

fn decode_threshold(
  dynamic: Dynamic,
  constructor: fn(types.NumericInput) -> types.NumericComparison,
) -> Result(types.NumericComparison, types.EqualityConfigError) {
  case read_string(dynamic, "threshold") {
    Ok(raw) -> Ok(constructor(types.numeric_input(raw)))
    Error(error) -> Error(error)
  }
}

fn decode_range(
  dynamic: Dynamic,
  constructor: fn(types.NumericInput, types.NumericInput, types.RangeBounds) ->
    types.NumericComparison,
) -> Result(types.NumericComparison, types.EqualityConfigError) {
  case read_string(dynamic, "lower") {
    Error(error) -> Error(error)
    Ok(lower) ->
      case read_string(dynamic, "upper") {
        Error(error) -> Error(error)
        Ok(upper) ->
          case read_string(dynamic, "bounds") {
            Error(error) -> Error(error)
            Ok(bounds) ->
              case bounds_from_string(bounds) {
                Ok(decoded_bounds) ->
                  Ok(constructor(
                    types.numeric_input(lower),
                    types.numeric_input(upper),
                    decoded_bounds,
                  ))
                Error(error) -> Error(error)
              }
          }
      }
  }
}

fn decode_tolerance(
  dynamic: Dynamic,
) -> Result(types.NumericTolerance, types.EqualityConfigError) {
  case read_dynamic(dynamic, "tolerance") {
    Error(error) -> Error(error)
    Ok(tolerance_dynamic) ->
      case read_string(tolerance_dynamic, "type") {
        Error(error) -> Error(error)
        Ok(kind) ->
          case kind {
            "none" -> Ok(types.NoTolerance)
            "absolute" ->
              decode_float_field(
                tolerance_dynamic,
                "value",
                types.AbsoluteTolerance,
              )
            "relative" ->
              decode_float_field(
                tolerance_dynamic,
                "value",
                types.RelativeTolerance,
              )
            "absolute_or_relative" ->
              decode_absolute_or_relative(tolerance_dynamic)
            other ->
              Error(types.UnknownDiscriminator(
                field: "tolerance.type",
                value: other,
              ))
          }
      }
  }
}

fn decode_absolute_or_relative(
  dynamic: Dynamic,
) -> Result(types.NumericTolerance, types.EqualityConfigError) {
  case read_float(dynamic, "absolute") {
    Error(error) -> Error(error)
    Ok(absolute) ->
      case read_float(dynamic, "relative") {
        Ok(relative) ->
          case absolute >=. 0.0 && relative >=. 0.0 {
            True ->
              Ok(types.AbsoluteOrRelativeTolerance(
                absolute: absolute,
                relative: relative,
              ))
            False ->
              Error(types.InvalidField(
                field: "tolerance",
                reason: "expected non-negative float values",
              ))
          }
        Error(error) -> Error(error)
      }
  }
}

fn decode_float_field(
  dynamic: Dynamic,
  field: String,
  constructor: fn(Float) -> types.NumericTolerance,
) -> Result(types.NumericTolerance, types.EqualityConfigError) {
  case read_float(dynamic, field) {
    Ok(value) ->
      case value >=. 0.0 {
        True -> Ok(constructor(value))
        False ->
          Error(types.InvalidField(
            field: "tolerance." <> field,
            reason: "expected non-negative float",
          ))
      }
    Error(error) -> Error(error)
  }
}

fn decode_representation(
  dynamic: Dynamic,
) -> Result(types.NumericRepresentation, types.EqualityConfigError) {
  case read_dynamic(dynamic, "representation") {
    Error(error) -> Error(error)
    Ok(representation_dynamic) ->
      case read_string(representation_dynamic, "type") {
        Error(error) -> Error(error)
        Ok(kind) ->
          case kind {
            "any" -> Ok(types.AnyRepresentation)
            "integer" -> Ok(types.IntegerRepresentation)
            "decimal" -> Ok(types.DecimalRepresentation)
            "scientific" -> Ok(types.ScientificRepresentation)
            other ->
              Error(types.UnknownDiscriminator(
                field: "representation.type",
                value: other,
              ))
          }
      }
  }
}

fn decode_precision(
  dynamic: Dynamic,
) -> Result(types.NumericPrecision, types.EqualityConfigError) {
  case read_dynamic(dynamic, "precision") {
    Error(error) -> Error(error)
    Ok(precision_dynamic) ->
      case read_string(precision_dynamic, "type") {
        Error(error) -> Error(error)
        Ok(kind) ->
          case kind {
            "none" -> Ok(types.NoPrecision)
            "legacy_significant_figures" ->
              case read_int(precision_dynamic, "count") {
                Ok(count) ->
                  case count > 0 {
                    True -> Ok(types.LegacySignificantFigures(count: count))
                    False ->
                      Error(types.InvalidField(
                        field: "precision.count",
                        reason: "expected positive integer",
                      ))
                  }
                Error(error) -> Error(error)
              }
            "decimal_places" -> decode_decimal_places(precision_dynamic)
            other ->
              Error(types.UnknownDiscriminator(
                field: "precision.type",
                value: other,
              ))
          }
      }
  }
}

fn decode_decimal_places(
  dynamic: Dynamic,
) -> Result(types.NumericPrecision, types.EqualityConfigError) {
  case read_string(dynamic, "rule") {
    Error(error) -> Error(error)
    Ok(rule) ->
      case decimal_rule_from_string(rule) {
        Error(error) -> Error(error)
        Ok(decoded_rule) ->
          case read_int(dynamic, "count") {
            Ok(count) ->
              case count >= 0 {
                True ->
                  Ok(types.DecimalPlaces(rule: decoded_rule, count: count))
                False ->
                  Error(types.InvalidField(
                    field: "precision.count",
                    reason: "expected non-negative integer",
                  ))
              }
            Error(error) -> Error(error)
          }
      }
  }
}

fn decode_expression_spec(
  dynamic: Dynamic,
  version: Int,
) -> Result(types.EqualitySpec, types.EqualityConfigError) {
  case read_dynamic(dynamic, "comparison") {
    Error(error) -> Error(error)
    Ok(comparison_dynamic) ->
      case decode_expression_comparison(comparison_dynamic) {
        Error(error) -> Error(error)
        Ok(comparison) ->
          case read_dynamic(dynamic, "validation") {
            Error(error) -> Error(error)
            Ok(validation_dynamic) ->
              case decode_expression_validation(validation_dynamic) {
                Ok(validation) ->
                  Ok(types.EqualitySpec(
                    version: version,
                    mode: types.Expression(types.ExpressionSpec(
                      comparison: comparison,
                      validation: validation,
                    )),
                  ))
                Error(error) -> Error(error)
              }
          }
      }
  }
}

fn decode_expression_comparison(
  dynamic: Dynamic,
) -> Result(types.ExpressionComparison, types.EqualityConfigError) {
  case read_string(dynamic, "type") {
    Error(error) -> Error(error)
    Ok(kind) ->
      case kind {
        "exact_expression" ->
          case read_string(dynamic, "expected") {
            Ok(expected) -> Ok(types.ExactExpression(expected: expected))
            Error(error) -> Error(error)
          }
        "algebraic_equivalence" ->
          case read_string(dynamic, "expected") {
            Error(error) -> Error(error)
            Ok(expected) ->
              case read_dynamic(dynamic, "sampling") {
                Error(error) -> Error(error)
                Ok(sampling_dynamic) ->
                  case decode_sampling(sampling_dynamic) {
                    Ok(sampling) ->
                      Ok(types.AlgebraicEquivalence(
                        expected: expected,
                        sampling: sampling,
                      ))
                    Error(error) -> Error(error)
                  }
              }
          }
        other ->
          Error(types.UnknownDiscriminator(
            field: "comparison.type",
            value: other,
          ))
      }
  }
}

fn decode_sampling(
  dynamic: Dynamic,
) -> Result(types.SamplingConfig, types.EqualityConfigError) {
  case read_int(dynamic, "seed") {
    Error(error) -> Error(error)
    Ok(seed) ->
      case read_int(dynamic, "sampleCount") {
        Ok(sample_count) ->
          case sample_count > 0 {
            True ->
              Ok(types.SamplingConfig(seed: seed, sample_count: sample_count))
            False ->
              Error(types.InvalidField(
                field: "comparison.sampling.sampleCount",
                reason: "expected positive integer",
              ))
          }
        Error(error) -> Error(error)
      }
  }
}

fn decode_expression_validation(
  dynamic: Dynamic,
) -> Result(types.ExpressionValidation, types.EqualityConfigError) {
  case read_string_list(dynamic, "allowedVariables") {
    Error(error) -> Error(error)
    Ok(allowed_variables) ->
      case read_string_list(dynamic, "allowedFunctions") {
        Error(error) -> Error(error)
        Ok(raw_functions) ->
          case decode_functions(raw_functions) {
            Error(error) -> Error(error)
            Ok(allowed_functions) ->
              case read_dynamic_list(dynamic, "domains") {
                Error(error) -> Error(error)
                Ok(domain_values) ->
                  case decode_domains(domain_values, []) {
                    Ok(domains) ->
                      Ok(types.ExpressionValidation(
                        allowed_variables: allowed_variables,
                        allowed_functions: allowed_functions,
                        domains: domains,
                      ))
                    Error(error) -> Error(error)
                  }
              }
          }
      }
  }
}

fn decode_functions(
  raw_functions: List(String),
) -> Result(List(ast.FunctionName), types.EqualityConfigError) {
  decode_functions_loop(raw_functions, [])
}

fn decode_functions_loop(
  raw_functions: List(String),
  acc: List(ast.FunctionName),
) -> Result(List(ast.FunctionName), types.EqualityConfigError) {
  case raw_functions {
    [] -> Ok(list.reverse(acc))
    [first, ..rest] ->
      case function_from_string(first) {
        Ok(name) -> decode_functions_loop(rest, [name, ..acc])
        Error(error) -> Error(error)
      }
  }
}

fn decode_domains(
  values: List(Dynamic),
  acc: List(types.VariableDomain),
) -> Result(List(types.VariableDomain), types.EqualityConfigError) {
  case values {
    [] -> Ok(list.reverse(acc))
    [first, ..rest] ->
      case decode_domain(first) {
        Ok(domain) -> decode_domains(rest, [domain, ..acc])
        Error(error) -> Error(error)
      }
  }
}

fn decode_domain(
  dynamic: Dynamic,
) -> Result(types.VariableDomain, types.EqualityConfigError) {
  case read_string(dynamic, "name") {
    Error(error) -> Error(error)
    Ok(name) ->
      case read_float(dynamic, "lower") {
        Error(error) -> Error(error)
        Ok(lower) ->
          case read_float(dynamic, "upper") {
            Ok(upper) ->
              Ok(types.VariableDomain(name: name, lower: lower, upper: upper))
            Error(error) -> Error(error)
          }
      }
  }
}

fn decode_unit_spec(
  dynamic: Dynamic,
  version: Int,
) -> Result(types.EqualitySpec, types.EqualityConfigError) {
  case read_dynamic(dynamic, "comparison") {
    Error(error) -> Error(error)
    Ok(comparison_dynamic) ->
      case decode_unit_comparison(comparison_dynamic) {
        Error(error) -> Error(error)
        Ok(comparison) ->
          case read_dynamic(dynamic, "policy") {
            Error(error) -> Error(error)
            Ok(policy_dynamic) ->
              case decode_unit_policy(policy_dynamic) {
                Ok(policy) ->
                  Ok(types.EqualitySpec(
                    version: version,
                    mode: types.UnitAware(types.UnitSpec(
                      comparison: comparison,
                      policy: policy,
                    )),
                  ))
                Error(error) -> Error(error)
              }
          }
      }
  }
}

fn decode_unit_comparison(
  dynamic: Dynamic,
) -> Result(types.UnitComparison, types.EqualityConfigError) {
  case read_string(dynamic, "type") {
    Error(error) -> Error(error)
    Ok(kind) ->
      case kind {
        "unit_numeric" ->
          case read_string(dynamic, "expectedValue") {
            Error(error) -> Error(error)
            Ok(expected_value) ->
              case read_string(dynamic, "expectedUnit") {
                Ok(expected_unit) ->
                  Ok(types.UnitNumeric(
                    expected_value: types.numeric_input(expected_value),
                    expected_unit: expected_unit,
                  ))
                Error(error) -> Error(error)
              }
          }
        "unit_expression" ->
          case read_string(dynamic, "expectedExpression") {
            Error(error) -> Error(error)
            Ok(expected_expression) ->
              case read_string(dynamic, "expectedUnit") {
                Ok(expected_unit) ->
                  Ok(types.UnitExpression(
                    expected_expression: expected_expression,
                    expected_unit: expected_unit,
                  ))
                Error(error) -> Error(error)
              }
          }
        other ->
          Error(types.UnknownDiscriminator(
            field: "comparison.type",
            value: other,
          ))
      }
  }
}

fn decode_unit_policy(
  dynamic: Dynamic,
) -> Result(types.UnitPolicy, types.EqualityConfigError) {
  case read_string(dynamic, "type") {
    Error(error) -> Error(error)
    Ok(kind) ->
      case kind {
        "ignored" -> Ok(types.UnitsIgnored)
        "required" -> Ok(types.UnitsRequired)
        "accepted_units" -> decode_unit_list(dynamic, types.AcceptedUnits)
        "strict_unit" ->
          case read_string(dynamic, "unit") {
            Ok(unit) -> Ok(types.StrictUnit(unit: unit))
            Error(error) -> Error(error)
          }
        "convertible_units" -> decode_unit_list(dynamic, types.ConvertibleUnits)
        other ->
          Error(types.UnknownDiscriminator(field: "policy.type", value: other))
      }
  }
}

fn decode_unit_list(
  dynamic: Dynamic,
  constructor: fn(List(String)) -> types.UnitPolicy,
) -> Result(types.UnitPolicy, types.EqualityConfigError) {
  case read_string_list(dynamic, "units") {
    Ok(units) -> Ok(constructor(units))
    Error(error) -> Error(error)
  }
}

fn read_dynamic(
  dynamic: Dynamic,
  field: String,
) -> Result(Dynamic, types.EqualityConfigError) {
  read_field(dynamic, field, decode.dynamic, expected: "value")
}

fn read_string(
  dynamic: Dynamic,
  field: String,
) -> Result(String, types.EqualityConfigError) {
  read_field(dynamic, field, decode.string, expected: "string")
}

fn read_int(
  dynamic: Dynamic,
  field: String,
) -> Result(Int, types.EqualityConfigError) {
  read_field(dynamic, field, decode.int, expected: "integer")
}

fn read_float(
  dynamic: Dynamic,
  field: String,
) -> Result(Float, types.EqualityConfigError) {
  read_field(
    dynamic,
    field,
    decode.one_of(decode.float, or: [decode.int |> decode.map(int.to_float)]),
    expected: "number",
  )
}

fn read_string_list(
  dynamic: Dynamic,
  field: String,
) -> Result(List(String), types.EqualityConfigError) {
  read_field(
    dynamic,
    field,
    decode.list(of: decode.string),
    expected: "string array",
  )
}

fn read_dynamic_list(
  dynamic: Dynamic,
  field: String,
) -> Result(List(Dynamic), types.EqualityConfigError) {
  read_field(dynamic, field, decode.list(of: decode.dynamic), expected: "array")
}

/// All field reads go through `gleam/dynamic/decode` so JSON structure handling
/// is delegated to the library while Torus still maps failures into stable
/// equality-config error variants.
fn read_field(
  dynamic: Dynamic,
  field: String,
  decoder: decode.Decoder(a),
  expected expected: String,
) -> Result(a, types.EqualityConfigError) {
  case decode.run(dynamic, decode.field(field, decoder, decode.success)) {
    Ok(value) -> Ok(value)
    Error(errors) -> Error(field_error(field, expected, errors))
  }
}

fn field_error(
  field: String,
  expected: String,
  errors: List(decode.DecodeError),
) -> types.EqualityConfigError {
  case list.any(errors, fn(error) { error.found == "Nothing" }) {
    True -> types.MissingField(field: field)
    False -> types.InvalidField(field: field, reason: "expected " <> expected)
  }
}

fn bounds_to_string(bounds: types.RangeBounds) -> String {
  case bounds {
    types.Inclusive -> "inclusive"
    types.Exclusive -> "exclusive"
  }
}

fn bounds_from_string(
  bounds: String,
) -> Result(types.RangeBounds, types.EqualityConfigError) {
  case bounds {
    "inclusive" -> Ok(types.Inclusive)
    "exclusive" -> Ok(types.Exclusive)
    other ->
      Error(types.UnknownDiscriminator(field: "comparison.bounds", value: other))
  }
}

fn decimal_rule_to_string(rule: types.DecimalPlaceRule) -> String {
  case rule {
    types.Exactly -> "exactly"
    types.AtLeast -> "at_least"
    types.AtMost -> "at_most"
  }
}

fn decimal_rule_from_string(
  rule: String,
) -> Result(types.DecimalPlaceRule, types.EqualityConfigError) {
  case rule {
    "exactly" -> Ok(types.Exactly)
    "at_least" -> Ok(types.AtLeast)
    "at_most" -> Ok(types.AtMost)
    other ->
      Error(types.UnknownDiscriminator(field: "precision.rule", value: other))
  }
}

fn function_to_string(name: ast.FunctionName) -> String {
  case name {
    ast.Sin -> "sin"
    ast.Cos -> "cos"
    ast.Tan -> "tan"
    ast.Ln -> "ln"
    ast.Log -> "log"
    ast.Log10 -> "log10"
    ast.Log2 -> "log2"
    ast.Sqrt -> "sqrt"
    ast.Abs -> "abs"
    ast.Exp -> "exp"
  }
}

fn function_from_string(
  raw: String,
) -> Result(ast.FunctionName, types.EqualityConfigError) {
  case raw {
    "sin" -> Ok(ast.Sin)
    "cos" -> Ok(ast.Cos)
    "tan" -> Ok(ast.Tan)
    "ln" -> Ok(ast.Ln)
    "log" -> Ok(ast.Log)
    "log10" -> Ok(ast.Log10)
    "log2" -> Ok(ast.Log2)
    "sqrt" -> Ok(ast.Sqrt)
    "abs" -> Ok(ast.Abs)
    "exp" -> Ok(ast.Exp)
    other ->
      Error(types.UnknownDiscriminator(
        field: "allowedFunctions[]",
        value: other,
      ))
  }
}
