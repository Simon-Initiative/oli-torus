# Supported Units Catalog - MVP Scope

## Purpose
This file defines the hard MVP unit catalog for `docs/exec-plans/current/epics/math/units`.

The implementation must support this catalog as unit atoms, aliases, dimensions, and multiplicative scale factors. It must not implement supported units as a whitelist of complete compound units. Common compound units listed here are required presets, fixtures, or autocomplete suggestions that must be parsed through the same unit expression grammar as author-entered units.

## Catalog Approach
- The unit model is atom-based: every supported unit has a canonical symbol, aliases, dimension vector, scale-to-canonical factor, and kind.
- Unit expressions are composed from atoms through multiplication, division, and integer powers.
- Accepted unit strings such as `m/s^2`, `kg*m/s^2`, `mol/L`, and `km/hr` are parsed and normalized; they are not special-case compound records.
- The first catalog is intentionally broad enough for first-course physics, chemistry, and math.
- The MVP remains multiplicative-only. Celsius, Fahrenheit, pH, dB, and context-dependent concentration ratios are not supported as conversions in this slice.
- SI prefixes are not inferred generically. Every prefixed unit supported by the MVP must be listed explicitly.

## Base Dimensions
The unit normalizer must support these base dimensions:

| Dimension | Canonical base unit |
| --- | --- |
| Length | `m` |
| Mass | `kg` |
| Time | `s` |
| ElectricCurrent | `A` |
| Temperature | `K` |
| AmountOfSubstance | `mol` |
| LuminousIntensity | `cd` |

Angle may be represented as a semantic dimension tag for diagnostics, but it is dimensionless for conversion math.

## Dimensionless And Angle Units
| Canonical | Aliases | Scale | Kind | Notes |
| --- | --- | ---: | --- | --- |
| `1` | `unitless`, `dimensionless` | 1 | base | Internal and author-facing dimensionless unit. |
| `rad` | `radian`, `radians` | 1 | SI named derived | Dimensionless angle. |
| `deg` | `degree`, `degrees` | pi/180 | accepted non-SI | Degree angle; converts to radians. |
| `rev` | `revolution`, `revolutions`, `turn`, `turns` | 2*pi | accepted non-SI | Useful for angular motion. |
| `sr` | `steradian`, `steradians` | 1 | SI named derived | Dimensionless solid angle. |

Percent is excluded from MVP unit support.

## Length
| Canonical | Aliases | Scale to meter | Kind | Notes |
| --- | --- | ---: | --- | --- |
| `m` | `meter`, `meters`, `metre`, `metres` | 1 | SI base | Canonical length. |
| `km` | `kilometer`, `kilometers`, `kilometre`, `kilometres` | 1000 | explicit SI-prefixed | Required for first-course physics. |
| `cm` | `centimeter`, `centimeters`, `centimetre`, `centimetres` | 0.01 | explicit SI-prefixed | Required for physics and chemistry. |
| `mm` | `millimeter`, `millimeters`, `millimetre`, `millimetres` | 0.001 | explicit SI-prefixed | Required for first-course science. |
| `um` | `micrometer`, `micrometers`, `micrometre`, `micrometres`, `µm` | 1.0e-6 | explicit SI-prefixed | ASCII `um` and Unicode `µm` are both supported aliases. |
| `nm` | `nanometer`, `nanometers`, `nanometre`, `nanometres` | 1.0e-9 | explicit SI-prefixed | Common in chemistry and waves. |
| `pm` | `picometer`, `picometers`, `picometre`, `picometres` | 1.0e-12 | explicit SI-prefixed | Common molecular scale. |
| `angstrom` | `angstroms`, `Å` | 1.0e-10 | accepted non-SI | Do not use plain `A` for angstrom because `A` is ampere. |
| `in` | `inch`, `inches` | 0.0254 | accepted non-SI | Common education/engineering unit. |
| `ft` | `foot`, `feet` | 0.3048 | accepted non-SI | Common physics word problems. |
| `yd` | `yard`, `yards` | 0.9144 | accepted non-SI | Common education unit. |
| `mi` | `mile`, `miles` | 1609.344 | accepted non-SI | Required for `mi/hr` and `mph`. |

## Area And Volume Convenience Atoms
Area and volume expressions such as `m^2`, `cm^3`, and `m^3` should work through powers. The following convenience atoms are also required.

