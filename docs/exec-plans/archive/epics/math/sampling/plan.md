# Deterministic Expression Evaluation And Sampling Infrastructure - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/math/sampling/prd.md`
- FDD: `docs/exec-plans/current/epics/math/sampling/fdd.md`
- Requirements: `docs/exec-plans/current/epics/math/sampling/requirements.yml`

## Scope
Deliver deterministic real-valued expression evaluation and sampling primitives in shared Gleam code. The plan covers runtime types, assignment/domain modeling, normalized-expression evaluation, pure deterministic PRNG sampling, valid-sample execution with retries, numeric tolerance comparison, stable debug formatting, public `torus_math` API exposure, and direct Gleam tests on Erlang and JavaScript targets.

Guardrails:
- Do not implement final expected-versus-candidate algebraic equivalence.
- Do not implement symbolic simplification, broad domain inference, unit evaluation, complex numbers, or degree-mode trigonometry.
- Do not use JavaScript, Erlang, or Elixir runtime random sources.
- Do not update the math prototype LiveView or frontend preview in this work item.
- Do not add database storage, migrations, production telemetry, learner-facing UI, or feature flags.
- Keep executable sampling types separate from existing `math/equality` config placeholders until a future algebraic equivalence work item wires them together.
- Add useful Gleam source comments throughout implementation. Every exported type, constructor group, public function, and non-obvious helper should explain intent, invariants, target-parity assumptions, runtime math semantics, or privacy constraints rather than restating syntax.

## Clarifications & Default Assumptions
- Evaluator public APIs accept normalized expression nodes only, not raw strings or parser AST values.
- Default future expression tolerance starts at `0.0001`; this work exposes that as a default helper without applying final equivalence policy.
- Integer-only domains must produce unique samples. If the requested count cannot be satisfied uniquely, return structured diagnostics.
- Default effective domain for unspecified variables is finite `[-10, 10]`.
- Trigonometric functions use radians, and `log(x)` means natural logarithm.
- `0^0` is invalid.
- Production telemetry is not added. If future integrations add telemetry, it must use aggregate categories, counts, timings, and hashes rather than raw learner expressions or raw sampled assignments.
- Documentation comments are part of each implementation phase, not a cleanup task deferred to the end.

## Phase 1: Runtime Type Contracts And Public Boundary Skeleton
- Goal: Establish the sampling subsystem type model, default config contracts, and public API placeholders before behavior is implemented.
- Tasks:
  - [ ] Create `gleam/src/math/sampling/types.gleam`.
  - [ ] Define `Assignment`, `VariableValue`, `EvalConfig`, `AngleMode`, `RuntimeMathError`, `DomainConfig`, `VariableDomain`, `Bound`, `SamplingConfig`, `SampleAssignment`, `SampleSource`, `ValidSampleBatch`, `SamplingError`, `RejectedSampleSummary`, `Tolerance`, `ComparisonError`, and `ComparisonResult`.
  - [ ] Add default config helpers for evaluation, domain, sampling, and default expression tolerance.
  - [ ] Add initial public `torus_math` API declarations only when backing modules exist enough to compile.
  - [ ] Keep executable types under `math/sampling` and avoid moving runtime execution concerns into `math/equality/types.gleam`.
  - [ ] Add Gleam documentation comments for every exported type and helper explaining the invariant it protects, especially finite real evaluation, deterministic sampling, unique integer samples, and non-cryptographic PRNG scope.
  - [ ] Add comments near tolerance defaults explaining that `0.0001` is a future equivalence default helper, not an equivalence decision in this phase.
- Testing Tasks:
  - [ ] Add compile-only or constructor smoke tests for the type model and defaults.
  - [ ] Confirm exported contracts compile on Erlang first.
  - Command(s): `cd gleam && gleam format --check src test`
  - Command(s): `cd gleam && gleam test --target erlang`
- Definition of Done:
  - Runtime type contracts and defaults compile.
  - Comments explain exported type and default-helper intent.
  - No existing parser, normalization, or equality config public behavior changes.
- Gate:
  - Gate A passes when the type skeleton compiles and the comment review confirms all exported contracts are documented.
- Dependencies:
  - Existing parser and normalization modules, especially `gleam/src/math/normalization/types.gleam`.
- Parallelizable Work:
  - Evaluator and domain test case drafting can proceed once type names are stable.

