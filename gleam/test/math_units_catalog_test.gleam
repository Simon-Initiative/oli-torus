import gleam/float
import gleam/list
import gleeunit
import math/units/catalog
import math/units/types

pub fn main() {
  gleeunit.main()
}

pub fn catalog_version_and_inventory_are_exposed_test() {
  assert catalog.catalog_version() == "units-mvp-2026-05"
  assert list.length(catalog.all_entries()) == 104
  assert list.length(catalog.common_compound_presets()) == 35
}

pub fn catalog_includes_all_required_symbols_and_aliases_test() {
  list.each(required_supported_symbols(), fn(symbol) {
    assert_supported(symbol)
  })
}

pub fn common_compound_presets_are_inventory_fixtures_test() {
  assert catalog.common_compound_presets()
    == [
      "m/s",
      "m/s^2",
      "cm/s",
      "cm/s^2",
      "km/hr",
      "mi/hr",
      "mph",
      "ft/s",
      "ft/s^2",
      "kg*m/s^2",
      "N",
      "N*m",
      "J",
      "J/s",
      "W",
      "Pa",
      "kPa",
      "atm",
      "bar",
      "torr",
      "mmHg",
      "mol/L",
      "M",
      "mM",
      "uM",
      "g/L",
      "mg/L",
      "g/mL",
      "kg/m^3",
      "J/mol",
      "kJ/mol",
      "cal/mol",
      "kcal/mol",
      "J/(mol*K)",
      "L*atm",
    ]
}

pub fn core_catalog_examples_have_expected_dimensions_and_scales_test() {
  assert_unit("m", [types.DimensionPower(types.Length, 1)], 1.0)
  assert_unit("cm", [types.DimensionPower(types.Length, 1)], 0.01)
  assert_unit("ft", [types.DimensionPower(types.Length, 1)], 0.3048)
  assert_unit("mi", [types.DimensionPower(types.Length, 1)], 1609.344)
  assert_unit("s", [types.DimensionPower(types.Time, 1)], 1.0)
  assert_unit("min", [types.DimensionPower(types.Time, 1)], 60.0)
  assert_unit("h", [types.DimensionPower(types.Time, 1)], 3600.0)
  assert_unit("kg", [types.DimensionPower(types.Mass, 1)], 1.0)
  assert_unit("g", [types.DimensionPower(types.Mass, 1)], 0.001)
  assert_unit("L", [types.DimensionPower(types.Length, 3)], 0.001)
  assert_unit(
    "M",
    [
      types.DimensionPower(types.AmountOfSubstance, 1),
      types.DimensionPower(types.Length, -3),
    ],
    1000.0,
  )
  assert_unit(
    "N",
    [
      types.DimensionPower(types.Mass, 1),
      types.DimensionPower(types.Length, 1),
      types.DimensionPower(types.Time, -2),
    ],
    1.0,
  )
  assert_unit(
    "Pa",
    [
      types.DimensionPower(types.Mass, 1),
      types.DimensionPower(types.Length, -1),
      types.DimensionPower(types.Time, -2),
    ],
    1.0,
  )
  assert_unit(
    "J",
    [
      types.DimensionPower(types.Mass, 1),
      types.DimensionPower(types.Length, 2),
      types.DimensionPower(types.Time, -2),
    ],
    1.0,
  )
  assert_unit(
    "W",
    [
      types.DimensionPower(types.Mass, 1),
      types.DimensionPower(types.Length, 2),
      types.DimensionPower(types.Time, -3),
    ],
    1.0,
  )
  assert_unit("Hz", [types.DimensionPower(types.Time, -1)], 1.0)
  assert_unit("A", [types.DimensionPower(types.ElectricCurrent, 1)], 1.0)
  assert_unit(
    "C",
    [
      types.DimensionPower(types.ElectricCurrent, 1),
      types.DimensionPower(types.Time, 1),
    ],
    1.0,
  )
  assert_unit(
    "V",
    [
      types.DimensionPower(types.Mass, 1),
      types.DimensionPower(types.Length, 2),
      types.DimensionPower(types.Time, -3),
      types.DimensionPower(types.ElectricCurrent, -1),
    ],
    1.0,
  )
  assert_unit("Bq", [types.DimensionPower(types.Time, -1)], 1.0)
  assert_unit(
    "Gy",
    [
      types.DimensionPower(types.Length, 2),
      types.DimensionPower(types.Time, -2),
    ],
    1.0,
  )
  assert_unit(
    "mph",
    [
      types.DimensionPower(types.Length, 1),
      types.DimensionPower(types.Time, -1),
    ],
    0.44704,
  )
}

