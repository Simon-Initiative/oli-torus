# Exact Form And Representation Constraints - Functional Design Document

## 1. Executive Summary
This design adds a shared Gleam exact-form layer for Math Expression answers. It classifies a candidate's whole-answer written form from the raw parsed AST and applies author-style constraints after semantic equivalence has already passed.

The core design is deliberately narrow:

- new form types and logic under `gleam/src/math/equality/`;
- public entry points through `gleam/src/torus_math.gleam`;
- raw-string candidate form checking;
- form-aware algebraic checking that delegates semantic comparison to existing algebraic equivalence first;
- a developer-only Math Prototype LiveView update that exposes exact-form controls and diagnostics;
- no production grading, activity JSON, persistence, production authoring UI, learner UI, scoring, or feedback-rule integration.

This satisfies the PRD's central requirement that exact form refine correctness rather than replace it. Direct form checks cover `AC-001` through `AC-009`, form-aware semantic ordering covers `AC-010` through `AC-012`, public API and diagnostics cover `AC-013` and `AC-014`, compatibility and privacy cover `AC-015` through `AC-017`, and cross-target verification covers `AC-018` and `AC-019`.

## 2. Requirements & Assumptions
- Functional requirements:
  - Define exact-form config, observed-form summaries, form failures, standalone form results, and form-aware algebraic results (`FR-001`, `AC-001`, `AC-002`).
  - Classify whole-answer forms from parsed source metadata, not normalized expressions or floats (`FR-002`, `AC-003`, `AC-004`, `AC-005`).
  - Enforce integer, fraction, simplified-fraction, decimal, and decimal-place rules (`FR-003`, `AC-006`, `AC-007`, `AC-008`, `AC-009`).
  - Run form checks only after semantic equivalence passes (`FR-004`, `AC-010`, `AC-011`, `AC-012`).
  - Expose stable public APIs and debug formatters through `torus_math` (`FR-005`, `AC-013`, `AC-014`).
  - Extend the developer-only Math Prototype LiveView so developers can exercise standalone exact-form and form-aware algebraic checks through the existing prototype surface.
  - Preserve existing numeric and production boundaries (`FR-006`, `AC-015`, `AC-016`, `AC-017`).
  - Prove target-stable behavior with Gleam tests (`FR-007`, `AC-018`, `AC-019`).
- Non-functional requirements:
  - Keep exact-form checks deterministic and bounded.
  - Avoid target-specific inspect output in debug formatting.
  - Do not emit raw submitted answers in production-oriented summaries.
  - Avoid symbolic simplification, rational-expression analysis, sampling, or repeated evaluation inside the form module.
- Assumptions:
  - Simplified fractions require a positive denominator. `-4/5` is canonical; `4/-5` is non-canonical.
  - Zero fractions are simplified only as `0/1`; `0/5` is unsimplified.
  - Unary plus is accepted anywhere unary minus is accepted for MVP literal form parsing.
  - Scientific notation is not decimal form for Math Expression exact-form constraints.
  - Fraction form means whole-answer division of integer literals, not rational expressions such as `1/x`.
  - Large integer literals outside the shared safe integer range are rejected for exact-form arithmetic details instead of accepted as raw-only valid form.
  - A future authoring UI should not expose non-canonical fraction sign as a separate author-facing feedback category in this phase; it remains structured diagnostic detail.

