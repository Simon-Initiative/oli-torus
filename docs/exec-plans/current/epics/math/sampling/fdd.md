# Deterministic Expression Evaluation And Sampling Infrastructure - Functional Design Document

## 1. Executive Summary
Implement deterministic expression evaluation and sampling as a shared Gleam subsystem layered after math parsing and structural normalization. The evaluator will consume normalized expression nodes, variable assignments, and evaluation config, then return either a finite `Float` or a structured runtime math error. The sampler will consume variables, domain config, sample config, and a deterministic seed to produce repeatable assignments, then the valid-sample executor will retry expression-invalid assignments and report insufficient-sample diagnostics when needed.

This design intentionally does not implement final algebraic equivalence. It creates the primitives future equivalence will use: evaluation, assignment/domain modeling, deterministic sampling, valid-point discovery, and numeric tolerance comparison. The implementation lives in `gleam/src/math/`, exposes a small public surface through `gleam/src/torus_math.gleam`, and must pass equivalent Gleam tests on Erlang and JavaScript targets. It satisfies FR-001 through FR-008 and AC-001 through AC-013.

## 2. Requirements & Assumptions
- Functional requirements:
  - FR-001: evaluate normalized real-valued math expressions and return structured runtime errors.
  - FR-002: define first-class assignment, domain, evaluation config, sampling config, runtime error, and diagnostic models.
  - FR-003: generate deterministic samples from domains and seeds with pure Gleam PRNG behavior.
  - FR-004: execute expression-aware valid sampling with retry and insufficient-sample diagnostics.
  - FR-005: provide detailed numeric tolerance comparison helpers.
  - FR-006: preserve shared Gleam API, stable debug output, function-level comments, and cross-target parity.
  - FR-007: maintain privacy boundaries and keep final equivalence, symbolic simplification, units, and complex numbers out of scope.
  - FR-008: establish representative evaluation and sampling performance checks.
- Non-functional requirements:
  - Determinism across Erlang and JavaScript is mandatory for PRNG output, samples, evaluation outcomes, debug strings, and comparison details.
  - Runtime math failures must be explicit result values, not panics, `NaN`, infinity, or unstructured strings.
  - Production telemetry must avoid raw learner expressions and raw sampled assignments by default.
  - Public APIs must stay narrow and documented with Gleam comments, especially exported functions.
  - Integer-only domains must return unique samples; if uniqueness cannot satisfy the requested count, return structured insufficient-sample diagnostics rather than duplicates.
- Assumptions:
  - The public evaluator accepts normalized expression nodes only, not raw parsed expressions and not strings.
  - The default tolerance for future equivalence consumers starts at `0.0001`; this work will expose that as a default tolerance helper but will not apply equivalence policy.
  - The default effective domain for unspecified variables is finite `[-10, 10]`.
  - Trigonometric functions use radians, and `log(x)` means natural logarithm.
  - `0^0` is invalid in the domain-aware evaluator.
  - No math prototype LiveView or frontend preview surface is updated in this work item.

## 3. Repository Context Summary
- What we know:
  - `gleam/src/math/ast.gleam` owns parser-level constants, function names, spans, and parsed expression structures.
  - `gleam/src/math/normalization/types.gleam` owns `NormalExpr`, `NormalParsed`, `ExactNumber`, and unit placeholder structures. This work consumes `NormalExpr`.
  - `gleam/src/torus_math.gleam` is the public shared math boundary for Torus callers and should be extended with small evaluator, sampler, and tolerance entry points.
  - `gleam/src/math/equality/types.gleam` already has equality-contract placeholders for expression specs, simple domains, and sampling config. This sampling layer should remain separate from that config contract until the later algebraic equivalence work wires them together.
  - `docs/TOOLING.md` and `docs/TESTING.md` require shared Gleam behavior to pass `gleam test --target erlang` and `gleam test --target javascript`.
  - `docs/BACKEND.md` and `docs/FRONTEND.md` establish shared Gleam as the source of truth, with Elixir and TypeScript wrappers kept thin when they are needed.
- Unknowns to confirm:
  - Whether future algebraic equivalence will import this layer directly or wrap it behind `math/equality` APIs.
  - Whether production grading will later need telemetry events for sample counts, retry counts, and runtime error categories.
  - Whether future authoring UI will require serialization shapes for assignment/domain config beyond the internal debug strings designed here.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
Add a new internal subsystem under `gleam/src/math/sampling/`:

