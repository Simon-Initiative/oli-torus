import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/json as gleam_json
import gleam/list
import gleam/option.{type Option, None, Some}
import math/equality/algebraic_types
import math/equality/form_types
import math/equality/types as equality_types
import math/match/evaluate
import math/match/types
import math/sampling/sample
import math/sampling/types as sampling_types
import math/units/types as unit_types

pub fn decode_match_config(
  source: String,
) -> Result(types.MatchConfig, types.MatchConfigError) {
  case gleam_json.parse(source, using: decode.dynamic) {
    Ok(dynamic) -> decode_config(dynamic)
    Error(_) -> Error(types.InvalidJson(reason: "could not parse JSON"))
  }
}

pub fn encode_match_config(config: types.MatchConfig) -> String {
  config_to_json(config)
  |> gleam_json.to_string
}

fn config_to_json(config: types.MatchConfig) -> gleam_json.Json {
  case config.matcher {
    types.Always ->
      gleam_json.object([
        #("version", gleam_json.int(config.version)),
        #("type", gleam_json.string("always")),
      ])

    types.MathExpression(math) ->
      gleam_json.object([
        #("version", gleam_json.int(config.version)),
        #("type", gleam_json.string("math_expression")),
        #("math", math_to_json(math)),
      ])
  }
}

fn math_to_json(spec: types.MathExpressionSpec) -> gleam_json.Json {
  case spec {
    types.Numeric(numeric) -> numeric_to_json(numeric)
    types.LatexDirect(expected) ->
      gleam_json.object([
        #("mode", gleam_json.string("latex_direct")),
        #("expected", gleam_json.string(expected)),
      ])
    types.AlgebraicEquivalence(expected, equivalence, form, expression_match) ->
      algebraic_to_json(expected, equivalence, form, expression_match)
    types.UnitAware(
      expected,
      config,
      tolerance,
      equivalence,
      match_wrong_units,
      match_missing_unit,
      expression_match,
    ) -> {
      let fields = [
        #("mode", gleam_json.string("unit_aware")),
        #("expected", gleam_json.string(expected)),
        #("unitPolicy", unit_policy_to_json(config)),
        #("tolerance", tolerance_to_json(tolerance)),
      ]

      let fields = case match_wrong_units {
        False -> fields
        True ->
          list.append(fields, [
            #("matchWrongUnits", gleam_json.bool(True)),
          ])
      }

      let fields = case match_missing_unit {
        False -> fields
        True ->
          list.append(fields, [
            #("matchMissingUnit", gleam_json.bool(True)),
          ])
      }

      let fields = case equivalence {
        None -> fields
        Some(equivalence) ->
          fields
          |> append_validation_if_needed(equivalence)
          |> append_sampling_if_needed(equivalence)
      }

      let fields = encode_expression_match_policy(fields, expression_match)

      gleam_json.object(fields)
    }
  }
}

fn numeric_to_json(spec: equality_types.NumericSpec) -> gleam_json.Json {
  let fields = [
    #("mode", gleam_json.string("numeric")),
    #("operator", gleam_json.string(numeric_operator(spec.comparison))),
    #("tolerance", numeric_tolerance_to_json(spec.tolerance)),
    #("representation", representation_to_json(spec.representation)),
    #("precision", numeric_precision_to_json(spec.precision)),
  ]

  comparison_fields(spec.comparison)
  |> list.append(fields)
  |> gleam_json.object
}

fn comparison_fields(
  comparison: equality_types.NumericComparison,
) -> List(#(String, gleam_json.Json)) {
  case comparison {
    equality_types.Equal(expected) | equality_types.NotEqual(expected) -> [
      #("expected", gleam_json.string(expected.raw)),
    ]
    equality_types.GreaterThan(threshold)
    | equality_types.GreaterThanOrEqual(threshold)
    | equality_types.LessThan(threshold)
    | equality_types.LessThanOrEqual(threshold) -> [
      #("threshold", gleam_json.string(threshold.raw)),
    ]
    equality_types.Between(lower, upper, bounds)
    | equality_types.NotBetween(lower, upper, bounds) -> [
      #("lower", gleam_json.string(lower.raw)),
      #("upper", gleam_json.string(upper.raw)),
      #("bounds", gleam_json.string(bounds_to_string(bounds))),
    ]
  }
}