## 3. Repository Context Summary
- What we know:
  - `gleam/src/torus_math.gleam` is the stable shared public math boundary for Elixir and browser consumers.
  - `gleam/src/math/ast.gleam` already preserves `NumberLiteral.raw`, `NumberLiteral.notation`, `NumberLiteral.decimal_places`, expression spans, prefix signs, and binary division.
  - `gleam/src/math/parser.gleam` represents fractions as `Binary(Divide, left, right)` and signs as `Prefix`, while grouping expands spans without adding a group node.
  - `gleam/src/math/normalization/types.gleam` keeps `Normalized.original`, but exact-form checks should not require normalization.
  - `gleam/src/math/equality/algebraic.gleam` provides raw-string semantic equivalence and structured outcomes.
  - `gleam/src/math/equality/numeric.gleam` owns Number-input scalar representation and precision behavior and should remain separate unless helper extraction is proven by regression tests.
  - `gleam/src/math/equality/json.gleam` currently encodes expression comparison and validation without a production `form` object.
  - `lib/oli/math/algebraic.ex` is the thin Elixir bridge around the public Gleam algebraic equivalence API for the developer prototype.
  - `lib/oli_web/live/dev/math_prototype_live.ex` already renders parser and algebraic equivalence prototype panels with form state, event handlers, per-variable domain rows, and structured algebraic diagnostics.
  - `test/oli/math/algebraic_test.exs` and the Math Prototype LiveView tests provide the existing pattern for bridge and prototype coverage.
  - The publication and attempt models require learner-facing behavior to remain stable unless explicitly integrated; this work item does not modify those boundaries.
- Unknowns to confirm:
  - Whether a later production integration will store form config in the existing equality JSON shape or a response-level wrapper. This FDD designs the core typed layer without committing storage.
  - Whether future UI copy will collapse `NonCanonicalFractionSign` into `wrong_form` or `unsimplified_fraction`; this work item only returns structured diagnostics.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `gleam/src/math/equality/form_types.gleam`
  - Owns exact-form config, decimal precision config, observed form summaries, form failure categories, standalone form result, and form-aware algebraic result.
  - Reuses `math/equality/types.DecimalPlaceRule` if doing so keeps dependencies simple; otherwise mirrors the three-rule vocabulary with conversion helpers.
  - Must include Gleam comments for exported types because these become the public vocabulary for later authoring UI and feedback mapping.
- `gleam/src/math/equality/form.gleam`
  - Parses raw candidates for standalone checks.
  - Classifies parsed expressions into whole-answer observed forms.
  - Applies exact-form config.
  - Wraps `algebraic.check_algebraic_equivalence` for form-aware algebraic checks.
  - Does not evaluate values, generate samples, normalize expressions, or inspect production activity state.
- `gleam/src/math/equality/form_format.gleam`
  - Formats form configs, observed forms, failures, standalone results, and form-aware algebraic results using target-stable strings.
  - May include raw numeric fragments needed for developer/test diagnostics, but comments must state the output is not learner-facing feedback or production telemetry.
- `gleam/src/torus_math.gleam`
  - Imports the form modules and exposes only the stable functions documented in this FDD.
- `lib/oli/math/exact_form.ex`
  - Thin Elixir bridge around the public Gleam exact-form APIs for developer prototype use.
  - Provides `default_config/0`, `check/2`, `check_algebraic/4`, `result_debug/1`, `form_aware_result_debug/1`, and `config_from_form/1`.
  - Converts prototype form strings into Gleam config tuples without duplicating form-classification semantics.
  - Does not create dynamic atoms from user input.
- `lib/oli_web/live/dev/math_prototype_live.ex`
  - Extends the existing Algebraic Equivalence panel with exact-form controls.
  - Submits the same expected and candidate expressions through form-aware algebraic checking when a form constraint is selected.
  - Displays semantic outcome, form outcome, observed form, form failures, exact-form debug text, and the existing algebraic diagnostics.
  - Keeps all state transient in LiveView assigns.
- `test/oli/math/exact_form_test.exs`
  - Covers the thin Elixir bridge and form config conversion for developer prototype usage.
- `test/oli_web/live/dev/math_prototype_live_test.exs`
  - Covers exact-form controls, successful form-aware checks, form failures, and semantic-failure precedence in the prototype.
- Existing modules:
  - `math/parser` remains the syntactic source of truth.
  - `math/equality/algebraic` remains the semantic equivalence source of truth.
  - `math/equality/numeric` remains the Number-input scalar representation source of truth.

### 4.2 State & Data Flow
Standalone form check flow:

1. `torus_math.check_exact_form(candidate, config)` calls `form.check_exact_form`.
2. Validate `config`.
3. If `config` is `NoFormConstraint`, return `FormSatisfied` with an observed summary when parsing succeeds; parse failure can still return `FormCheckParseFailed` because standalone checks are developer diagnostics.
4. Parse `candidate` through `math/parser.parse`.
5. Require `ast.Expression(expr)`. Any future `Quantity` result is `ObservedOther` because unit-aware exact form is out of scope.
6. Classify the expression by peeling supported unary signs and inspecting the whole remaining node.
7. Apply the required form rule and return `FormSatisfied` or `FormNotSatisfied`.

Form-aware algebraic flow:

1. `torus_math.check_algebraic_equivalence_with_form(expected, candidate, equivalence_config, form_config)` calls `algebraic.check_algebraic_equivalence`.
2. If the algebraic outcome is not `Equivalent(_)`, return `SemanticsFailed(result)` and do not run or surface form failures (`AC-011`, `AC-012`).
3. If the algebraic outcome is `Equivalent(_)`, run `check_exact_form(candidate, form_config)`.
4. Return `SemanticsPassedFormSatisfied` when form succeeds or `SemanticsPassedFormFailed` when form fails (`AC-010`).
5. If standalone form checking unexpectedly reports a parse failure after algebraic equivalence passed, surface it as `SemanticsPassedFormFailed` with a structured form failure category indicating inconsistent parse state. This should be unreachable in normal operation and covered by defensive formatting.

Developer prototype flow:

1. `mount/3` initializes exact-form fields inside the existing algebraic form state.
2. `update_algebraic_form` merges exact-form params alongside existing algebraic params.
3. `check_algebraic_equivalence` builds the existing algebraic config and a new exact-form config from the same form payload.
4. If the exact-form selector is `none`, the LiveView may call the existing algebraic bridge or the new form-aware bridge with `NoFormConstraint`; the rendered result should keep the same user-visible semantic diagnostics either way.
5. If a concrete exact-form selector is chosen, the LiveView calls the form-aware exact-form bridge and renders both semantic and form result sections.
6. Form config errors, such as negative decimal-place counts or non-integer precision input, render in the existing error panel style without crashing the LiveView.
7. No prototype inputs or results are persisted.

Classification details:

- Integer:
  - Accept a single `Num(NumberLiteral(..., IntegerNotation, ...))` with optional unary sign.
  - Reject unsafe integer values outside `-9007199254740991..9007199254740991` as `UnsafeIntegerLiteral`.
  - Reject decimal, scientific, fraction, additive, product, variable, call, power, and factorial shapes (`AC-003`, `AC-006`).
- Decimal:
  - Accept a single `Num(NumberLiteral(..., DecimalNotation, Some(count)))` with optional unary sign.
  - Use `decimal_places` directly for precision checks.
  - Reject scientific notation and any expression shape other than a single decimal literal (`AC-005`, `AC-009`).
- Fraction:
  - Accept a single `Binary(Divide, numerator, denominator)` after peeling optional outer sign.
  - Numerator and denominator must each be integer literals with optional unary signs.
  - Denominator must be non-zero.
  - Denominator-negative fractions classify as fractions but carry `NonCanonicalFractionSign` when simplified fraction is required.
  - Reject chained division, variable rational forms, decimal components, scientific components, calls, products, and additive forms (`AC-004`, `AC-007`).
- Simplified fraction:
  - First require fraction classification.
  - Normalize signs for value details, but fail non-canonical denominator signs.
  - Compute `gcd(abs(numerator), abs(denominator))`.
  - Fail with `UnsimplifiedFraction` when `gcd > 1` or when numerator is zero and denominator is not `1`.
  - Fail unsafe integer components rather than attempting cross-target-unsafe arithmetic (`AC-008`).

### 4.3 Lifecycle & Ownership
- Gleam owns exact-form semantics, classification, validation, result taxonomy, and stable formatting.
- Elixir owns only developer-prototype form conversion and display of Gleam results.
- Phoenix LiveView owns transient prototype state and rendering.
- React, activities, attempts, response rules, publication, and persistence are not changed in this work item.
- The work item produces reusable primitives for later production integration but does not decide feedback text, score, response selection, or authoring controls.
- The Math Prototype LiveView update is developer-only diagnostic UI and is included in this design.