- `gleam/src/math/sampling/types.gleam`
  - Owns `Assignment`, `VariableValue`, `EvalConfig`, `RuntimeMathError`, `DomainConfig`, `VariableDomain`, `Bound`, `SamplingConfig`, `SampleAssignment`, `SampleSource`, `ValidSampleBatch`, `SamplingError`, `RejectedSampleSummary`, `Tolerance`, and `ComparisonResult`.
  - Keeps executable sampling types separate from `math/equality/types.gleam` contract placeholders.
- `gleam/src/math/sampling/assignment.gleam`
  - Owns deterministic assignment construction, validation, lookup, equality, and stable ordering by variable name.
  - Rejects missing variables at evaluation time as `MissingVariable`.
- `gleam/src/math/sampling/domain.gleam`
  - Owns domain defaults, domain validation, bound checks, exclusions, integer-only checks, preferred-value filtering, and unique-sample capacity checks.
  - Treats unspecified variables as using the default finite `[-10, 10]` domain.
- `gleam/src/math/sampling/evaluate.gleam`
  - Owns recursive evaluation of `normalization/types.NormalExpr` into finite real `Float` values.
  - Supports numbers, constants, variables, arithmetic, unary nodes, supported functions, absolute value, and factorial. This covers AC-001 and AC-002.
- `gleam/src/math/sampling/prng.gleam`
  - Owns the pure deterministic PRNG.
  - Uses a Park-Miller-style integer generator with `modulus = 2_147_483_647` and `multiplier = 48_271`, normalizing invalid or zero seeds into a deterministic valid state.
  - Does not call JavaScript, Erlang, or Elixir random sources, satisfying AC-004.
- `gleam/src/math/sampling/sample.gleam`
  - Owns raw assignment generation and valid-sample execution.
  - Combines special points, preferred values, and pseudo-random values; filters through domains; avoids correlated multi-variable values; enforces unique assignments; and retries expression-invalid candidates. This covers AC-005, AC-006, and AC-007.
- `gleam/src/math/sampling/tolerance.gleam`
  - Owns tolerance validation and numeric comparison.
  - Provides exact/no-tolerance, absolute, relative, and absolute-or-relative comparison with the default `0.0001` helper for future equivalence consumers. This covers AC-008 and AC-009.
- `gleam/src/math/sampling/format.gleam`
  - Owns stable debug strings for assignments, runtime errors, sample batches, rejection summaries, and comparison results.
  - Does not use target-specific inspect formatting, satisfying AC-010.

Expose only small public functions through `gleam/src/torus_math.gleam`. Internal modules may remain importable by tests, but Torus integration code should use the public boundary.

### 4.2 State & Data Flow
Evaluation flow:

1. Caller parses and normalizes an expression using the existing parser and normalizer.
2. Caller passes a `NormalExpr`, `Assignment`, and `EvalConfig` to the public evaluation function.
3. `evaluate.gleam` recursively computes finite real values and validates every operation boundary.
4. The function returns `Ok(Float)` or `Error(RuntimeMathError)`.

Raw sampling flow:

1. Caller passes variable names, `DomainConfig`, and `SamplingConfig`.
2. Domain config is normalized by filling in defaults and validating bounds, exclusions, and integer-only capacity.
3. The sampler emits candidate assignments from preferred/special values first, then deterministic PRNG values.
4. Multi-variable samples use offsets for special values and independent PRNG draws for random values.
5. Integer-only variables emit unique integer values; insufficient unique capacity returns diagnostics.

Valid-sample flow:

1. Caller passes a `NormalExpr`, variables, domain config, sampling config, and eval config.
2. The executor iterates candidate assignments until it reaches `desired_count` or `max_attempts`.
3. Domain-invalid, duplicate, or expression-invalid candidates are rejected with reason summaries.
4. Expression-invalid candidates are retried because this executor is finding valid points for the expression under test.
5. If enough valid samples are found, return `Ok(ValidSampleBatch)`.
6. If attempts are exhausted, return `Error(InsufficientValidSamples(...))`.

Tolerance flow:

1. Caller validates a `Tolerance`.
2. Caller compares two finite floats.
3. The comparator returns `ComparisonResult` with pass/fail, expected, actual, difference, absolute-pass status, and relative-pass status.

### 4.3 Lifecycle & Ownership
- Parser and normalization remain responsible for syntax and structural shape.
- This sampling subsystem owns runtime numeric evaluation and deterministic sample generation.
- Future algebraic equivalence owns expected-versus-candidate policy and should consume this subsystem rather than embedding evaluator or PRNG logic into `math/equality/types.gleam`.
- Elixir and TypeScript wrappers remain out of scope unless later integration work needs them.
- Developer prototype UI remains out of scope until sampling and future algebraic equivalence are both finished.

