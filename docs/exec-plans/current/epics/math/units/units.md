# Unit Support — Informal Technical Approach

## Purpose

This document captures the recommended approach for adding unit support to the Torus Math Expression evaluator.

The central recommendation is:

> Do **not** build units as a hardcoded whitelist of complete compound units like only `m/s`, `cm/s`, `m/s^2`, or `km/hr`. Instead, build a versioned catalog of supported **unit atoms**, parse unit expressions composed from those atoms, normalize them into canonical dimensions and scale factors, and then reuse the existing numeric tolerance machinery after conversion.

This keeps the MVP practical while avoiding a brittle design that would require developers to predefine every possible compound unit.

---

## Core Model

A student answer should eventually parse as either:

```text
Expression
```

or:

```text
Quantity = value expression + unit expression
```

Examples:

```text
9.8 m/s^2
980 cm/s^2
36 km/hr
10 N
```

Internally, this:

```text
9.8 m/s^2
```

should become something conceptually like:

```text
Quantity(
  value: Number(9.8),
  unit: Divide(
    UnitAtom("m"),
    Power(UnitAtom("s"), 2)
  )
)
```

The important design point is that the unit expression is **not normal student algebra**. It should use its own smaller grammar and semantic model.

---

## Unit Catalog, Not Compound-Unit Whitelist

The system should maintain a hardcoded, versioned catalog of supported unit atoms and aliases.

Examples:

```text
m       length, scale 1
cm      length, scale 0.01
km      length, scale 1000
ft      length, scale 0.3048
mile    length, scale 1609.344

s       time, scale 1
sec     time, alias of s
second  time, alias of s
hr      time, scale 3600
hour    alias of hr

kg      mass, scale 1
g       mass, scale 0.001

N       force, dimension kg*m/s^2, scale 1
```

The parser then composes those unit atoms into unit expressions:

```text
m/s
cm/s^2
km/hr
kg*m/s^2
N
```

This gives much more flexibility than hardcoding every compound unit.

Common compound units can still appear as **authoring presets** or autocomplete options:

```text
m/s
cm/s
m/s^2
cm/s^2
km/hr
N
```

But those presets should be UI conveniences only. Under the hood, they should just insert parseable unit strings.

---

## Conversion Model

Each parsed unit expression should normalize to:

```text
dimension vector + scale factor to canonical base units
```

For example:

```text
m/s^2
```

has dimension:

```text
length^1 time^-2
```

and scale:

```text
1
```

because `m` and `s` are canonical base units for length and time.

But:

```text
cm/s^2
```

has the same dimension:

```text
length^1 time^-2
```

with scale:

```text
0.01
```

because:

```text
1 cm = 0.01 m
```

So:

```text
980 cm/s^2
```

converts to canonical value:

```text
980 * 0.01 = 9.8 m/s^2
```

That is how it can match:

```text
9.8 m/s^2
```

Another example:

```text
36 km/hr
```

normalizes as:

```text
36 * (1000 / 3600) = 10 m/s
```

So `36 km/hr` and `10 m/s` are equivalent values if speed units are allowed.

---

## Author Configuration

The author model should stay simple at first.

An author might enter the correct answer as:

```text
9.8 m/s^2
```

Then configure unit behavior:

```text
Units: ignored | required
Accepted units: [m/s^2, cm/s^2]
Conversion: allow conversion among accepted units
```

### Mode 1: Ignore Units

In this mode, the answer is primarily numeric.

Depending on product strictness, these could all be treated as numeric answers:

```text
9.8
9.8 m/s^2
980 cm/s^2
```

This is useful when the prompt already supplies the unit and the answer field is really asking only for the number.

Example prompt:

```text
Enter the acceleration in m/s^2: ___
```

In that case, requiring the student to type `m/s^2` may be unnecessary.

### Mode 2: Require Units with Accepted Unit List

Author config:

```text
expected: 9.8 m/s^2
units: required
accepted: [m/s^2, cm/s^2]
conversion: allowed
```

Student answers:

```text
9.8 m/s^2      correct
980 cm/s^2     correct after conversion
9.8            missing_unit
9.8 ft/s^2     wrong_unit_convertible or unit_not_accepted
9.8 m/s        incompatible_unit
```

This should be the main MVP mode for unit-aware answers.

### Mode 3: Strict Unit / Specific Final Unit

This can be an advanced setting.

Author config:

```text
expected: 9.8 m/s^2
accepted: [m/s^2]
strict: true
```

Student answers:

```text
9.8 m/s^2      correct
980 cm/s^2     wrong_unit_convertible
```

This is useful when the author cares not only about the physical quantity, but also the final unit form.

