# Deterministic Expression Evaluation And Sampling Infrastructure - Product Requirements Document

## 1. Overview
Build the next shared Gleam math layer after parsing and normalization: deterministic real-valued expression evaluation, variable assignments, variable domains, seeded sampling, valid-sample execution, and numeric tolerance comparison. This work creates the primitives future algebraic equivalence will depend on without implementing the final expected-versus-candidate equivalence API.

The feature must remain deterministic across Erlang and JavaScript targets so author preview, grading, debugging, and automated tests produce repeatable outcomes for the same expression, domain configuration, seed, sample count, and runtime options.

## 2. Background & Problem Statement
The parser milestone gives Torus a stable AST for ASCII math, and the normalization milestone gives Torus a domain-preserving structural representation. The next product need is to compute expression behavior at concrete variable values and to generate those values predictably.

Torus should not jump directly to symbolic algebra or a single `equivalent(expected, candidate)` decision. Equivalence is a policy built over repeated deterministic evaluations. This work therefore creates independent, testable building blocks: evaluate one expression, generate repeatable assignments, filter assignments that are invalid for the expression, and compare numeric results with explicit tolerance details.

## 3. Goals & Non-Goals
### Goals
- Evaluate parsed or normalized real-valued math expressions against first-class variable assignments.
- Return structured runtime math errors instead of exceptions, booleans, `Nil`, `NaN`, or infinities.
- Define first-class assignment, domain, sampling, runtime-error, and comparison result models in Gleam.
- Generate deterministic sample assignments from variables, domain configuration, sample count, and seed.
- Include special points and seeded pseudo-random points while avoiding correlated multi-variable assignments.
- Provide a valid-sample executor that retries expected-expression-invalid assignments and reports insufficient valid samples with diagnostics.
- Provide reusable absolute, relative, and absolute-or-relative numeric tolerance comparison helpers.
- Preserve browser/server parity by passing equivalent Gleam tests on Erlang and JavaScript targets.

### Non-Goals
- Do not implement final algebraic equivalence between expected and candidate expressions in this work item.
- Do not implement symbolic simplification, expansion, factoring, cancellation, identity rewrites, or broad domain inference.
- Do not evaluate units; unit-bearing expressions remain outside this feature except for value-expression handling after a future unit layer separates units.
- Do not support complex numbers or degree-mode trigonometry in the MVP.
- Do not use runtime random functions from JavaScript, Erlang, or Elixir.
- Do not log raw learner expressions or raw sample details in production telemetry by default.

## 4. Users & Use Cases
- Developers: test evaluation, runtime errors, deterministic sample generation, retry behavior, and tolerance comparison directly in shared Gleam code.
- Authors: eventually preview whether an expression and domain configuration can produce enough valid sample points and understand configuration problems such as sampling only undefined values.
- Students: eventually receive concise, actionable feedback when an expression is undefined for required values, without seeing low-level sample internals.
- Instructors and learning engineers: rely on deterministic behavior that can be reproduced across grading, preview, support, and automated test environments.

## 5. UX / UI Requirements
- No learner-facing UI changes are required for this work item.
- Existing developer prototype or preview surfaces may be extended to show expression evaluation results, runtime errors, generated assignments, rejected sample summaries, and comparison details.
- Author-facing messages introduced later must translate structured diagnostics into concise guidance and must not expose unnecessary internals to students.
- Student-facing messaging is out of scope except for preserving structured error categories that future feedback layers can use.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Determinism: the same inputs must generate the same assignments, evaluation outcomes, comparison details, and debug strings on Erlang and JavaScript targets.
- Reliability: invalid expressions at runtime must return structured errors and must not crash the evaluator or sampler.
- Safety: this layer must preserve the distinction between expected-expression invalid samples, which can be retried, and future candidate-expression invalidity at expected-valid points, which is evidence for non-equivalence.
- Performance: representative evaluation and eight-sample batches should be suitable for author preview and later grading; the work should establish baseline checks rather than premature optimization targets.
- Privacy: production telemetry must prefer hashes, categories, counts, timings, and aggregate outcomes over raw learner expressions or raw sampled assignments.
- Maintainability: public APIs should stay narrow, with replaceable internal modules and function-level Gleam comments for exported behavior.

## 9. Data, Interfaces & Dependencies
- Input dependency: parsed AST and normalized expression types from the existing Gleam math parser and normalization work.
- Public interface dependency: expose stable entry points through the shared Gleam math API, keeping Elixir and TypeScript wrappers thin.
- Assignment data: Torus-owned assignment types should represent variable names and finite float values in a deterministic, serializable form.
- Domain data: variable domains should support lower and upper bounds, inclusive or exclusive bounds, exclusions, integer-only sampling, preferred or special values, and default finite ranges.
- Sampling data: sampling config should include seed, desired count, max attempts, and special-point inclusion.
- Runtime errors: evaluation and sampling must use structured categories such as missing variable, division by zero, invalid root, invalid logarithm, undefined tangent, invalid factorial, invalid power, overflow, non-finite result, invalid domain config, and insufficient valid samples.
- Comparison data: comparison results should include pass/fail plus expected, actual, difference, absolute-pass status, and relative-pass status.