### 4.4 Alternatives Considered
- Accept raw parsed expressions and normalize internally:
  - Rejected by PRD answer. The evaluator accepts normalized expressions only so callers make the parser/normalizer boundary explicit.
- Add executable sampling behavior into `math/equality/types.gleam`:
  - Rejected. Existing equality types are authoring/config contracts. Runtime execution belongs in a separate layer to avoid coupling configuration shape to evaluation mechanics.
- Use runtime random functions:
  - Rejected. Target runtime random APIs would break reproducibility and cross-target parity.
- Return duplicate integer samples when the range is too small:
  - Rejected by PRD answer. Integer-only domains require unique samples; insufficient capacity is a configuration outcome.
- Update the math prototype LiveView now:
  - Rejected by PRD answer. Prototype updates should wait until sampling and algebraic equivalence are both complete.

## 5. Interfaces
- Public evaluation API:

```gleam
pub fn evaluate_normal_expr(
  expression: normalization_types.NormalExpr,
  assignment: sampling_types.Assignment,
  config: sampling_types.EvalConfig,
) -> Result(Float, sampling_types.RuntimeMathError)
```

- Public raw sampling API:

```gleam
pub fn sample_assignments(
  variables: List(String),
  domains: sampling_types.DomainConfig,
  config: sampling_types.SamplingConfig,
) -> Result(List(sampling_types.SampleAssignment), sampling_types.SamplingError)
```

- Public valid-sample API:

```gleam
pub fn valid_samples_for_expression(
  expression: normalization_types.NormalExpr,
  variables: List(String),
  domains: sampling_types.DomainConfig,
  sampling_config: sampling_types.SamplingConfig,
  eval_config: sampling_types.EvalConfig,
) -> Result(sampling_types.ValidSampleBatch, sampling_types.SamplingError)
```

- Public tolerance API:

```gleam
pub fn compare_numbers(
  expected: Float,
  actual: Float,
  tolerance: sampling_types.Tolerance,
) -> Result(sampling_types.ComparisonResult, sampling_types.ComparisonError)
```

- Public defaults:

```gleam
pub fn default_eval_config() -> sampling_types.EvalConfig

pub fn default_domain_config() -> sampling_types.DomainConfig

pub fn default_sampling_config(seed: Int) -> sampling_types.SamplingConfig

pub fn default_expression_tolerance() -> sampling_types.Tolerance
```

`default_expression_tolerance()` returns absolute-or-relative tolerance using `0.0001` for both absolute and relative tolerance and a small epsilon floor for relative comparisons.

- Public debug formatting:

```gleam
pub fn assignment_to_debug_string(assignment: sampling_types.Assignment) -> String

pub fn runtime_error_to_debug_string(error: sampling_types.RuntimeMathError) -> String

pub fn sample_batch_to_debug_string(batch: sampling_types.ValidSampleBatch) -> String

pub fn comparison_to_debug_string(result: sampling_types.ComparisonResult) -> String
```

Function names may be refined during implementation to match existing naming style, but the public surface must remain narrow and documented.

## 6. Data Model & Storage
- No database schema changes.
- No Ecto migrations.
- No persisted activity model changes.
- No equality JSON storage changes in this work item.
- Runtime types are Gleam values only. Future authoring or grading integration may serialize domain and sampling config, but that is outside this FDD.

Core type shapes:

```gleam
pub type Assignment {
  Assignment(values: List(VariableValue))
}

pub type VariableValue {
  VariableValue(name: String, value: Float)
}

pub type EvalConfig {
  EvalConfig(
    angle_mode: AngleMode,
    factorial_max: Int,
    tangent_epsilon: Float,
  )
}

pub type AngleMode {
  Radians
}
```

```gleam
pub type RuntimeMathError {
  MissingVariable(name: String)
  DivisionByZero
  InvalidRoot(value: Float)
  InvalidLogarithm(value: Float)
  UndefinedTangent(value: Float)
  InvalidFactorial(value: Float)
  FactorialTooLarge(value: Int, max: Int)
  InvalidPower(base: Float, exponent: Float)
  Overflow
  NonFiniteResult
  UnsupportedEvaluationNode(description: String)
}
```

```gleam
pub type DomainConfig {
  DomainConfig(variables: List(VariableDomain))
}

pub type VariableDomain {
  VariableDomain(
    name: String,
    lower: Bound,
    upper: Bound,
    exclusions: List(Float),
    integer_only: Bool,
    preferred_values: List(Float),
  )
}

pub type Bound {
  Inclusive(Float)
  Exclusive(Float)
}
```

