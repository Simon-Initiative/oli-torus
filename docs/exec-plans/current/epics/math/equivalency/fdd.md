# Algebraic Expression Equivalence - Functional Design Document

## 1. Executive Summary
This design adds algebraic expression equivalence as the first executable expression comparison policy in the shared Gleam math layer. The core implementation lives under `gleam/src/math/equality/`, reuses parser, normalization, deterministic sampling, evaluation, domains, and tolerance helpers, and exposes a narrow public API through `gleam/src/torus_math.gleam`.

The MVP checks value equivalence over deterministic sample assignments where the expected expression is defined. It is not symbolic proof, does not perform CAS-style rewrites, and does not change production grading behavior. The developer-only Math Prototype LiveView gains an Algebraic Equivalence panel backed by a thin Elixir bridge so developers can inspect structured outcomes, per-variable domains, full sample comparisons, rejection summaries, and production-friendly summary data.

## 2. Requirements & Assumptions
- Functional requirements:
  - FR-001: expose raw-string and normalized-expression algebraic equivalence APIs.
  - FR-002: compose existing math layers instead of duplicating parser, normalizer, sampler, evaluator, domain, or tolerance behavior.
  - FR-003: implement `ExpectedDefinedDomain` semantics: expected-invalid sample points retry; candidate-invalid at expected-valid points fails as non-equivalence.
  - FR-004: validate variables, functions, domains, sampling config, and tolerance config before or during the equivalence loop.
  - FR-005: return structured diagnostics, full sample comparisons, production-friendly summary data, and stable debug output.
  - FR-006: extend the developer Math Prototype LiveView with per-variable domain rows and structured result output.
  - FR-007: preserve cross-target determinism and avoid production grading, authoring, learner UI, or telemetry changes.
  - FR-008: add representative golden corpus and failure coverage.
- Non-functional requirements:
  - Deterministic results on Erlang and JavaScript targets.
  - Bounded work through `max_attempts`, early exit on first mismatch or candidate runtime failure, and no unbounded symbolic search.
  - Developer diagnostics may include raw expressions and assignments in the prototype; production telemetry must not log them by default.
  - Public Gleam exports must include useful function-level comments and remain small enough for Elixir and browser wrappers to consume safely.
- Assumptions:
  - Default allowed variables are inferred from the expected expression. Candidate-only variables fail validation unless explicitly allowed.
  - Default sample count is 8 valid expected-defined samples.
  - Default sampling seed is the existing sampling default when available, otherwise `42`.
  - Default tolerance is `AbsoluteOrRelativeTolerance(abs: 0.0001, rel: 0.0001, epsilon: 0.000000000001)`.
  - Trigonometric functions use radians.
  - The initial prototype supports per-variable domain rows.
  - Result values retain full sample comparison rows and include production-friendly summary fields.

## 3. Repository Context Summary
- What we know:
  - `gleam/src/torus_math.gleam` is the shared public math boundary used by Elixir and browser wrappers.
  - `gleam/src/math/equality/types.gleam` already models expression equality placeholders, but executable expression modes currently return `UnsupportedMode(ExpressionEvaluation)`.
  - `gleam/src/math/normalization/types.gleam` provides `NormalExpr` and reserves `NormalQuantity`; this feature supports expression values only and leaves units out of scope.
  - `gleam/src/math/sampling/types.gleam`, `sample.gleam`, `evaluate.gleam`, `domain.gleam`, `assignment.gleam`, and `tolerance.gleam` already own the assignment, domain, sampler, runtime error, and comparison contracts this feature should reuse.
  - `lib/oli/math.ex`, `lib/oli/math/equality.ex`, and `lib/oli/math/gleam.ex` show the current thin Elixir bridge pattern over generated Gleam modules.
  - `lib/oli_web/live/dev/math_prototype_live.ex` is the existing developer-only prototype surface and currently compares server and browser parser output.
  - `assets/src/gleam/torusExpression.ts` and `assets/src/hooks/math_prototype.ts` provide the current browser parser prototype path.
- Unknowns to confirm:
  - Whether the existing `/math_prototype` route is already adequately restricted for all deployed environments. The implementation should preserve the current route placement and not promote the panel into production authoring or delivery.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `gleam/src/math/equality/algebraic_types.gleam`
  - Owns algebraic equivalence config, allowed-variable policy, allowed-function policy, domain policy, diagnostic level, result, summary, validation errors, sample comparisons, and candidate runtime failure types.
  - Reuses `math/sampling/types.gleam` for `DomainConfig`, `SamplingConfig`, `EvalConfig`, `Tolerance`, `Assignment`, `SampleSource`, `RuntimeMathError`, `ComparisonResult`, and `RejectedSampleSummary`.
