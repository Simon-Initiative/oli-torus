import gleam/float
import gleam/int
import gleam/list
import gleam/string
import math/units/catalog
import math/units/types

const max_finite_float = 1.7976931348623157e308

const max_unit_exponent = 24

type NormalParts {
  NormalParts(
    dimensions: List(types.DimensionPower),
    scale_to_canonical: Float,
    canonical_debug: String,
    semantic: types.UnitSemantic,
  )
}

/// Normalize a parsed unit expression to deterministic dimensions and scale.
pub fn normalize_unit(
  unit: types.UnitExpr,
) -> Result(types.NormalUnit, types.UnitNormalizeError) {
  case normalize(unit) {
    Ok(parts) ->
      Ok(types.NormalUnit(
        dimensions: sort_dimensions(remove_zero_dimensions(parts.dimensions)),
        scale_to_canonical: parts.scale_to_canonical,
        canonical_debug: parts.canonical_debug,
        original: unit,
        catalog_version: catalog.catalog_version(),
        semantic: parts.semantic,
      ))

    Error(error) -> Error(error)
  }
}

fn normalize(
  unit: types.UnitExpr,
) -> Result(NormalParts, types.UnitNormalizeError) {
  case unit {
    types.UnitAtom(symbol) -> normalize_atom(symbol)

    types.UnitMul(left, right) -> {
      case normalize(left) {
        Ok(left_parts) -> {
          case normalize(right) {
            Ok(right_parts) -> combine_product(left_parts, right_parts)
            Error(error) -> Error(error)
          }
        }

        Error(error) -> Error(error)
      }
    }

    types.UnitDiv(left, right) -> {
      case normalize(left) {
        Ok(left_parts) -> {
          case normalize(right) {
            Ok(right_parts) -> combine_quotient(left_parts, right_parts)
            Error(error) -> Error(error)
          }
        }

        Error(error) -> Error(error)
      }
    }

    types.UnitPow(base, exponent) -> {
      case normalize(base) {
        Ok(parts) -> apply_power(parts, exponent)
        Error(error) -> Error(error)
      }
    }
  }
}

fn normalize_atom(
  symbol: String,
) -> Result(NormalParts, types.UnitNormalizeError) {
  case catalog.lookup(symbol) {
    Ok(found) ->
      Ok(NormalParts(
        dimensions: found.definition.dimensions,
        scale_to_canonical: found.definition.scale_to_canonical,
        canonical_debug: found.definition.canonical_symbol,
        semantic: found.definition.semantic,
      ))

    Error(_) -> Error(types.UnknownAtom(symbol: symbol))
  }
}

fn combine_product(
  left: NormalParts,
  right: NormalParts,
) -> Result(NormalParts, types.UnitNormalizeError) {
  let scale = left.scale_to_canonical *. right.scale_to_canonical

  case is_finite(scale) {
    False -> Error(types.NonFiniteUnitScale)
    True ->
      Ok(NormalParts(
        dimensions: add_dimension_lists(left.dimensions, right.dimensions),
        scale_to_canonical: scale,
        canonical_debug: product_debug(
          left.canonical_debug,
          right.canonical_debug,
        ),
        semantic: combine_semantics(left.semantic, right.semantic),
      ))
  }
}

fn combine_quotient(
  left: NormalParts,
  right: NormalParts,
) -> Result(NormalParts, types.UnitNormalizeError) {
  let scale = left.scale_to_canonical /. right.scale_to_canonical

  case right.scale_to_canonical == 0.0 || !is_finite(scale) {
    True -> Error(types.NonFiniteUnitScale)
    False ->
      Ok(NormalParts(
        dimensions: add_dimension_lists(
          left.dimensions,
          negate_dimensions(right.dimensions),
        ),
        scale_to_canonical: scale,
        canonical_debug: quotient_debug(
          left.canonical_debug,
          right.canonical_debug,
        ),
        semantic: combine_semantics(left.semantic, right.semantic),
      ))
  }
}

fn apply_power(
  parts: NormalParts,
  exponent: Int,
) -> Result(NormalParts, types.UnitNormalizeError) {
  case int.absolute_value(exponent) > max_unit_exponent {
    True -> Error(types.InvalidUnitPower(exponent: exponent))
    False -> {
      case scale_power(parts.scale_to_canonical, exponent) {
        Ok(scale) ->
          Ok(NormalParts(
            dimensions: scale_dimensions(parts.dimensions, exponent),
            scale_to_canonical: scale,
            canonical_debug: power_debug(parts.canonical_debug, exponent),
            semantic: parts.semantic,
          ))

        Error(error) -> Error(error)
      }
    }
  }
}

fn scale_power(
  scale: Float,
  exponent: Int,
) -> Result(Float, types.UnitNormalizeError) {
  case exponent {
    0 -> Ok(1.0)
    _ -> {
      let magnitude = int.absolute_value(exponent)

      case multiply_scale_repeated(scale, magnitude, 1.0) {
        Ok(powered) -> {
          let value = case exponent < 0 {
            True -> 1.0 /. powered
            False -> powered
          }

          case powered == 0.0 || !is_finite(value) {
            True -> Error(types.NonFiniteUnitScale)
            False -> Ok(value)
          }
        }

        Error(error) -> Error(error)
      }
    }
  }
}