### 4.4 Alternatives Considered
- Add form checks into `math/equality/numeric.gleam`.
  - Rejected because Number input scalar representation accepts compatibility forms, including leading decimals, and is not AST-based. Mixing it with Math Expression exact form risks changing `AC-015`.
- Add form config directly to `math/equality/types.ExpressionSpec` and JSON now.
  - Deferred because this work item intentionally avoids production storage and evaluator integration. The core form types should be designed so a later JSON/storage slice can add a `form` object without changing classifier semantics.
- Classify form from normalized expressions.
  - Rejected because normalization intentionally erases or canonicalizes source details needed for exact form.
- Extend `algebraic_types.AlgebraicEquivalenceResult` to carry parsed candidate ASTs.
  - Deferred. Reparsing the candidate after semantic pass is simpler, bounded, and avoids widening algebraic diagnostics. If profiling or API ergonomics later justify it, the pipeline can retain `ast.Parsed` as an internal optimization.
- Use arbitrary precision integer arithmetic for large fractions.
  - Rejected for MVP simplicity and cross-target stability. Unsafe integer components fail with structured detail.

## 5. Interfaces
- Form config:

```gleam
pub type ExactFormConfig {
  NoFormConstraint
  RequireInteger
  RequireFraction
  RequireSimplifiedFraction
  RequireDecimal(precision: DecimalPrecisionConstraint)
}

pub type DecimalPrecisionConstraint {
  AnyDecimalPlaces
  DecimalPlaces(rule: types.DecimalPlaceRule, count: Int)
}
```

- Observed form summary:

```gleam
pub type ObservedFormSummary {
  ObservedFormSummary(kind: ObservedFormKind, span: ast.Span)
}

pub type ObservedFormKind {
  ObservedInteger
  ObservedDecimal(decimal_places: Int)
  ObservedFraction
  ObservedOther
}
```

- Form failures:

```gleam
pub type FormFailure {
  WrongForm(required: RequiredForm, observed: ObservedFormKind)
  UnsimplifiedFraction(numerator: Int, denominator: Int, gcd: Int)
  DecimalPrecisionMismatch(
    rule: types.DecimalPlaceRule,
    expected_count: Int,
    actual_count: Int,
  )
  NonCanonicalFractionSign
  UnsafeIntegerLiteral
}
```

- Standalone result:

```gleam
pub type FormCheckResult {
  FormSatisfied(observed: ObservedFormSummary)
  FormNotSatisfied(observed: ObservedFormSummary, failures: List(FormFailure))
  FormCheckParseFailed(error: ast.ParseError)
  InvalidFormConfig(error: FormConfigError)
}

pub type FormConfigError {
  InvalidDecimalPlaceCount(count: Int)
}
```

- Form-aware result:

```gleam
pub type FormAwareAlgebraicResult {
  SemanticsFailed(result: algebraic_types.AlgebraicEquivalenceResult)
  SemanticsPassedFormSatisfied(
    equivalence: algebraic_types.AlgebraicEquivalenceResult,
    form: FormCheckResult,
  )
  SemanticsPassedFormFailed(
    equivalence: algebraic_types.AlgebraicEquivalenceResult,
    form: FormCheckResult,
  )
}
```

- Public `torus_math` functions:

```gleam
pub fn default_exact_form_config() -> form_types.ExactFormConfig

pub fn check_exact_form(
  candidate: String,
  config: form_types.ExactFormConfig,
) -> form_types.FormCheckResult

pub fn check_algebraic_equivalence_with_form(
  expected: String,
  candidate: String,
  equivalence_config: algebraic_types.AlgebraicEquivalenceConfig,
  form_config: form_types.ExactFormConfig,
) -> form_types.FormAwareAlgebraicResult

pub fn form_check_result_to_debug_string(
  result: form_types.FormCheckResult,
) -> String

pub fn form_aware_algebraic_result_to_debug_string(
  result: form_types.FormAwareAlgebraicResult,
) -> String
```

- Elixir bridge in `Oli.Math.ExactForm`:

```elixir
default_config() :: term()
check(candidate :: String.t(), config :: term()) :: term()
check_algebraic(expected :: String.t(), candidate :: String.t(), equivalence_config :: term(), form_config :: term()) :: term()
result_debug(result :: term()) :: String.t()
form_aware_result_debug(result :: term()) :: String.t()
config_from_form(params :: map()) :: {:ok, term()} | {:error, [%{field: String.t(), message: String.t()}]}
```

- Prototype form fields under the existing `algebraic[...]` form:
  - `form_constraint`: `none`, `integer`, `fraction`, `simplified_fraction`, or `decimal`.
  - `decimal_precision_rule`: `any`, `exactly`, `at_least`, or `at_most`.
  - `decimal_precision_count`: non-negative integer string used when the rule is not `any`.
- Prototype assigns:
  - `algebraic_form`: extended with exact-form fields.
  - `algebraic_result`: supports either existing algebraic result display data or form-aware display data.
  - `algebraic_errors`: reused for form config errors.

- Internal helpers in `form.gleam`:
  - `classify_expression(expr: ast.Expr) -> ObservedFormDetail`
  - `peel_sign(expr: ast.Expr) -> #(Sign, ast.Expr)`
  - `integer_literal(expr: ast.Expr) -> Result(SignedInteger, LiteralFailure)`
  - `fraction_literal(expr: ast.Expr) -> Result(FractionDetail, LiteralFailure)`
  - `gcd(a: Int, b: Int) -> Int`
  - `decimal_precision_matches(actual: Int, constraint: DecimalPrecisionConstraint) -> Result(List(FormFailure), FormConfigError)`

## 6. Data Model & Storage
- No database schema changes.
- No activity JSON schema changes.
- No response-rule, attempt, publication, section, or resource migration.
- No Cachex, Oban, analytics, or xAPI data changes.
- The proposed future equality JSON shape may include a sibling `form` object under expression configs, but this work item should not implement JSON persistence unless a later plan explicitly adds that slice.
- Public result summaries should avoid raw submitted text. Debug formatters may include raw numeric literal fragments if needed for developer and test clarity.
- Prototype form state and results are transient LiveView assigns only.

## 7. Consistency & Transactions
- No database transactions are introduced.
- Consistency is functional:
  - parse raw candidate once for standalone form checks;
  - classify from AST shape and numeric metadata;
  - for form-aware algebraic checks, preserve the original algebraic semantic result unchanged when semantics fail;
  - apply form checks only after an `Equivalent(_)` semantic outcome.
- GCD and integer parsing must use only safe integer components so Erlang and JavaScript results cannot diverge.

## 8. Caching Strategy
N/A. Form checks are pure, small, and bounded. Do not add caching for this work item.

## 9. Performance & Scalability Posture
- Standalone form checks are O(size of candidate AST) plus bounded integer parsing and GCD.
- Form-aware checks add one candidate parse and classification only after semantic equivalence passes.
- The form module must not perform sampling, normalization, symbolic expansion, factoring, rational simplification, or repeated evaluation.
- Reject unsafe integer components instead of adding arbitrary precision code to the MVP.
- Required performance posture for review: confirm no unbounded recursion beyond AST traversal and no regex-heavy source scanning.

## 10. Failure Modes & Resilience
- Invalid form config:
  - Negative decimal-place counts return `InvalidFormConfig(InvalidDecimalPlaceCount(...))`.
- Candidate parse failure in standalone form check:
  - Return `FormCheckParseFailed`.
- Candidate parse failure in form-aware algebraic check:
  - Algebraic equivalence returns candidate parse failure first; do not run form checks (`AC-012`).
- Invalid prototype form config:
  - `Oli.Math.ExactForm.config_from_form/1` returns structured field errors and the LiveView renders them without calling the form-aware checker.
- Semantic non-equivalence:
  - Return `SemanticsFailed` and do not expose wrong-form as primary (`AC-011`).
- Equivalent but wrong form:
  - Return `SemanticsPassedFormFailed` with form failures (`AC-010`).
- Unsafe integer literal or unsafe fraction component:
  - Return `FormNotSatisfied` with `UnsafeIntegerLiteral`; do not attempt GCD.
