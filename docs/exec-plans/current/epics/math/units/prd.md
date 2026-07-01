# Unit-Aware Math Expression Evaluation - Product Requirements Document

## 1. Overview
Build MVP unit support for Torus Math Expression evaluation. The feature lets a submitted answer be evaluated as either a pure numeric expression or a quantity composed of a numeric value expression plus a unit expression, such as `9.8 m/s^2` or `980 cm/s^2`.

The core product outcome is unit-aware answer checking that supports first-course physics, chemistry, and math units without hardcoding every compound unit. Torus should maintain the versioned catalog of supported unit atoms and aliases defined in `supported-units.md`, parse unit expressions composed from those atoms, normalize units into canonical dimensions and scale factors, and then reuse existing numeric tolerance behavior after canonical conversion.

## 2. Background & Problem Statement
Torus Math already has shared Gleam infrastructure for parsing, normalization, deterministic evaluation, sampling, numeric tolerance comparison, algebraic equivalence, and exact-form diagnostics. Those layers can determine whether numeric expressions are equivalent, but they do not yet understand answers where the submitted value includes units.

Authors in physics, engineering, chemistry-adjacent, and quantitative courses often need to require units or accept convertible unit forms. For example, `9.8 m/s^2` and `980 cm/s^2` represent the same acceleration, while `9.8 m/s` is dimensionally incompatible and `9.8` may be missing a required unit. A brittle whitelist of complete compound units would fail as soon as authors need variants such as `kg*m/s^2`, `N`, `km/hr`, or future combinations composed from known atoms.

The MVP should therefore introduce a durable unit model while keeping scope controlled: multiplicative scale conversions only, the broad first-course science atom catalog in `supported-units.md`, whitespace-delimited unit suffixes, structured result categories, and no production activity integration unless a later work item explicitly wires this capability into grading surfaces.

## 3. Goals & Non-Goals
### Goals
- Parse quantity answers as a value expression followed by a whitespace-delimited unit suffix.
- Maintain the hardcoded, versioned unit atom catalog defined in `supported-units.md`, including aliases, canonical symbols, dimensions, scale factors, and required common compound presets.
- Parse unit expressions made from known atoms using multiplication, division, and integer powers.
- Normalize parsed unit expressions into canonical dimension vectors and scale factors.
- Support unit-aware comparison for expected and submitted quantities by converting compatible units to canonical numeric values and using existing tolerance semantics.
- Provide author-facing configuration concepts for ignored units, required units, accepted unit expressions, conversion allowance, and strict final-unit behavior.
- Return structured unit outcome categories that distinguish numeric mismatch, missing units, unsupported units, incompatible dimensions, convertible-but-unaccepted units, unit syntax errors, and correct answers.
- Expose the behavior through a small shared Gleam boundary suitable for BEAM and JavaScript consumers.
- Provide developer diagnostics suitable for the Math Prototype LiveView and future authoring validation.

### Non-Goals
- Do not hardcode a whitelist of complete compound units as the primary model.
- Do not support units without whitespace after the value, such as `9.8m/s^2`, in the MVP.
- Do not support Celsius, Fahrenheit, offset conversions, currency, percent as a physical unit, pH, decibels, contextual `ppm` or `ppb`, custom author-defined units, automatic SI prefix inference, or complex unit systems in the MVP.
- Do not build a complex numerator/denominator unit builder as the initial authoring UI.
- Do not integrate unit-aware comparison into production grading, activity schemas, persistence, feedback rules, or learner UI in this PRD unless later architecture explicitly scopes that integration.
- Do not replace existing numeric tolerance, parser, normalization, sampling, algebraic equivalence, or exact-form layers.

## 4. Users & Use Cases
- Authors: configure a correct answer such as `9.8 m/s^2`, require units, and accept equivalent unit expressions such as `m/s^2` and `cm/s^2`.
- Students: submit quantity answers such as `980 cm/s^2` and receive correct evaluation when the value and accepted unit policy match.
- Learning engineers: inspect structured unit outcomes to distinguish conceptual mistakes from representation or policy mistakes.
- Developers: validate unit catalog entries, parser output, normalized dimensions, canonical scale factors, and comparison diagnostics in shared Gleam and the developer Math Prototype.
- Future authoring UI consumers: validate accepted unit strings and show concise diagnostics such as dimension and canonical scale.

## 5. UX / UI Requirements
- The MVP authoring model should be compact: ignored versus required units, correct answer, accepted unit expressions, conversion allowance, and optional strict final-unit behavior.
- Accepted units should be entered as parseable unit strings such as `m/s^2`, `cm/s^2`, `N`, `kg*m/s^2`, or `km/hr`.
- Common compound units may be offered as presets or autocomplete suggestions, but they must insert normal parseable unit strings rather than becoming a separate data model.
- Unit validation should provide immediate developer or future authoring diagnostics for valid units, unsupported atoms, syntax errors, dimensions, and canonical scale.
- Learner-facing feedback copy is out of scope for this PRD; the unit layer should return structured categories that future UI can map to copy.
- The developer Math Prototype may show raw diagnostics, but production surfaces should not expose raw internal debug strings as learner feedback.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Determinism: unit parsing, normalization, comparison results, and debug diagnostics must be stable across repeated runs and across Gleam Erlang and JavaScript targets.
- Reliability: malformed unit syntax, unsupported atoms, incompatible dimensions, missing units, invalid accepted-unit config, and numeric mismatch must return structured outcomes rather than crashes or generic false values.
- Performance: unit parsing and normalization must be bounded by answer length and unit-expression tree size; comparison should reuse existing numeric tolerance logic after conversion and avoid symbolic algebra or exhaustive compound-unit lookup.
- Security and privacy: production summaries and future telemetry should prefer outcome categories, unit catalog versions, and normalized dimensions over raw learner answer text.
- Maintainability: unit behavior should live in shared Gleam modules behind a small public `torus_math` API and should not duplicate BEAM/browser conversion logic.
- Accessibility: future authoring UI diagnostics must be representable as text, not only color or icon state.