```gleam
pub type SamplingConfig {
  SamplingConfig(
    seed: Int,
    desired_count: Int,
    max_attempts: Int,
    include_special_points: Bool,
  )
}

pub type SampleAssignment {
  SampleAssignment(index: Int, assignment: Assignment, source: SampleSource)
}

pub type SampleSource {
  PreferredPoint
  SpecialPoint
  PseudoRandom
}
```

```gleam
pub type Tolerance {
  NoTolerance
  AbsoluteTolerance(abs: Float)
  RelativeTolerance(rel: Float, epsilon: Float)
  AbsoluteOrRelativeTolerance(abs: Float, rel: Float, epsilon: Float)
}
```

If implementation finds that error variants need source spans, add optional span-bearing variants only when spans are available on normalized nodes. Do not require spans for all runtime errors in the MVP.

## 7. Consistency & Transactions
- No transactional database behavior is introduced.
- Consistency is deterministic functional consistency:
  - same normalized expression, assignment, and eval config produce the same result;
  - same variables, domains, seed, and sampling config produce the same assignments;
  - same expected, actual, and tolerance produce the same comparison details.
- Assignment and domain values should be normalized into stable variable-name order before formatting or duplicate checks.
- Avoid map-iteration ordering in stable outputs. Lists sorted by variable name are preferred.
- Avoid target-specific inspect output in debug strings.

## 8. Caching Strategy
- No Cachex or application cache is required.
- PRNG state is local to a sampling call.
- Evaluation is pure for a given expression and assignment. Any later grading cache should be added at the future equivalence boundary, keyed by normalized expression hash plus assignment/config data.

## 9. Performance & Scalability Posture
- Evaluation is a recursive tree walk and should be linear in expression node count for ordinary expressions.
- Sampling is bounded by `max_attempts`, with defaults in the range described by the PRD and informal spec.
- Domain checks should be simple numeric comparisons and list checks. Integer-only uniqueness should use deterministic list/set-like helpers appropriate for expected small sample counts.
- Avoid expensive string formatting in hot evaluator loops; debug strings should be generated only when requested or when constructing diagnostics.
- Add representative checks or fixtures for simple arithmetic, polynomial expressions, functions, multiple variables, retry-heavy expressions, and domain-error expressions to satisfy AC-013.
- This work establishes baselines only. Production latency budgets belong to later grading integration.

## 10. Failure Modes & Resilience
- Missing variable: return `MissingVariable(name)`.
- Division by exact zero: return `DivisionByZero`.
- `sqrt(x)` where `x < 0`: return `InvalidRoot(value)`.
- `ln`, `log`, `log10`, or `log2` where `x <= 0`: return `InvalidLogarithm(value)`.
- `tan(x)` where `abs(cos(x)) < tangent_epsilon`: return `UndefinedTangent(value)`.
- Factorial for negative, non-integer, or too-large inputs: return `InvalidFactorial` or `FactorialTooLarge`.
- Power edge cases:
  - base greater than zero: allow real exponent;
  - base equals zero with exponent greater than zero: allow;
  - `0^0` and zero to negative exponent: return `InvalidPower`;
  - negative base with integer exponent: allow;
  - negative base with non-integer exponent: return `InvalidPower`.
- Non-finite result after any operation: return `Overflow` or `NonFiniteResult`.
- Unsupported normalized node, including unit-oriented input: return `UnsupportedEvaluationNode`.
- Invalid domain config: return structured sampling/config error before generating samples.
- Insufficient unique integer samples or too many invalid candidates: return structured `InsufficientValidSamples` diagnostics rather than duplicates, crashes, or partial success.

## 11. Observability
- No production telemetry is required in this work item.
- Stable debug string helpers should support tests, developer diagnostics, and future author preview without requiring target-specific formatting.
- If future grading or preview integration emits telemetry, it should include categories, counts, timings, normalized hashes, and aggregate retry/error summaries rather than raw learner expressions or raw sample assignments.
- Rejection summaries should aggregate runtime error categories so support and author-preview layers can explain configuration problems without logging every sampled value.

## 12. Security & Privacy
- Do not log raw learner expressions or raw sampled assignments in production telemetry by default.
- Runtime errors and diagnostics should be structured categories; they are not direct student-facing feedback strings.
- The PRNG is deterministic and non-cryptographic. It must not be used for secrets, tokens, access control, or security-sensitive randomness.
- No authorization or role changes are introduced.
- No database access, external network access, or file-system access is introduced by the Gleam evaluator/sampler.
- Detailed debug output is appropriate for tests and developer tooling; future UI integrations must decide what is safe for authors and students separately.