fn multiply_scale_repeated(
  scale: Float,
  remaining: Int,
  acc: Float,
) -> Result(Float, types.UnitNormalizeError) {
  case remaining {
    0 -> Ok(acc)
    _ -> {
      let next = acc *. scale

      case is_finite(next) {
        True -> multiply_scale_repeated(scale, remaining - 1, next)
        False -> Error(types.NonFiniteUnitScale)
      }
    }
  }
}

fn add_dimension_lists(
  left: List(types.DimensionPower),
  right: List(types.DimensionPower),
) -> List(types.DimensionPower) {
  list.fold(right, from: left, with: fn(acc, power) {
    add_dimension(acc, power.dimension, power.exponent)
  })
  |> remove_zero_dimensions
  |> sort_dimensions
}

fn add_dimension(
  dimensions: List(types.DimensionPower),
  dimension: types.BaseDimension,
  exponent: Int,
) -> List(types.DimensionPower) {
  case dimensions {
    [] -> [types.DimensionPower(dimension: dimension, exponent: exponent)]
    [first, ..rest] -> {
      case first.dimension == dimension {
        True -> [
          types.DimensionPower(
            dimension: dimension,
            exponent: first.exponent + exponent,
          ),
          ..rest
        ]

        False -> [first, ..add_dimension(rest, dimension, exponent)]
      }
    }
  }
}

fn negate_dimensions(
  dimensions: List(types.DimensionPower),
) -> List(types.DimensionPower) {
  list.map(dimensions, fn(power) {
    types.DimensionPower(
      dimension: power.dimension,
      exponent: 0 - power.exponent,
    )
  })
}

fn scale_dimensions(
  dimensions: List(types.DimensionPower),
  multiplier: Int,
) -> List(types.DimensionPower) {
  list.map(dimensions, fn(power) {
    types.DimensionPower(
      dimension: power.dimension,
      exponent: power.exponent * multiplier,
    )
  })
  |> remove_zero_dimensions
  |> sort_dimensions
}

fn remove_zero_dimensions(
  dimensions: List(types.DimensionPower),
) -> List(types.DimensionPower) {
  list.filter(dimensions, fn(power) { power.exponent != 0 })
}

fn sort_dimensions(
  dimensions: List(types.DimensionPower),
) -> List(types.DimensionPower) {
  list.sort(dimensions, by: fn(left, right) {
    int.compare(
      dimension_rank(left.dimension),
      with: dimension_rank(right.dimension),
    )
  })
}

fn dimension_rank(dimension: types.BaseDimension) -> Int {
  case dimension {
    types.Length -> 0
    types.Mass -> 1
    types.Time -> 2
    types.ElectricCurrent -> 3
    types.Temperature -> 4
    types.AmountOfSubstance -> 5
    types.LuminousIntensity -> 6
  }
}

fn combine_semantics(
  left: types.UnitSemantic,
  right: types.UnitSemantic,
) -> types.UnitSemantic {
  case left, right {
    types.PlainUnit, other -> other
    other, types.PlainUnit -> other
    types.Angle, types.Angle -> types.Angle
    types.SolidAngle, types.SolidAngle -> types.SolidAngle
    _, _ -> types.PlainUnit
  }
}

fn product_debug(left: String, right: String) -> String {
  left <> "*" <> right
}

fn quotient_debug(left: String, right: String) -> String {
  left <> "/" <> maybe_group_for_quotient(right)
}

fn power_debug(source: String, exponent: Int) -> String {
  maybe_group_for_power(source) <> "^" <> int.to_string(exponent)
}

fn maybe_group_for_quotient(source: String) -> String {
  case string.contains(source, "*") || string.contains(source, "/") {
    True -> "(" <> source <> ")"
    False -> source
  }
}

fn maybe_group_for_power(source: String) -> String {
  case string.contains(source, "*") || string.contains(source, "/") {
    True -> "(" <> source <> ")"
    False -> source
  }
}

fn is_finite(value: Float) -> Bool {
  float.absolute_value(value) <=. max_finite_float
}

/// Format a normalized unit as a deterministic developer/debug string.
pub fn normal_unit_to_debug_string(unit: types.NormalUnit) -> String {
  "NormalUnit(dimensions=["
  <> string.join(
    list.map(unit.dimensions, dimension_power_to_debug_string),
    with: ",",
  )
  <> "],scale="
  <> float.to_string(unit.scale_to_canonical)
  <> ",canonical="
  <> quote(unit.canonical_debug)
  <> ",catalog="
  <> quote(unit.catalog_version)
  <> ",semantic="
  <> semantic_to_debug_string(unit.semantic)
  <> ")"
}

fn dimension_power_to_debug_string(power: types.DimensionPower) -> String {
  dimension_to_debug_string(power.dimension)
  <> "^"
  <> int.to_string(power.exponent)
}

fn dimension_to_debug_string(dimension: types.BaseDimension) -> String {
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

fn semantic_to_debug_string(semantic: types.UnitSemantic) -> String {
  case semantic {
    types.PlainUnit -> "PlainUnit"
    types.Angle -> "Angle"
    types.SolidAngle -> "SolidAngle"
  }
}

fn quote(value: String) -> String {
  "\"" <> value <> "\""
}
