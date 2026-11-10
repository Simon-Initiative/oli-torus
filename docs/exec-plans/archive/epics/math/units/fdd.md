# Unit-Aware Math Expression Evaluation - Functional Design Document

## 1. Executive Summary
Implement unit-aware math evaluation as a shared Gleam subsystem under `gleam/src/math/units/`, exposed through the public `torus_math` boundary. The subsystem will parse optional quantity answers, parse and normalize unit expressions from the hard MVP catalog in `supported-units.md`, enforce unit policy, convert compatible quantities to canonical values, and delegate numeric comparison to the existing tolerance primitive.

The design intentionally keeps production grading, persistence, activity JSON, and learner UI unchanged. Existing `torus_math.parse/1` remains expression-focused for backwards compatibility; unit-aware callers use new explicit public APIs such as `parse_quantity_or_expression`, `parse_unit`, `normalize_unit`, `validate_unit_config`, and `compare_quantities`. This satisfies the quantity and catalog requirements without creating parser ambiguity or forcing all existing math callers into unit semantics.

## 2. Requirements & Assumptions
- Functional requirements:
  - Parse pure expressions and whitespace-delimited quantities without accepting ambiguous suffixes such as `9.8m/s^2` (FR-001, AC-001, AC-002, AC-003).
  - Implement the catalog in `supported-units.md` as hard MVP scope, including every atom, alias, explicit prefix, convenience unit, non-SI education unit, and preset fixture (FR-002, AC-004, AC-005, AC-006, AC-024).
  - Parse unit expressions from atoms with multiplication, division, integer powers, and grouping needed for presets such as `J/(mol*K)` (FR-003, AC-007, AC-008).
  - Normalize units to deterministic dimensions and canonical scale factors (FR-004, AC-009, AC-010).
  - Compare quantities through dimensional compatibility, accepted-unit policy, canonical conversion, and existing tolerance semantics (FR-005, AC-011, AC-012, AC-013, AC-014).
  - Represent ignored-units, required-units, accepted-unit expressions, conversion allowance, and strict final-unit policy explicitly (FR-006, AC-015, AC-016, AC-017).
  - Return structured outcomes and stable developer diagnostics (FR-007, AC-018, AC-019).
  - Expose public APIs through `torus_math` and preserve existing math behavior and production boundaries (FR-008, FR-009, AC-020, AC-021, AC-022, AC-023).
- Non-functional requirements:
  - The catalog, parser, normalizer, and comparison pipeline must be deterministic on both Gleam targets.
  - No production telemetry, persistence, or grading behavior changes are part of this FDD.
  - Diagnostics may include source strings in tests and developer tools, but production-safe results should use structured categories, spans, catalog version, dimensions, and scale summaries.
- Assumptions:
  - Unit suffix parsing begins only after a whitespace boundary.
  - Existing expression parsing remains authoritative for value expressions.
  - Multiplicative scale conversion is sufficient for MVP; offset/log/contextual units remain excluded.
  - The primary result for a compatible known unit outside the accepted list is `WrongButConvertibleUnit` when conversion is allowed, and `UnitNotAccepted` when strict final-unit matching or conversion-disabled policy rejects the submitted unit.
  - In ignored-units mode, supported unit suffixes may be ignored after successful parsing; unsupported or malformed suffixes still return structured unit diagnostics rather than being silently stripped.
  - Strict final-unit behavior compares against the accepted-unit entries, not only the expected answer's unit.

## 3. Repository Context Summary
- What we know:
  - Shared math behavior lives in Gleam under `gleam/src/math/` and is exposed to Elixir and browser callers through `gleam/src/torus_math.gleam`.
  - `math/ast.gleam` already reserves `Parsed.Quantity(value: Expr, unit: UnitExpr)` and `UnitExpr` variants for atoms, multiplication, division, and powers.
  - `math/parser.gleam` currently parses ordinary expressions and consumes the whole token stream.
  - `math/sampling/tolerance.gleam` exposes `compare_numbers/3`, which should remain the numeric comparison primitive after unit conversion.
  - Existing math layers include parser, normalization, sampling/evaluation, algebraic equivalence, equality config, exact-form checking, and debug formatting.
  - The PRD constrains this work to the shared math layer. No Ecto schema, publication model, activity JSON, or learner workflow changes are planned.