- `gleam/src/math/equality/pipeline.gleam`
  - Owns parse/normalize helpers, extraction of `NormalExpr` from normalized parsed output, variable collection, function collection, validation, and stable variable-to-sample resolution.
  - Does not decide equivalence; it only prepares validated inputs and config.
- `gleam/src/math/equality/algebraic.gleam`
  - Owns the equivalence algorithm for raw strings and normalized expressions.
  - Uses the same accepted assignments for expected and candidate evaluation.
  - Calls existing sampler and evaluator modules rather than creating a separate random source or evaluator.
- `gleam/src/math/equality/algebraic_format.gleam`
  - Owns stable debug strings for configs, outcomes, summaries, sample comparisons, runtime failures, and validation errors.
  - Must not depend on target-specific inspect formatting.
- `gleam/src/torus_math.gleam`
  - Exposes `default_algebraic_equivalence_config/0`, `check_algebraic_equivalence/3`, `check_normalized_algebraic_equivalence/3`, and `algebraic_equivalence_result_to_debug_string/1`.
- `lib/oli/math/algebraic.ex`
  - Thin Elixir bridge that hides generated Gleam module names and Erlang tuple shapes from the LiveView.
  - Converts prototype form values into the public Gleam config terms without reimplementing equivalence semantics.
- `lib/oli_web/live/dev/math_prototype_live.ex`
  - Adds the Algebraic Equivalence panel and result rendering.
  - Keeps form state and display concerns in LiveView; all math decisions remain in Gleam.

### 4.2 State & Data Flow
Raw-string API flow for AC-001, AC-003, AC-009, and AC-012:

1. `torus_math.check_algebraic_equivalence(expected, candidate, config)` calls the pipeline.
2. Parse expected. On failure, return `ExpectedParseFailed`.
3. Parse candidate. On failure, return `CandidateParseFailed`.
4. Normalize both parsed values.
5. Extract `NormalExpression` values. `NormalQuantity` or unit-bearing shapes return an unsupported expression-shape outcome because units are out of scope.
6. Collect expected variables, candidate variables, expected functions, and candidate functions.
7. Resolve allowed variables:
   - `InferFromExpected` uses the stable sorted expected variable list.
   - `ExplicitAllowedVariables(names)` sorts and deduplicates configured names.
8. Validate expected and candidate variables are subsets of allowed variables. Default inferred mode therefore rejects candidate-only variables.
9. Resolve variables to sample as the stable sorted union of variables present in the validated expected and candidate expressions. Do not sample unused allowed variables.
10. Validate allowed functions and config.
11. If the variables-to-sample list is empty, run the constant-expression path.
12. Otherwise, run the expected-defined-domain sampling comparison loop.

Sampling comparison flow for AC-004, AC-005, AC-006, AC-007, AC-008, AC-010, AC-011, AC-016, AC-019, and AC-020:

1. Use `math/sampling/sample.valid_samples_for_expression(expected, variables, domains, sampling_config, eval_config)` to get accepted expected-valid assignments and expected rejection summaries.
2. If sampling returns `InsufficientValidSamples`, surface it unchanged as an equivalence outcome with requested, found, attempts, and rejected summaries.
3. For each accepted assignment, evaluate expected again to capture the expected value for the result row.
4. Evaluate candidate with the same assignment.
5. If candidate evaluation fails while expected succeeded, return `NotEquivalent(CandidateUndefined(...))`.
6. Compare expected and candidate values with `math/sampling/tolerance.compare_numbers`.
7. If comparison fails, return `NotEquivalent(ValueMismatch(first_failure))`.
8. If all accepted samples pass, return `Equivalent(valid_sample_count)`.
9. Always include full successful comparison rows produced before the final outcome, rejection summaries from expected sampling, config summary, and production-friendly summary data.

Constant-expression flow:

1. Build an empty assignment using the assignment module.
2. Evaluate expected and candidate once.
3. Candidate runtime failure after expected success is `CandidateUndefined`.
4. Tolerance comparison pass returns `Equivalent(1)`; failure returns `NotEquivalent(ValueMismatch(...))`.
5. The sample comparison source is an algebraic-specific `ConstantExpression` source rather than overloading sampler `SampleSource`.