## Phase 2: Assignment, Domain, And Config Validation
- Goal: Implement deterministic assignment lookup and domain validation before evaluation and sampling consume those contracts.
- Tasks:
  - [ ] Create `gleam/src/math/sampling/assignment.gleam`.
  - [ ] Implement deterministic assignment construction, stable variable-name ordering, duplicate-name handling, lookup, equality, and stable assignment identity for duplicate detection.
  - [ ] Create `gleam/src/math/sampling/domain.gleam`.
  - [ ] Implement default domain lookup, inclusive/exclusive bound checks, exclusions, preferred values, integer-only checks, and invalid-domain validation.
  - [ ] Implement unique-capacity checks for integer-only domains so impossible sample requests fail as configuration/sampling diagnostics.
  - [ ] Add comments for public functions and non-obvious helpers explaining ordering choices, exact float exclusion limits, integer uniqueness, and why maps or runtime ordering are avoided in stable outputs.
  - [ ] Keep domain inference out of scope; comments should make clear domains come from config plus runtime validity checks, not symbolic analysis.
- Testing Tasks:
  - [ ] Add assignment lookup and ordering tests for AC-003.
  - [ ] Add domain tests for inclusive bounds, exclusive bounds, exclusions, integer-only ranges, preferred values, default finite ranges, invalid bounds, and unique integer capacity for AC-003.
  - Command(s): `cd gleam && gleam format --check src test`
  - Command(s): `cd gleam && gleam test --target erlang`
- Definition of Done:
  - Assignment and domain modules are deterministic and tested.
  - Integer-only uniqueness failures return structured errors rather than duplicate samples.
  - Function-level comments document assignment/domain invariants and config limits.
- Gate:
  - Gate B passes when AC-003 has direct Erlang-target coverage and comments explain all stable-ordering decisions.
- Dependencies:
  - Phase 1 type contracts.
- Parallelizable Work:
  - Evaluator implementation can begin after `Assignment` lookup behavior is available.

## Phase 3: Normalized Expression Evaluator
- Goal: Evaluate normalized real-valued expressions into finite `Float` results or structured runtime math errors.
- Tasks:
  - [ ] Create `gleam/src/math/sampling/evaluate.gleam`.
  - [ ] Implement numeric literal evaluation from normalized `ExactNumber` variants.
  - [ ] Implement constants `pi` and `e`.
  - [ ] Implement variable lookup through `Assignment`.
  - [ ] Implement `+`, `-`, `*`, `/`, `^`, unary positive-equivalent behavior through normalized structure, `NNegate`, `NAbs`, `NFactorial`, and supported function calls.
  - [ ] Implement radians-only trig behavior and `log` as natural log.
  - [ ] Implement domain checks for division by zero, invalid roots, invalid logarithms, undefined tangent, invalid factorial, factorial too large, invalid powers including `0^0`, overflow, and non-finite results.
  - [ ] Return `UnsupportedEvaluationNode` for unit-oriented or otherwise unsupported normalized input rather than guessing semantics.
  - [ ] Expose `evaluate_normal_expr` through `torus_math` after the backing function is stable.
  - [ ] Add Gleam comments for the public evaluator, each runtime error boundary, power semantics, tangent epsilon, factorial max, and non-finite handling. Comments should explain math/domain decisions and why invalid values become structured results, not exceptions.
- Testing Tasks:
  - [ ] Add evaluator success tests for numeric literals, `pi`, `e`, variables, missing variables, arithmetic, powers, unary forms, `sin`, `cos`, `tan`, `ln`, `log`, `log10`, `log2`, `sqrt`, `abs`, and `exp` for AC-001.
  - [ ] Add runtime error tests for division by zero, invalid roots, invalid logs, undefined tangent, invalid factorial, factorial max, invalid powers, overflow, and non-finite results for AC-002.
  - [ ] Add public API tests through `torus_math` for evaluator boundary coverage supporting AC-010.
  - Command(s): `cd gleam && gleam format --check src test`
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Evaluator covers AC-001 and AC-002 on both targets.
  - Public evaluator API is commented and tested through `torus_math`.
  - No unit, complex-number, or final equivalence behavior is introduced.
- Gate:
  - Gate C passes when evaluator success/error tests and public API tests pass on Erlang and JavaScript.
- Dependencies:
  - Phase 2 assignment lookup.
- Parallelizable Work:
  - PRNG exact-sequence tests can be authored while evaluator edge cases are implemented.

## Phase 4: Deterministic PRNG And Raw Assignment Sampler
- Goal: Generate deterministic raw sample assignments from variables, domains, preferred/special points, and a portable seed.
- Tasks:
  - [ ] Create `gleam/src/math/sampling/prng.gleam`.
  - [ ] Implement Park-Miller-style PRNG with `modulus = 2_147_483_647` and `multiplier = 48_271`.
  - [ ] Normalize invalid or zero seeds into a deterministic valid state.
  - [ ] Create `gleam/src/math/sampling/sample.gleam`.
  - [ ] Implement `sample_assignments` for raw assignment generation.
  - [ ] Include preferred points, special points, and pseudo-random values in deterministic order.
  - [ ] Filter preferred/special/random values through domains.
  - [ ] Avoid correlated multi-variable assignments through special-point offsets and independent PRNG draws.
  - [ ] Enforce unique assignments, especially for integer-only domains.
  - [ ] Expose raw sampling through `torus_math` after implementation stabilizes.
  - [ ] Add comments for PRNG state transitions, seed normalization, non-cryptographic limitations, special-point ordering, anti-correlation logic, and uniqueness enforcement.