- Unknowns to confirm:
  - Whether later production integration will use the same public APIs directly or add Elixir/TypeScript wrappers first.
  - Whether authoring UI will store unit config in an existing equality JSON shape or a new activity model field in a later work item.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
Add a `math/units/` subsystem with these modules:

- `math/units/types.gleam`
  - Defines `UnitAtomDefinition`, `UnitKind`, `BaseDimension`, `DimensionPower`, `UnitExpr`, `NormalUnit`, `Quantity`, `UnitConfig`, `AcceptedUnit`, `UnitComparisonResult`, `UnitOutcome`, and error types.
  - Reuses `ast.Expr` for value expressions and `sampling_types.Tolerance` / `ComparisonResult` for numeric tolerance details.

- `math/units/catalog.gleam`
  - Owns the hardcoded catalog from `supported-units.md`.
  - Exposes `catalog_version() -> String`, `lookup(symbol: String)`, `all_entries()`, and preset lists for tests/authoring diagnostics.
  - Stores aliases as explicit entries that resolve to canonical symbols; there is no generic SI-prefix expansion.

- `math/units/parser.gleam`
  - Parses unit-only strings into `types.UnitExpr`.
  - Grammar:
    - `unit_expr := unit_product`
    - `unit_product := unit_power (("*" | "/") unit_power)*`
    - `unit_power := unit_primary ["^" signed_integer]`
    - `unit_primary := unit_atom | "(" unit_expr ")"`
    - `unit_atom := supported catalog symbol or alias`
  - Unit atoms may contain ASCII letters, digits, underscore, and supported Unicode symbols such as `µ`, `Å`, and `Ω`.
  - Returns structured syntax errors and unsupported-atom errors with spans (AC-007, AC-008).

- `math/units/normalize.gleam`
  - Resolves atom aliases, expands derived/convenience atoms, combines dimension powers, multiplies/divides scale factors, applies integer exponents, sorts dimensions deterministically, and removes zero powers.
  - Produces `NormalUnit(dimensions, scale_to_canonical, canonical_debug, original, catalog_version)`.
  - Treats angle units as dimensionless for conversion while preserving optional semantic kind in diagnostics.

- `math/units/quantity.gleam`
  - Exposes `parse_quantity_or_expression(source: String) -> Result(types.ParsedQuantity, types.QuantityParseError)`.
  - First attempts existing `math/parser.parse(source)` on the trimmed full input. If it succeeds, returns a pure expression.
  - If full expression parsing fails, enumerates whitespace split points from right to left, parses the left side with `math/parser.parse`, parses the right side with `math/units/parser.parse_unit`, and returns the first split where both sides succeed.
  - Rejects `9.8m/s^2` as an ordinary expression parse failure, not a quantity, preserving the whitespace rule (AC-003).

- `math/units/config.gleam`
  - Validates `UnitConfig`.
  - Parses and normalizes accepted unit strings once into `AcceptedUnit` values.
  - Checks empty accepted lists, malformed accepted-unit expressions, unsupported atoms, duplicate normalized units, and strict policy consistency.

- `math/units/compare.gleam`
  - Orchestrates expected/source parsing, submitted/source parsing, config validation, unit presence policy, dimensional compatibility, accepted-unit policy, canonical value conversion, and numeric comparison.
  - Evaluates numeric value expressions using existing normalization and evaluator helpers with explicit empty assignment for constant expressions in MVP. Variable-containing quantity comparison returns a structured unsupported-value error unless a later slice defines sampled unit comparison.
  - Calls `sampling_tolerance.compare_numbers(expected_canonical, submitted_canonical, tolerance)`.

- `math/units/format.gleam`
  - Provides stable debug strings for catalog entries, unit parse errors, normalized units, config errors, quantity parse results, and comparison outcomes.
  - Debug strings are for tests and developer tools, not learner-facing copy.

`torus_math.gleam` imports these modules and exposes the public API. Internal modules remain replaceable.

### 4.2 State & Data Flow
Unit-aware comparison flow:

1. Caller supplies expected source, submitted source, `UnitConfig`, and tolerance.
2. `config.validate_unit_config` parses and normalizes accepted unit expressions.
3. `quantity.parse_quantity_or_expression` parses expected and submitted values as pure expressions or quantities.
4. The comparison layer applies unit mode:
   - Ignored: compare numeric values; supported unit suffixes are ignored after parsing.
   - Required: missing submitted units return `MissingUnit`.