### 4.3 Lifecycle & Ownership
- Gleam owns equivalence semantics, result taxonomy, config defaults, validation, deterministic ordering, and stable debug formatting.
- Elixir owns only prototype form parsing, calling the public Gleam boundary, and rendering results.
- TypeScript/browser code is not required for the first equivalence prototype panel. Browser-target parity is proved with `gleam test --target javascript`.
- No persistent activity config, response-rule config, attempt data, publication data, or analytics data changes are made in this work item.

### 4.4 Alternatives Considered
- Add equivalence directly to `math/equality/evaluate.gleam`.
  - Rejected for MVP because existing equality evaluation handles the stored equality-config contract and numeric scalar mode. Algebraic equivalence has a richer config/result shape and should remain independently testable before production grading integration.
- Generate independent sample sets for expected and candidate expressions.
  - Rejected because equivalence must compare both expressions at the same assignments. Separate sample sets can hide differences and break explainability.
- Use raw `sample_assignments` and implement all expected retry behavior in the algebraic module.
  - Rejected for the first implementation because `valid_samples_for_expression` already owns expected-defined retry behavior and rejection summaries. The algebraic module should reuse it, then re-evaluate expected to populate comparison rows.
- Add production authoring UI immediately.
  - Rejected by PRD scope. The developer prototype is the only UI surface in this work item.

## 5. Interfaces
- Gleam public API in `torus_math`:
  - `pub fn default_algebraic_equivalence_config() -> algebraic_types.AlgebraicEquivalenceConfig`
  - `pub fn check_algebraic_equivalence(expected: String, candidate: String, config: algebraic_types.AlgebraicEquivalenceConfig) -> algebraic_types.AlgebraicEquivalenceResult`
  - `pub fn check_normalized_algebraic_equivalence(expected: normalization_types.NormalExpr, candidate: normalization_types.NormalExpr, config: algebraic_types.AlgebraicEquivalenceConfig) -> algebraic_types.AlgebraicEquivalenceResult`
  - `pub fn algebraic_equivalence_result_to_debug_string(result: algebraic_types.AlgebraicEquivalenceResult) -> String`
- Core config types:
  - `AlgebraicEquivalenceConfig(allowed_variables, allowed_functions, domains, sampling, eval, tolerance, domain_policy, diagnostics)`
  - `AllowedVariables = InferFromExpected | ExplicitAllowedVariables(List(String))`
  - `AllowedFunctions = DefaultSupportedFunctions | ExplicitAllowedFunctions(List(ast.FunctionName))`
  - `DomainPolicy = ExpectedDefinedDomain`
  - `DiagnosticLevel = SummaryDiagnostics | DetailedDiagnostics`
- Core result types:
  - `AlgebraicEquivalenceResult(outcome, expected_debug, candidate_debug, samples, rejected_samples, summary, config_summary)`
  - `AlgebraicEquivalenceOutcome = Equivalent(valid_sample_count) | NotEquivalent(reason) | ExpectedParseFailed(error) | CandidateParseFailed(error) | UnsupportedExpressionShape(side, reason) | ValidationFailed(errors) | InvalidConfiguration(error) | InsufficientValidSamples(error) | ExpectedEvaluationFailed(error)`
  - `NonEquivalenceReason = ValueMismatch(first_failure) | CandidateUndefined(first_failure) | ComparisonFailed(error)`
  - `SampleComparison(index, source, assignment, expected_value, candidate_value, comparison)`
  - `CandidateRuntimeFailure(index, source, assignment, expected_value, error)`
  - `EquivalenceSummary(outcome_category, requested_sample_count, valid_sample_count, attempts, rejected_sample_count, first_failure_index, variables_sampled)`
- Elixir bridge:
  - `Oli.Math.Algebraic.default_config/0`
  - `Oli.Math.Algebraic.check/3`
  - `Oli.Math.Algebraic.result_debug/1`
  - `Oli.Math.Algebraic.config_from_form/1`
- LiveView events:
  - `update_algebraic_form`: stores expected, candidate, sample count, seed, max attempts, allowed variables, tolerance controls, and per-variable domain rows.
  - `add_domain_row`: appends a domain row.
  - `remove_domain_row`: removes a domain row.
  - `check_algebraic_equivalence`: builds config through `Oli.Math.Algebraic`, calls Gleam, and assigns rendered result data.

## 6. Data Model & Storage
- No database schema changes.
- No activity JSON schema changes.
- No response-rule, attempt, publication, section, or resource migration.
- Per-variable domain rows are transient LiveView form state only:
  - variable name
  - lower value
  - lower inclusivity
  - upper value
  - upper inclusivity
  - integer-only flag
  - exclusions as comma-separated floats
  - preferred values as comma-separated floats