- Testing Tasks:
  - [ ] Add exact PRNG sequence tests and repeated-run sampler tests for AC-004.
  - [ ] Add cross-target raw sampler fixture tests for fixed variables, domains, sample counts, and seeds for AC-004 and AC-011.
  - [ ] Add special-point filtering and multi-variable anti-correlation tests for AC-005.
  - [ ] Add integer-only unique-sample tests, including too-small ranges.
  - Command(s): `cd gleam && gleam format --check src test`
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Raw sampler is deterministic on both targets.
  - No runtime random APIs are used.
  - PRNG and sampling helpers have function-level comments documenting determinism, portability, and non-security scope.
- Gate:
  - Gate D passes when AC-004, AC-005, and raw-sampler parts of AC-011 pass on both targets.
- Dependencies:
  - Phase 2 domain checks and assignment identity behavior.
- Parallelizable Work:
  - Tolerance helper tests can be drafted while sampler implementation proceeds.

## Phase 5: Valid-Sample Executor And Rejection Diagnostics
- Goal: Combine raw sampling with evaluation so expression-invalid points are retried and insufficient samples are reported structurally.
- Tasks:
  - [ ] Implement `valid_samples_for_expression` in `sample.gleam`.
  - [ ] Track candidate attempts up to `max_attempts`.
  - [ ] Evaluate candidates with `evaluate_normal_expr`.
  - [ ] Accept assignments only when evaluation succeeds with a finite result.
  - [ ] Reject and summarize domain-invalid, duplicate, and runtime-invalid assignments.
  - [ ] Return `InsufficientValidSamples` with requested count, found count, attempts, and rejection summaries when the executor cannot satisfy `desired_count`.
  - [ ] Expose valid-sample execution through `torus_math`.
  - [ ] Add comments explaining why expected-expression invalid samples are retried here and why future candidate invalidity at expected-valid points belongs to the later equivalence layer.
  - [ ] Comment rejection-summary aggregation so future telemetry and preview integrations can use categories without raw sampled assignments.
- Testing Tasks:
  - [ ] Add retry tests for `1 / x` where generated `x = 0` is rejected and later valid samples are accepted for AC-006.
  - [ ] Add insufficient-sample tests for impossible or over-constrained domains such as `1 / x` with `x in [0, 0]` for AC-007.
  - [ ] Add rejection-summary tests proving requested count, found count, attempts, and reason summaries are returned for AC-007.
  - [ ] Add cross-target valid-sample fixture tests for AC-011.
  - Command(s): `cd gleam && gleam format --check src test`
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Valid sampling covers AC-006 and AC-007 on both targets.
  - Diagnostics are structured and avoid raw learner-expression telemetry assumptions.
  - Comments make the expected-expression retry policy explicit.
- Gate:
  - Gate E passes when valid-sample executor tests and cross-target fixtures pass.
- Dependencies:
  - Phase 3 evaluator and Phase 4 raw sampler.
- Parallelizable Work:
  - Debug formatting for assignment and runtime errors can be implemented alongside valid-sample diagnostics once types are stable.

## Phase 6: Tolerance Comparison And Stable Debug Formatting
- Goal: Provide reusable numeric comparison details and deterministic debug strings for developer tooling, tests, and future preview.
- Tasks:
  - [ ] Create `gleam/src/math/sampling/tolerance.gleam`.
  - [ ] Implement validation and comparison for `NoTolerance`, `AbsoluteTolerance`, `RelativeTolerance`, and `AbsoluteOrRelativeTolerance`.
  - [ ] Implement epsilon floor behavior for relative tolerance.
  - [ ] Implement `default_expression_tolerance` as absolute-or-relative `0.0001` with an explicit epsilon floor.
  - [ ] Create `gleam/src/math/sampling/format.gleam`.
  - [ ] Implement stable debug strings for assignments, runtime errors, sampling errors, valid sample batches, rejection summaries, and comparison results.
  - [ ] Expose comparison and debug formatting through `torus_math` with a narrow public API.
  - [ ] Add comments for tolerance math, negative tolerance rejection, default tolerance intent, debug-string stability, and why debug strings are not learner-facing messages.
