# Algebraic Expression Equivalence - Product Requirements Document

## 1. Overview
Build the first shared Torus Math equivalence policy layer for algebraic expressions. The feature compares an expected expression and a candidate expression by parsing, normalizing, validating, deterministically sampling assignments over configured domains, evaluating both expressions at the same assignments, and comparing numeric results with the existing tolerance helper.

This work also extends the existing developer-only Math Prototype LiveView with an Algebraic Equivalence panel so developers can inspect structured outcomes, normalized forms, sample comparisons, and rejection diagnostics before the behavior is wired into production grading.

## 2. Background & Problem Statement
Torus now has Gleam-based math infrastructure for parsing, normalization, deterministic evaluation, seeded sampling, domains, and numeric tolerance comparison. Future Math Expression responses need to accept mathematically equivalent answers such as `2x + 6` for `2(x + 3)` without relying on fragile string matching.

The immediate product need is not a symbolic algebra system or a production grading change. It is a deterministic, bounded, explainable equivalence policy that composes the existing math layers and produces enough diagnostics for developers to validate behavior across BEAM and browser targets.

## 3. Goals & Non-Goals
### Goals
- Provide raw-string and normalized-expression algebraic equivalence APIs through the shared Gleam math boundary.
- Treat equivalence as value equivalence over configured domains where the expected expression is defined.
- Evaluate expected and candidate expressions against the same deterministic assignments.
- Return structured outcomes for equivalence, non-equivalence, parse failure, validation failure, candidate runtime failure, and insufficient valid samples.
- Reuse existing parser, normalization, sampling, evaluation, domain, and tolerance functionality rather than reimplementing lower layers.
- Support developer diagnostics in the Math Prototype LiveView.
- Preserve deterministic parity across Erlang and JavaScript Gleam targets.

### Non-Goals
- Do not implement production Short Answer, Multi-Input, Number, legacy Math, adaptive activity, or response-rule grading integration.
- Do not build production student UI or production authoring UI.
- Do not implement CAS-style symbolic proof, expansion, factoring, cancellation, rational canonicalization, or broad domain-equivalence proof.
- Do not implement units, unit-aware equivalence, complex numbers, piecewise expressions, exact-form grading, partial credit, or feedback-rule matching.
- Do not log raw learner expressions or raw sampled assignments in production telemetry by default.

## 4. Users & Use Cases
- Developers: check expected and candidate expressions in the Math Prototype LiveView and inspect why the equivalence layer passed, failed, rejected samples, or ran out of valid samples.
- Future authors: preview sample student answers against expected expressions once this behavior is promoted into authoring workflows.
- Future students: receive credit for mathematically equivalent expressions without being constrained to one written form.
- Instructors and learning engineers: rely on deterministic behavior that can be reproduced in support, preview, grading, and automated test environments after production integration.

## 5. UX / UI Requirements
- Add an Algebraic Equivalence section to the existing developer-only Math Prototype LiveView.
- Provide inputs for expected expression, candidate expression, sample count, seed, max attempts, special-point inclusion, allowed variables, per-variable domain rows, and tolerance configuration.
- Display a clear high-level outcome such as Equivalent, Not equivalent, Parse error, Validation error, Insufficient valid samples, or Candidate undefined at sample.
- Show developer diagnostics including parsed and normalized debug strings, detected variables, effective sampled variables, config summary, full sample comparison rows, first failure details, rejected sample summaries, and production-friendly summary data.
- Include concise copy that states the checker uses deterministic sampling and is not symbolic proof.
- Keep this UI developer-only and do not expose it as production authoring or learner UI.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Determinism: the same expressions, config, domains, seed, sample count, and tolerance must produce the same outcomes on repeated runs and on both Gleam targets.
- Reliability: parse errors, validation errors, runtime math errors, and insufficient sampling must return structured outcomes rather than crashes, vague booleans, `Nil`, `NaN`, or infinities.
- Performance: equivalence checks must be bounded by max attempts and should stop early on first mismatch or candidate runtime failure.
- Privacy: production telemetry must not include raw learner expressions or raw sampled assignments by default; developer-only prototype output may show them.
- Maintainability: public APIs should stay narrow under `torus_math`, with replaceable internals under `math/equality` and useful Gleam comments for exported behavior.

