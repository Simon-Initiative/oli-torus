# Math AST Normalization - Product Requirements Document

## 1. Overview
Create a Level 1 structural normalization layer for Torus Math expressions. The feature should convert parsed Gleam math ASTs into a deterministic, stable internal representation that can support hashing, diagnostics, validation, exact-form checks, and later evaluator work without becoming a symbolic algebra system.

The normalizer must be shared across server and browser runtimes by living in the existing `gleam/` math subsystem and passing on both Erlang and JavaScript targets.

## 2. Background & Problem Statement
The math parser milestone produces a Torus-owned AST, parse errors, source metadata, and cross-target Gleam support. Downstream equality, diagnostics, and evaluator work now need a stable internal expression shape so equivalent surface forms such as `x + 2` and `2 + x` can be treated consistently.

Without a clear normalization boundary, the implementation can drift into unsafe simplification. Rewrites such as `x / x -> 1`, `(x^2 - 1)/(x - 1) -> x + 1`, or `0 * f(x) -> 0` can erase undefined behavior or depend on assumptions that Torus has not modeled. The first milestone must therefore normalize expression structure while preserving source form and domain behavior.

## 3. Goals & Non-Goals
### Goals
- Provide a deterministic structural normalizer for parsed math expressions.
- Produce a separate normalized AST while preserving the original parsed AST and source metadata.
- Canonicalize safe structural differences such as commutative ordering, associative flattening, explicit versus implicit multiplication shape, unary plus cleanup, and literal-only numeric folding.
- Provide stable normalized debug strings and hashes that are consistent across Erlang and JavaScript targets.
- Keep normalization useful for later equality, validation, diagnostics, and exact-form checks.

### Non-Goals
- Do not implement expansion, factoring, cancellation, rational reduction, trigonometric identities, assumption-dependent rewrites, or heuristic simplification.
- Do not decide algebraic equivalence solely through normalization.
- Do not discard raw numeric literals, source spans, decimal precision, fraction syntax, scientific notation, or implicit-multiplication metadata.
- Do not introduce production grading use of aggressive normalization modes until those modes have separate contracts and tests.

## 4. Users & Use Cases
- Students: receive consistent math grading and diagnostics for syntactically different but structurally equivalent responses.
- Authors: can rely on exact-form constraints later because normalization preserves original answer representation.
- Instructors: benefit from stable grading behavior that does not accidentally accept domain-changing simplifications.
- Engineers and learning engineers: get deterministic normalized debug output and hashes for tests, diagnostics, and future evaluator layers.

## 5. UX / UI Requirements
- No learner-facing UI changes are required for the MVP.
- Developer or prototype UI surfaces may show normalized debug strings, hashes, and developer-preview warnings when useful for validating behavior.
- Any future student-facing diagnostic messages must be derived from structured errors or warnings and must not expose raw sensitive answer data beyond the student's own submitted expression.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Determinism: identical inputs must produce identical normalized debug strings and hashes on both Erlang and JavaScript targets.
- Safety: Level 1 normalization must preserve domain behavior and must not remove potentially undefined subexpressions.
- Performance: normalization must be bounded and suitable for interactive grading/prototype use; it should avoid unbounded symbolic search and avoid expensive repeated scans in hot paths.
- Reliability: malformed or unsupported expressions must remain represented through existing parse or validation errors rather than causing normalizer panics.
- Security and privacy: diagnostics, warnings, and telemetry must avoid logging sensitive raw answer data.
- Maintainability: normalization passes must be named and scoped so future polynomial or rational work can be added without changing Level 1 behavior.

## 9. Data, Interfaces & Dependencies
- Input dependency: parsed math `Expr` values from the existing Gleam parser.
- Output interface: a normalized result that preserves the original expression, contains a separate normalized AST, and exposes stable debug and hash representations.
- Metadata dependency: source spans, raw numeric literal data, notation metadata, fraction or decimal form, and implicit multiplication metadata must survive normalization.
- Runtime dependency: the implementation must remain compatible with Gleam's Erlang and JavaScript targets.
- Integration dependency: Elixir and TypeScript wrappers should remain thin and consume the shared Gleam public API rather than duplicating normalization logic.

## 10. Repository & Platform Considerations
- The implementation belongs under `gleam/src/math/` with the public API exposed through `gleam/src/torus_math.gleam`.
- Tests belong under `gleam/test/` and should run with `gleam test --target erlang` and `gleam test --target javascript`.
- Any Elixir integration should stay in the `lib/oli/math*` boundary and load generated Gleam BEAM paths consistently.
- Any browser integration should use thin TypeScript wrappers under `assets/src/gleam/` and consume generated Gleam JavaScript.
- Code review should include `.review/gleam.md`, `.review/security.md`, and `.review/performance.md`; add `.review/elixir.md` or `.review/typescript.md` only if wrappers change.
- No Jira issue key was provided with this request; use this work item directory as the planning source of truth until an issue is linked.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Primary success signal: the same normalization test corpus passes on Erlang and JavaScript targets.
- Secondary success signal: normalized debug strings and hashes remain stable for commutative and associative examples across repeated runs.
- No new production telemetry is required for the MVP unless normalization is wired into runtime grading paths in a later implementation phase.
- If prototype diagnostics emit telemetry later, they must report aggregate event categories rather than raw submitted expressions.

## 13. Risks & Mitigations
- Scope creep into simplification: keep Level 1 limited to structural normalization and name future passes separately.
- Domain-changing rewrites: explicitly reject cancellation, denominator removal, `x/x -> 1`, and undefined-subexpression elimination unless a future guarded representation exists.
- Cross-target numeric drift: limit exact numeric folding to values that can be represented consistently on both targets, or preserve large values as strings until a big-number strategy exists.
- Metadata loss: require tests proving raw/source information remains available after normalization.
- API instability: expose a small public API through `torus_math` and keep internal normalized AST modules replaceable.

## 14. Open Questions & Assumptions
### Open Questions
- Should the MVP expose only `structural_normalize`, or also expose `normalize_with_options` with only the `Structural` level enabled?
- What hash algorithm should be used for normalized hashes, and should it be implemented in Gleam or provided by thin target-specific wrappers?
- What exact integer size limit should determine when numeric values are folded versus preserved as strings?
- Should developer-preview warnings be returned in the MVP result type or deferred until the prototype UI needs them?

### Assumptions
- The parser and current AST contracts from the previous math milestone are stable enough to serve as the normalizer input.
- Structural normalization is the only implementation scope for this work item.
- Algebraic equivalence will be handled by later evaluator and sampling work rather than by expanding the normalizer.
- Exact-form constraints will continue to inspect original parsed AST metadata, not only the normalized AST.

## 15. QA Plan
- Automated validation:
  - Run `cd gleam && gleam format --check src test`.
  - Run `cd gleam && gleam test --target erlang`.
  - Run `cd gleam && gleam test --target javascript`.
  - Add tests for structural equivalence, Level 1 non-equivalence, metadata preservation, stable debug strings, and stable hashes.
- Manual validation:
  - Inspect representative normalized debug output for examples from `math-normalization-design.md`.
  - Confirm no Level 1 test accepts expansion, factoring, cancellation, trig identity simplification, or assumption-dependent rewrites.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