| Canonical | Aliases | Equivalent | Kind | Notes |
| --- | --- | --- | --- | --- |
| `L` | `liter`, `liters`, `litre`, `litres`, `l` | `0.001 m^3` | accepted non-SI | Required for chemistry. |
| `mL` | `milliliter`, `milliliters`, `millilitre`, `millilitres`, `ml` | `1.0e-6 m^3` | accepted non-SI | Required for chemistry. |
| `uL` | `microliter`, `microliters`, `microlitre`, `microlitres`, `µL` | `1.0e-9 m^3` | accepted non-SI | ASCII and Unicode micro aliases required. |
| `cm3` | `cc` | `1.0e-6 m^3` | convenience alias | Equivalent to `1 cm^3` and `1 mL`. |
| `gal` | `gallon`, `gallons` | `0.003785411784 m^3` | accepted non-SI | US gallon only. |
| `qt` | `quart`, `quarts` | `0.000946352946 m^3` | accepted non-SI | US liquid quart only. |

## Time
| Canonical | Aliases | Scale to second | Kind | Notes |
| --- | --- | ---: | --- | --- |
| `s` | `sec`, `second`, `seconds` | 1 | SI base | Canonical time. |
| `ms` | `millisecond`, `milliseconds` | 1.0e-3 | explicit SI-prefixed | Required. |
| `us` | `microsecond`, `microseconds`, `µs` | 1.0e-6 | explicit SI-prefixed | ASCII and Unicode micro aliases required. |
| `ns` | `nanosecond`, `nanoseconds` | 1.0e-9 | explicit SI-prefixed | Required. |
| `min` | `minute`, `minutes` | 60 | accepted non-SI | Required for first-course science. |
| `h` | `hr`, `hour`, `hours` | 3600 | accepted non-SI | Required for `km/hr`, `mi/hr`, and `mph`. |
| `d` | `day`, `days` | 86400 | accepted non-SI | Required. |
| `yr` | `year`, `years` | 31557600 | accepted non-SI | Defined as 365.25 days. |

## Mass
| Canonical | Aliases | Scale to kilogram | Kind | Notes |
| --- | --- | ---: | --- | --- |
| `kg` | `kilogram`, `kilograms` | 1 | SI base | Canonical mass. |
| `g` | `gram`, `grams` | 0.001 | explicit SI-prefixed | Required for chemistry. |
| `mg` | `milligram`, `milligrams` | 1.0e-6 | explicit SI-prefixed | Required. |
| `ug` | `microgram`, `micrograms`, `µg` | 1.0e-9 | explicit SI-prefixed | ASCII and Unicode micro aliases required. |
| `ng` | `nanogram`, `nanograms` | 1.0e-12 | explicit SI-prefixed | Required. |
| `lb` | `lbs`, `pound`, `pounds` | 0.45359237 | accepted non-SI | Treat as mass, not force. |
| `oz` | `ounce`, `ounces` | 0.028349523125 | accepted non-SI | Treat as mass. |
| `u` | `amu`, `Da`, `dalton`, `daltons` | 1.66053906660e-27 | accepted non-SI | Atomic mass unit / dalton. |

## Amount Of Substance
| Canonical | Aliases | Scale to mole | Kind | Notes |
| --- | --- | ---: | --- | --- |
| `mol` | `mole`, `moles` | 1 | SI base | Canonical amount. |
| `mmol` | `millimole`, `millimoles` | 1.0e-3 | explicit SI-prefixed | Required for chemistry. |
| `umol` | `micromole`, `micromoles`, `µmol` | 1.0e-6 | explicit SI-prefixed | ASCII and Unicode micro aliases required. |
| `nmol` | `nanomole`, `nanomoles` | 1.0e-9 | explicit SI-prefixed | Required for chemistry. |

## Temperature
| Canonical | Aliases | Scale | Kind | Notes |
| --- | --- | ---: | --- | --- |
| `K` | `kelvin`, `kelvins` | 1 | SI base | Only temperature unit supported in MVP conversion. |

Celsius and Fahrenheit are excluded because they require offset conversions. Do not treat `C` as Celsius or `F` as Fahrenheit in the MVP; `C` is coulomb and `F` is farad.

## Electric Current And Charge
| Canonical | Aliases | Equivalent | Kind | Notes |
| --- | --- | --- | --- | --- |
| `A` | `ampere`, `amperes`, `amp`, `amps` | SI base current | SI base | Canonical electric current. |
| `mA` | `milliampere`, `milliamperes`, `milliamp`, `milliamps` | `1.0e-3 A` | explicit SI-prefixed | Required. |
| `uA` | `microampere`, `microamperes`, `microamp`, `microamps`, `µA` | `1.0e-6 A` | explicit SI-prefixed | ASCII and Unicode micro aliases required. |
| `C` | `coulomb`, `coulombs` | `A*s` | SI named derived | Charge. |

