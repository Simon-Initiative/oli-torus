# Math Equality Contract And Numeric Evaluation - Functional Design Document

## 1. Executive Summary

Build the equality contract as a shared Gleam subsystem layered on top of the completed parser foundation. The root contract is a JSON-encodable equality spec that can eventually be stored on a Response object as `equalityConfig`. It contains the comparison mode, the expected answer parameters required by that mode, and the numeric or future math options that determine whether a submitted answer is equal.

This FDD selects a narrow implementation boundary: Gleam owns the typed equality spec, JSON encode/decode, numeric scalar evaluation, and diagnostic result taxonomy. Elixir and TypeScript should only get thin wrappers around the public Gleam API. Production evaluator reducers, feedback selection, authoring UI, legacy rule-string conversion, algebraic equivalence execution, and unit conversion remain outside this work item.

The first executable evaluator behavior is numeric scalar comparison for standard/basic page response evaluation. It must preserve existing Number input behavior from `lib/oli/delivery/evaluation/rule.ex` and `assets/src/data/activities/model/rules.ts`, while adding explicit tolerance, representation, and decimal precision options. Adaptive page evaluation remains on the existing `lib/oli/delivery/attempts/activity_lifecycle/adaptive_part_evaluation.ex` branch and is not incorporated into the new Gleam evaluator.

## 2. Requirements & Assumptions

- Functional requirements:
  - Define a type-safe Gleam equality configuration model with durable JSON encode/decode. Supports FR-001 and AC-001 through AC-003.
  - Define an equality API that returns equality outcomes and diagnostics only, with no feedback or scoring decisions. Supports FR-002 and AC-004 through AC-006.
  - Represent all current standard/basic page Number input operators and explicitly exclude adaptive page numeric behavior from this work item. Supports FR-003 and AC-007 through AC-009.
  - Reimplement scalar numeric comparison semantics, including ranges, inverse ranges, notation, and legacy `#precision`. Supports FR-004 and AC-010 through AC-013.
  - Add explicit numeric tolerance, decimal precision, and representation constraints. Supports FR-005, FR-006, and AC-014 through AC-018.
  - Model future algebraic, form, and unit modes without executing those modes in this work item. Supports FR-007 and AC-019 through AC-020.
  - Provide thin cross-runtime boundaries where needed for server and browser use. Supports FR-008 and AC-021 through AC-023.
  - Establish a parity corpus comparing legacy rule behavior with equivalent equality specs. Supports FR-009 and AC-024 through AC-026.
- Non-functional requirements:
  - Core behavior must be deterministic across Gleam Erlang and JavaScript targets.
  - JSON field names and discriminators must be stable enough for long-lived course content.
  - The evaluator must not log raw student submissions or expressions.
  - Numeric comparisons must remain cheap enough for the current response-reduce evaluation shape.
  - Gleam implementation should use liberal function-level and code-level comments where the reason for a type, config variant, or legacy parity rule is not obvious.
- Assumptions:
  - The top-level `gleam/` project remains the shared math implementation home.
  - `torus_math.gleam` remains the public Gleam API boundary.
  - Adding a small JSON dependency to the Gleam project is acceptable if no existing stdlib-only JSON encoder/decoder is sufficient.
  - The stored JSON root may be named `equalityConfig` on future Response objects even if the Gleam root type is named `EqualitySpec`.
  - Legacy rule-string conversion will be designed later at the evaluator integration boundary, not inside the numeric evaluator.

## 3. Repository Context Summary

- What we know:
  - Torus is a Phoenix application with domain code under `lib/oli/`, web code under `lib/oli_web/`, and browser assets under `assets/src/`.
  - The shared Gleam math code lives under `gleam/src` and already exposes parser behavior through `torus_math.gleam`.
  - `lib/oli/math.ex` is the current thin Elixir wrapper around generated Gleam BEAM modules in `gleam/build/dev/erlang/oli/ebin`.
  - Browser code can import generated Gleam JavaScript through the `gleam/build/dev/javascript` webpack alias established by the parser milestone.
  - Current standard response evaluation uses `lib/oli/delivery/evaluation/evaluator.ex` to reduce configured responses and `Oli.Delivery.Evaluation.Rule.parse_and_evaluate/2` to check rule strings.
  - Current numeric rule strings are built in `assets/src/data/activities/model/rules.ts`.
  - Adaptive activity numeric checks exist in `lib/oli/delivery/attempts/activity_lifecycle/adaptive_part_evaluation.ex` and continue to execute there. They are context only, not a parity or integration target for this work item.
  - No production storage, publication, delivery attempt, or LMS behavior should change in this work item.