## 10. Repository & Platform Considerations
- Implementation belongs under `gleam/src/math/` with small public API additions exposed through `gleam/src/torus_math.gleam`.
- Tests belong under `gleam/test/` and must include both `gleam test --target erlang` and `gleam test --target javascript` for shared behavior.
- The PRNG must be pure Gleam and portable; a Park-Miller-style deterministic integer generator is acceptable for sample selection and is not intended to be cryptographic.
- Developer debug formatting should be stable enough for golden tests and prototype diagnostics.
- Code review should include `.review/gleam.md`, `.review/security.md`, `.review/performance.md`, and `.review/requirements.md`; add `.review/elixir.md`, `.review/typescript.md`, or `.review/ui.md` only if integration wrappers or UI surfaces change.
- No Jira issue key was provided with this request; use this work item directory as the planning source of truth until an issue is linked.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Primary success signal: evaluator, sampler, domain, tolerance, and cross-target fixture tests pass on Erlang and JavaScript targets.
- Secondary success signal: fixed seeds produce identical sample assignments across repeated runs and targets.
- Diagnostic success signal: insufficient valid sample outcomes include requested count, found count, attempts, and rejection summaries useful for author preview and debugging.
- No new production telemetry is required unless this work is wired into runtime grading or preview paths. If telemetry is added later, it should emit aggregate categories, counts, timings, and hashes rather than raw learner expressions.

## 13. Risks & Mitigations
- Scope creep into equivalence: keep this feature limited to primitives and leave expected-versus-candidate policy for a later work item.
- Cross-target numeric drift: use shared Gleam implementation, deterministic PRNG tests, target-paired test suites, and tolerance-aware comparisons for floating operations.
- Hidden domain errors: preserve structured runtime errors and retry only when sampling the expression that defines valid points.
- False confidence from sampling: include special points, seeded pseudo-random points, anti-correlation behavior for multiple variables, and clear documentation that sampling is behavioral evidence, not proof.
- Privacy leakage through diagnostics: avoid raw learner expressions in telemetry and treat detailed assignments as developer or author-preview data, not student-facing data.
- Performance regressions: add representative corpora and baseline checks before the code becomes part of grading hot paths.

## 14. Open Questions & Assumptions
### Open Questions
- Should the MVP public API accept only normalized expressions, or should it also accept parsed expressions and normalize internally through a helper?
ANSWER: It should only take normalized expressions
- What default tolerance values should be used once future equivalence consumes this layer in production grading?
ANSWER: start with 0.0001 default tolerance
- Should integer-only domains require unique samples, or may duplicates be returned when the valid integer range is smaller than the requested count if they are explicitly marked?
ANSWER: Integer only domains MUST require unique samples
- Which developer prototype surface, if any, should be updated during implementation to visualize assignments and sampling diagnostics?
ANSWER: None, we will update the math prototype LiveView AFTER this sampling and then the next phase (Algebraic Equivalance) are both finished.

### Assumptions
- Parser and normalization contracts are stable enough for this work item to consume their AST and normalized expression structures.
- Real-valued `Float` evaluation is sufficient for the MVP.
- Trigonometric functions use radians, and `log(x)` means natural logarithm.
- Default effective variable domains are finite, with `[-10, 10]` as the default range when no author domain is configured.
- `0^0` is treated as invalid unless a later explicit policy chooses calculator semantics.
- Gleam remains the single source of truth for shared evaluator and sampler behavior.

## 15. QA Plan
- Automated validation:
  - Run `cd gleam && gleam format --check src test`.
  - Run `cd gleam && gleam test --target erlang`.
  - Run `cd gleam && gleam test --target javascript`.
  - Add evaluator tests for numeric literals, constants, variables, arithmetic, unary operators, functions, absolute value, factorial, non-finite rejection, and structured runtime errors.
  - Add domain and sampler tests for bounds, exclusions, integer-only domains, defaults, deterministic PRNG sequences, special points, anti-correlation, retries, and insufficient sample diagnostics.
  - Add tolerance tests for no tolerance, absolute tolerance, relative tolerance, combined tolerance, near-zero behavior, and invalid tolerance configuration.
  - Add cross-target fixture tests for fixed expressions, domains, seeds, sample assignments, and evaluation outputs.
- Manual validation:
  - Inspect developer debug output for representative expressions and sample batches.
  - Confirm diagnostics are suitable for future author preview and do not require raw learner telemetry.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