- Denominator zero:
  - Classify as wrong form or invalid fraction detail; do not treat it as a valid fraction.
- Unit or quantity expression:
  - Treat as `ObservedOther` because unit-aware exact form is out of scope.
- Unexpected parser shape:
  - Treat as `ObservedOther` and fail with `WrongForm` when a concrete form is required.

## 11. Observability
- No production telemetry is required or introduced.
- Stable debug formatting is the observability mechanism for tests and developer diagnostics (`AC-014`).
- Debug formatter comments must state that output is not learner-facing feedback and must not be logged as production telemetry by default.
- The Math Prototype LiveView may render raw expected/candidate expressions and debug details because it is developer-only. It must not log them.
- Future telemetry, if added outside this work item, should use form categories, outcome counts, normalized hashes, and timing buckets, not raw expressions or assignments.

## 12. Security & Privacy
- Do not log raw submitted expressions, raw expected answers, raw numeric fragments, or sampled assignments in production paths (`AC-017`).
- Keep raw strings out of production-oriented result summaries.
- Avoid dynamic atoms or runtime code generation; all form categories are Gleam variants.
- The Elixir bridge must pattern-match known form selector strings and return validation errors for unknown values instead of converting user input into atoms.
- The LiveView update must remain under the existing developer-only prototype route and must not expose exact-form controls in production activity authoring or learner delivery.
- The standalone and form-aware APIs parse user-provided strings but do not execute code, perform IO, touch the database, or allocate unbounded symbolic structures.
- Review with `.review/security.md` and `.review/performance.md` is required. `.review/gleam.md`, `.review/elixir.md`, `.review/ui.md`, and `.review/requirements.md` also apply when the prototype update is implemented.

## 13. Testing Strategy
- Add `gleam/test/math_equality_form_test.gleam`:
  - Config and result constructor coverage for `AC-001` and `AC-002`.
  - Integer classifier and integer-only form cases for `AC-003` and `AC-006`.
  - Fraction classifier and fraction-only form cases for `AC-004` and `AC-007`.
  - Decimal classifier and decimal precision cases for `AC-005` and `AC-009`.
  - Simplified fraction, zero denominator policy, zero numerator policy, non-canonical sign, and unsafe integer cases for `AC-008`.
- Add `gleam/test/math_equality_form_algebraic_test.gleam` or equivalent:
  - `4/5` vs `8/10` with simplified-fraction required returns semantic pass plus form failure (`AC-010`).
  - `4/5` vs `8/11` with simplified-fraction required returns semantic failure, not wrong form (`AC-011`).
  - Malformed candidates, unexpected variables, disallowed functions, invalid config, runtime failures, and insufficient samples preserve semantic outcomes (`AC-012`).
  - Public `torus_math` functions are covered (`AC-013`).
- Add `gleam/test/math_equality_form_format_test.gleam`:
  - Stable debug strings for satisfied form, wrong form, unsimplified fraction, decimal precision mismatch, invalid config, parse failure, semantic failure, semantic pass plus form pass, and semantic pass plus form fail (`AC-014`, `AC-019`).
- Add `test/oli/math/exact_form_test.exs`:
  - Bridge calls the public Gleam default config, standalone form check, form-aware algebraic check, and debug formatter.
  - `config_from_form/1` converts each selector to the expected Gleam config.
  - Invalid selector and invalid decimal precision inputs return structured errors without dynamic atom creation.
- Update `test/oli_web/live/dev/math_prototype_live_test.exs`:
  - The Algebraic Equivalence panel renders exact-form controls.
  - Selecting simplified fraction and checking expected `4/5` against candidate `8/10` displays semantic pass plus form failure.
  - Checking expected `4/5` against candidate `8/11` displays semantic failure as primary.
  - Decimal precision controls render and validate exactly/at least/at most count inputs.
  - Invalid form config displays errors without crashing the LiveView.
- Keep or extend existing numeric tests:
  - Run `gleam/test/math_equality_numeric_test.gleam` when shared helper extraction touches representation or precision behavior (`AC-015`).
