# Unit-Aware Math Expression Evaluation - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/math/units/prd.md`
- FDD: `docs/exec-plans/current/epics/math/units/fdd.md`
- Required catalog: `docs/exec-plans/current/epics/math/units/supported-units.md`
- Traceability: `docs/exec-plans/current/epics/math/units/requirements.yml`

## Scope
Deliver the shared Gleam unit-aware math subsystem described in the PRD and FDD. The implementation covers quantity parsing, the full required MVP unit catalog, unit expression parsing, normalization, unit policy validation, constant quantity comparison, stable diagnostics, and public `torus_math` APIs for BEAM and JavaScript callers.

This plan does not include production grading integration, activity JSON changes, database migrations, learner UI changes, authoring UI configuration, or telemetry changes. Those remain outside this work item unless a later exec-plan explicitly scopes them.

## Clarifications & Default Assumptions
- `supported-units.md` is a hard MVP requirement, not guidance. Every listed atom, alias, explicit prefixed unit, convenience unit, selected non-SI unit, and common compound preset must be implemented or covered by automated catalog/preset tests.
- Existing `torus_math.parse/1` remains expression-focused. Unit-aware behavior is exposed through explicit new public APIs.
- Quantity parsing requires whitespace between the value expression and unit expression. Inputs such as `9.8m/s^2` and `10m` are rejected as MVP quantities.
- MVP quantity comparison evaluates constant value expressions only. Variable-sampled unit comparison is deferred and must return a structured unsupported-value outcome if encountered.
- Celsius, Fahrenheit, pH, dB, contextual `ppm`/`ppb`, and unlisted SI-prefix expansion remain excluded because they break or exceed the multiplicative-only MVP.

## Phase 1: Unit Types, Catalog, and Fixtures
- Goal: Establish the unit subsystem type boundary and implement the full hardcoded MVP catalog from `supported-units.md`.
- Tasks:
  - [ ] Add `gleam/src/math/units/types.gleam` with catalog, dimension, unit expression, normalized unit, quantity, config, comparison, and diagnostic result types.
  - [ ] Add `gleam/src/math/units/catalog.gleam` with `catalog_version`, canonical entries, aliases, explicit prefixed variants, convenience units, non-SI educational units, and preset fixture strings.
  - [ ] Represent dimensions deterministically using the seven SI base dimensions plus angle semantics where needed while treating angle as dimensionless for conversion.
  - [ ] Encode derived atoms through dimension vectors and scale-to-canonical factors rather than a whitelist of compound units.
  - [ ] Keep ambiguous symbols aligned with `supported-units.md`: `A` is ampere, `C` is coulomb, `F` is farad, and angstrom uses `angstrom`/`Å`, not plain `A`.
- Testing Tasks:
  - [ ] Add `gleam/test/math_units_catalog_test.gleam` with catalog coverage for all supported atoms, aliases, explicit prefixes, convenience units, selected non-SI units, and common compound preset strings.
  - [ ] Assert core catalog examples for length, time, mass, force, `mph`, liter, molarity, pressure, energy, electricity, and radiation units.
  - Command(s): `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`
- Definition of Done:
  - The catalog exports deterministic entries and test-visible preset fixtures.
  - Catalog tests prove coverage for the full `supported-units.md` MVP inventory.
  - FR-002, AC-004, AC-005, AC-006, and AC-024 are satisfied at the catalog layer.
- Gate:
  - Gate A passes when every `supported-units.md` unit entry has an implementation-backed catalog assertion or an explicit preset assertion.
- Dependencies:
  - None.
- Parallelizable Work:
  - Catalog data entry and catalog coverage test authoring can proceed in parallel once the type skeleton is in place.

## Phase 2: Unit Expression Parser
- Goal: Parse unit-only strings from catalog atoms using multiplication, division, signed integer powers, and grouping.
- Tasks:
  - [ ] Add `gleam/src/math/units/parser.gleam` using the grammar from the FDD.
  - [ ] Support atom characters required by the catalog, including ASCII names, digits, underscores, `µ`, `Å`, and `Ω`.
  - [ ] Return structured syntax errors, unsupported-atom errors, spans, and expected-token diagnostics.
  - [ ] Parse compound preset strings through the same grammar used for submitted answers.