fn algebraic_to_json(
  expected: String,
  equivalence: algebraic_types.AlgebraicEquivalenceConfig,
  form,
  expression_match: types.ExpressionMatchPolicy,
) -> gleam_json.Json {
  let fields = [
    #("mode", gleam_json.string("algebraic_equivalence")),
    #("expected", gleam_json.string(expected)),
  ]

  let fields = case should_encode_validation(equivalence) {
    False -> fields
    True ->
      list.append(fields, [#("validation", validation_to_json(equivalence))])
  }

  let fields = case should_encode_sampling(equivalence) {
    False -> fields
    True ->
      list.append(fields, [
        #("sampling", sampling_to_json(equivalence.sampling)),
      ])
  }

  let fields = encode_expression_match_policy(fields, expression_match)

  case form {
    None -> gleam_json.object(fields)
    Some(config) ->
      gleam_json.object(list.append(fields, [#("form", form_to_json(config))]))
  }
}

fn encode_expression_match_policy(
  fields: List(#(String, gleam_json.Json)),
  policy: types.ExpressionMatchPolicy,
) -> List(#(String, gleam_json.Json)) {
  case policy {
    types.AllowEquivalent -> fields
    types.MatchExact ->
      list.append(fields, [
        #("expressionMatch", gleam_json.string("exact")),
      ])
  }
}

fn should_encode_validation(
  equivalence: algebraic_types.AlgebraicEquivalenceConfig,
) -> Bool {
  case equivalence.allowed_variables, equivalence.domains.variables {
    algebraic_types.InferFromExpected, [] -> False
    _, _ -> True
  }
}

fn should_encode_sampling(
  equivalence: algebraic_types.AlgebraicEquivalenceConfig,
) -> Bool {
  let base = algebraic_types.default_algebraic_equivalence_config()
  equivalence.sampling != base.sampling
}

fn append_validation_if_needed(
  fields: List(#(String, gleam_json.Json)),
  equivalence: algebraic_types.AlgebraicEquivalenceConfig,
) -> List(#(String, gleam_json.Json)) {
  case should_encode_validation(equivalence) {
    False -> fields
    True ->
      list.append(fields, [#("validation", validation_to_json(equivalence))])
  }
}

fn append_sampling_if_needed(
  fields: List(#(String, gleam_json.Json)),
  equivalence: algebraic_types.AlgebraicEquivalenceConfig,
) -> List(#(String, gleam_json.Json)) {
  case should_encode_sampling(equivalence) {
    False -> fields
    True ->
      list.append(fields, [
        #("sampling", sampling_to_json(equivalence.sampling)),
      ])
  }
}

fn validation_to_json(
  equivalence: algebraic_types.AlgebraicEquivalenceConfig,
) -> gleam_json.Json {
  let allowed_variables = case equivalence.allowed_variables {
    algebraic_types.InferFromExpected -> []
    algebraic_types.ExplicitAllowedVariables(names) -> names
  }

  let fields = [#("allowedVariables", string_array(allowed_variables))]

  case equivalence.domains.variables {
    [] -> gleam_json.object(fields)
    domains ->
      gleam_json.object(
        list.append(fields, [
          #("domains", json_array(domains, domain_to_json)),
        ]),
      )
  }
}

fn sampling_to_json(
  sampling: sampling_types.SamplingConfig,
) -> gleam_json.Json {
  gleam_json.object([
    #("seed", gleam_json.int(sampling.seed)),
    #("desiredCount", gleam_json.int(sampling.desired_count)),
    #("maxAttempts", gleam_json.int(sampling.max_attempts)),
    #("includeSpecialPoints", gleam_json.bool(sampling.include_special_points)),
  ])
}

fn domain_to_json(domain: sampling_types.VariableDomain) -> gleam_json.Json {
  gleam_json.object([
    #("name", gleam_json.string(domain.name)),
    #("lower", gleam_json.float(bound_value(domain.lower))),
    #("lowerInclusive", gleam_json.bool(bound_inclusive(domain.lower))),
    #("upper", gleam_json.float(bound_value(domain.upper))),
    #("upperInclusive", gleam_json.bool(bound_inclusive(domain.upper))),
    #("exclusions", float_array(domain.exclusions)),
    #("integerOnly", gleam_json.bool(domain.integer_only)),
    #("preferredValues", float_array(domain.preferred_values)),
  ])
}

fn bound_value(bound: sampling_types.Bound) -> Float {
  case bound {
    sampling_types.Inclusive(value) | sampling_types.Exclusive(value) -> value
  }
}

fn bound_inclusive(bound: sampling_types.Bound) -> Bool {
  case bound {
    sampling_types.Inclusive(_) -> True
    sampling_types.Exclusive(_) -> False
  }
}

fn form_to_json(config: form_types.ExactFormConfig) -> gleam_json.Json {
  case config {
    form_types.NoFormConstraint ->
      gleam_json.object([#("type", gleam_json.string("none"))])
    form_types.RequireInteger ->
      gleam_json.object([#("type", gleam_json.string("integer"))])
    form_types.RequireFraction ->
      gleam_json.object([#("type", gleam_json.string("fraction"))])
    form_types.RequireSimplifiedFraction ->
      gleam_json.object([#("type", gleam_json.string("simplified_fraction"))])
    form_types.RequireDecimal(precision) ->
      gleam_json.object([
        #("type", gleam_json.string("decimal")),
        #("precision", decimal_precision_to_json(precision)),
      ])
  }
}

fn decimal_precision_to_json(
  precision: form_types.DecimalPrecisionConstraint,
) -> gleam_json.Json {
  case precision {
    form_types.AnyDecimalPlaces ->
      gleam_json.object([#("type", gleam_json.string("any"))])
    form_types.DecimalPlaces(rule, count) ->
      gleam_json.object([
        #("type", gleam_json.string("decimal_places")),
        #("rule", gleam_json.string(decimal_rule_to_string(rule))),
        #("count", gleam_json.int(count)),
      ])
  }
}

fn unit_policy_to_json(config: unit_types.UnitConfig) -> gleam_json.Json {
  case config.mode {
    unit_types.IgnoreUnits ->
      gleam_json.object([#("type", gleam_json.string("ignored"))])
    unit_types.RequireUnits ->
      case config.conversion, config.final_unit, config.accepted_units {
        unit_types.AllowConversion, unit_types.AnyAcceptedUnit, units ->
          gleam_json.object([
            #("type", gleam_json.string("convertible_units")),
            #("units", string_array(units)),
          ])
        unit_types.DisallowConversion, unit_types.AnyAcceptedUnit, units ->
          gleam_json.object([
            #("type", gleam_json.string("accepted_units")),
            #("units", string_array(units)),
          ])
        _, unit_types.StrictAcceptedUnit, [unit] ->
          gleam_json.object([
            #("type", gleam_json.string("strict_unit")),
            #("unit", gleam_json.string(unit)),
          ])
        _, _, units ->
          gleam_json.object([
            #("type", gleam_json.string("accepted_units")),
            #("units", string_array(units)),
          ])
      }
  }
}

fn string_array(values: List(String)) -> gleam_json.Json {
  gleam_json.array(values, of: gleam_json.string)
}

fn float_array(values: List(Float)) -> gleam_json.Json {
  gleam_json.array(values, of: gleam_json.float)
}

fn json_array(
  values: List(a),
  encoder: fn(a) -> gleam_json.Json,
) -> gleam_json.Json {
  gleam_json.preprocessed_array(list.map(values, encoder))
}

fn decode_config(
  dynamic: Dynamic,
) -> Result(types.MatchConfig, types.MatchConfigError) {
  case read_int(dynamic, "version") {
    Error(error) -> Error(error)
    Ok(version) ->
      case evaluate.validate_config(default_version_probe(version)) {
        Error(error) -> Error(error)
        Ok(_) -> decode_supported_config(dynamic, version)
      }
  }
}

fn default_version_probe(version: Int) -> types.MatchConfig {
  types.MatchConfig(version: version, matcher: types.Always)
}

fn decode_supported_config(
  dynamic: Dynamic,
  version: Int,
) -> Result(types.MatchConfig, types.MatchConfigError) {
  case read_string(dynamic, "type") {
    Error(error) -> Error(error)
    Ok(kind) ->
      case kind {
        "always" ->
          Ok(types.MatchConfig(version: version, matcher: types.Always))
        "math_expression" -> decode_math_expression(dynamic, version)
        other -> Error(types.UnknownDiscriminator(field: "type", value: other))
      }
  }
}

fn decode_math_expression(
  dynamic: Dynamic,
  version: Int,
) -> Result(types.MatchConfig, types.MatchConfigError) {
  case read_dynamic(dynamic, "math") {
    Error(error) -> Error(error)
    Ok(math_dynamic) ->
      case decode_math_spec(math_dynamic) {
        Ok(spec) ->
          Ok(types.MatchConfig(
            version: version,
            matcher: types.MathExpression(spec),
          ))
        Error(error) -> Error(error)
      }
  }
}

fn decode_math_spec(
  dynamic: Dynamic,
) -> Result(types.MathExpressionSpec, types.MatchConfigError) {
  case read_string(dynamic, "mode") {
    Error(error) -> Error(error)
    Ok(mode) ->
      case mode {
        "numeric" -> decode_numeric_spec(dynamic)
        "latex_direct" -> decode_latex_direct(dynamic)
        "algebraic_equivalence" -> decode_algebraic(dynamic)
        "unit_aware" -> decode_unit_aware(dynamic)
        other ->
          Error(types.UnknownDiscriminator(field: "math.mode", value: other))
      }
  }
}

fn decode_numeric_spec(
  dynamic: Dynamic,
) -> Result(types.MathExpressionSpec, types.MatchConfigError) {
  case decode_numeric_comparison(dynamic) {
    Error(error) -> Error(error)
    Ok(comparison) -> {
      let tolerance = decode_optional_numeric_tolerance(dynamic)
      let representation = decode_optional_representation(dynamic)
      let precision = decode_optional_numeric_precision(dynamic)

      case tolerance, representation, precision {
        Ok(tolerance), Ok(representation), Ok(precision) ->
          Ok(
            types.Numeric(equality_types.NumericSpec(
              comparison: comparison,
              tolerance: tolerance,
              representation: representation,
              precision: precision,
            )),
          )
        Error(error), _, _ | _, Error(error), _ | _, _, Error(error) ->
          Error(error)
      }
    }
  }
}

fn decode_numeric_comparison(
  dynamic: Dynamic,
) -> Result(equality_types.NumericComparison, types.MatchConfigError) {
  case read_string(dynamic, "operator") {
    Error(error) -> Error(error)
    Ok(operator) ->
      case operator {
        "equal" -> decode_expected(dynamic, equality_types.Equal)
        "not_equal" -> decode_expected(dynamic, equality_types.NotEqual)
        "greater_than" -> decode_threshold(dynamic, equality_types.GreaterThan)
        "greater_than_or_equal" ->
          decode_threshold(dynamic, equality_types.GreaterThanOrEqual)
        "less_than" -> decode_threshold(dynamic, equality_types.LessThan)
        "less_than_or_equal" ->
          decode_threshold(dynamic, equality_types.LessThanOrEqual)
        "between" -> decode_range(dynamic, equality_types.Between)
        "not_between" -> decode_range(dynamic, equality_types.NotBetween)
        other ->
          Error(types.UnknownDiscriminator(field: "math.operator", value: other))
      }
  }
}

fn decode_expected(
  dynamic: Dynamic,
  constructor: fn(equality_types.NumericInput) ->
    equality_types.NumericComparison,
) -> Result(equality_types.NumericComparison, types.MatchConfigError) {
  case read_string(dynamic, "expected") {
    Ok(raw) -> Ok(constructor(equality_types.numeric_input(raw)))
    Error(error) -> Error(error)
  }
}

fn decode_threshold(
  dynamic: Dynamic,
  constructor: fn(equality_types.NumericInput) ->
    equality_types.NumericComparison,
) -> Result(equality_types.NumericComparison, types.MatchConfigError) {
  case read_string(dynamic, "threshold") {
    Ok(raw) -> Ok(constructor(equality_types.numeric_input(raw)))
    Error(error) -> Error(error)
  }
}

fn decode_range(
  dynamic: Dynamic,
  constructor: fn(
    equality_types.NumericInput,
    equality_types.NumericInput,
    equality_types.RangeBounds,
  ) -> equality_types.NumericComparison,
) -> Result(equality_types.NumericComparison, types.MatchConfigError) {
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
                    equality_types.numeric_input(lower),
                    equality_types.numeric_input(upper),
                    decoded_bounds,
                  ))
                Error(error) -> Error(error)
              }
          }
      }
  }
}

fn decode_optional_numeric_tolerance(
  dynamic: Dynamic,
) -> Result(equality_types.NumericTolerance, types.MatchConfigError) {
  case read_optional_dynamic(dynamic, "tolerance") {
    Error(error) -> Error(error)
    Ok(None) -> Ok(equality_types.NoTolerance)
    Ok(Some(tolerance_dynamic)) ->
      case read_string(tolerance_dynamic, "type") {
        Error(error) -> Error(error)
        Ok(kind) ->
          case kind {
            "none" -> Ok(equality_types.NoTolerance)
            "absolute" ->
              decode_numeric_float_field(
                tolerance_dynamic,
                "value",
                equality_types.AbsoluteTolerance,
              )
            "relative" ->
              decode_numeric_float_field(
                tolerance_dynamic,
                "value",
                equality_types.RelativeTolerance,
              )
            "absolute_or_relative" ->
              decode_numeric_absolute_or_relative(tolerance_dynamic)
            other ->
              Error(types.UnknownDiscriminator(
                field: "math.tolerance.type",
                value: other,
              ))
          }
      }
  }
}

fn decode_numeric_absolute_or_relative(
  dynamic: Dynamic,
) -> Result(equality_types.NumericTolerance, types.MatchConfigError) {
  case read_float(dynamic, "absolute") {
    Error(error) -> Error(error)
    Ok(absolute) ->
      case read_float(dynamic, "relative") {
        Ok(relative) ->
          case absolute >=. 0.0 && relative >=. 0.0 {
            True ->
              Ok(equality_types.AbsoluteOrRelativeTolerance(
                absolute: absolute,
                relative: relative,
              ))
            False ->
              Error(types.InvalidField(
                field: "math.tolerance",
                reason: "expected non-negative float values",
              ))
          }
        Error(error) -> Error(error)
      }
  }
}

fn decode_numeric_float_field(
  dynamic: Dynamic,
  field: String,
  constructor: fn(Float) -> equality_types.NumericTolerance,
) -> Result(equality_types.NumericTolerance, types.MatchConfigError) {
  case read_float(dynamic, field) {
    Ok(value) ->
      case value >=. 0.0 {
        True -> Ok(constructor(value))
        False ->
          Error(types.InvalidField(
            field: "math.tolerance." <> field,
            reason: "expected non-negative float",
          ))
      }
    Error(error) -> Error(error)
  }
}

fn decode_optional_representation(
  dynamic: Dynamic,
) -> Result(equality_types.NumericRepresentation, types.MatchConfigError) {
  case read_optional_dynamic(dynamic, "representation") {
    Error(error) -> Error(error)
    Ok(None) -> Ok(equality_types.AnyRepresentation)
    Ok(Some(representation_dynamic)) ->
      case read_string(representation_dynamic, "type") {
        Error(error) -> Error(error)
        Ok(kind) ->
          case kind {
            "any" -> Ok(equality_types.AnyRepresentation)
            "integer" -> Ok(equality_types.IntegerRepresentation)
            "decimal" -> Ok(equality_types.DecimalRepresentation)
            "scientific" -> Ok(equality_types.ScientificRepresentation)
            other ->
              Error(types.UnknownDiscriminator(
                field: "math.representation.type",
                value: other,
              ))
          }
      }
  }
}

fn decode_optional_numeric_precision(
  dynamic: Dynamic,
) -> Result(equality_types.NumericPrecision, types.MatchConfigError) {
  case read_optional_dynamic(dynamic, "precision") {
    Error(error) -> Error(error)
    Ok(None) -> Ok(equality_types.NoPrecision)
    Ok(Some(precision_dynamic)) ->
      case read_string(precision_dynamic, "type") {
        Error(error) -> Error(error)
        Ok(kind) ->
          case kind {
            "none" -> Ok(equality_types.NoPrecision)
            "significant_figures" | "legacy_significant_figures" ->
              case read_int(precision_dynamic, "count") {
                Ok(count) ->
                  case count > 0 {
                    True ->
                      Ok(equality_types.LegacySignificantFigures(count: count))
                    False ->
                      Error(types.InvalidField(
                        field: "math.precision.count",
                        reason: "expected positive integer",
                      ))
                  }
                Error(error) -> Error(error)
              }
            "decimal_places" -> decode_decimal_places(precision_dynamic)
            other ->
              Error(types.UnknownDiscriminator(
                field: "math.precision.type",
                value: other,
              ))
          }
      }
  }
}

fn decode_decimal_places(
  dynamic: Dynamic,
) -> Result(equality_types.NumericPrecision, types.MatchConfigError) {
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
                  Ok(equality_types.DecimalPlaces(
                    rule: decoded_rule,
                    count: count,
                  ))
                False ->
                  Error(types.InvalidField(
                    field: "math.precision.count",
                    reason: "expected non-negative integer",
                  ))
              }
            Error(error) -> Error(error)
          }
      }
  }
}

fn decode_latex_direct(
  dynamic: Dynamic,
) -> Result(types.MathExpressionSpec, types.MatchConfigError) {
  case read_string(dynamic, "expected") {
    Ok(expected) -> Ok(types.LatexDirect(expected: expected))
    Error(error) -> Error(error)
  }
}

fn decode_algebraic(
  dynamic: Dynamic,
) -> Result(types.MathExpressionSpec, types.MatchConfigError) {
  case read_string(dynamic, "expected") {
    Error(error) -> Error(error)
    Ok(expected) -> {
      let equivalence = decode_algebraic_config(dynamic)
      let form = decode_optional_form(dynamic)
      let expression_match = decode_optional_expression_match_policy(dynamic)

      case equivalence, form, expression_match {
        Ok(equivalence), Ok(form), Ok(expression_match) ->
          Ok(types.AlgebraicEquivalence(
            expected: expected,
            equivalence: equivalence,
            form: form,
            expression_match: expression_match,
          ))
        Error(error), _, _ | _, Error(error), _ | _, _, Error(error) ->
          Error(error)
      }
    }
  }
}

fn decode_optional_expression_match_policy(
  dynamic: Dynamic,
) -> Result(types.ExpressionMatchPolicy, types.MatchConfigError) {
  case read_optional_string(dynamic, "expressionMatch") {
    Error(error) -> Error(error)
    Ok(None) -> Ok(types.AllowEquivalent)
    Ok(Some(value)) ->
      case value {
        "equivalent" -> Ok(types.AllowEquivalent)
        "exact" -> Ok(types.MatchExact)
        other ->
          Error(types.UnknownDiscriminator(
            field: "math.expressionMatch",
            value: other,
          ))
      }
  }
}

fn decode_algebraic_config(
  dynamic: Dynamic,
) -> Result(algebraic_types.AlgebraicEquivalenceConfig, types.MatchConfigError) {
  let base = algebraic_types.default_algebraic_equivalence_config()
  let validation = decode_optional_algebraic_validation(dynamic, base)
  let sampling = decode_optional_algebraic_sampling(dynamic, base.sampling)

  case validation, sampling {
    Ok(#(allowed_variables, domains)), Ok(sampling) ->
      Ok(
        algebraic_types.AlgebraicEquivalenceConfig(
          ..base,
          allowed_variables: allowed_variables,
          domains: domains,
          sampling: sampling,
        ),
      )

    Error(error), _ | _, Error(error) -> Error(error)
  }
}

fn decode_optional_algebraic_validation(
  dynamic: Dynamic,
  base: algebraic_types.AlgebraicEquivalenceConfig,
) -> Result(
  #(algebraic_types.AllowedVariables, sampling_types.DomainConfig),
  types.MatchConfigError,
) {
  case read_optional_dynamic(dynamic, "validation") {
    Error(error) -> Error(error)
    Ok(None) -> Ok(#(base.allowed_variables, base.domains))
    Ok(Some(validation_dynamic)) ->
      case read_optional_string_list(validation_dynamic, "allowedVariables") {
        Error(error) -> Error(error)
        Ok(allowed_variables) -> {
          let domains = decode_optional_domain_config(validation_dynamic)

          case domains {
            Error(error) -> Error(error)
            Ok(domains) -> {
              let allowed_variables = case allowed_variables {
                None -> base.allowed_variables
                Some(allowed_variables) ->
                  algebraic_types.ExplicitAllowedVariables(allowed_variables)
              }

              Ok(#(allowed_variables, domains))
            }
          }
        }
      }
  }
}

fn decode_optional_algebraic_sampling(
  dynamic: Dynamic,
  default_sampling: sampling_types.SamplingConfig,
) -> Result(sampling_types.SamplingConfig, types.MatchConfigError) {
  case read_optional_dynamic(dynamic, "sampling") {
    Error(error) -> Error(error)
    Ok(None) -> Ok(default_sampling)
    Ok(Some(sampling_dynamic)) ->
      decode_sampling_config(sampling_dynamic, default_sampling)
  }
}

fn decode_sampling_config(
  dynamic: Dynamic,
  default_sampling: sampling_types.SamplingConfig,
) -> Result(sampling_types.SamplingConfig, types.MatchConfigError) {
  let seed = read_int(dynamic, "seed")
  let desired_count = read_int_or_alias(dynamic, "desiredCount", "sampleCount")
  let max_attempts =
    read_optional_int(dynamic, "maxAttempts", default_sampling.max_attempts)
  let include_special_points =
    read_optional_bool(
      dynamic,
      "includeSpecialPoints",
      default_sampling.include_special_points,
    )

  case seed, desired_count, max_attempts, include_special_points {
    Ok(seed), Ok(desired_count), Ok(max_attempts), Ok(include_special_points) -> {
      let sampling =
        sampling_types.SamplingConfig(
          seed: seed,
          desired_count: desired_count,
          max_attempts: max_attempts,
          include_special_points: include_special_points,
        )

      case sample.validate_sampling_config(sampling) {
        Ok(_) -> Ok(sampling)
        Error(error) -> Error(sampling_config_error(error))
      }
    }

    Error(error), _, _, _
    | _, Error(error), _, _
    | _, _, Error(error), _
    | _, _, _, Error(error)
    -> Error(error)
  }
}

fn sampling_config_error(
  error: sampling_types.SamplingError,
) -> types.MatchConfigError {
  case error {
    sampling_types.InvalidSamplingConfig(field, reason) ->
      types.InvalidField(field: "math." <> field, reason: reason)
    sampling_types.InvalidDomainConfig(variable, reason) ->
      types.InvalidField(
        field: "math.sampling",
        reason: variable <> ": " <> reason,
      )
    sampling_types.NoVariablesButVariablesRequired ->
      types.InvalidField(field: "math.sampling", reason: "no variables")
    sampling_types.TooFewIntegerValues(variable, requested, available) ->
      types.InvalidField(
        field: "math.sampling",
        reason: variable
          <> ": requested "
          <> int.to_string(requested)
          <> " samples but only "
          <> int.to_string(available)
          <> " integer values are available",
      )
    sampling_types.AllSamplesExcluded(variable) ->
      types.InvalidField(
        field: "math.sampling",
        reason: variable <> ": all samples excluded",
      )
    sampling_types.InsufficientValidSamples(..) ->
      types.InvalidField(
        field: "math.sampling",
        reason: "insufficient valid samples",
      )
  }
}

fn decode_optional_domain_config(
  dynamic: Dynamic,
) -> Result(sampling_types.DomainConfig, types.MatchConfigError) {
  case read_optional_dynamic_list(dynamic, "domains") {
    Error(error) -> Error(error)
    Ok(None) -> Ok(sampling_types.default_domain_config())
    Ok(Some(domain_values)) ->
      case decode_domains(domain_values, []) {
        Ok(domains) -> Ok(sampling_types.DomainConfig(variables: domains))
        Error(error) -> Error(error)
      }
  }
}

fn decode_domains(
  values: List(Dynamic),
  acc: List(sampling_types.VariableDomain),
) -> Result(List(sampling_types.VariableDomain), types.MatchConfigError) {
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
) -> Result(sampling_types.VariableDomain, types.MatchConfigError) {
  case read_string(dynamic, "name") {
    Error(error) -> Error(error)
    Ok(name) ->
      case read_float(dynamic, "lower") {
        Error(error) -> Error(error)
        Ok(lower) ->
          case read_float(dynamic, "upper") {
            Error(error) -> Error(error)
            Ok(upper) -> {
              let lower_inclusive =
                read_optional_bool(dynamic, "lowerInclusive", True)
              let upper_inclusive =
                read_optional_bool(dynamic, "upperInclusive", True)
              let exclusions = read_optional_float_list(dynamic, "exclusions")
              let integer_only =
                read_optional_bool(dynamic, "integerOnly", False)
              let preferred_values =
                read_optional_float_list(dynamic, "preferredValues")

              case
                lower_inclusive,
                upper_inclusive,
                exclusions,
                integer_only,
                preferred_values
              {
                Ok(lower_inclusive),
                  Ok(upper_inclusive),
                  Ok(exclusions),
                  Ok(integer_only),
                  Ok(preferred_values)
                ->
                  Ok(sampling_types.VariableDomain(
                    name: name,
                    lower: bound(lower, lower_inclusive),
                    upper: bound(upper, upper_inclusive),
                    exclusions: exclusions,
                    integer_only: integer_only,
                    preferred_values: preferred_values,
                  ))
                Error(error), _, _, _, _
                | _, Error(error), _, _, _
                | _, _, Error(error), _, _
                | _, _, _, Error(error), _
                | _, _, _, _, Error(error)
                -> Error(error)
              }
            }
          }
      }
  }
}

fn bound(value: Float, inclusive: Bool) -> sampling_types.Bound {
  case inclusive {
    True -> sampling_types.Inclusive(value)
    False -> sampling_types.Exclusive(value)
  }
}

fn decode_optional_form(
  dynamic: Dynamic,
) -> Result(Option(form_types.ExactFormConfig), types.MatchConfigError) {
  case read_optional_dynamic(dynamic, "form") {
    Error(error) -> Error(error)
    Ok(None) -> Ok(None)
    Ok(Some(form_dynamic)) ->
      case decode_form(form_dynamic) {
        Ok(config) -> Ok(Some(config))
        Error(error) -> Error(error)
      }
  }
}

fn decode_form(
  dynamic: Dynamic,
) -> Result(form_types.ExactFormConfig, types.MatchConfigError) {
  case read_string(dynamic, "type") {
    Error(error) -> Error(error)
    Ok(kind) ->
      case kind {
        "none" -> Ok(form_types.NoFormConstraint)
        "integer" -> Ok(form_types.RequireInteger)
        "fraction" -> Ok(form_types.RequireFraction)
        "simplified_fraction" -> Ok(form_types.RequireSimplifiedFraction)
        "decimal" -> decode_decimal_form(dynamic)
        other ->
          Error(types.UnknownDiscriminator(
            field: "math.form.type",
            value: other,
          ))
      }
  }
}

fn decode_decimal_form(
  dynamic: Dynamic,
) -> Result(form_types.ExactFormConfig, types.MatchConfigError) {
  case read_optional_dynamic(dynamic, "precision") {
    Error(error) -> Error(error)
    Ok(None) ->
      Ok(form_types.RequireDecimal(precision: form_types.AnyDecimalPlaces))
    Ok(Some(precision_dynamic)) ->
      case decode_decimal_precision(precision_dynamic) {
        Ok(precision) -> Ok(form_types.RequireDecimal(precision: precision))
        Error(error) -> Error(error)
      }
  }
}

fn decode_decimal_precision(
  dynamic: Dynamic,
) -> Result(form_types.DecimalPrecisionConstraint, types.MatchConfigError) {
  case read_string(dynamic, "type") {
    Error(error) -> Error(error)
    Ok(kind) ->
      case kind {
        "any" -> Ok(form_types.AnyDecimalPlaces)
        "decimal_places" ->
          case read_string(dynamic, "rule") {
            Error(error) -> Error(error)
            Ok(rule) ->
              case decimal_rule_from_string(rule) {
                Error(error) -> Error(error)
                Ok(decoded_rule) ->
                  case read_int(dynamic, "count") {
                    Ok(count) ->
                      Ok(form_types.DecimalPlaces(
                        rule: decoded_rule,
                        count: count,
                      ))
                    Error(error) -> Error(error)
                  }
              }
          }
        other ->
          Error(types.UnknownDiscriminator(
            field: "math.form.precision.type",
            value: other,
          ))
      }
  }
}

fn decode_unit_aware(
  dynamic: Dynamic,
) -> Result(types.MathExpressionSpec, types.MatchConfigError) {
  case read_string(dynamic, "expected") {
    Error(error) -> Error(error)
    Ok(expected) -> {
      let config = decode_unit_config(dynamic)
      let tolerance = decode_optional_sampling_tolerance(dynamic)
      let equivalence = decode_optional_unit_algebraic_config(dynamic)
      let match_wrong_units =
        read_optional_bool(dynamic, "matchWrongUnits", False)
      let match_missing_unit =
        read_optional_bool(dynamic, "matchMissingUnit", False)
      let expression_match = decode_optional_expression_match_policy(dynamic)

      case
        config,
        tolerance,
        equivalence,
        match_wrong_units,
        match_missing_unit,
        expression_match
      {
        Ok(config),
          Ok(tolerance),
          Ok(equivalence),
          Ok(match_wrong_units),
          Ok(match_missing_unit),
          Ok(expression_match)
        ->
          Ok(types.UnitAware(
            expected: expected,
            config: config,
            tolerance: tolerance,
            equivalence: equivalence,
            match_wrong_units: match_wrong_units,
            match_missing_unit: match_missing_unit,
            expression_match: expression_match,
          ))
        Error(error), _, _, _, _, _
        | _, Error(error), _, _, _, _
        | _, _, Error(error), _, _, _
        | _, _, _, Error(error), _, _
        | _, _, _, _, Error(error), _
        | _, _, _, _, _, Error(error)
        -> Error(error)
      }
    }
  }
}

fn decode_optional_unit_algebraic_config(
  dynamic: Dynamic,
) -> Result(
  Option(algebraic_types.AlgebraicEquivalenceConfig),
  types.MatchConfigError,
) {
  let validation = read_optional_dynamic(dynamic, "validation")
  let sampling = read_optional_dynamic(dynamic, "sampling")

  case validation, sampling {
    Error(error), _ | _, Error(error) -> Error(error)
    Ok(None), Ok(None) -> Ok(None)
    _, _ ->
      case decode_algebraic_config(dynamic) {
        Ok(config) -> Ok(Some(config))
        Error(error) -> Error(error)
      }
  }
}

fn decode_unit_config(
  dynamic: Dynamic,
) -> Result(unit_types.UnitConfig, types.MatchConfigError) {
  case read_dynamic(dynamic, "unitPolicy") {
    Error(error) -> Error(error)
    Ok(policy_dynamic) ->
      case read_string(policy_dynamic, "type") {
        Error(error) -> Error(error)
        Ok(kind) ->
          case kind {
            "ignored" ->
              Ok(unit_types.UnitConfig(
                mode: unit_types.IgnoreUnits,
                accepted_units: [],
                conversion: unit_types.AllowConversion,
                final_unit: unit_types.AnyAcceptedUnit,
              ))
            "accepted_units" ->
              decode_unit_list_policy(
                policy_dynamic,
                unit_types.DisallowConversion,
                unit_types.AnyAcceptedUnit,
              )
            "convertible_units" ->
              decode_unit_list_policy(
                policy_dynamic,
                unit_types.AllowConversion,
                unit_types.AnyAcceptedUnit,
              )
            "strict_unit" ->
              case read_string(policy_dynamic, "unit") {
                Ok(unit) ->
                  Ok(unit_types.UnitConfig(
                    mode: unit_types.RequireUnits,
                    accepted_units: [unit],
                    conversion: unit_types.AllowConversion,
                    final_unit: unit_types.StrictAcceptedUnit,
                  ))
                Error(error) -> Error(error)
              }
            other ->
              Error(types.UnknownDiscriminator(
                field: "math.unitPolicy.type",
                value: other,
              ))
          }
      }
  }
}

fn decode_unit_list_policy(
  dynamic: Dynamic,
  conversion: unit_types.ConversionPolicy,
  final_unit: unit_types.FinalUnitPolicy,
) -> Result(unit_types.UnitConfig, types.MatchConfigError) {
  case read_string_list(dynamic, "units") {
    Ok(units) ->
      Ok(unit_types.UnitConfig(
        mode: unit_types.RequireUnits,
        accepted_units: units,
        conversion: conversion,
        final_unit: final_unit,
      ))
    Error(error) -> Error(error)
  }
}

fn decode_optional_sampling_tolerance(
  dynamic: Dynamic,
) -> Result(sampling_types.Tolerance, types.MatchConfigError) {
  case read_optional_dynamic(dynamic, "tolerance") {
    Error(error) -> Error(error)
    Ok(None) -> Ok(sampling_types.default_expression_tolerance())
    Ok(Some(tolerance_dynamic)) -> decode_sampling_tolerance(tolerance_dynamic)
  }
}

fn decode_sampling_tolerance(
  dynamic: Dynamic,
) -> Result(sampling_types.Tolerance, types.MatchConfigError) {
  case read_string(dynamic, "type") {
    Error(error) -> Error(error)
    Ok(kind) ->
      case kind {
        "none" -> Ok(sampling_types.NoTolerance)
        "absolute" ->
          case read_float(dynamic, "abs") {
            Ok(abs) -> Ok(sampling_types.AbsoluteTolerance(abs: abs))
            Error(error) -> Error(error)
          }
        "relative" ->
          case read_float(dynamic, "rel") {
            Error(error) -> Error(error)
            Ok(rel) ->
              case read_optional_float(dynamic, "epsilon") {
                Ok(epsilon) ->
                  Ok(sampling_types.RelativeTolerance(
                    rel: rel,
                    epsilon: epsilon,
                  ))
                Error(error) -> Error(error)
              }
          }
        "absolute_or_relative" ->
          case read_float(dynamic, "abs") {
            Error(error) -> Error(error)
            Ok(abs) ->
              case read_float(dynamic, "rel") {
                Error(error) -> Error(error)
                Ok(rel) ->
                  case read_optional_float(dynamic, "epsilon") {
                    Ok(epsilon) ->
                      Ok(sampling_types.AbsoluteOrRelativeTolerance(
                        abs: abs,
                        rel: rel,
                        epsilon: epsilon,
                      ))
                    Error(error) -> Error(error)
                  }
              }
          }
        other ->
          Error(types.UnknownDiscriminator(
            field: "math.tolerance.type",
            value: other,
          ))
      }
  }
}

fn read_dynamic(
  dynamic: Dynamic,
  field: String,
) -> Result(Dynamic, types.MatchConfigError) {
  read_field(dynamic, field, decode.dynamic, expected: "value")
}

fn read_optional_dynamic(
  dynamic: Dynamic,
  field: String,
) -> Result(Option(Dynamic), types.MatchConfigError) {
  case read_dynamic(dynamic, field) {
    Ok(value) -> Ok(Some(value))
    Error(types.MissingField(_)) -> Ok(None)
    Error(error) -> Error(error)
  }
}

fn read_optional_dynamic_list(
  dynamic: Dynamic,
  field: String,
) -> Result(Option(List(Dynamic)), types.MatchConfigError) {
  case
    read_field(
      dynamic,
      field,
      decode.list(of: decode.dynamic),
      expected: "array",
    )
  {
    Ok(value) -> Ok(Some(value))
    Error(types.MissingField(_)) -> Ok(None)
    Error(error) -> Error(error)
  }
}

fn read_string(
  dynamic: Dynamic,
  field: String,
) -> Result(String, types.MatchConfigError) {
  read_field(dynamic, field, decode.string, expected: "string")
}

fn read_optional_string(
  dynamic: Dynamic,
  field: String,
) -> Result(Option(String), types.MatchConfigError) {
  case read_string(dynamic, field) {
    Ok(value) -> Ok(Some(value))
    Error(types.MissingField(_)) -> Ok(None)
    Error(error) -> Error(error)
  }
}

fn read_bool(
  dynamic: Dynamic,
  field: String,
) -> Result(Bool, types.MatchConfigError) {
  read_field(dynamic, field, decode.bool, expected: "boolean")
}

fn read_optional_bool(
  dynamic: Dynamic,
  field: String,
  default default: Bool,
) -> Result(Bool, types.MatchConfigError) {
  case read_bool(dynamic, field) {
    Ok(value) -> Ok(value)
    Error(types.MissingField(_)) -> Ok(default)
    Error(error) -> Error(error)
  }
}

fn read_int(
  dynamic: Dynamic,
  field: String,
) -> Result(Int, types.MatchConfigError) {
  read_field(dynamic, field, decode.int, expected: "integer")
}

fn read_optional_int(
  dynamic: Dynamic,
  field: String,
  default default: Int,
) -> Result(Int, types.MatchConfigError) {
  case read_int(dynamic, field) {
    Ok(value) -> Ok(value)
    Error(types.MissingField(_)) -> Ok(default)
    Error(error) -> Error(error)
  }
}

fn read_int_or_alias(
  dynamic: Dynamic,
  field: String,
  alias alias: String,
) -> Result(Int, types.MatchConfigError) {
  case read_int(dynamic, field) {
    Ok(value) -> Ok(value)
    Error(types.MissingField(_)) -> read_int(dynamic, alias)
    Error(error) -> Error(error)
  }
}

fn read_float(
  dynamic: Dynamic,
  field: String,
) -> Result(Float, types.MatchConfigError) {
  read_field(
    dynamic,
    field,
    decode.one_of(decode.float, or: [decode.int |> decode.map(int.to_float)]),
    expected: "number",
  )
}

fn read_float_list(
  dynamic: Dynamic,
  field: String,
) -> Result(List(Float), types.MatchConfigError) {
  read_field(
    dynamic,
    field,
    decode.list(
      of: decode.one_of(decode.float, or: [
        decode.int |> decode.map(int.to_float),
      ]),
    ),
    expected: "number array",
  )
}

fn read_optional_float_list(
  dynamic: Dynamic,
  field: String,
) -> Result(List(Float), types.MatchConfigError) {
  case read_float_list(dynamic, field) {
    Ok(value) -> Ok(value)
    Error(types.MissingField(_)) -> Ok([])
    Error(error) -> Error(error)
  }
}

fn read_optional_float(
  dynamic: Dynamic,
  field: String,
) -> Result(Float, types.MatchConfigError) {
  case read_float(dynamic, field) {
    Ok(value) -> Ok(value)
    Error(types.MissingField(_)) -> Ok(0.000000000001)
    Error(error) -> Error(error)
  }
}

fn read_string_list(
  dynamic: Dynamic,
  field: String,
) -> Result(List(String), types.MatchConfigError) {
  read_field(
    dynamic,
    field,
    decode.list(of: decode.string),
    expected: "string array",
  )
}

fn read_optional_string_list(
  dynamic: Dynamic,
  field: String,
) -> Result(Option(List(String)), types.MatchConfigError) {
  case read_string_list(dynamic, field) {
    Ok(value) -> Ok(Some(value))
    Error(types.MissingField(_)) -> Ok(None)
    Error(error) -> Error(error)
  }
}

fn read_field(
  dynamic: Dynamic,
  field: String,
  decoder: decode.Decoder(a),
  expected expected: String,
) -> Result(a, types.MatchConfigError) {
  case decode.run(dynamic, decode.field(field, decoder, decode.success)) {
    Ok(value) -> Ok(value)
    Error(errors) -> Error(field_error(field, expected, errors))
  }
}

fn field_error(
  field: String,
  expected: String,
  errors: List(decode.DecodeError),
) -> types.MatchConfigError {
  case list.any(errors, fn(error) { error.found == "Nothing" }) {
    True -> types.MissingField(field: field)
    False -> types.InvalidField(field: field, reason: "expected " <> expected)
  }
}

fn numeric_operator(comparison: equality_types.NumericComparison) -> String {
  case comparison {
    equality_types.Equal(_) -> "equal"
    equality_types.NotEqual(_) -> "not_equal"
    equality_types.GreaterThan(_) -> "greater_than"
    equality_types.GreaterThanOrEqual(_) -> "greater_than_or_equal"
    equality_types.LessThan(_) -> "less_than"
    equality_types.LessThanOrEqual(_) -> "less_than_or_equal"
    equality_types.Between(..) -> "between"
    equality_types.NotBetween(..) -> "not_between"
  }
}

fn numeric_tolerance_to_json(
  tolerance: equality_types.NumericTolerance,
) -> gleam_json.Json {
  case tolerance {
    equality_types.NoTolerance ->
      gleam_json.object([#("type", gleam_json.string("none"))])
    equality_types.AbsoluteTolerance(value) ->
      gleam_json.object([
        #("type", gleam_json.string("absolute")),
        #("value", gleam_json.float(value)),
      ])
    equality_types.RelativeTolerance(value) ->
      gleam_json.object([
        #("type", gleam_json.string("relative")),
        #("value", gleam_json.float(value)),
      ])
    equality_types.AbsoluteOrRelativeTolerance(absolute, relative) ->
      gleam_json.object([
        #("type", gleam_json.string("absolute_or_relative")),
        #("absolute", gleam_json.float(absolute)),
        #("relative", gleam_json.float(relative)),
      ])
  }
}

fn representation_to_json(
  representation: equality_types.NumericRepresentation,
) -> gleam_json.Json {
  case representation {
    equality_types.AnyRepresentation ->
      gleam_json.object([#("type", gleam_json.string("any"))])
    equality_types.IntegerRepresentation ->
      gleam_json.object([#("type", gleam_json.string("integer"))])
    equality_types.DecimalRepresentation ->
      gleam_json.object([#("type", gleam_json.string("decimal"))])
    equality_types.ScientificRepresentation ->
      gleam_json.object([#("type", gleam_json.string("scientific"))])
  }
}

fn numeric_precision_to_json(
  precision: equality_types.NumericPrecision,
) -> gleam_json.Json {
  case precision {
    equality_types.NoPrecision ->
      gleam_json.object([#("type", gleam_json.string("none"))])
    equality_types.LegacySignificantFigures(count) ->
      gleam_json.object([
        #("type", gleam_json.string("significant_figures")),
        #("count", gleam_json.int(count)),
      ])
    equality_types.DecimalPlaces(rule, count) ->
      gleam_json.object([
        #("type", gleam_json.string("decimal_places")),
        #("rule", gleam_json.string(decimal_rule_to_string(rule))),
        #("count", gleam_json.int(count)),
      ])
  }
}

fn tolerance_to_json(tolerance: sampling_types.Tolerance) -> gleam_json.Json {
  case tolerance {
    sampling_types.NoTolerance ->
      gleam_json.object([#("type", gleam_json.string("none"))])
    sampling_types.AbsoluteTolerance(abs) ->
      gleam_json.object([
        #("type", gleam_json.string("absolute")),
        #("abs", gleam_json.float(abs)),
      ])
    sampling_types.RelativeTolerance(rel, epsilon) ->
      gleam_json.object([
        #("type", gleam_json.string("relative")),
        #("rel", gleam_json.float(rel)),
        #("epsilon", gleam_json.float(epsilon)),
      ])
    sampling_types.AbsoluteOrRelativeTolerance(abs, rel, epsilon) ->
      gleam_json.object([
        #("type", gleam_json.string("absolute_or_relative")),
        #("abs", gleam_json.float(abs)),
        #("rel", gleam_json.float(rel)),
        #("epsilon", gleam_json.float(epsilon)),
      ])
  }
}

fn bounds_to_string(bounds: equality_types.RangeBounds) -> String {
  case bounds {
    equality_types.Inclusive -> "inclusive"
    equality_types.Exclusive -> "exclusive"
  }
}

fn bounds_from_string(
  bounds: String,
) -> Result(equality_types.RangeBounds, types.MatchConfigError) {
  case bounds {
    "inclusive" -> Ok(equality_types.Inclusive)
    "exclusive" -> Ok(equality_types.Exclusive)
    other ->
      Error(types.UnknownDiscriminator(field: "math.bounds", value: other))
  }
}

fn decimal_rule_to_string(rule: equality_types.DecimalPlaceRule) -> String {
  case rule {
    equality_types.Exactly -> "exactly"
    equality_types.AtLeast -> "at_least"
    equality_types.AtMost -> "at_most"
  }
}

fn decimal_rule_from_string(
  rule: String,
) -> Result(equality_types.DecimalPlaceRule, types.MatchConfigError) {
  case rule {
    "exactly" -> Ok(equality_types.Exactly)
    "at_least" -> Ok(equality_types.AtLeast)
    "at_most" -> Ok(equality_types.AtMost)
    other ->
      Error(types.UnknownDiscriminator(field: "precision.rule", value: other))
  }
}