5. If units are required, normalize expected and submitted units.
6. Compare dimension vectors. Mismatches return `IncompatibleUnit`.
7. Check accepted-unit policy:
   - If submitted unit matches an accepted normalized unit, continue.
   - If dimensions are compatible but submitted unit is not accepted and conversion is allowed, return `WrongButConvertibleUnit`.
   - If strict or conversion-disabled policy rejects the submitted unit, return `UnitNotAccepted`.
8. Convert numeric values by multiplying by each unit's `scale_to_canonical`.
9. Compare canonical numbers through existing tolerance.
10. Return `Correct` or `NumericMismatchAfterConversion` with tolerance details.

### 4.3 Lifecycle & Ownership
- Catalog entries are code-owned in `math/units/catalog.gleam` and versioned with a constant. Any catalog change must update catalog fixture tests and `supported-units.md` if the scope changes.
- Unit parsing and normalization are pure functions with no runtime state.
- Accepted unit config is caller-owned; the shared math layer validates it but does not persist it.
- No Phoenix, Ecto, publication, delivery, activity, or attempt lifecycle is changed in this work item.

### 4.4 Alternatives Considered
- Modify `torus_math.parse/1` to return `Quantity` automatically:
  - Rejected for MVP. It risks changing current parser behavior and browser/server callers that expect expression-only parsing. Explicit unit-aware APIs preserve backwards compatibility while still using `ast.Quantity` internally.
- Hardcode compound units such as `m/s^2`, `km/hr`, or `mol/L`:
  - Rejected. It violates the PRD and would make accepted-unit growth brittle. Compound examples remain presets and fixtures parsed through the grammar.
- Infer every SI prefix generically:
  - Rejected. `supported-units.md` explicitly requires listed prefixes only to avoid surprising units and symbol collisions.
- Store catalog in database or external config:
  - Rejected. The MVP needs deterministic BEAM/JS behavior and no persistence changes.

## 5. Interfaces
- Public Gleam API additions in `torus_math.gleam`:
  - `unit_catalog_version() -> String`
  - `parse_unit(source: String) -> Result(units_types.UnitExpr, units_types.UnitParseError)`
  - `normalize_unit(unit: units_types.UnitExpr) -> Result(units_types.NormalUnit, units_types.UnitNormalizeError)`
  - `parse_quantity_or_expression(source: String) -> Result(units_types.ParsedQuantity, units_types.QuantityParseError)`
  - `validate_unit_config(config: units_types.UnitConfig) -> Result(units_types.ValidatedUnitConfig, List(units_types.UnitConfigError))`
  - `compare_quantities(expected: String, submitted: String, config: units_types.UnitConfig, tolerance: sampling_types.Tolerance) -> units_types.UnitComparisonResult`
  - `unit_parse_error_to_debug_string(error: units_types.UnitParseError) -> String`
  - `normal_unit_to_debug_string(unit: units_types.NormalUnit) -> String`
  - `unit_comparison_result_to_debug_string(result: units_types.UnitComparisonResult) -> String`

- Proposed core types:

```gleam
pub type ParsedQuantity {
  ParsedExpression(value: ast.Expr)
  ParsedQuantity(value: ast.Expr, unit: UnitExpr)
}

pub type UnitConfig {
  UnitConfig(
    mode: UnitMode,
    accepted_units: List(String),
    conversion: ConversionPolicy,
    final_unit: FinalUnitPolicy,
  )
}

pub type UnitMode {
  IgnoreUnits
  RequireUnits
}

pub type ConversionPolicy {
  AllowConversion
  DisallowConversion
}

pub type FinalUnitPolicy {
  AnyAcceptedUnit
  StrictAcceptedUnit
}

pub type UnitOutcome {
  Correct(comparison: sampling_types.ComparisonResult)
  MissingUnit
  UnsupportedUnit(atom: String)
  IncompatibleUnit(expected: NormalUnit, submitted: NormalUnit)
  WrongButConvertibleUnit(submitted: NormalUnit)
  UnitNotAccepted(submitted: NormalUnit)
  NumericMismatchAfterConversion(comparison: sampling_types.ComparisonResult)
  UnitSyntaxError(error: UnitParseError)
  InvalidUnitConfig(errors: List(UnitConfigError))
  InvalidNumericComparison(error: sampling_types.ComparisonError)
  UnsupportedValueExpression(reason: String)
}

pub type UnitComparisonResult {
  UnitComparisonResult(
    outcome: UnitOutcome,
    expected: Option(ParsedQuantity),
    submitted: Option(ParsedQuantity),
    config: UnitConfig,
  )
}
```