- Production boundary checks:
  - Inspection confirms no production Short Answer, Multi-Input, Number, legacy Math, adaptive activity, authoring UI, learner UI, response-rule grading, scoring, persistence, telemetry, or feedback-rule behavior changed (`AC-016`, `AC-017`).
- Required commands:
  - `cd gleam && gleam format --check src test`
  - `cd gleam && gleam test --target erlang`
  - `cd gleam && gleam test --target javascript`
  - If Elixir bridge or LiveView files are changed, run targeted `mix format --check-formatted` and targeted ExUnit tests for those files.
  - These satisfy `AC-018` and support `AC-019`.

## 14. Backwards Compatibility
- Existing parser AST shapes are consumed but not changed.
- Existing algebraic equivalence APIs remain available and keep their current outcomes.
- Existing numeric scalar representation and precision behavior remains unchanged (`AC-015`).
- Existing equality JSON decoding/encoding remains unchanged unless a future storage slice explicitly adds form config.
- Existing Math Prototype parser and algebraic-equivalence behavior remains available. The exact-form controls extend the algebraic panel rather than replacing it.
- No production grading or activity behavior changes are introduced (`AC-016`).

## 15. Risks & Mitigations
- Risk: form checks appear before or instead of semantic correctness.
  - Mitigation: form-aware wrapper gates on `Equivalent(_)`, and tests explicitly cover semantic failure precedence (`AC-010`, `AC-011`, `AC-012`).
- Risk: normalized-expression APIs are used without source metadata.
  - Mitigation: expose exact-form checks only for raw candidates or parsed AST internal helpers; do not add normalized-only exact-form API.
- Risk: Number-input behavior regresses through helper reuse.
  - Mitigation: keep form logic separate initially and run numeric tests for any shared helper extraction (`AC-015`).
- Risk: large integer behavior drifts between Erlang and JavaScript.
  - Mitigation: reject unsafe integer components and test the failure category.
- Risk: diagnostics leak raw answers into production logs.
  - Mitigation: keep raw fragments in debug formatters only and document non-production use (`AC-014`, `AC-017`).
- Risk: scope expands into algebraic form recognition.
  - Mitigation: classify only whole-answer integer, decimal, and scalar integer-literal fraction forms.
- Risk: developer prototype exact-form controls are mistaken for production authoring behavior.
  - Mitigation: keep the update in `lib/oli_web/live/dev/math_prototype_live.ex`, avoid storage, and label/render it as diagnostics beside existing algebraic prototype output.

## 16. Open Questions & Follow-ups
- Follow-up: define production equality JSON storage for a `form` object when production activity integration is planned.
- Follow-up: define author-facing feedback mapping for `WrongForm`, `UnsimplifiedFraction`, `DecimalPrecisionMismatch`, `NonCanonicalFractionSign`, and `UnsafeIntegerLiteral`.
- Follow-up: consider arbitrary precision integer support only if future product requirements need exact-form checks for very large fractions.

## 17. References
- `docs/exec-plans/current/epics/math/exact-form/prd.md`
- `docs/exec-plans/current/epics/math/exact-form/requirements.yml`
- `docs/exec-plans/current/epics/math/exact-form/informal.md`
- `docs/exec-plans/current/epics/math/plan.md`
- `gleam/src/torus_math.gleam`
- `gleam/src/math/ast.gleam`
- `gleam/src/math/parser.gleam`
- `gleam/src/math/equality/algebraic.gleam`
- `gleam/src/math/equality/algebraic_types.gleam`
- `gleam/src/math/equality/numeric.gleam`
- `gleam/src/math/equality/json.gleam`
- `lib/oli/math/algebraic.ex`
- `lib/oli_web/live/dev/math_prototype_live.ex`
- `test/oli/math/algebraic_test.exs`
- `docs/STACK.md`
- `docs/TOOLING.md`
- `docs/TESTING.md`
- `docs/BACKEND.md`
- `docs/FRONTEND.md`
- `docs/DESIGN.md`
- `docs/OPERATIONS.md`
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
- `docs/design-docs/attempt.md`
- `docs/design-docs/attempt-handling.md`