## 13. Testing Strategy
- Evaluator tests:
  - Cover numeric literals, constants, variables, missing variables, arithmetic, powers, unary plus/minus, supported functions, absolute value, and exponentials for AC-001.
  - Cover division by zero, invalid roots, invalid logs, undefined tangent, invalid factorial, factorial max, invalid powers including `0^0`, overflow, and non-finite rejection for AC-002.
- Assignment and domain tests:
  - Cover deterministic lookup, inclusive bounds, exclusive bounds, exclusions, integer-only sampling, preferred values, default domain range, and invalid domain configs for AC-003.
- PRNG and raw sampler tests:
  - Assert exact deterministic PRNG and assignment sequences for fixed seeds on repeated runs.
  - Assert parity under `gleam test --target erlang` and `gleam test --target javascript` for AC-004 and AC-011.
  - Assert special-point filtering and multi-variable anti-correlation for AC-005.
- Valid-sample executor tests:
  - Assert `1 / x` rejects `x = 0`, continues sampling, and records rejection reasons for AC-006.
  - Assert impossible domains such as `x in [0, 0]` for `1 / x` return insufficient-sample diagnostics with requested count, found count, attempts, and rejection summaries for AC-007.
- Tolerance tests:
  - Cover no tolerance, absolute tolerance, relative tolerance with epsilon, absolute-or-relative tolerance, near-zero behavior, failed comparisons, and negative tolerance rejection for AC-008.
  - Assert comparison result fields for AC-009.
- API and formatting tests:
  - Assert public `torus_math` functions call the shared implementation and exported functions have Gleam comments during review for AC-010.
  - Assert stable debug strings for assignments, runtime errors, sample batches, rejection summaries, and comparison results for AC-010.
- Scope and privacy inspection:
  - Verify no final equivalence API, symbolic simplification, unit evaluation, complex-number support, runtime random source usage, or production raw learner telemetry is introduced for AC-012.
- Performance fixtures:
  - Add representative fixtures or checks for arithmetic, polynomial expressions, functions, multiple variables, retry-heavy expressions, and domain-error expressions for AC-013.
- Required gates:
  - Run `cd gleam && gleam format --check src test`.
  - Run `cd gleam && gleam test --target erlang`.
  - Run `cd gleam && gleam test --target javascript`.

## 14. Backwards Compatibility
- Existing parser, normalization, and equality config APIs remain compatible.
- Existing `math/equality` placeholder types should not be removed or repurposed in this work.
- No migration is required.
- No feature flag is required because no production grading or learner-facing path is changed by this work item.
- Future equivalence work may adapt existing equality config sampling fields into the richer sampling subsystem, but that adapter is out of scope here.

## 15. Risks & Mitigations
- Cross-target PRNG drift: keep PRNG integer arithmetic small, test exact sequences on both targets, and avoid target runtime random APIs.
- Floating-point edge drift: validate non-finite results after operations and use tolerance-aware tests for trig/log examples where exact representation differs.
- Scope creep into equivalence: expose evaluator/sampler/comparator primitives only; do not add expected-versus-candidate APIs.
- Configuration ambiguity: return explicit domain and sampling errors for invalid bounds, negative counts, too-small integer ranges, and exhausted attempts.
- Privacy leakage: restrict production telemetry guidance to aggregate categories and hashes; keep raw assignment debug strings in tests/developer contexts.
- Performance surprises: bound sampling by `max_attempts` and add representative baseline checks before grading integration.

## 16. Open Questions & Follow-ups
- Future algebraic equivalence must decide how `math/equality` config types map into this richer domain and sampling model.
- Future authoring or preview UI must decide which diagnostics are author-facing and how to phrase them.
- Future production grading integration must decide whether to emit aggregate telemetry for sample counts, retry counts, and runtime error categories.
- Future unit support must decide how quantity value evaluation composes with unit semantics; this work returns unsupported evaluation for unit-oriented inputs.

## 17. References
- `docs/exec-plans/current/epics/math/sampling/prd.md`
- `docs/exec-plans/current/epics/math/sampling/requirements.yml`
- `docs/exec-plans/current/epics/math/sampling/sampling-informal.md`
- `docs/exec-plans/current/epics/math/normalization/fdd.md`
- `gleam/src/math/normalization/types.gleam`
- `gleam/src/torus_math.gleam`
- `gleam/src/math/equality/types.gleam`
- `ARCHITECTURE.md`
- `docs/STACK.md`
- `docs/TOOLING.md`
- `docs/TESTING.md`
- `docs/BACKEND.md`
- `docs/FRONTEND.md`
- `docs/OPERATIONS.md`
- `docs/CODEREVIEW.md`