- Elixir and TypeScript wrappers:
  - Not required in this FDD unless a developer prototype slice is added.
  - If added, wrappers must stay thin and call the public `torus_math` API.

## 6. Data Model & Storage
- No database schema changes.
- No Ecto migrations.
- No activity JSON or publication format changes.
- No attempt or scoring persistence changes.
- All new data structures are Gleam types and generated target artifacts.
- Catalog version is a source-code constant. It should appear in normalized-unit diagnostics so test failures can identify catalog drift.

## 7. Consistency & Transactions
- Unit parsing, normalization, config validation, and comparison are pure deterministic functions.
- There are no database transactions or distributed consistency concerns.
- Consistency across BEAM and JavaScript targets is enforced through identical Gleam source, shared tests, and target-stable debug formatting.

## 8. Caching Strategy
- No runtime cache is needed.
- The catalog is static code data. It can be represented as a list and simple lookup functions for MVP.
- If lookup cost becomes visible later, introduce an internal generated lookup helper in Gleam only after benchmark evidence; do not add Cachex or process state for this MVP.

## 9. Performance & Scalability Posture
- Unit parsing is linear in unit-string length for normal input.
- Quantity parsing may attempt multiple whitespace splits. Inputs are short answer strings, so this is acceptable. Implement from right to left and stop at the first successful expression/unit split.
- Unit normalization walks the unit expression tree once and combines dimension powers in a small fixed dimension set.
- Catalog lookup is bounded by the hard MVP catalog size. Tests should include all aliases, but runtime answers remain small.
- Numeric comparison reuses `compare_numbers/3` and should not introduce sampling or algebraic equivalence work for constant quantity comparison.
- Guard against non-finite canonical values after scale multiplication and return a structured comparison/config error rather than passing non-finite values to tolerance comparison.

## 10. Failure Modes & Resilience
- Malformed unit syntax returns `UnitSyntaxError` with span and expected token data (AC-008, AC-018).
- Unknown catalog atoms return `UnsupportedUnit` rather than a generic parse failure (AC-008, AC-018).
- Missing submitted units in required mode return `MissingUnit` (AC-015).
- Dimension mismatch returns `IncompatibleUnit` before numeric comparison (AC-013).
- Known compatible but unaccepted units return `WrongButConvertibleUnit` or `UnitNotAccepted` according to conversion/final-unit policy (AC-017, AC-018).
- Converted numeric mismatch returns `NumericMismatchAfterConversion` with `ComparisonResult` details (AC-014).
- Invalid config returns `InvalidUnitConfig` before parsing submitted answers when possible.
- Existing expression parser failures remain expression parser failures for pure-expression inputs and should not be collapsed into unit errors.

## 11. Observability
- No production telemetry is added in this work item.
- Debug formatters provide deterministic strings for developer tools and tests (AC-019, AC-021).
- Future production telemetry, if added by integration work, should include only outcome categories, catalog version, timing buckets, and normalized dimension summaries. It should not log raw learner expressions or raw accepted unit strings by default (AC-023).

## 12. Security & Privacy
- The subsystem is pure parsing and comparison logic with no authorization surface.
- No raw learner submissions should be logged by the shared layer.
- Public result types should expose structured categories and normalized summaries rather than requiring consumers to inspect raw source.
- Unit aliases with Unicode symbols must be handled as ordinary strings; do not use dynamic atom creation in Elixir wrappers.
- The catalog is source-controlled and hardcoded; there is no author-provided executable code or custom unit definition in MVP.