## Force, Pressure, Energy, And Power
| Canonical | Aliases | Equivalent | Kind | Notes |
| --- | --- | --- | --- | --- |
| `N` | `newton`, `newtons` | `kg*m/s^2` | SI named derived | Force. |
| `dyn` | `dyne`, `dynes` | `1.0e-5 N` | accepted non-SI | CGS force. |
| `Pa` | `pascal`, `pascals` | `N/m^2` | SI named derived | Pressure. |
| `kPa` | `kilopascal`, `kilopascals` | `1000 Pa` | explicit SI-prefixed | Required. |
| `MPa` | `megapascal`, `megapascals` | `1.0e6 Pa` | explicit SI-prefixed | Required. |
| `bar` | `bars` | `1.0e5 Pa` | accepted non-SI | Chemistry and engineering pressure. |
| `mbar` | `millibar`, `millibars` | `100 Pa` | accepted non-SI | Pressure. |
| `atm` | `atmosphere`, `atmospheres` | `101325 Pa` | accepted non-SI | Chemistry pressure. |
| `torr` | `Torr` | `101325/760 Pa` | accepted non-SI | Pressure. |
| `mmHg` | `millimeter_mercury`, `millimeters_mercury` | `101325/760 Pa` | accepted non-SI | Commonly equivalent to torr. |
| `psi` | `pounds_per_square_inch` | `6894.757293168 Pa` | accepted non-SI | Useful in physics/engineering. |
| `J` | `joule`, `joules` | `N*m` | SI named derived | Energy. |
| `kJ` | `kilojoule`, `kilojoules` | `1000 J` | explicit SI-prefixed | Required. |
| `MJ` | `megajoule`, `megajoules` | `1.0e6 J` | explicit SI-prefixed | Required. |
| `cal` | `calorie`, `calories` | `4.184 J` | accepted non-SI | Chemistry energy. |
| `kcal` | `kilocalorie`, `kilocalories`, `Cal`, `food_calorie` | `4184 J` | accepted non-SI | Food calorie / kilocalorie. |
| `eV` | `electronvolt`, `electronvolts` | `1.602176634e-19 J` | accepted non-SI | Physics and chemistry energy. |
| `keV` | `kiloelectronvolt`, `kiloelectronvolts` | `1000 eV` | accepted non-SI | Required. |
| `MeV` | `megaelectronvolt`, `megaelectronvolts` | `1.0e6 eV` | accepted non-SI | Required. |
| `Wh` | `watt_hour`, `watt_hours` | `3600 J` | accepted non-SI | Energy. |
| `kWh` | `kilowatt_hour`, `kilowatt_hours` | `3.6e6 J` | accepted non-SI | Energy. |
| `W` | `watt`, `watts` | `J/s` | SI named derived | Power. |
| `kW` | `kilowatt`, `kilowatts` | `1000 W` | explicit SI-prefixed | Required. |
| `MW` | `megawatt`, `megawatts` | `1.0e6 W` | explicit SI-prefixed | Required. |

## Frequency, Wave, And Light
| Canonical | Aliases | Equivalent | Kind | Notes |
| --- | --- | --- | --- | --- |
| `Hz` | `hertz` | `1/s` | SI named derived | Frequency. |
| `kHz` | `kilohertz` | `1000 Hz` | explicit SI-prefixed | Required. |
| `MHz` | `megahertz` | `1.0e6 Hz` | explicit SI-prefixed | Required. |
| `GHz` | `gigahertz` | `1.0e9 Hz` | explicit SI-prefixed | Required. |
| `THz` | `terahertz` | `1.0e12 Hz` | explicit SI-prefixed | Required. |
| `cd` | `candela`, `candelas` | SI base luminous intensity | SI base | Included for complete SI base coverage. |
| `lm` | `lumen`, `lumens` | `cd*sr` | SI named derived | Luminous flux. |
| `lx` | `lux` | `lm/m^2` | SI named derived | Illuminance. |