- Unknowns to confirm:
  - Whether the first implementation should add an Elixir wrapper module immediately or keep Elixir integration limited to tests.
  - Whether TypeScript needs a wrapper in this work item or can wait until authoring UI planning.
  - Whether future authoring will store expected values inside `equalityConfig` only, or split expected answer data and comparison options across separate Response fields.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

Add a new equality subsystem under `gleam/src/math/equality*` and expose it only through `torus_math.gleam`.

- `gleam/src/math/equality/types.gleam`: owns the public equality spec, expected answer variants, numeric config variants, future expression/unit config variants, result types, and diagnostics.
- `gleam/src/math/equality/json.gleam`: owns JSON encode/decode for the equality spec. Decoders reject invalid combinations instead of producing partially valid configs.
- `gleam/src/math/equality/numeric.gleam`: owns numeric scalar parsing, comparison, tolerance handling, representation checks, decimal precision checks, and legacy significant-figure precision behavior.
- `gleam/src/math/equality/evaluate.gleam`: owns the public equality dispatcher. Numeric specs are evaluated. Non-numeric specs return `UnsupportedMode` until their future features implement behavior.
- `gleam/src/math/equality/diagnostic.gleam`: optional helper module if diagnostic formatting grows large enough to separate from the result types.
- `gleam/src/torus_math.gleam`: exposes decode, encode, validate, and evaluate entry points. Internal equality modules remain replaceable.
- `lib/oli/math/equality.ex`: optional thin Elixir wrapper if implementation needs server tests or prototype use. It should call generated Gleam modules and map results into plain Elixir maps or tagged tuples.
- `assets/src/gleam/torusEquality.ts`: optional thin TypeScript wrapper if implementation needs browser smoke tests. It should import generated `.mjs` modules and not duplicate equality logic.

The root persisted JSON shape should be treated as an equality spec:

```json
{
  "version": 1,
  "mode": "numeric",
  "comparison": {
    "type": "between",
    "lower": "1",
    "upper": "3",
    "bounds": "inclusive"
  },
  "tolerance": { "type": "none" },
  "representation": { "type": "any" },
  "precision": { "type": "none" }
}
```

Numeric expected values should be stored as strings in JSON so raw authored form is not lost before the numeric evaluator can enforce representation and precision rules. The evaluator parses those strings into internal numeric values at evaluation time.

Future non-numeric specs should share the same root envelope and version field but use their own mode-specific payloads:

- `mode: "expression"` for exact expression/form comparison and later algebraic equivalence.
- `mode: "unit"` or `mode: "unit_aware"` for later unit-aware quantity comparison.

Those modes are contract-level variants now and executable behavior later.

### 4.2 State & Data Flow

Numeric equality is a pure in-memory evaluation:

1. Caller provides a submitted answer string and an equality spec, either as a typed Gleam value or as JSON that is decoded first.
2. JSON decoding validates the root version, mode discriminator, comparison discriminator, required fields, numeric option fields, and unsupported combinations.
3. Numeric evaluation parses the submitted answer and authored expected numeric strings.
4. Representation constraints are checked against the raw submitted answer form when configured.
5. The numeric value comparison runs using the configured comparison operator.
6. Tolerance is applied only to comparison modes where tolerance is meaningful, primarily equality-style numeric comparisons.
7. Decimal-place precision and legacy significant-figure precision are checked as separate concepts.
8. The evaluator returns an equality result with structured diagnostics.

No database state is read or written. No feedback, score, or response matching decision is made.

### 4.3 Lifecycle & Ownership

The equality subsystem is shared math domain infrastructure. It is owned by the top-level Gleam project, versioned with Torus, and built for both Erlang and JavaScript targets.

The public stability boundary is `torus_math.gleam` plus the JSON equality spec. Internal module layout can change as long as the public Gleam API, JSON fixtures, and tests are intentionally updated.

Future production integration will call this contract from the standard/basic page evaluation flow. That later integration owns:

- Deciding when a Response should use `equalityConfig` instead of `rule`.
- Translating legacy rule strings into equality specs in memory.
- Selecting the matched Response, score, and feedback after an equality predicate returns true.

Adaptive page evaluation is not part of that integration target. The adaptive branch should continue through `AdaptivePartEvaluation` as it does today unless a later, separate work item explicitly changes that behavior.