- The Gleam config uses `math/sampling/types.DomainConfig` and `VariableDomain`; the LiveView converts form rows into that config shape through the Elixir bridge.
- Production-friendly summary data is part of the returned result value, not persisted storage.

## 7. Consistency & Transactions
- No transactional database work is introduced.
- Consistency is functional and deterministic:
  - Sort variables, allowed-variable lists, function lists, domain rows, and assignment values by stable string order before comparison or debug formatting.
  - Use the existing pure Gleam PRNG through the sampling module.
  - Never use JavaScript, Erlang, or Elixir runtime random functions.
  - Evaluate both expressions against the same assignment values.

## 8. Caching Strategy
N/A. The prototype should compute results on demand. Do not add Cachex or LiveView-level result caching in this work item. Deterministic behavior and bounded `max_attempts` are sufficient for developer usage.

## 9. Performance & Scalability Posture
- Expected cost is bounded by parsing two expressions, normalizing two expressions, generating up to `max_attempts` expected-valid samples, evaluating expected and candidate over accepted samples, and tolerance comparisons.
- The algorithm stops early on:
  - parse failure;
  - validation failure;
  - invalid config;
  - first candidate runtime failure;
  - first value mismatch;
  - insufficient expected-valid samples.
- Full sample comparison retention is acceptable because default sample count is 8 and `max_attempts` is bounded. The implementation should store only accepted comparison rows and aggregate rejected expected samples, not every rejected raw assignment.
- Avoid debug string formatting inside the sampling/evaluation loop unless constructing a final result after an outcome is known.
- No production latency SLO is set in this phase because the only UI integration is developer-only.

## 10. Failure Modes & Resilience
- Expected parse failure:
  - Return `ExpectedParseFailed` with parse error and no sampling.
- Candidate parse failure:
  - Return `CandidateParseFailed` with parse error and no sampling.
- Normalization yields unit or unsupported quantity shape:
  - Return `UnsupportedExpressionShape` because units are out of scope.
- Unexpected variable:
  - Return `ValidationFailed` instead of `NotEquivalent`.
- Disallowed function:
  - Return `ValidationFailed`.
- Invalid sampling/domain/tolerance config:
  - Return `InvalidConfiguration` with structured details.
- Expected runtime failure at generated sample:
  - Let `valid_samples_for_expression` reject and retry it.
- Too few expected-valid samples:
  - Return `InsufficientValidSamples` with requested count, found count, attempts, and rejection summaries.
- Candidate runtime failure at expected-valid sample:
  - Return `NotEquivalent(CandidateUndefined(...))`.
- Tolerance comparison failure:
  - Return `NotEquivalent(ValueMismatch(...))`.
- Non-finite evaluation or unsupported evaluator node:
  - Preserve existing runtime math error categories and surface them through the same expected/candidate policies.

## 11. Observability
- No production telemetry is required or introduced.
- Stable debug output is the primary observability mechanism for tests and the developer prototype.
- The LiveView may render raw expressions, assignments, values, and debug strings because it is developer-only.
- Future telemetry, if added outside this work item, must prefer:
  - outcome category;
  - sample count;
  - attempt count;
  - rejection category counts;
  - normalized expression hash;
  - elapsed time bucket.
- Future telemetry must not log raw learner expressions or raw sampled assignments by default.

## 12. Security & Privacy
- Keep the Algebraic Equivalence panel inside the existing developer-only Math Prototype LiveView route.
- Do not expose this work through production authoring, production delivery, student UI, response-rule evaluation, Short Answer, Multi-Input, Number, legacy Math, or adaptive activity paths.
- Do not persist prototype expressions, assignments, or sample details.
- Do not add logs that include raw expressions or raw assignments.
- Treat debug strings as developer/test/prototype diagnostics, not learner-facing feedback copy.
- The Elixir bridge must not use dynamic atom creation from user-supplied variable or function names.

## 13. Testing Strategy
- Gleam unit and golden tests:
  - Raw-string API coverage for AC-001.
  - Normalized-expression API coverage for AC-002.
  - Reuse inspection and targeted tests for AC-003.
  - Equivalent examples: `2(x+3)` vs `2x+6`, `(x+1)(x-1)` vs `x^2-1`, commutative/associative examples, constants, functions, and multi-variable identities for AC-004 and AC-019.
  - Near misses: `2(x+3)` vs `2x+7`, `x^2` vs `x`, `x+y` vs `2x`, and sign errors for AC-005 and AC-019.
  - Expected runtime retry examples such as `1/x` vs `x^-1` for AC-006.
  - Candidate runtime failures such as `x` vs `1/(1/x)` with `x=0` in-domain for AC-007.
  - Insufficient samples such as `1/x` over `x in [0,0]` for AC-008.
  - Parse, variable validation, function validation, and invalid config outcomes for AC-009 and AC-010.
  - Stable variables-to-sample ordering and unused allowed-variable exclusion for AC-011.
  - Result detail fields, summary fields, full comparison rows, and stable debug strings for AC-012 and AC-013.
  - Cross-target deterministic fixtures for AC-016 and AC-020.