## Electricity And Magnetism
| Canonical | Aliases | Equivalent | Kind | Notes |
| --- | --- | --- | --- | --- |
| `V` | `volt`, `volts` | `W/A` | SI named derived | Electric potential. |
| `mV` | `millivolt`, `millivolts` | `1.0e-3 V` | explicit SI-prefixed | Required. |
| `kV` | `kilovolt`, `kilovolts` | `1000 V` | explicit SI-prefixed | Required. |
| `ohm` | `Ω`, `Ohm`, `ohms` | `V/A` | SI named derived | Electric resistance. |
| `kohm` | `kΩ`, `kilohm`, `kilohms` | `1000 ohm` | explicit SI-prefixed | Required. |
| `Mohm` | `MΩ`, `megaohm`, `megaohms` | `1.0e6 ohm` | explicit SI-prefixed | Required. |
| `S` | `siemens` | `A/V` | SI named derived | Conductance. |
| `F` | `farad`, `farads` | `C/V` | SI named derived | Capacitance. |
| `uF` | `microfarad`, `microfarads`, `µF` | `1.0e-6 F` | explicit SI-prefixed | Required. |
| `nF` | `nanofarad`, `nanofarads` | `1.0e-9 F` | explicit SI-prefixed | Required. |
| `pF` | `picofarad`, `picofarads` | `1.0e-12 F` | explicit SI-prefixed | Required. |
| `H` | `henry`, `henrys` | `Wb/A` | SI named derived | Inductance. |
| `T` | `tesla`, `teslas` | `Wb/m^2` | SI named derived | Magnetic flux density. |
| `G` | `gauss` | `1.0e-4 T` | accepted non-SI | Common in magnetism. |
| `Wb` | `weber`, `webers` | `V*s` | SI named derived | Magnetic flux. |

## Chemistry Concentration And Density Convenience Units
These convenience atoms are required because first-course chemistry authors and students expect them. They normalize to amount-per-volume or mass-per-volume dimensions.

| Canonical | Aliases | Equivalent | Kind | Notes |
| --- | --- | --- | --- | --- |
| `M` | `molar`, `molarity` | `mol/L` | convenience alias | Molar concentration. |
| `mM` | `millimolar` | `1.0e-3 mol/L` | convenience alias | Required. |
| `uM` | `micromolar`, `µM` | `1.0e-6 mol/L` | convenience alias | ASCII and Unicode micro aliases required. |
| `nM` | `nanomolar` | `1.0e-9 mol/L` | convenience alias | Required. |

The following must work through the general unit grammar, not as separate compound atoms: `mol/L`, `mol/m^3`, `g/L`, `mg/L`, `g/mL`, `kg/m^3`.

`ppm` and `ppb` are excluded from MVP support because they are context-dependent.

## Radioactivity, Radiation, And Catalysis
| Canonical | Aliases | Equivalent | Kind | Notes |
| --- | --- | --- | --- | --- |
| `Bq` | `becquerel`, `becquerels` | `1/s` | SI named derived | Radioactivity. |
| `Gy` | `gray`, `grays` | `J/kg` | SI named derived | Absorbed dose. |
| `Sv` | `sievert`, `sieverts` | `J/kg` | SI named derived | Dose equivalent. |
| `kat` | `katal`, `katals` | `mol/s` | SI named derived | Catalytic activity. |

## Required Speed Convenience Atom
| Canonical | Aliases | Equivalent | Kind | Notes |
| --- | --- | --- | --- | --- |
| `mph` | `mile_per_hour`, `miles_per_hour` | `mi/hr` | convenience alias | Required because it is common in introductory physics and is multiplicative. Scale is `0.44704 m/s`. |

The general grammar must also support `mi/hr`, `mile/hr`, and `miles/hour` from existing atoms and aliases.

## Required Common Compound Presets
These are required authoring presets, autocomplete suggestions, or test fixtures. They must be parsed by the same unit grammar and must not bypass catalog normalization.

```text
m/s
m/s^2
cm/s
cm/s^2
km/hr
mi/hr
mph
ft/s
ft/s^2

kg*m/s^2
N
N*m
J
J/s
W

Pa
kPa
atm
bar
torr
mmHg

mol/L
M
mM
uM
g/L
mg/L
g/mL
kg/m^3

J/mol
kJ/mol
cal/mol
kcal/mol
J/(mol*K)
L*atm
```

## Explicit MVP Exclusions
These entries must not be supported as multiplicative unit conversions in the MVP:

| Excluded unit or family | Reason |
| --- | --- |
| Celsius / `degC` / degree Celsius | Requires offset conversion. |
| Fahrenheit / `degF` / degree Fahrenheit | Requires offset conversion. |
| `pH` | Logarithmic and context-specific. |
| `dB` | Logarithmic and context-specific. |
| `ppm`, `ppb` | Context-dependent ratio semantics. |
| `%` | Ratio/form feature, not a physical unit in this MVP. |
| Currency | Not a physical unit domain. |
| Custom author-defined units | Out of scope for MVP. |
| Automatic SI prefix inference | Explicitly list supported prefixed atoms instead. |

## Ambiguity Rules
- `A` means ampere, not angstrom. Use `angstrom` or `Å` for angstrom.
- `C` means coulomb, not Celsius.
- `F` means farad, not Fahrenheit.
- `T` means tesla inside the unit parser. It remains an expression variable outside the unit suffix.
- `M` means molarity inside the unit parser. It is not generic mega-prefix inference.
- Unit suffix parsing is separate from expression parsing and only begins after the required whitespace boundary.