- Testing Tasks:
  - [ ] Add no-tolerance, absolute, relative, absolute-or-relative, near-zero, failed comparison, and negative tolerance tests for AC-008.
  - [ ] Add comparison detail field tests for AC-009.
  - [ ] Add stable debug string tests for assignments, runtime errors, sample batches, rejection summaries, and comparison results for AC-010.
  - [ ] Add public API tests through `torus_math` for comparator and formatter functions for AC-010.
  - Command(s): `cd gleam && gleam format --check src test`
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - Tolerance comparison covers AC-008 and AC-009 on both targets.
  - Stable debug formatting supports AC-010.
  - Public functions and non-obvious helpers have useful comments.
- Gate:
  - Gate F passes when tolerance, debug formatting, and public API tests pass on both targets.
- Dependencies:
  - Phase 1 type contracts and stable diagnostic shapes from Phase 5.
- Parallelizable Work:
  - Representative performance fixtures can be drafted while formatting tests are finalized.

## Phase 7: Cross-Target Fixtures, Performance Baselines, Scope Review, And Handoff
- Goal: Complete parity, performance, privacy, and review gates before implementation is considered ready.
- Tasks:
  - [ ] Add representative fixtures or checks for simple arithmetic, polynomial expressions, supported functions, multiple variables, retry-heavy expressions, and domain-error expressions.
  - [ ] Confirm fixture output is deterministic and target-stable.
  - [ ] Review implementation for scope boundaries: no final equivalence API, no symbolic simplification, no unit evaluation, no complex-number support, no runtime random source, and no production raw learner telemetry.
  - [ ] Review all new Gleam modules for comments on exported types, public functions, and non-obvious internal helpers.
  - [ ] Ensure comments explain function intent, invariants, target-parity assumptions, domain/error semantics, and privacy constraints where relevant.
  - [ ] Remove comments that merely narrate obvious syntax or imply raw learner expressions should be logged.
  - [ ] Run code review against `.review/gleam.md`, `.review/security.md`, `.review/performance.md`, and `.review/requirements.md`; include `.review/elixir.md`, `.review/typescript.md`, or `.review/ui.md` only if those files changed despite the current scope.
  - [ ] Capture final command outputs and any known unrelated failures in execution notes.
- Testing Tasks:
  - [ ] Run final complete Gleam format and both target test suites for AC-011.
  - [ ] Verify scope and privacy by inspection for AC-012.
  - [ ] Verify representative performance fixtures/checks for AC-013.
  - [ ] Run targeted broader checks only if implementation unexpectedly touches Elixir, TypeScript, or UI wrappers.
  - Command(s): `cd gleam && gleam format --check src test`
  - Command(s): `cd gleam && gleam test --target erlang`
  - Command(s): `cd gleam && gleam test --target javascript`
- Definition of Done:
  - AC-001 through AC-013 have direct proof through tests, inspection, review notes, or execution records.
  - Cross-target tests pass.
  - Performance baseline fixtures exist.
  - Comment review confirms useful function-level and invariant-level Gleam documentation is present.
  - Scope review confirms no production behavior or telemetry was added outside the work item.
- Gate:
  - Gate G passes when final verification, review, comment audit, and scope/privacy inspection are complete.
- Dependencies:
  - Phases 1 through 6.
- Parallelizable Work:
  - Review checklist preparation, execution note drafting, and comment audit can happen while final test commands run.

## Parallelization Notes
- Phase 1 type contracts block most implementation.
- Evaluator test case drafting, domain fixture drafting, PRNG expected-sequence drafting, and tolerance test drafting can proceed in parallel once type names stabilize.
- Assignment/domain work and evaluator work may overlap after `Assignment` lookup behavior is agreed, but they should not edit the same files.
- PRNG implementation can proceed independently from evaluator once sampling types exist.
- Raw sampler and tolerance comparison are separable after Phase 1; valid-sample execution requires both evaluator and raw sampler.
- Debug formatting can be built incrementally as each result type stabilizes.
- Comment review should be continuous in each phase. Phase 7 is a final audit, not the first pass.

## Phase Gate Summary
- Gate A: Runtime type contracts, defaults, and comments compile under Erlang.
- Gate B: Assignment/domain behavior covers AC-003 and documents deterministic ordering plus integer uniqueness.
- Gate C: Evaluator covers AC-001, AC-002, and public boundary parts of AC-010 on both targets.
- Gate D: PRNG and raw sampler cover AC-004, AC-005, and raw-sampler AC-011 on both targets.
- Gate E: Valid-sample executor covers AC-006, AC-007, and valid-sample AC-011 on both targets.
- Gate F: Tolerance and debug formatting cover AC-008, AC-009, and AC-010 on both targets.
- Gate G: Final format/tests pass, AC-012 and AC-013 are verified, comments are audited, and review scope is complete.