### 4.4 Alternatives Considered

- Keep extending rule strings: rejected because new tolerances, algebraic equivalence, units, and authoring controls need typed structured config rather than string parsing.
- Put the contract in Elixir first and mirror it in TypeScript: rejected because it would recreate server/browser drift. Gleam is already the shared parser foundation.
- Store comparison operator separately from expected values: deferred because current numeric behavior and future Response storage need a self-contained equality spec. A later integration may still adapt separate authoring fields into this spec.
- Implement algebraic and unit behavior now: rejected because the roadmap requires numeric scalar semantics to be proven before expression sampling and unit conversion.
- Reuse the existing parser numeric literal rules exactly for Number inputs: rejected for legacy parity. The parser intentionally rejects `.5`, while current numeric rule evaluation accepts leading-decimal notation. Numeric scalar evaluation should preserve current Number input support even where expression syntax is stricter.

## 5. Interfaces

- Public Gleam JSON decode:
  - `decode_equality_config(json: String) -> Result(EqualitySpec, EqualityConfigError)`
  - Decodes JSON string input into a typed equality spec.
- Public Gleam JSON encode:
  - `encode_equality_config(spec: EqualitySpec) -> String`
  - Produces stable JSON for fixtures and future storage.
- Public Gleam evaluation:
  - `evaluate_equality(spec: EqualitySpec, submitted: String) -> EqualityResult`
  - Evaluates submitted input against the self-contained spec.
- Public Gleam validation:
  - `validate_equality_config(spec: EqualitySpec) -> Result(EqualitySpec, EqualityConfigError)`
  - Allows callers to validate constructed specs before storage or tests.
- Optional Elixir wrapper:
  - `Oli.Math.Equality.decode_config/1`
  - `Oli.Math.Equality.encode_config/1`
  - `Oli.Math.Equality.evaluate/2`
- Optional TypeScript wrapper:
  - `assets/src/gleam/torusEquality.ts`
  - Exposes decode/evaluate helpers for browser prototypes without duplicating rules.

Core Gleam type shape:

```gleam
pub type EqualitySpec {
  EqualitySpec(version: Int, mode: EqualityMode)
}

pub type EqualityMode {
  Numeric(NumericSpec)
  Expression(ExpressionSpec)
  UnitAware(UnitSpec)
}

pub type NumericSpec {
  NumericSpec(
    comparison: NumericComparison,
    tolerance: NumericTolerance,
    representation: NumericRepresentation,
    precision: NumericPrecision,
  )
}

pub type NumericComparison {
  Equal(expected: NumericInput)
  NotEqual(expected: NumericInput)
  GreaterThan(threshold: NumericInput)
  GreaterThanOrEqual(threshold: NumericInput)
  LessThan(threshold: NumericInput)
  LessThanOrEqual(threshold: NumericInput)
  Between(lower: NumericInput, upper: NumericInput, bounds: RangeBounds)
  NotBetween(lower: NumericInput, upper: NumericInput, bounds: RangeBounds)
}
```

The exact type names can change during implementation, but the FDD decision is that invalid mode-specific combinations should be represented by variants instead of option bags.

Numeric option types:

- `NumericTolerance`: `NoTolerance`, `AbsoluteTolerance(value)`, `RelativeTolerance(value)`, `AbsoluteOrRelativeTolerance(absolute, relative)`.
- `NumericRepresentation`: `AnyRepresentation`, `IntegerRepresentation`, `DecimalRepresentation`, `ScientificRepresentation`.
- `NumericPrecision`: `NoPrecision`, `LegacySignificantFigures(count)`, `DecimalPlaces(rule, count)`.
- `DecimalPlaceRule`: `Exactly`, `AtLeast`, `AtMost`.
- `RangeBounds`: `Inclusive`, `Exclusive`.

Result types:

- `Equal`: the submitted answer matched the spec.
- `NotEqual`: value comparison failed.
- `InvalidConfig`: typed config or decoded JSON was invalid.
- `InvalidSubmittedAnswer`: submitted value could not be parsed as required.
- `RepresentationMismatch`: numeric value may parse, but submitted form violates representation config.
- `PrecisionMismatch`: submitted form violates decimal-place or significant-figure config.
- `UnsupportedMode`: spec is valid, but executable evaluator behavior is not part of this work item.

## 6. Data Model & Storage