## 9. Data, Interfaces & Dependencies
- Depends on the existing Gleam parser, AST, normalization, evaluator, and numeric tolerance layers under `gleam/src/math/`.
- Adds the versioned unit atom catalog specified in `supported-units.md` in Gleam with canonical symbols, aliases, dimension vectors, scale-to-canonical factors, and unit kind metadata.
- Adds unit expression types for atoms, multiplication, division, and integer powers.
- Adds normalized unit types with dimension powers, canonical scale factor, canonical debug text, and original unit expression.
- Adds quantity parsing or wrapping that separates value expression parsing from unit suffix parsing.
- Adds unit-aware comparison configuration for ignored units, required units, accepted unit expressions, conversion allowance, and strict final-unit policy.
- Adds structured result taxonomy for correct answers and unit-specific failure outcomes.
- Public APIs should be exposed through `gleam/src/torus_math.gleam`; Elixir and TypeScript wrappers may be added in later integration slices.
- No database schema, publication schema, activity JSON, or attempt persistence changes are required for the shared math-layer MVP.

## 10. Repository & Platform Considerations
- Core behavior belongs in shared Gleam because the math engine must remain deterministic across server and browser contexts.
- Unit code should be organized under `gleam/src/math/` and keep internal catalog, parser, normalization, and comparison modules replaceable behind `torus_math`.
- Existing parser ambiguity around implicit multiplication requires the MVP whitespace rule before unit suffixes.
- Required Gleam gates are `cd gleam && gleam format --check src test`, `cd gleam && gleam test --target erlang`, and `cd gleam && gleam test --target javascript`.
- If a developer prototype is updated, run targeted LiveView tests and verify the asset bundle does not pull browser-incompatible generated modules.
- Code review should include `.review/security.md`, `.review/performance.md`, `.review/requirements.md`, and `.review/gleam.md`; add `.review/elixir.md`, `.review/ui.md`, or `.review/typescript.md` if later slices add wrappers or UI.
- No Jira issue key was provided; this work item directory is the planning source of truth until a ticket is linked.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Primary success signal: unit parser, unit normalization, and unit-aware comparison tests pass on both Gleam targets.
- Quality signal: test cases prove accepted-unit conversion, strict final-unit rejection, missing-unit detection, unsupported-unit detection, and incompatible-dimension detection.
- Compatibility signal: existing parser, evaluator, sampling, algebraic equivalence, exact-form, and numeric tolerance tests continue to pass.
- No new production telemetry is required for the shared math-layer MVP. Future production telemetry should use unit outcome categories, catalog version, and timing buckets rather than raw learner answers.

## 13. Risks & Mitigations
- Ambiguous parsing of `10m` as either multiplication or meters: require whitespace before unit suffixes in the MVP.
- Catalog growth risk: treat `supported-units.md` as the hard MVP inventory and do not add automatic prefix inference, offset conversions, or context-dependent units while implementing the broad first-course catalog.
- Incorrect conversion due to floating-point scale factors: reuse existing tolerance comparison and cover representative conversion cases on both targets.
- Author confusion between accepted convertible units and strict final unit: keep both policies explicit in config and result categories.
- Browser/server drift: implement catalog, parser, normalization, and comparison once in Gleam and test both targets.
- Privacy leakage through diagnostics: separate developer debug formatting from structured production-safe outcomes.

## 14. Open Questions & Assumptions
### Open Questions
- In required-units mode with conversion enabled, should known but unaccepted compatible units return `WrongButConvertibleUnit` or `UnitNotAccepted` as the primary outcome?
- Should units ignored mode accept unsupported unit suffixes by stripping units, or should unsupported units still return diagnostics?
- Should strict final-unit behavior compare against the expected unit only or against a specific selected accepted-unit entry?

### Assumptions
- The MVP supports only multiplicative scale conversions; offset conversions such as Celsius and Fahrenheit are excluded.
- Unit suffixes require whitespace after the numeric expression.
- Accepted unit entries are parseable unit expressions and are normalized at configuration/validation time.
- The broad first-course catalog in `supported-units.md` is hard MVP scope and can be versioned for future expansion.
- `mph` is included in the initial catalog as a convenience speed atom that normalizes to `mi/hr` with scale `0.44704 m/s`.
- Numeric value comparison after unit conversion uses existing tolerance semantics.
- Production grading integration will be handled by a later work item after the shared math layer is proven.

## 15. QA Plan
- Automated validation:
  - Run `cd gleam && gleam format --check src test`.
  - Run `cd gleam && gleam test --target erlang`.
  - Run `cd gleam && gleam test --target javascript`.
  - Add Gleam tests for every supported atom and alias in `supported-units.md`, catalog aliases, atom normalization, compound unit parsing, dimension arithmetic, scale conversion, quantity parsing, accepted-unit config validation, strict final-unit policy, ignored-units mode, and structured outcome taxonomy.
  - Add cross-target fixture tests for examples such as `9.8 m/s^2`, `980 cm/s^2`, `36 km/hr`, `10 m/s`, `10 N`, and `kg*m/s^2`.
  - Run existing parser, normalization, sampling, algebraic equivalence, exact-form, and numeric tolerance tests when shared math modules are touched.
- Manual validation:
  - Inspect developer diagnostics for clear dimensions, canonical scale, unsupported atoms, syntax errors, and accepted-unit policy outcomes.
  - Review changed files for raw learner answer logging, browser-incompatible generated imports, hardcoded compound-unit whitelist behavior, and production grading integration drift.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