- Testing Tasks:
  - [ ] Add parser tests for `m`, `cm`, `s`, `m/s`, `m/s^2`, `cm/s^2`, `kg*m/s^2`, `km/hr`, `N`, `J/(mol*K)`, `mol/L`, and `mph`.
  - [ ] Add negative tests for unsupported atoms, empty strings, malformed operators, malformed powers, unbalanced parentheses, and malformed Unicode aliases.
  - Command(s): `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Unit parsing succeeds for required simple and compound unit expressions.
  - Unit parsing failures are structured and stable enough for public diagnostics.
  - FR-003, AC-007, and AC-008 are satisfied.
- Gate:
  - Gate B passes when every required parser success and failure fixture is covered on both Gleam targets.
- Dependencies:
  - Phase 1 catalog lookup and unit expression types.
- Parallelizable Work:
  - Negative parser fixtures can be written in parallel with parser implementation after the error type names are stable.

## Phase 3: Unit Normalization
- Goal: Convert parsed unit expressions into deterministic dimensions, canonical scale factors, and stable debug summaries.
- Tasks:
  - [ ] Add `gleam/src/math/units/normalize.gleam`.
  - [ ] Resolve aliases to canonical atoms and expand derived/convenience atoms through catalog definitions.
  - [ ] Combine dimension powers, apply multiplication/division/exponents, remove zero powers, and sort dimensions deterministically.
  - [ ] Compose scale-to-canonical factors for all multiplicative units, including `cm/s^2`, `N`, `kg*m/s^2`, `km/hr`, `mph`, `M`, `L*atm`, and `J/(mol*K)`.
  - [ ] Detect non-finite or otherwise invalid scale composition and return structured normalization diagnostics.
- Testing Tasks:
  - [ ] Add normalization tests for equivalent dimensions with different scales, including `m/s^2` versus `cm/s^2`, `N` versus `kg*m/s^2`, `10 m/s`-style speed units, pressure, energy, concentration, and electric units.
  - [ ] Assert deterministic dimension ordering and debug summaries on both targets.
  - Command(s): `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Normalization produces target-stable dimensions and scale factors for catalog atoms, aliases, and compounds.
  - FR-004, AC-009, and AC-010 are satisfied.
- Gate:
  - Gate C passes when equivalent-unit normalization fixtures agree by dimensions and expected scale relationships.
- Dependencies:
  - Phases 1 and 2.
- Parallelizable Work:
  - Expected normalization fixtures can be expanded while parser coverage is being finalized.

## Phase 4: Quantity Parsing and Config Validation
- Goal: Add explicit quantity parsing and validated unit policy configuration.
- Tasks:
  - [ ] Add `gleam/src/math/units/quantity.gleam` with `parse_quantity_or_expression`.
  - [ ] Preserve pure numeric expression parsing for inputs such as `9.8`.
  - [ ] Implement right-to-left whitespace split parsing so `9.8 m/s^2` is a quantity and `9.8m/s^2` is rejected.
  - [ ] Add `gleam/src/math/units/config.gleam` with validation for ignored-units mode, required-units mode, accepted unit expressions, conversion allowance, and strict final-unit behavior.
  - [ ] Normalize accepted-unit config once and report malformed, unsupported, duplicate, empty, and inconsistent config errors.
- Testing Tasks:
  - [ ] Add quantity parser tests for pure expressions, whitespace-delimited quantities, expression-valued quantities, and no-whitespace rejections.
  - [ ] Add config validation tests for accepted lists, conversion-disabled policy, strict final-unit policy, malformed accepted units, and unsupported accepted units.
  - Command(s): `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Quantity and config APIs are deterministic and preserve existing expression parsing behavior.
  - FR-001, FR-006, AC-001, AC-002, AC-003, AC-015, AC-016, and AC-017 are satisfied at the parsing/config layer.
- Gate:
  - Gate D passes when quantity/config tests prove whitespace semantics and all MVP policy modes.
- Dependencies:
  - Phases 1 through 3 and the existing expression parser.
- Parallelizable Work:
  - Config validation tests can proceed alongside quantity parser work after normalized accepted-unit types exist.

## Phase 5: Quantity Comparison Pipeline
- Goal: Compare constant unit-aware quantities through dimensional compatibility, accepted-unit policy, canonical conversion, and existing tolerance semantics.
- Tasks:
  - [ ] Add `gleam/src/math/units/compare.gleam`.
  - [ ] Parse expected and submitted sources through the quantity parser and validate unit config before comparison.
  - [ ] Implement ignored-units behavior, required-units missing-unit behavior, incompatible-unit detection, accepted-unit enforcement, wrong-but-convertible outcomes, strict final-unit rejection, and numeric mismatch after conversion.
  - [ ] Evaluate constant value expressions using existing math evaluation helpers and compare canonical values with the existing tolerance primitive.
  - [ ] Return a structured unsupported-value outcome for variable-containing quantity expressions in MVP.
- Testing Tasks:
  - [ ] Add comparison tests for `9.8 m/s^2` versus `980 cm/s^2`, `10 m/s` versus `36 km/hr`, acceleration versus speed, wrong converted values, missing submitted units, strict final-unit rejection, ignored-units behavior, unsupported unit atoms, unit syntax errors, and invalid config.
  - [ ] Assert tolerance detail propagation for numeric mismatch after conversion.
  - Command(s): `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`
- Definition of Done:
  - The comparison pipeline returns every required structured category and delegates numeric tolerance consistently.
  - FR-005, FR-007, AC-011, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, and AC-018 are satisfied.
- Gate:
  - Gate E passes when all comparison outcome categories are covered with positive and negative tests on both targets.
- Dependencies:
  - Phases 1 through 4.
- Parallelizable Work:
  - Outcome formatting fixtures can be prepared while comparison branches are implemented.

## Phase 6: Public API and Diagnostics
- Goal: Expose stable unit APIs through `torus_math` and provide developer diagnostics without leaking internal modules to callers.
- Tasks:
  - [ ] Update `gleam/src/torus_math.gleam` with public APIs for catalog version, unit parsing, unit normalization, quantity parsing, config validation, quantity comparison, and diagnostic formatting.
  - [ ] Add `gleam/src/math/units/format.gleam` for stable debug strings for parse errors, normalized units, config errors, quantity parse results, and comparison outcomes.
  - [ ] Keep internal module shapes private to the subsystem where possible, exposing only public result types required by BEAM and JavaScript consumers.
  - [ ] Confirm no existing callers of `torus_math.parse/1` are forced into unit-aware semantics.
- Testing Tasks:
  - [ ] Add public-boundary tests that call only `torus_math` APIs for unit parse, normalize, validate config, compare quantities, and format diagnostics.
  - [ ] Add target-stability tests for debug strings and normalized summaries.
  - Command(s): `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Public APIs cover the FDD interface list and produce stable diagnostics on both targets.
  - FR-008, AC-019, AC-020, and AC-021 are satisfied.