- No database migration is required.
- No persisted Response schema changes are required in this work item.
- JSON fixtures should be committed near the Gleam equality tests and treated as the first compatibility contract.
- Future Response storage should use a JSON object under `equalityConfig` with:
  - `version`: integer version, initially `1`.
  - `mode`: discriminator, initially `numeric`, `expression`, or `unit_aware`.
  - Mode-specific payload fields.
  - Option fields for tolerance, representation, precision, form, expression validation, and units.

The first implementation should avoid relying on generated Gleam tuple shapes as the storage contract. JSON fixtures, decoders, and encoders define storage compatibility.

## 7. Consistency & Transactions

- Equality config decode, validation, and evaluation are pure functions with no transaction boundary.
- Consistency is enforced by a single Gleam source of truth and cross-target tests.
- Browser and server code must not reinterpret equality JSON independently.
- Later production integration must translate legacy rule strings in memory before calling the equality API, rather than mutating historical content during evaluation.

## 8. Caching Strategy

No caching should be introduced in this work item.

The evaluator is expected to parse short numeric strings and config objects cheaply. If later production integration identifies repeated decoding in hot response loops, caching should be designed at the evaluator integration boundary with clear invalidation and privacy rules.

## 9. Performance & Scalability Posture

- Numeric evaluation should be O(1) for scalar and range comparisons.
- JSON decode cost should be proportional to one small equality spec.
- The parity corpus should include ordinary and edge-case numeric inputs, but this work item does not need load testing.
- Implementation should avoid regular expressions or string scans in inner loops where simple parsing helpers are enough.
- Future expression and unit modes may need stronger budgets; numeric scalar evaluation should not introduce architecture that blocks those later budgets.

## 10. Failure Modes & Resilience

- Invalid JSON: return `InvalidConfig` with a decode error category.
- Unsupported version: return `InvalidConfig` and do not attempt best-effort evaluation.
- Missing required mode-specific field: return `InvalidConfig`.
- Unknown mode or comparison discriminator: return `InvalidConfig`.
- Non-numeric submitted answer for numeric spec: return `InvalidSubmittedAnswer`.
- Non-numeric expected value in numeric spec: return `InvalidConfig`.
- Leading-decimal submitted values such as `.5`: accept for numeric scalar parity even though expression parsing rejects this syntax.
- Division by zero, domain errors, and expression runtime errors: not applicable until later expression evaluation features.
- Future expression or unit mode evaluation before implementation: return `UnsupportedMode`.
- Cross-target mismatch: fail Gleam golden tests and block integration.

## 11. Observability

- The Gleam core should not emit logs, telemetry, AppSignal events, or traces.
- Tests and developer prototypes should inspect structured diagnostics directly.
- If optional Elixir wrappers emit errors in future production paths, they must log categories only and avoid raw submitted answers or raw expected answers.
- Success metrics for this work item are validation gates, test pass rates, JSON fixture stability, and parity-corpus coverage rather than production telemetry.

## 12. Security & Privacy

- Treat submitted answers and expected-answer strings as untrusted input.
- Do not use dynamic code evaluation, shell execution, JavaScript `eval`, or equivalent runtime evaluation.
- Do not log raw student answers by default.
- JSON decoders must reject malformed or unknown structures rather than accepting extra fields that might alter behavior later.
- No new authorization path is introduced because this work item is pure shared math infrastructure.
- Any future display of diagnostics must pass through product UI copy and not expose internal parser or config details directly to students.

## 13. Testing Strategy

- Gleam config tests:
  - Constructor and validation tests for valid numeric, expression, form, and unit-aware spec variants.
  - Decode rejection tests for missing fields, unknown discriminators, invalid tolerance values, invalid precision counts, and unsupported versions.
  - Encode/decode round-trip tests for every supported equality spec family.
- Gleam numeric evaluator tests:
  - Scalar comparisons for equal, not equal, greater than, greater than or equal, less than, and less than or equal.
  - Range comparisons for between and not between.
  - Inclusive and exclusive range boundaries.
  - Reversed bounds.
  - Integer, decimal, leading-decimal, negative, and scientific notation.
  - Legacy significant-figure precision from `#precision`.
  - Decimal-place precision with exactly, at least, and at most rules.
  - No tolerance, absolute tolerance, relative tolerance, and absolute-or-relative tolerance.
  - Representation constraints for any, integer, decimal, and scientific notation.
  - Unsupported-mode results for expression and unit-aware specs.