## 13. Testing Strategy
- Gleam unit tests:
  - `math_units_catalog_test.gleam`: every supported atom, alias, explicit prefix, convenience atom, non-SI atom, and preset from `supported-units.md` is covered (AC-004, AC-005, AC-006, AC-024).
  - `math_units_parser_test.gleam`: atom parsing, multiplication, division, signed integer powers, parentheses, Unicode aliases, malformed operators, malformed powers, empty input, and unsupported atoms (AC-007, AC-008).
  - `math_units_normalization_test.gleam`: dimension sorting, zero-power removal, scale composition, `m/s^2` vs `cm/s^2`, `N` vs `kg*m/s^2`, `mph`, `L`, `M`, and representative SI derived units (AC-009, AC-010).
  - `math_units_quantity_test.gleam`: pure expression parsing, quantity parsing, whitespace boundary, split behavior with spaces inside value expressions, and rejection of `9.8m/s^2` and `10m` as quantities (AC-001, AC-002, AC-003).
  - `math_units_compare_test.gleam`: accepted conversion success, strict final-unit rejection, missing units, ignored-units behavior, incompatible dimensions, unaccepted compatible units, numeric mismatch after conversion, invalid config, and unsupported value expressions (AC-011 through AC-018).
  - `math_units_public_api_test.gleam`: all public `torus_math` unit APIs delegate correctly and callers do not need internal modules (AC-020).
  - `math_units_format_test.gleam`: stable debug strings for parse errors, normalized units, config errors, and comparison results (AC-019, AC-021).
- Cross-target gates:
  - Run `cd gleam && gleam format --check src test`.
  - Run `cd gleam && gleam test --target erlang`.
  - Run `cd gleam && gleam test --target javascript` (AC-021).
- Regression gates:
  - Run existing parser, normalization, sampling, tolerance, algebraic equivalence, exact-form, and equality tests touched by imports or type changes (AC-022).
- Inspection gates:
  - Confirm no database migrations, activity model changes, production grading changes, learner UI changes, or production telemetry are introduced (AC-023).

## 14. Backwards Compatibility
- Existing `torus_math.parse/1`, parser tests, expression normalization, sampling, algebraic equivalence, exact-form, and equality APIs must continue to behave as they do today.
- Unit-aware parsing is opt-in through new public APIs.
- Existing browser wrappers should not import generated modules that pull in browser-incompatible dependencies. If a wrapper is added, bundle verification is required.
- No persisted data changes means no migration, rollback, publication compatibility, or attempt compatibility work is needed.

## 15. Risks & Mitigations
- Broad catalog implementation error: require exhaustive catalog/alias tests generated or manually enumerated from `supported-units.md` (AC-024).
- Ambiguous value/unit split: require whitespace and parse full expression first before trying quantity splits (AC-001, AC-002, AC-003).
- Floating-point conversion drift: cover representative conversions on both targets and route final comparison through existing tolerance logic (AC-011, AC-012, AC-014, AC-021).
- Unit symbol collisions: enforce ambiguity rules from `supported-units.md`; `A` is ampere, `C` is coulomb, `F` is farad, `M` is molarity, and angstrom uses `angstrom` or `Å`.
- Scope creep into offset/log/contextual units: keep Celsius, Fahrenheit, pH, dB, percent, ppm, and ppb out of conversion support.
- Parser regression: keep existing parser API stable and unit parsing opt-in (AC-022).
- Privacy leakage: keep raw source out of production-safe outcomes and avoid telemetry/logging changes (AC-023).

## 16. Open Questions & Follow-ups
- Production integration into activity authoring, delivery, scoring, feedback, and persistence remains a follow-up work item.
- Future UI design for accepted-unit editing, autocomplete, and presets should use `supported-units.md` but is not designed here.
- Future support for offset conversions, context-dependent ratios, custom units, and generic prefix inference is out of scope.
- If sampled unit-aware algebraic comparison is needed for variable expressions, design it as a later extension. MVP quantity comparison supports constant value expressions.

## 17. References
- `docs/exec-plans/current/epics/math/units/prd.md`
- `docs/exec-plans/current/epics/math/units/requirements.yml`
- `docs/exec-plans/current/epics/math/units/supported-units.md`
- `docs/exec-plans/current/epics/math/units/units.md`
- `gleam/src/torus_math.gleam`
- `gleam/src/math/ast.gleam`
- `gleam/src/math/parser.gleam`
- `gleam/src/math/sampling/tolerance.gleam`
- `ARCHITECTURE.md`
- `docs/STACK.md`
- `docs/TOOLING.md`
- `docs/TESTING.md`
- `docs/BACKEND.md`
- `docs/FRONTEND.md`
- `docs/OPERATIONS.md`
- `docs/DESIGN.md`
