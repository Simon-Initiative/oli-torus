import gleam/list
import math/units/types

/// Version for the hardcoded MVP catalog described in `supported-units.md`.
pub fn catalog_version() -> String {
  "units-mvp-2026-05"
}

/// Canonical catalog atoms. Aliases live on each canonical definition.
pub fn all_entries() -> List(types.UnitAtomDefinition) {
  [
    entry(
      "1",
      ["unitless", "dimensionless"],
      [],
      1.0,
      types.BaseUnit,
      types.PlainUnit,
    ),
    entry(
      "rad",
      ["radian", "radians"],
      [],
      1.0,
      types.SiNamedDerived,
      types.Angle,
    ),
    entry(
      "deg",
      ["degree", "degrees"],
      [],
      0.017453292519943295,
      types.AcceptedNonSi,
      types.Angle,
    ),
    entry(
      "rev",
      ["revolution", "revolutions", "turn", "turns"],
      [],
      6.283185307179586,
      types.AcceptedNonSi,
      types.Angle,
    ),
    entry(
      "sr",
      ["steradian", "steradians"],
      [],
      1.0,
      types.SiNamedDerived,
      types.SolidAngle,
    ),
    entry(
      "m",
      ["meter", "meters", "metre", "metres"],
      length(1),
      1.0,
      types.BaseUnit,
      types.PlainUnit,
    ),
    entry(
      "km",
      ["kilometer", "kilometers", "kilometre", "kilometres"],
      length(1),
      1000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "cm",
      ["centimeter", "centimeters", "centimetre", "centimetres"],
      length(1),
      0.01,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "mm",
      ["millimeter", "millimeters", "millimetre", "millimetres"],
      length(1),
      0.001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "um",
      ["micrometer", "micrometers", "micrometre", "micrometres", "µm"],
      length(1),
      0.000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "nm",
      ["nanometer", "nanometers", "nanometre", "nanometres"],
      length(1),
      0.000000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "pm",
      ["picometer", "picometers", "picometre", "picometres"],
      length(1),
      0.000000000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "angstrom",
      ["angstroms", "Å"],
      length(1),
      0.0000000001,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "in",
      ["inch", "inches"],
      length(1),
      0.0254,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "ft",
      ["foot", "feet"],
      length(1),
      0.3048,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "yd",
      ["yard", "yards"],
      length(1),
      0.9144,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "mi",
      ["mile", "miles"],
      length(1),
      1609.344,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "L",
      ["liter", "liters", "litre", "litres", "l"],
      length(3),
      0.001,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "mL",
      ["milliliter", "milliliters", "millilitre", "millilitres", "ml"],
      length(3),
      0.000001,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "uL",
      ["microliter", "microliters", "microlitre", "microlitres", "µL"],
      length(3),
      0.000000001,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "cm3",
      ["cc"],
      length(3),
      0.000001,
      types.ConvenienceAlias,
      types.PlainUnit,
    ),
    entry(
      "gal",
      ["gallon", "gallons"],
      length(3),
      0.003785411784,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "qt",
      ["quart", "quarts"],
      length(3),
      0.000946352946,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "s",
      ["sec", "second", "seconds"],
      time(1),
      1.0,
      types.BaseUnit,
      types.PlainUnit,
    ),
    entry(
      "ms",
      ["millisecond", "milliseconds"],
      time(1),
      0.001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "us",
      ["microsecond", "microseconds", "µs"],
      time(1),
      0.000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "ns",
      ["nanosecond", "nanoseconds"],
      time(1),
      0.000000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "min",
      ["minute", "minutes"],
      time(1),
      60.0,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "h",
      ["hr", "hour", "hours"],
      time(1),
      3600.0,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "d",
      ["day", "days"],
      time(1),
      86_400.0,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "yr",
      ["year", "years"],
      time(1),
      31_557_600.0,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "kg",
      ["kilogram", "kilograms"],
      mass(1),
      1.0,
      types.BaseUnit,
      types.PlainUnit,
    ),
    entry(
      "g",
      ["gram", "grams"],
      mass(1),
      0.001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "mg",
      ["milligram", "milligrams"],
      mass(1),
      0.000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "ug",
      ["microgram", "micrograms", "µg"],
      mass(1),
      0.000000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "ng",
      ["nanogram", "nanograms"],
      mass(1),
      0.000000000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "lb",
      ["lbs", "pound", "pounds"],
      mass(1),
      0.45359237,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "oz",
      ["ounce", "ounces"],
      mass(1),
      0.028349523125,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "u",
      ["amu", "Da", "dalton", "daltons"],
      mass(1),
      0.0000000000000000000000000016605390666,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "mol",
      ["mole", "moles"],
      amount(1),
      1.0,
      types.BaseUnit,
      types.PlainUnit,
    ),
    entry(
      "mmol",
      ["millimole", "millimoles"],
      amount(1),
      0.001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "umol",
      ["micromole", "micromoles", "µmol"],
      amount(1),
      0.000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "nmol",
      ["nanomole", "nanomoles"],
      amount(1),
      0.000000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "K",
      ["kelvin", "kelvins"],
      temperature(1),
      1.0,
      types.BaseUnit,
      types.PlainUnit,
    ),
    entry(
      "A",
      ["ampere", "amperes", "amp", "amps"],
      current(1),
      1.0,
      types.BaseUnit,
      types.PlainUnit,
    ),
    entry(
      "mA",
      ["milliampere", "milliamperes", "milliamp", "milliamps"],
      current(1),
      0.001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "uA",
      ["microampere", "microamperes", "microamp", "microamps", "µA"],
      current(1),
      0.000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "C",
      ["coulomb", "coulombs"],
      dimensions([#(types.ElectricCurrent, 1), #(types.Time, 1)]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "N",
      ["newton", "newtons"],
      dimensions([#(types.Mass, 1), #(types.Length, 1), #(types.Time, -2)]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "dyn",
      ["dyne", "dynes"],
      dimensions([#(types.Mass, 1), #(types.Length, 1), #(types.Time, -2)]),
      0.00001,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "Pa",
      ["pascal", "pascals"],
      dimensions([#(types.Mass, 1), #(types.Length, -1), #(types.Time, -2)]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "kPa",
      ["kilopascal", "kilopascals"],
      dimensions([#(types.Mass, 1), #(types.Length, -1), #(types.Time, -2)]),
      1000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "MPa",
      ["megapascal", "megapascals"],
      dimensions([#(types.Mass, 1), #(types.Length, -1), #(types.Time, -2)]),
      1_000_000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "bar",
      ["bars"],
      dimensions([#(types.Mass, 1), #(types.Length, -1), #(types.Time, -2)]),
      100_000.0,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "mbar",
      ["millibar", "millibars"],
      dimensions([#(types.Mass, 1), #(types.Length, -1), #(types.Time, -2)]),
      100.0,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "atm",
      ["atmosphere", "atmospheres"],
      dimensions([#(types.Mass, 1), #(types.Length, -1), #(types.Time, -2)]),
      101_325.0,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "torr",
      ["Torr"],
      dimensions([#(types.Mass, 1), #(types.Length, -1), #(types.Time, -2)]),
      133.32236842105263,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "mmHg",
      ["millimeter_mercury", "millimeters_mercury"],
      dimensions([#(types.Mass, 1), #(types.Length, -1), #(types.Time, -2)]),
      133.32236842105263,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "psi",
      ["pounds_per_square_inch"],
      dimensions([#(types.Mass, 1), #(types.Length, -1), #(types.Time, -2)]),
      6894.757293168,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "J",
      ["joule", "joules"],
      dimensions([#(types.Mass, 1), #(types.Length, 2), #(types.Time, -2)]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "kJ",
      ["kilojoule", "kilojoules"],
      dimensions([#(types.Mass, 1), #(types.Length, 2), #(types.Time, -2)]),
      1000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "MJ",
      ["megajoule", "megajoules"],
      dimensions([#(types.Mass, 1), #(types.Length, 2), #(types.Time, -2)]),
      1_000_000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "cal",
      ["calorie", "calories"],
      dimensions([#(types.Mass, 1), #(types.Length, 2), #(types.Time, -2)]),
      4.184,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "kcal",
      ["kilocalorie", "kilocalories", "Cal", "food_calorie"],
      dimensions([#(types.Mass, 1), #(types.Length, 2), #(types.Time, -2)]),
      4184.0,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "eV",
      ["electronvolt", "electronvolts"],
      dimensions([#(types.Mass, 1), #(types.Length, 2), #(types.Time, -2)]),
      0.0000000000000000001602176634,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "keV",
      ["kiloelectronvolt", "kiloelectronvolts"],
      dimensions([#(types.Mass, 1), #(types.Length, 2), #(types.Time, -2)]),
      0.0000000000000001602176634,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "MeV",
      ["megaelectronvolt", "megaelectronvolts"],
      dimensions([#(types.Mass, 1), #(types.Length, 2), #(types.Time, -2)]),
      0.0000000000001602176634,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "Wh",
      ["watt_hour", "watt_hours"],
      dimensions([#(types.Mass, 1), #(types.Length, 2), #(types.Time, -2)]),
      3600.0,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "kWh",
      ["kilowatt_hour", "kilowatt_hours"],
      dimensions([#(types.Mass, 1), #(types.Length, 2), #(types.Time, -2)]),
      3_600_000.0,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "W",
      ["watt", "watts"],
      dimensions([#(types.Mass, 1), #(types.Length, 2), #(types.Time, -3)]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "kW",
      ["kilowatt", "kilowatts"],
      dimensions([#(types.Mass, 1), #(types.Length, 2), #(types.Time, -3)]),
      1000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "MW",
      ["megawatt", "megawatts"],
      dimensions([#(types.Mass, 1), #(types.Length, 2), #(types.Time, -3)]),
      1_000_000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry("Hz", ["hertz"], time(-1), 1.0, types.SiNamedDerived, types.PlainUnit),
    entry(
      "kHz",
      ["kilohertz"],
      time(-1),
      1000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "MHz",
      ["megahertz"],
      time(-1),
      1_000_000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "GHz",
      ["gigahertz"],
      time(-1),
      1_000_000_000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "THz",
      ["terahertz"],
      time(-1),
      1_000_000_000_000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "cd",
      ["candela", "candelas"],
      luminous(1),
      1.0,
      types.BaseUnit,
      types.PlainUnit,
    ),
    entry(
      "lm",
      ["lumen", "lumens"],
      luminous(1),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "lx",
      ["lux"],
      dimensions([#(types.LuminousIntensity, 1), #(types.Length, -2)]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "V",
      ["volt", "volts"],
      dimensions([
        #(types.Mass, 1),
        #(types.Length, 2),
        #(types.Time, -3),
        #(types.ElectricCurrent, -1),
      ]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "mV",
      ["millivolt", "millivolts"],
      dimensions([
        #(types.Mass, 1),
        #(types.Length, 2),
        #(types.Time, -3),
        #(types.ElectricCurrent, -1),
      ]),
      0.001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "kV",
      ["kilovolt", "kilovolts"],
      dimensions([
        #(types.Mass, 1),
        #(types.Length, 2),
        #(types.Time, -3),
        #(types.ElectricCurrent, -1),
      ]),
      1000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "ohm",
      ["Ω", "Ohm", "ohms"],
      dimensions([
        #(types.Mass, 1),
        #(types.Length, 2),
        #(types.Time, -3),
        #(types.ElectricCurrent, -2),
      ]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "kohm",
      ["kΩ", "kilohm", "kilohms"],
      dimensions([
        #(types.Mass, 1),
        #(types.Length, 2),
        #(types.Time, -3),
        #(types.ElectricCurrent, -2),
      ]),
      1000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "Mohm",
      ["MΩ", "megaohm", "megaohms"],
      dimensions([
        #(types.Mass, 1),
        #(types.Length, 2),
        #(types.Time, -3),
        #(types.ElectricCurrent, -2),
      ]),
      1_000_000.0,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "S",
      ["siemens"],
      dimensions([
        #(types.Mass, -1),
        #(types.Length, -2),
        #(types.Time, 3),
        #(types.ElectricCurrent, 2),
      ]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "F",
      ["farad", "farads"],
      dimensions([
        #(types.Mass, -1),
        #(types.Length, -2),
        #(types.Time, 4),
        #(types.ElectricCurrent, 2),
      ]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "uF",
      ["microfarad", "microfarads", "µF"],
      dimensions([
        #(types.Mass, -1),
        #(types.Length, -2),
        #(types.Time, 4),
        #(types.ElectricCurrent, 2),
      ]),
      0.000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "nF",
      ["nanofarad", "nanofarads"],
      dimensions([
        #(types.Mass, -1),
        #(types.Length, -2),
        #(types.Time, 4),
        #(types.ElectricCurrent, 2),
      ]),
      0.000000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "pF",
      ["picofarad", "picofarads"],
      dimensions([
        #(types.Mass, -1),
        #(types.Length, -2),
        #(types.Time, 4),
        #(types.ElectricCurrent, 2),
      ]),
      0.000000000001,
      types.ExplicitSiPrefixed,
      types.PlainUnit,
    ),
    entry(
      "H",
      ["henry", "henrys"],
      dimensions([
        #(types.Mass, 1),
        #(types.Length, 2),
        #(types.Time, -2),
        #(types.ElectricCurrent, -2),
      ]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "T",
      ["tesla", "teslas"],
      dimensions([
        #(types.Mass, 1),
        #(types.Time, -2),
        #(types.ElectricCurrent, -1),
      ]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "G",
      ["gauss"],
      dimensions([
        #(types.Mass, 1),
        #(types.Time, -2),
        #(types.ElectricCurrent, -1),
      ]),
      0.0001,
      types.AcceptedNonSi,
      types.PlainUnit,
    ),
    entry(
      "Wb",
      ["weber", "webers"],
      dimensions([
        #(types.Mass, 1),
        #(types.Length, 2),
        #(types.Time, -2),
        #(types.ElectricCurrent, -1),
      ]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "M",
      ["molar", "molarity"],
      dimensions([#(types.AmountOfSubstance, 1), #(types.Length, -3)]),
      1000.0,
      types.ConvenienceAlias,
      types.PlainUnit,
    ),
    entry(
      "mM",
      ["millimolar"],
      dimensions([#(types.AmountOfSubstance, 1), #(types.Length, -3)]),
      1.0,
      types.ConvenienceAlias,
      types.PlainUnit,
    ),
    entry(
      "uM",
      ["micromolar", "µM"],
      dimensions([#(types.AmountOfSubstance, 1), #(types.Length, -3)]),
      0.001,
      types.ConvenienceAlias,
      types.PlainUnit,
    ),
    entry(
      "nM",
      ["nanomolar"],
      dimensions([#(types.AmountOfSubstance, 1), #(types.Length, -3)]),
      0.000001,
      types.ConvenienceAlias,
      types.PlainUnit,
    ),
    entry(
      "Bq",
      ["becquerel", "becquerels"],
      time(-1),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "Gy",
      ["gray", "grays"],
      dimensions([#(types.Length, 2), #(types.Time, -2)]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "Sv",
      ["sievert", "sieverts"],
      dimensions([#(types.Length, 2), #(types.Time, -2)]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "kat",
      ["katal", "katals"],
      dimensions([#(types.AmountOfSubstance, 1), #(types.Time, -1)]),
      1.0,
      types.SiNamedDerived,
      types.PlainUnit,
    ),
    entry(
      "mph",
      ["mile_per_hour", "miles_per_hour"],
      dimensions([#(types.Length, 1), #(types.Time, -1)]),
      0.44704,
      types.ConvenienceAlias,
      types.PlainUnit,
    ),
  ]
}

/// Resolve a canonical symbol or alias to the corresponding catalog definition.
pub fn lookup(
  symbol: String,
) -> Result(types.UnitLookup, types.UnitCatalogError) {
  case
    list.find(in: all_entries(), one_that: fn(definition) {
      definition.canonical_symbol == symbol
      || list.contains(definition.aliases, any: symbol)
    })
  {
    Ok(definition) -> {
      let match = case definition.canonical_symbol == symbol {
        True -> types.CanonicalSymbol
        False -> types.AliasSymbol
      }

      Ok(types.UnitLookup(
        requested_symbol: symbol,
        matched_symbol: symbol,
        definition: definition,
        match: match,
      ))
    }
    Error(_) -> Error(types.UnknownUnitAtom(symbol: symbol))
  }
}

/// Every canonical symbol and alias supported by the catalog.
pub fn all_supported_symbols() -> List(String) {
  all_entries()
  |> list.flat_map(fn(definition) {
    [definition.canonical_symbol, ..definition.aliases]
  })
}

/// Required compound-unit fixtures that later phases parse through the grammar.
pub fn common_compound_presets() -> List(String) {
  [
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

fn entry(
  canonical_symbol: String,
  aliases: List(String),
  dimensions: List(types.DimensionPower),
  scale_to_canonical: Float,
  kind: types.UnitKind,
  semantic: types.UnitSemantic,
) -> types.UnitAtomDefinition {
  types.UnitAtomDefinition(
    canonical_symbol: canonical_symbol,
    aliases: aliases,
    dimensions: dimensions,
    scale_to_canonical: scale_to_canonical,
    kind: kind,
    semantic: semantic,
  )
}

fn length(exponent: Int) -> List(types.DimensionPower) {
  dimensions([#(types.Length, exponent)])
}

fn mass(exponent: Int) -> List(types.DimensionPower) {
  dimensions([#(types.Mass, exponent)])
}

fn time(exponent: Int) -> List(types.DimensionPower) {
  dimensions([#(types.Time, exponent)])
}

fn current(exponent: Int) -> List(types.DimensionPower) {
  dimensions([#(types.ElectricCurrent, exponent)])
}

fn temperature(exponent: Int) -> List(types.DimensionPower) {
  dimensions([#(types.Temperature, exponent)])
}

fn amount(exponent: Int) -> List(types.DimensionPower) {
  dimensions([#(types.AmountOfSubstance, exponent)])
}

fn luminous(exponent: Int) -> List(types.DimensionPower) {
  dimensions([#(types.LuminousIntensity, exponent)])
}

fn dimensions(
  powers: List(#(types.BaseDimension, Int)),
) -> List(types.DimensionPower) {
  list.map(powers, fn(power) {
    let #(dimension, exponent) = power
    types.DimensionPower(dimension: dimension, exponent: exponent)
  })
}