- Legacy parity corpus:
  - Build fixtures from `assets/src/data/activities/model/rules.ts` operators: `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `btw`, and `nbtw`.
  - Exclude adaptive numeric forms from `adaptive_part_evaluation.ex`; adaptive pages remain on the existing adaptive evaluation branch.
  - Compare new equality-spec results with expected current behavior for positive and negative examples.
- Cross-target gates:
  - `cd gleam && gleam test --target erlang`
  - `cd gleam && gleam test --target javascript`
- Integration checks when wrappers are introduced:
  - Targeted `mix test` for `Oli.Math.Equality` wrapper behavior.
  - Targeted `yarn` or TypeScript checks for `assets/src/gleam/torusEquality.ts`.
- Documentation validation:
  - `python3 /Users/darren/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/math/contract --action verify_fdd`
  - `python3 /Users/darren/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/math/contract --action master_validate --stage fdd_only`
  - `python3 /Users/darren/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/math/contract --check fdd`

## 14. Backwards Compatibility

- This work item does not change production evaluation behavior.
- Existing course content, activity models, Response rule strings, attempts, publications, and learner results remain unchanged.
- Numeric behavior must preserve current comparison semantics before later integration routes evaluation through the new contract.
- Adaptive page evaluation remains unchanged and continues to execute through `lib/oli/delivery/attempts/activity_lifecycle/adaptive_part_evaluation.ex`.
- The legacy rule-string compatibility layer is a later permanent component at the evaluator integration boundary. It will translate existing rule strings into equality specs in memory when `equalityConfig` is absent.
- Legacy `#precision` must remain distinct from new decimal-place precision so existing authored content does not silently change meaning.

## 15. Risks & Mitigations

- Config shape is too loose: use Gleam variants for mode-specific valid states and strict JSON decoders at the boundary.
- Stored JSON evolves unsafely: add `version` now and require golden fixtures for every public shape.
- Numeric parity drifts from current standard/basic page behavior: build parity examples directly from current standard rule operators.
- Adaptive behavior is accidentally pulled into this evaluator: keep `AdaptivePartEvaluation` documented as out of scope and exclude adaptive-specific parity fixtures from this work item.
- Decimal precision and significant figures are conflated: model `LegacySignificantFigures` and `DecimalPlaces` separately.
- Parser syntax and numeric input syntax conflict: keep Number input numeric parsing in the equality numeric module and document intentional differences such as leading-decimal support.
- Scope expands into feedback or UI: keep the equality result limited to equal/not-equal and diagnostics.
- Cross-target float differences appear: keep representative Erlang and JavaScript target tests and favor explicit tolerance rules over hidden tolerance behavior.

## 16. Open Questions & Follow-ups

- Phase 2 selected `gleam_json` for JSON parsing and encoding inside the shared Gleam equality boundary.
- Confirm whether `equalityConfig` should be the long-term storage name for the entire equality spec, including expected values, or whether expected answers should eventually be stored beside it.
- Confirm the exact Elixir wrapper module name if server-side tests need one in this work item.
- Later architecture work must design the legacy rule-string translator at the production evaluator integration boundary.
- Later architecture work must design authoring UI controls from the equality spec vocabulary.

## 17. References

- `docs/exec-plans/current/epics/math/contract/prd.md`
- `docs/exec-plans/current/epics/math/contract/requirements.yml`
- `docs/exec-plans/current/epics/math/plan.md`
- `docs/exec-plans/current/epics/math/parser/fdd.md`
- `docs/exec-plans/current/epics/math/parser/prd.md`
- `gleam/src/torus_math.gleam`
- `gleam/src/math/ast.gleam`
- `lib/oli/math.ex`
- `lib/oli/delivery/evaluation/evaluator.ex`
- `lib/oli/delivery/evaluation/rule.ex`
- `assets/src/data/activities/model/rules.ts`
- `lib/oli/delivery/attempts/activity_lifecycle/adaptive_part_evaluation.ex`
- `ARCHITECTURE.md`
- `harness.yml`
- `docs/STACK.md`
- `docs/TOOLING.md`
- `docs/TESTING.md`
- `docs/PRODUCT_SENSE.md`
- `docs/FRONTEND.md`
- `docs/BACKEND.md`
- `docs/DESIGN.md`
- `docs/OPERATIONS.md`
- `docs/CODEREVIEW.md`
- `docs/ISSUE_TRACKING.md`
- `docs/design-docs/attempt.md`
- `docs/design-docs/attempt-handling.md`
- `docs/design-docs/high-level.md`