pub fn ambiguous_symbols_follow_mvp_rules_test() {
  let assert Ok(ampere) = catalog.lookup("A")
  assert ampere.definition.canonical_symbol == "A"
  assert ampere.definition.dimensions
    == [types.DimensionPower(types.ElectricCurrent, 1)]

  let assert Ok(angstrom) = catalog.lookup("Å")
  assert angstrom.definition.canonical_symbol == "angstrom"

  let assert Ok(coulomb) = catalog.lookup("C")
  assert coulomb.definition.canonical_symbol == "C"

  let assert Ok(farad) = catalog.lookup("F")
  assert farad.definition.canonical_symbol == "F"
}

pub fn aliases_resolve_to_canonical_entries_test() {
  let assert Ok(meter) = catalog.lookup("meters")
  assert meter.match == types.AliasSymbol
  assert meter.definition.canonical_symbol == "m"

  let assert Ok(micro_liter) = catalog.lookup("µL")
  assert micro_liter.definition.canonical_symbol == "uL"

  let assert Ok(ohm) = catalog.lookup("Ω")
  assert ohm.definition.canonical_symbol == "ohm"

  let assert Ok(miles_per_hour) = catalog.lookup("miles_per_hour")
  assert miles_per_hour.definition.canonical_symbol == "mph"
}

fn assert_supported(symbol: String) -> Nil {
  let assert Ok(_) = catalog.lookup(symbol)
  Nil
}

fn assert_unit(
  symbol: String,
  dimensions: List(types.DimensionPower),
  scale_to_canonical: Float,
) -> Nil {
  let assert Ok(found) = catalog.lookup(symbol)
  assert found.definition.dimensions == dimensions
  assert_close(found.definition.scale_to_canonical, scale_to_canonical)
}

fn assert_close(actual: Float, expected: Float) -> Nil {
  assert float.absolute_value(actual -. expected) <. 0.000000000001
}