## 9. Data, Interfaces & Dependencies
- Depends on existing Gleam parser and normalization modules for expression parsing and normalized expression structures.
- Depends on existing sampling/evaluation modules for assignments, domains, seeded sample generation, valid-sample retry behavior, runtime math errors, and tolerance comparison.
- Adds algebraic equivalence config, allowed-variable policy, allowed-function policy, per-variable domain configuration, domain policy, diagnostic level, structured result, full sample comparison details, production summary data, candidate runtime failure, validation error, and stable debug formatting types.
- Exposes a raw-string API and a normalized-expression API through `gleam/src/torus_math.gleam`.
- Adds a thin Elixir/LiveView bridge only for the developer prototype; equivalence policy remains in shared Gleam code.

## 10. Repository & Platform Considerations
- Implement the core feature under `gleam/src/math/equality/` and expose only a small stable boundary through `gleam/src/torus_math.gleam`.
- Keep parser, normalizer, evaluator, sampler, and tolerance helpers independently reusable.
- Add Gleam tests under `gleam/test/` using the repository's current flat test naming convention unless a later design chooses nested paths.
- Shared behavior must pass `cd gleam && gleam format --check src test`, `cd gleam && gleam test --target erlang`, and `cd gleam && gleam test --target javascript`.
- LiveView prototype changes, if made in this work item, should use existing Phoenix/LiveView patterns and targeted ExUnit coverage.
- Code review should include `.review/security.md`, `.review/performance.md`, `.review/requirements.md`, `.review/gleam.md`, and `.review/elixir.md`; add UI review if the prototype surface changes materially.
- No Jira issue key was provided; this work item directory is the planning source of truth until a ticket is linked.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Primary success signal: algebraic equivalence golden corpus tests pass on Erlang and JavaScript targets.
- Developer success signal: the Math Prototype LiveView can show equivalent, not-equivalent, parse-error, validation-error, candidate-runtime-failure, and insufficient-sample outcomes with understandable diagnostics.
- Determinism signal: fixed seeds produce stable sample comparisons and debug output across repeated runs and both targets.
- No new production telemetry is required. If telemetry is added later, it should use outcome categories, sample counts, attempt counts, rejection category counts, normalized hashes, and timing buckets rather than raw expressions or assignments.

## 13. Risks & Mitigations
- False positives from sampling: include special points, deterministic pseudo-random samples, anti-correlated multi-variable assignments, a golden corpus, and explicit wording that this is sampling-based equivalence rather than proof.
- Hidden domain mismatches: document the MVP `ExpectedDefinedDomain` policy, preserve candidate runtime failures at expected-valid points, and defer strict domain compatibility to a named future mode.
- Floating-point drift: reuse the existing absolute/relative tolerance helper and validate cross-target behavior.
- Prototype UI becoming production UI: keep the panel in the developer-only Math Prototype LiveView and do not wire it into production activity authoring or delivery.
- Scope creep into symbolic algebra: treat expansion, factoring, cancellation, and CAS behavior as future work unless existing normalization and sampling already handle the case.

## 14. Open Questions & Assumptions
### Open Questions
- No open questions remain for the initial per-variable domain and result-detail scope decisions.

### Assumptions
- The initial implementation supports per-variable domain rows in the developer prototype rather than a single shared domain applied to all variables.
- Result details retain full sample comparisons and also include production-friendly summary data.
- Default allowed variables infer from the expected expression; candidates using unexpected variables fail validation unless explicitly allowed.
- The default seed will reuse the sampling layer default when available; otherwise it will be `42`.
- The default sample count is 8 valid expected-defined samples.
- The only MVP domain policy is `ExpectedDefinedDomain`.
- Default tolerance is absolute-or-relative tolerance with `0.0001` absolute and relative thresholds.
- Trigonometric functions use radians, and supported functions match the existing evaluator's real-valued function list.

## 15. QA Plan
- Automated validation:
  - Run `cd gleam && gleam format --check src test`.
  - Run `cd gleam && gleam test --target erlang`.
  - Run `cd gleam && gleam test --target javascript`.
  - Add Gleam unit tests for raw-string equivalence, normalized-expression equivalence, equivalent expressions, near misses, parse failures, validation failures, candidate runtime failures, expected runtime retries, insufficient samples, constant expressions, tolerance boundaries, and golden corpus fixtures.
  - Add cross-target tests proving stable outcomes, debug strings, sample details, and tolerance results.
  - Add targeted LiveView tests if the prototype panel is implemented in this work item.
- Manual validation:
  - Exercise the prototype panel with expansion, factoring, trig identity, near miss, unexpected variable, expected-domain, candidate-domain, and insufficient-sample examples.
  - Inspect developer diagnostics for clarity and confirm the UI states that deterministic sampling is not symbolic proof.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
