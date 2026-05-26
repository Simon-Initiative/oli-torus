import gleam/float
import gleeunit
import math/units/normalize
import math/units/parser
import math/units/types

pub fn main() {
  gleeunit.main()
}

pub fn normalizes_acceleration_units_with_expected_scales_test() {
  let meters = normalized("m/s^2")
  let centimeters = normalized("cm/s^2")

  assert meters.dimensions == acceleration_dimensions()
  assert centimeters.dimensions == acceleration_dimensions()
  assert_close(meters.scale_to_canonical, 1.0)
  assert_close(centimeters.scale_to_canonical, 0.01)
}

pub fn normalizes_force_named_and_compound_units_equivalently_test() {
  let newton = normalized("N")
  let compound = normalized("kg*m/s^2")

  assert newton.dimensions == force_dimensions()
  assert compound.dimensions == force_dimensions()
  assert_close(newton.scale_to_canonical, compound.scale_to_canonical)
  assert newton.canonical_debug == "N"
  assert compound.canonical_debug == "kg*m/s^2"
}

pub fn normalizes_speed_pressure_energy_and_concentration_examples_test() {
  assert_unit("km/hr", speed_dimensions(), 0.2777777777777778)
  assert_unit("mph", speed_dimensions(), 0.44704)
  assert_unit("ft/s^2", acceleration_dimensions(), 0.3048)
  assert_unit("atm", pressure_dimensions(), 101_325.0)
  assert_unit("L*atm", energy_dimensions(), 101.325)
  assert_unit("J/(mol*K)", molar_heat_capacity_dimensions(), 1.0)
  assert_unit("M", concentration_dimensions(), 1000.0)
  assert_unit("mol/L", concentration_dimensions(), 1000.0)
  assert_unit("g/mL", density_dimensions(), 1000.0)
}

pub fn normalizes_electricity_magnetism_light_and_radiation_examples_test() {
  assert_unit("V", voltage_dimensions(), 1.0)
  assert_unit("mV", voltage_dimensions(), 0.001)
  assert_unit("ohm", resistance_dimensions(), 1.0)
  assert_unit("kΩ", resistance_dimensions(), 1000.0)
  assert_unit("F", capacitance_dimensions(), 1.0)
  assert_unit("uF", capacitance_dimensions(), 0.000001)
  assert_unit("T", tesla_dimensions(), 1.0)
  assert_unit("G", tesla_dimensions(), 0.0001)
  assert_unit(
    "lx",
    [dim(types.Length, -2), dim(types.LuminousIntensity, 1)],
    1.0,
  )
  assert_unit("Bq", [dim(types.Time, -1)], 1.0)
  assert_unit("Gy", [dim(types.Length, 2), dim(types.Time, -2)], 1.0)
  assert_unit(
    "kat",
    [dim(types.Time, -1), dim(types.AmountOfSubstance, 1)],
    1.0,
  )
}

pub fn resolves_aliases_to_canonical_debug_and_preserves_original_test() {
  let meters = normalized("meters")
  assert meters.canonical_debug == "m"
  assert meters.original == atom("meters")

  let angstrom = normalized("Å")
  assert angstrom.canonical_debug == "angstrom"
  assert angstrom.dimensions == [dim(types.Length, 1)]
  assert_close(angstrom.scale_to_canonical, 0.0000000001)
}

pub fn removes_zero_powers_and_sorts_dimensions_deterministically_test() {
  let unit = normalized("s*kg/m/s")

  assert unit.dimensions == [dim(types.Length, -1), dim(types.Mass, 1)]
  assert_close(unit.scale_to_canonical, 1.0)
}

pub fn preserves_dimensionless_angle_semantics_for_simple_atoms_test() {
  let degree = normalized("deg")
  assert degree.dimensions == []
  assert degree.semantic == types.Angle
  assert_close(degree.scale_to_canonical, 0.017453292519943295)
}