- Elixir tests:
  - `Oli.Math.Algebraic` wrapper tests for config construction, default config call, equivalence call, and debug formatting.
  - `OliWeb.Dev.MathPrototypeLive` tests for rendering the Algebraic Equivalence panel, checking an equivalent pair, checking a near miss, showing a parse error, and displaying per-variable domain rows for AC-014.
- Manual prototype validation:
  - Exercise expansion, factoring, trig identity, near miss, unexpected variable, expected-domain, candidate-domain, and insufficient-sample presets.
  - Confirm the panel displays full comparison data, rejection summaries, first failure details, production-friendly summary data, and the note that deterministic sampling is not symbolic proof for AC-015.
- Required commands:
  - `cd gleam && gleam format --check src test`
  - `cd gleam && gleam test --target erlang`
  - `cd gleam && gleam test --target javascript`
  - Targeted `mix test` for `Oli.Math.Algebraic` and `OliWeb.Dev.MathPrototypeLive` if those Elixir files are changed.

## 14. Backwards Compatibility
- Existing parser, normalization, sampling, and numeric equality behavior must continue to pass current tests.
- `Oli.Math.Equality.evaluate_json/2` continues to return unsupported expression mode for stored `Expression(...)` equality specs unless a later production integration explicitly changes that behavior.
- No production grading behavior changes for Short Answer, Multi-Input, Number, legacy Math, adaptive activity, authoring UI, student UI, or response-rule evaluation, satisfying AC-017.
- No production telemetry containing raw learner expressions or raw sampled assignments is added, satisfying AC-018.
- The existing parser prototype behavior remains available; the Algebraic Equivalence panel is additive.

## 15. Risks & Mitigations
- False positives from sampling:
  - Use special points, deterministic pseudo-random samples, existing anti-correlation behavior, and golden corpus coverage; keep UI copy honest that this is not symbolic proof.
- Hidden domain mismatch:
  - Document and encode only `ExpectedDefinedDomain` in the MVP; candidate undefined at expected-valid points fails, while strict domain compatibility remains future work.
- Floating-point drift:
  - Use the existing tolerance helper and run both Erlang and JavaScript Gleam targets.
- Result objects grow too large:
  - Retain only accepted sample comparisons and aggregate rejected expected samples; default counts stay small and bounded by config.
- Prototype leaks into production:
  - Keep code path isolated to the dev LiveView and thin wrapper; do not wire equality config, response rules, or activity evaluation.
- Elixir tuple-shape coupling to Gleam:
  - Hide tuple construction and calls inside `Oli.Math.Algebraic`; tests should exercise the wrapper so generated-shape changes are caught locally.

## 16. Open Questions & Follow-ups
- No open questions block the initial implementation.
- Follow-up: add production author preview only after the developer prototype and golden corpus stabilize.
- Follow-up: add strict domain compatibility as a separate explicit mode if product needs domain-equivalence proof.
- Follow-up: add exact-form, unit-aware, partial-credit, and feedback-rule integration as separate work items.
- Follow-up: decide whether browser-side prototype equivalence is useful after server-side prototype diagnostics are stable.

## 17. References
- `docs/exec-plans/current/epics/math/equivalency/prd.md`
- `docs/exec-plans/current/epics/math/equivalency/requirements.yml`
- `docs/exec-plans/current/epics/math/equivalency/equivalency.md`
- `docs/exec-plans/current/epics/math/sampling/fdd.md`
- `docs/exec-plans/current/epics/math/normalization/fdd.md`
- `docs/exec-plans/current/epics/math/parser/fdd.md`
- `ARCHITECTURE.md`
- `docs/STACK.md`
- `docs/TOOLING.md`
- `docs/TESTING.md`
- `docs/BACKEND.md`
- `docs/FRONTEND.md`
- `docs/DESIGN.md`
- `docs/OPERATIONS.md`
- `gleam/src/torus_math.gleam`
- `gleam/src/math/equality/types.gleam`
- `gleam/src/math/sampling/types.gleam`
- `lib/oli/math/equality.ex`
- `lib/oli_web/live/dev/math_prototype_live.ex`