For example, a physics instructor may want the final answer specifically in `m/s^2`, not merely in any convertible acceleration unit.

---

## Accepted Units Should Be Unit Expressions

The accepted unit list should contain parseable unit expressions:

```text
m/s^2
cm/s^2
N
kg*m/s^2
km/hr
```

Each accepted unit string should be parsed and normalized into a `UnitSpec`.

The author should not be forced to manually construct compound units through rigid numerator/denominator dropdowns. The UI can support typing, autocomplete, presets, or a future builder, but the underlying model should always be the same:

```text
unit string -> UnitExpr -> NormalUnit
```

---

## Recommended Authoring UI

Do not overbuild a complex numerator/denominator unit builder for the MVP.

Use a compact configuration model:

```text
Units:
( ) Ignored
(x) Required

Correct answer:
[ 9.8 m/s^2 ]

Accepted units:
[ m/s^2 ] [ cm/s^2 ] [+ Add unit]

Conversion:
[x] Allow conversion between accepted units

Strict final unit:
[ ] Require a specific unit
```

When the author types an accepted unit such as:

```text
cm/s^2
```

validate it immediately.

Show a small preview or diagnostic:

```text
cm/s^2 is valid
Dimension: length / time^2
Canonical scale: 0.01 m/s^2
```

This gives authors confidence that the unit was interpreted correctly.

---

## Unit Grammar

The unit grammar should be deliberately small.

```text
unit_expr   := unit_term (("*" | "/") unit_term)*
unit_term   := unit_atom ["^" signed_integer]
unit_atom   := known unit symbol or alias
```

Accepted examples:

```text
m
cm
s
m/s
m/s^2
cm/s^2
kg*m/s^2
km/hr
N
```

For MVP, require units to appear as a suffix after whitespace:

```text
9.8 m/s^2
```

Do **not** initially support:

```text
9.8m/s^2
```

Reason: without whitespace, this collides with implicit multiplication and variables. Since the parser already supports expressions like `2x`, `10m` could mean either:

```text
10 * variable m
```

or:

```text
10 meters
```

Requiring whitespace before a unit suffix keeps the grammar sane and avoids ambiguous student input.

---

## Internal Type Sketch

Possible rough Gleam-style types:

```gleam
pub type Quantity {
  Quantity(value: NormalExpr, unit: UnitExpr)
}

pub type UnitExpr {
  UnitAtom(String)
  UnitMultiply(UnitExpr, UnitExpr)
  UnitDivide(UnitExpr, UnitExpr)
  UnitPower(UnitExpr, Int)
}
```

After normalization:

```gleam
pub type NormalUnit {
  NormalUnit(
    dimensions: List(DimensionPower),
    scale_to_canonical: Float,
    canonical_debug: String,
    original: UnitExpr,
  )
}

pub type DimensionPower {
  DimensionPower(dimension: BaseDimension, exponent: Int)
}

pub type BaseDimension {
  Length
  Time
  Mass
  ElectricCurrent
  Temperature
  Amount
  LuminousIntensity
}
```

For MVP, the initial implementation can support only the base dimensions needed by target courses.

A practical first set might be:

```text
Length
Time
Mass
```

That is enough to support:

```text
m
cm
km
ft
mile
s
hr
kg
g
N
m/s
m/s^2
km/hr
```

---

## Conversion Algorithm

Given:

```text
expected: 9.8 m/s^2
student: 980 cm/s^2
```

The evaluator should do this:

```text
1. Parse expected value expression.
2. Parse expected unit expression.
3. Normalize expected unit to dimensions + scale.
4. Evaluate expected numeric value.
5. Convert expected value to canonical value.

6. Parse student value expression.
7. Parse student unit expression.
8. Normalize student unit to dimensions + scale.
9. Evaluate student numeric value.
10. Convert student value to canonical value.

11. Check dimensions are compatible.
12. Check student unit is allowed by accepted-unit policy.
13. Compare canonical numeric values with tolerance.
```

Concrete example:

```text
expected value: 9.8
expected unit: m/s^2
expected scale: 1
expected canonical value: 9.8

student value: 980
student unit: cm/s^2
student scale: 0.01
student canonical value: 9.8
```

Then numeric comparison uses the existing tolerance semantics from the deterministic evaluation/sampling layer.

---

## Result Taxonomy

Unit support should not return only `correct` or `incorrect`.

It needs structured outcomes.

Recommended categories:

```text
Correct
MissingUnit
UnsupportedUnit
IncompatibleUnit
WrongButConvertibleUnit
UnitNotAccepted
NumericMismatchAfterConversion
UnitSyntaxError
```

Examples with:

```text
expected: 9.8 m/s^2
accepted: [m/s^2, cm/s^2]
```

Student:

```text
9.8
```

Result:

```text
MissingUnit
```

Student:

```text
9.8 m/s
```

Result:

```text
IncompatibleUnit
```

Student:

```text
980 cm/s^2
```

Result:

```text
Correct
```

Student:

```text
32.2 ft/s^2
```

If `ft/s^2` is known but not accepted:

```text
WrongButConvertibleUnit
```

or:

```text
UnitNotAccepted
```

depending on the configured policy.

Student:

```text
9.8 mph
```

For an acceleration answer, if `mph` is known as speed:

```text
IncompatibleUnit
```

If `mph` is unknown:

```text
UnsupportedUnit
```

---

## What Should Be Hardcoded?

For MVP, hardcode a **versioned unit atom catalog** in Gleam.

Do not hardcode every compound unit.

A reasonable first catalog:

```text
m, meter, meters
cm, centimeter, centimeters
km, kilometer, kilometers
ft, foot, feet
mile, miles

s, sec, second, seconds
min, minute, minutes
hr, h, hour, hours

kg, kilogram, kilograms
g, gram, grams

N, newton, newtons
```

Each catalog entry should have:

```text
canonical symbol
aliases
dimension vector
scale to canonical base units
```

Derived units like `N` should also be atoms, but their dimension is not primitive:

```text
N = kg*m/s^2
```

This lets the following normalize to the same dimension:

```text
N
kg*m/s^2
```

---

## Avoid in MVP

Do not support these initially:

```text
°C and °F
custom author-defined units
automatic SI prefix inference for every possible unit
complex unit systems
currency
percent as a physical unit
compound units without whitespace after the value
```

The most important reason to avoid Celsius and Fahrenheit at first is that they are not simple multiplicative scale conversions.

For example:

```text
0 °C = 273.15 K
```

That conversion has an offset.

By contrast:

```text
1 cm = 0.01 m
```

is just a scale factor.

For the first unit implementation, stick to multiplicative scale conversions.

---

## Opinionated Recommendation

Use this model:

> Maintain a hardcoded, versioned catalog of supported unit atoms and aliases. Parse unit expressions composed from those atoms using multiplication, division, and integer powers. Normalize every unit expression into canonical dimensions plus a scale factor. Let authors configure accepted unit expressions such as `m/s^2` and `cm/s^2`. Convert student quantities to canonical units, check dimensional compatibility and accepted-unit policy, then compare numeric values using the existing tolerance system.

So:

```text
No: only hardcode m/s, cm/s, m/s^2, km/hr as standalone supported units.

Yes: hardcode m, cm, km, s, hr, kg, N, etc., then parse and normalize m/s, cm/s^2, km/hr, kg*m/s^2, etc.

Also yes: provide common compound units as authoring presets/autocomplete suggestions.
```

This gives the feature a durable architecture without forcing the first UI to become overly complicated.

---

## Suggested Implementation Sequence

1. Add unit atom catalog.
2. Add unit expression parser.
3. Add unit normalization to dimensions plus scale.
4. Add quantity parse result or quantity wrapper.
5. Add accepted-unit config model.
6. Add unit-aware comparison pipeline.
7. Add result taxonomy and targeted unit outcomes.
8. Add author preview diagnostics.
9. Add common unit presets/autocomplete in UI.
10. Add stricter advanced policies later.

---

## Relationship to Existing Math Layers

Unit support should build on the existing layers:

```text
parser
  -> normalization
  -> deterministic evaluation
  -> sampling / tolerance
  -> algebraic equivalence
  -> unit-aware value comparison
```

The expression evaluator should remain responsible for numeric values.

The unit system should be responsible for:

```text
unit syntax
unit normalization
dimension compatibility
unit conversion
unit policy outcomes
```

Do not mix unit conversion deeply into the algebraic expression evaluator. Treat units as a suffix / quantity layer wrapped around a numeric expression.

---

## Open Questions

These do not need to block MVP, but should be decided before production authoring UI work:

1. Should `9.8 m/s^2` be accepted only when there is whitespace before `m`, or should compact `9.8m/s^2` eventually be allowed?
2. Should unknown unit symbols be treated as variables in expression mode, or rejected as unit syntax errors when units are required?
3. Should `ft/s^2` be included in the first catalog?
4. Should `mph` be included as a known alias for `mile/hr`, or avoided initially?
5. How much unit diagnostic detail should be shown to students versus authors?
6. Should the author be allowed to specify “any compatible unit” or only an explicit accepted-unit list?
7. Should strict final-unit mode be included in MVP or held for a later phase?