fn required_supported_symbols() -> List(String) {
  [
    "1",
    "unitless",
    "dimensionless",
    "rad",
    "radian",
    "radians",
    "deg",
    "degree",
    "degrees",
    "rev",
    "revolution",
    "revolutions",
    "turn",
    "turns",
    "sr",
    "steradian",
    "steradians",
    "m",
    "meter",
    "meters",
    "metre",
    "metres",
    "km",
    "kilometer",
    "kilometers",
    "kilometre",
    "kilometres",
    "cm",
    "centimeter",
    "centimeters",
    "centimetre",
    "centimetres",
    "mm",
    "millimeter",
    "millimeters",
    "millimetre",
    "millimetres",
    "um",
    "micrometer",
    "micrometers",
    "micrometre",
    "micrometres",
    "µm",
    "nm",
    "nanometer",
    "nanometers",
    "nanometre",
    "nanometres",
    "pm",
    "picometer",
    "picometers",
    "picometre",
    "picometres",
    "angstrom",
    "angstroms",
    "Å",
    "in",
    "inch",
    "inches",
    "ft",
    "foot",
    "feet",
    "yd",
    "yard",
    "yards",
    "mi",
    "mile",
    "miles",
    "L",
    "liter",
    "liters",
    "litre",
    "litres",
    "l",
    "mL",
    "milliliter",
    "milliliters",
    "millilitre",
    "millilitres",
    "ml",
    "uL",
    "microliter",
    "microliters",
    "microlitre",
    "microlitres",
    "µL",
    "cm3",
    "cc",
    "gal",
    "gallon",
    "gallons",
    "qt",
    "quart",
    "quarts",
    "s",
    "sec",
    "second",
    "seconds",
    "ms",
    "millisecond",
    "milliseconds",
    "us",
    "microsecond",
    "microseconds",
    "µs",
    "ns",
    "nanosecond",
    "nanoseconds",
    "min",
    "minute",
    "minutes",
    "h",
    "hr",
    "hour",
    "hours",
    "d",
    "day",
    "days",
    "yr",
    "year",
    "years",
    "kg",
    "kilogram",
    "kilograms",
    "g",
    "gram",
    "grams",
    "mg",
    "milligram",
    "milligrams",
    "ug",
    "microgram",
    "micrograms",
    "µg",
    "ng",
    "nanogram",
    "nanograms",
    "lb",
    "lbs",
    "pound",
    "pounds",
    "oz",
    "ounce",
    "ounces",
    "u",
    "amu",
    "Da",
    "dalton",
    "daltons",
    "mol",
    "mole",
    "moles",
    "mmol",
    "millimole",
    "millimoles",
    "umol",
    "micromole",
    "micromoles",
    "µmol",
    "nmol",
    "nanomole",
    "nanomoles",
    "K",
    "kelvin",
    "kelvins",
    "A",
    "ampere",
    "amperes",
    "amp",
    "amps",
    "mA",
    "milliampere",
    "milliamperes",
    "milliamp",
    "milliamps",
    "uA",
    "microampere",
    "microamperes",
    "microamp",
    "microamps",
    "µA",
    "C",
    "coulomb",
    "coulombs",
    "N",
    "newton",
    "newtons",
    "dyn",
    "dyne",
    "dynes",
    "Pa",
    "pascal",
    "pascals",
    "kPa",
    "kilopascal",
    "kilopascals",
    "MPa",
    "megapascal",
    "megapascals",
    "bar",
    "bars",
    "mbar",
    "millibar",
    "millibars",
    "atm",
    "atmosphere",
    "atmospheres",
    "torr",
    "Torr",
    "mmHg",
    "millimeter_mercury",
    "millimeters_mercury",
    "psi",
    "pounds_per_square_inch",
    "J",
    "joule",
    "joules",
    "kJ",
    "kilojoule",
    "kilojoules",
    "MJ",
    "megajoule",
    "megajoules",
    "cal",
    "calorie",
    "calories",
    "kcal",
    "kilocalorie",
    "kilocalories",
    "Cal",
    "food_calorie",
    "eV",
    "electronvolt",
    "electronvolts",
    "keV",
    "kiloelectronvolt",
    "kiloelectronvolts",
    "MeV",
    "megaelectronvolt",
    "megaelectronvolts",
    "Wh",
    "watt_hour",
    "watt_hours",
    "kWh",
    "kilowatt_hour",
    "kilowatt_hours",
    "W",
    "watt",
    "watts",
    "kW",
    "kilowatt",
    "kilowatts",
    "MW",
    "megawatt",
    "megawatts",
    "Hz",
    "hertz",
    "kHz",
    "kilohertz",
    "MHz",
    "megahertz",
    "GHz",
    "gigahertz",
    "THz",
    "terahertz",
    "cd",
    "candela",
    "candelas",
    "lm",
    "lumen",
    "lumens",
    "lx",
    "lux",
    "V",
    "volt",
    "volts",
    "mV",
    "millivolt",
    "millivolts",
    "kV",
    "kilovolt",
    "kilovolts",
    "ohm",
    "Ω",
    "Ohm",
    "ohms",
    "kohm",
    "kΩ",
    "kilohm",
    "kilohms",
    "Mohm",
    "MΩ",
    "megaohm",
    "megaohms",
    "S",
    "siemens",
    "F",
    "farad",
    "farads",
    "uF",
    "microfarad",
    "microfarads",
    "µF",
    "nF",
    "nanofarad",
    "nanofarads",
    "pF",
    "picofarad",
    "picofarads",
    "H",
    "henry",
    "henrys",
    "T",
    "tesla",
    "teslas",
    "G",
    "gauss",
    "Wb",
    "weber",
    "webers",
    "M",
    "molar",
    "molarity",
    "mM",
    "millimolar",
    "uM",
    "micromolar",
    "µM",
    "nM",
    "nanomolar",
    "Bq",
    "becquerel",
    "becquerels",
    "Gy",
    "gray",
    "grays",
    "Sv",
    "sievert",
    "sieverts",
    "kat",
    "katal",
    "katals",
    "mph",
    "mile_per_hour",
    "miles_per_hour",
  ]
}
