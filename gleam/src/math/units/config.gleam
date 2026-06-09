import gleam/float
import gleam/int
import gleam/list
import gleam/string
import math/units/normalize
import math/units/parser
import math/units/types

/// Validate unit-aware author configuration and pre-normalize accepted units.
pub fn validate_unit_config(
  config: types.UnitConfig,
) -> Result(types.ValidatedUnitConfig, List(types.UnitConfigError)) {
  let #(accepted_units, unit_errors) =
    validate_accepted_units(config.accepted_units, [], [], [])
  let policy_errors = validate_policy(config)
  let errors = list.append(unit_errors, policy_errors)

  case errors {
    [] ->
      Ok(types.ValidatedUnitConfig(
        mode: config.mode,
        accepted_units: accepted_units,
        conversion: config.conversion,
        final_unit: config.final_unit,
      ))

    _ -> Error(errors)
  }
}

fn validate_accepted_units(
  sources: List(String),
  seen_keys: List(String),
  accepted: List(types.AcceptedUnit),
  errors: List(types.UnitConfigError),
) -> #(List(types.AcceptedUnit), List(types.UnitConfigError)) {
  case sources {
    [] -> #(list.reverse(accepted), list.reverse(errors))
    [source, ..rest] -> {
      case parse_and_normalize_accepted(source) {
        Ok(normalized) -> {
          let key = normal_key(normalized)

          case list.contains(seen_keys, any: key) {
            True ->
              validate_accepted_units(rest, seen_keys, accepted, [
                types.DuplicateAcceptedUnit(source: source),
                ..errors
              ])

            False ->
              validate_accepted_units(
                rest,
                [key, ..seen_keys],
                [
                  types.AcceptedUnit(source: source, normalized: normalized),
                  ..accepted
                ],
                errors,
              )
          }
        }

        Error(error) ->
          validate_accepted_units(rest, seen_keys, accepted, [error, ..errors])
      }
    }
  }
}

fn parse_and_normalize_accepted(
  source: String,
) -> Result(types.NormalUnit, types.UnitConfigError) {
  case parser.parse_unit(source) {
    Ok(unit) -> {
      case normalize.normalize_unit(unit) {
        Ok(normalized) -> Ok(normalized)
        Error(types.UnknownAtom(symbol)) ->
          Error(types.UnsupportedAcceptedUnit(source: source, symbol: symbol))
        Error(error) ->
          Error(types.MalformedAcceptedUnit(
            source: source,
            reason: normalize_error_reason(error),
          ))
      }
    }

    Error(types.UnsupportedUnitAtom(symbol: symbol, ..)) ->
      Error(types.UnsupportedAcceptedUnit(source: source, symbol: symbol))

    Error(error) ->
      Error(types.MalformedAcceptedUnit(
        source: source,
        reason: parse_error_reason(error),
      ))
  }
}

fn validate_policy(config: types.UnitConfig) -> List(types.UnitConfigError) {
  let empty_required_error = case config.mode, config.accepted_units {
    types.RequireUnits, [] -> [types.EmptyAcceptedUnits]
    _, _ -> []
  }

  let strict_error = case config.final_unit, config.accepted_units {
    types.StrictAcceptedUnit, [] -> [types.EmptyAcceptedUnits]
    types.StrictAcceptedUnit, [_] -> []
    types.StrictAcceptedUnit, _ -> [
      types.InconsistentUnitPolicy(
        reason: "strict final-unit policy requires exactly one accepted unit",
      ),
    ]
    types.AnyAcceptedUnit, _ -> []
  }

  unique_errors(list.append(empty_required_error, strict_error), [])
}

fn unique_errors(
  errors: List(types.UnitConfigError),
  kept: List(types.UnitConfigError),
) -> List(types.UnitConfigError) {
  case errors {
    [] -> list.reverse(kept)
    [first, ..rest] -> {
      case list.contains(kept, any: first) {
        True -> unique_errors(rest, kept)
        False -> unique_errors(rest, [first, ..kept])
      }
    }
  }
}

fn normal_key(unit: types.NormalUnit) -> String {
  "dimensions=["
  <> string.join(list.map(unit.dimensions, dimension_key), with: ",")
  <> "];scale="
  <> float.to_string(unit.scale_to_canonical)
}

fn dimension_key(power: types.DimensionPower) -> String {
  dimension_name(power.dimension) <> "^" <> int.to_string(power.exponent)
}

fn dimension_name(dimension: types.BaseDimension) -> String {
  case dimension {
    types.Length -> "Length"
    types.Mass -> "Mass"
    types.Time -> "Time"
    types.ElectricCurrent -> "ElectricCurrent"
    types.Temperature -> "Temperature"
    types.AmountOfSubstance -> "AmountOfSubstance"
    types.LuminousIntensity -> "LuminousIntensity"
  }
}

fn parse_error_reason(error: types.UnitParseError) -> String {
  case error {
    types.EmptyUnitExpression -> "empty unit expression"
    types.UnexpectedUnitToken(expected: expected, found: found, ..) ->
      "unexpected unit token `"
      <> found
      <> "`, expected "
      <> string.join(expected, with: " or ")
    types.UnsupportedUnitAtom(symbol: symbol, ..) ->
      "unsupported unit atom `" <> symbol <> "`"
    types.MalformedUnitPower(..) -> "malformed unit power"
    types.UnclosedUnitParenthesis(..) -> "unclosed unit parenthesis"
    types.TrailingUnitInput(..) -> "trailing unit input"
  }
}

fn normalize_error_reason(error: types.UnitNormalizeError) -> String {
  case error {
    types.UnknownAtom(symbol) -> "unknown unit atom `" <> symbol <> "`"
    types.InvalidUnitPower(exponent) ->
      "invalid unit power `" <> int.to_string(exponent) <> "`"
    types.NonFiniteUnitScale -> "non-finite unit scale"
  }
}