pub fn stable_debug_summaries_include_dimensions_scale_and_catalog_test() {
  assert normalize.normal_unit_to_debug_string(normalized("cm/s^2"))
    == "NormalUnit(dimensions=[Length^1,Time^-2],scale=0.01,canonical=\"cm/s^2\",catalog=\"units-mvp-2026-05\",semantic=PlainUnit)"
}

pub fn normalization_errors_for_unknown_atoms_are_structured_test() {
  assert normalize.normalize_unit(atom("parsec"))
    == Error(types.UnknownAtom(symbol: "parsec"))
}

pub fn normalization_rejects_extreme_unit_powers_before_scale_work_test() {
  let assert Ok(unit) = parser.parse_unit("m^25")

  assert normalize.normalize_unit(unit)
    == Error(types.InvalidUnitPower(exponent: 25))
}

fn normalized(source: String) -> types.NormalUnit {
  let assert Ok(unit) = parser.parse_unit(source)
  let assert Ok(normal) = normalize.normalize_unit(unit)
  normal
}

fn assert_unit(
  source: String,
  dimensions: List(types.DimensionPower),
  scale_to_canonical: Float,
) -> Nil {
  let normal = normalized(source)
  assert normal.dimensions == dimensions
  assert_close(normal.scale_to_canonical, scale_to_canonical)
}

fn assert_close(actual: Float, expected: Float) -> Nil {
  assert float.absolute_value(actual -. expected) <. 0.000000001
}

fn atom(symbol: String) -> types.UnitExpr {
  types.UnitAtom(symbol: symbol)
}

fn dim(dimension: types.BaseDimension, exponent: Int) -> types.DimensionPower {
  types.DimensionPower(dimension: dimension, exponent: exponent)
}

fn speed_dimensions() -> List(types.DimensionPower) {
  [dim(types.Length, 1), dim(types.Time, -1)]
}

fn acceleration_dimensions() -> List(types.DimensionPower) {
  [dim(types.Length, 1), dim(types.Time, -2)]
}

fn force_dimensions() -> List(types.DimensionPower) {
  [dim(types.Length, 1), dim(types.Mass, 1), dim(types.Time, -2)]
}

fn pressure_dimensions() -> List(types.DimensionPower) {
  [dim(types.Length, -1), dim(types.Mass, 1), dim(types.Time, -2)]
}

fn energy_dimensions() -> List(types.DimensionPower) {
  [dim(types.Length, 2), dim(types.Mass, 1), dim(types.Time, -2)]
}

fn concentration_dimensions() -> List(types.DimensionPower) {
  [dim(types.Length, -3), dim(types.AmountOfSubstance, 1)]
}

fn density_dimensions() -> List(types.DimensionPower) {
  [dim(types.Length, -3), dim(types.Mass, 1)]
}

fn molar_heat_capacity_dimensions() -> List(types.DimensionPower) {
  [
    dim(types.Length, 2),
    dim(types.Mass, 1),
    dim(types.Time, -2),
    dim(types.Temperature, -1),
    dim(types.AmountOfSubstance, -1),
  ]
}

fn voltage_dimensions() -> List(types.DimensionPower) {
  [
    dim(types.Length, 2),
    dim(types.Mass, 1),
    dim(types.Time, -3),
    dim(types.ElectricCurrent, -1),
  ]
}

fn resistance_dimensions() -> List(types.DimensionPower) {
  [
    dim(types.Length, 2),
    dim(types.Mass, 1),
    dim(types.Time, -3),
    dim(types.ElectricCurrent, -2),
  ]
}

fn capacitance_dimensions() -> List(types.DimensionPower) {
  [
    dim(types.Length, -2),
    dim(types.Mass, -1),
    dim(types.Time, 4),
    dim(types.ElectricCurrent, 2),
  ]
}

fn tesla_dimensions() -> List(types.DimensionPower) {
  [dim(types.Mass, 1), dim(types.Time, -2), dim(types.ElectricCurrent, -1)]
}