- Gate:
  - Gate F passes when unit behavior is reachable through `torus_math` only and debug fixtures are deterministic on BEAM and JavaScript.
- Dependencies:
  - Phases 1 through 5.
- Parallelizable Work:
  - Diagnostic formatter implementation can start once comparison/result type names settle.

## Phase 7: Regression, Boundary Audit, and Readiness
- Goal: Verify the unit subsystem does not regress existing math behavior or cross production boundaries.
- Tasks:
  - [ ] Run the existing parser, normalization, sampling, tolerance, algebraic equivalence, and exact-form suites after the unit layer lands.
  - [ ] Inspect changed files to confirm no database migrations, activity JSON changes, production grading changes, learner UI changes, or raw learner-answer telemetry were introduced.
  - [ ] Run Gleam formatting and both Gleam targets for all math tests.
  - [ ] Update work-item docs only if implementation decisions materially diverge from the PRD/FDD/plan.
- Testing Tasks:
  - [ ] Run full relevant Gleam tests on BEAM and JavaScript.
  - [ ] Run focused ExUnit tests for existing server math wrappers if public API changes touch generated BEAM interfaces.
  - Command(s): `cd gleam && gleam format --check src test`; `cd gleam && gleam test --target erlang`; `cd gleam && gleam test --target javascript`; `mix test test/oli/math test/oli_web/live/dev/math_prototype_live_test.exs`
- Definition of Done:
  - New unit tests pass on both Gleam targets.
  - Existing math behavior remains green.
  - Boundary audit confirms the MVP remains shared-math-only.
  - FR-009, AC-021, AC-022, and AC-023 are satisfied.
- Gate:
  - Gate G passes when test evidence and inspection evidence are ready for implementation review.
- Dependencies:
  - Phases 1 through 6.
- Parallelizable Work:
  - Boundary inspection can run while final regression tests execute.

## Parallelization Notes
- Phase 1 catalog entry work and catalog coverage fixtures are the best parallel path because the catalog is broad and mechanically testable.
- Phase 2 parser tests can be prepared while catalog entry implementation is completed, but parser success tests depend on lookup behavior.
- Phase 3 normalization depends on parser and catalog correctness; expected-value fixture authoring can still proceed in parallel.
- Phase 4 config validation and quantity parsing can share normalized-unit fixtures but should be merged only after normalization is stable.
- Phase 5 comparison depends on all previous phases because it coordinates parsing, normalization, config, and numeric tolerance.
- Phase 6 public API work can begin once result types are stable, but final public-boundary tests should land after comparison behavior is complete.
- Phase 7 must remain last because it validates regression risk and production-boundary constraints across the complete unit layer.

## Phase Gate Summary
- Gate A: Full `supported-units.md` catalog inventory implemented and covered, including AC-004, AC-005, AC-006, and AC-024.
- Gate B: Unit parser accepts required grammar fixtures and rejects malformed/unsupported unit strings, covering AC-007 and AC-008.
- Gate C: Normalization is deterministic and scale-correct for equivalent units, covering AC-009 and AC-010.
- Gate D: Quantity parsing and unit config policies prove whitespace, pure expression, required, ignored, and strict behavior, covering AC-001, AC-002, AC-003, AC-015, AC-016, and AC-017.
- Gate E: Quantity comparison returns all required semantic outcomes, covering AC-011, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, and AC-018.
- Gate F: Public `torus_math` APIs and diagnostics are stable on both Gleam targets, covering AC-019, AC-020, and AC-021.
- Gate G: Existing math tests pass and boundary inspection confirms no production persistence, grading, UI, or telemetry changes, covering AC-021, AC-022, and AC-023.

## Requirements Traceability
- Phase 1: FR-002; AC-004, AC-005, AC-006, AC-024.
- Phase 2: FR-003; AC-007, AC-008.
- Phase 3: FR-004; AC-009, AC-010.
- Phase 4: FR-001, FR-006; AC-001, AC-002, AC-003, AC-015, AC-016, AC-017.
- Phase 5: FR-005, FR-007; AC-011, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, AC-018.
- Phase 6: FR-008; AC-019, AC-020, AC-021.
- Phase 7: FR-009; AC-021, AC-022, AC-023.
