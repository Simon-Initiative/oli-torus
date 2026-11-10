# Exact Form And Representation Constraints - Product Requirements Document

## 1. Overview
Build the exact-form constraint layer for Torus Math Expression evaluation. The feature lets a semantically correct answer fail a configured representation rule, such as requiring integer form, fraction form, simplified fraction form, or decimal form with decimal-place precision.

The feature is a post-semantics refinement over existing Gleam math infrastructure. It should inspect the candidate's original parsed AST and numeric-literal metadata, return structured form outcomes, and expose a small public boundary through `torus_math` without changing production grading behavior.

## 2. Background & Problem Statement
Torus Math now has shared Gleam infrastructure for parsing, normalization, deterministic sampling, evaluation, numeric tolerance comparison, and algebraic equivalence. Those layers intentionally answer whether two answers mean the same thing, not whether the learner wrote the answer in a required representation.

Authors often need representation to be part of the learning objective. For example, `0.8` is mathematically equivalent to `4/5`, but it should fail when the author requires a simplified fraction. Likewise, `0.80` and `0.8` are numerically equal, but only one satisfies a decimal form requiring exactly two decimal places.

The current Number-input scalar evaluator already has broad representation and precision checks, but Math Expression exact form must use parsed AST/source metadata so it can distinguish expression forms such as literal integers, literal decimals, literal fractions, and unsupported expression shapes without relying on evaluated floats.

## 3. Goals & Non-Goals
### Goals
- Define typed exact-form configuration, observed-form summaries, form failures, and form-aware result types in shared Gleam.
- Classify whole-answer candidate forms from parsed AST metadata and raw numeric literal data.
- Enforce integer-only, fraction-only, simplified-fraction, and decimal-form constraints with decimal-place precision rules.
- Layer form checks after semantic equivalence so parse, validation, domain, runtime, and non-equivalence outcomes remain primary.
- Expose standalone form checking and form-aware algebraic checking through `gleam/src/torus_math.gleam`.
- Provide stable debug formatting for tests, diagnostics, and developer prototype use.
- Preserve existing Number-input scalar representation and precision behavior.
- Prove deterministic behavior on Erlang and JavaScript Gleam targets.

### Non-Goals
- Do not integrate exact-form checks into production Short Answer, Multi-Input, Number, legacy Math, adaptive activity, response-rule, authoring, delivery, scoring, or feedback-rule flows.
- Do not add production authoring UI, learner UI, activity JSON persistence, database migrations, or publication/attempt schema changes.
- Do not implement unit-aware exact form, LaTeX form preservation, factored form, expanded form, collected terms, simplified radicals, polynomial form, rational-expression form, or CAS-style simplification.
- Do not treat scientific notation as decimal form for Math Expression exact-form constraints.
- Do not implement partial credit, final feedback text selection, feedback-rule ordering, or author linting.
- Do not log raw learner expressions, expected answers, or sampled assignments in production telemetry.

## 4. Users & Use Cases
- Future authors: require representation-specific answers when the written form is part of the learning objective, such as integer form or simplified fraction form.
- Future students: receive a correct semantic evaluation while still being held to a clearly configured answer form when the author requires it.
- Developers: inspect exact-form outcomes, observed forms, spans, numeric literal metadata, and stable debug strings while validating the math engine before production grading integration.
- Learning engineers: rely on deterministic representation checks that can later feed feedback categories such as wrong form, unsimplified fraction, or decimal precision mismatch.

## 5. UX / UI Requirements
- No production authoring UI, learner UI, or activity configuration UI is in scope for this work item.
- Result categories and debug formatting must be suitable for a future developer-only Math Prototype LiveView extension.
- Any future developer prototype surface must remain developer-only, avoid persistence, and clearly separate semantic outcome from form outcome.
- Future learner-facing feedback text is out of scope; this feature returns structured categories only.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Determinism: exact-form classification, form-aware algebraic outcomes, and debug strings must be stable across repeated runs and both Gleam targets.
- Reliability: malformed candidates, invalid form config, unsafe integer details, unsupported source shapes, and non-equivalent answers must return structured outcomes rather than crashes or generic false values.
- Privacy: public summaries should avoid raw submitted answer text by default; raw numeric fragments may appear only in developer/test diagnostics.
- Performance: form checks must be bounded to parsing, AST traversal, integer parsing, decimal-place inspection, and GCD for simplified fractions; no sampling, symbolic simplification, factoring, expansion, or repeated evaluation belongs in the form module.
- Maintainability: exact-form behavior should live behind a narrow public `torus_math` boundary with implementation modules under `gleam/src/math/equality/`.

## 9. Data, Interfaces & Dependencies
- Depends on `gleam/src/math/ast.gleam` for `NumberLiteral.raw`, `notation`, `decimal_places`, expression spans, unary prefixes, binary division, and source-preserving AST shape.
- Depends on existing parser behavior for numeric literals, unary signs, grouping, and fraction syntax represented as division.
- Depends on existing algebraic equivalence APIs for form-aware semantic-first checking.
- Adds new Gleam modules such as `math/equality/form_types.gleam`, `math/equality/form.gleam`, and `math/equality/form_format.gleam`.
- Adds public `torus_math` functions for default exact-form config, standalone candidate form checking, form-aware algebraic checking, and stable debug formatting.
- If equality JSON is extended in a later integration slice, the expression config should carry a separate `form` object rather than overloading comparison mode.

## 10. Repository & Platform Considerations
- Core behavior belongs in shared Gleam because exact-form checks must be reusable from BEAM and JavaScript targets.
- Keep form constraints separate from parser, normalization, sampling, evaluator, and feedback-rule matching concerns.
- Do not add exact-form enforcement to normalized-expression-only APIs unless source-form metadata is also provided.
- Add tests under `gleam/test/` using the existing flat test naming convention.
- Required Gleam gates are `cd gleam && gleam format --check src test`, `cd gleam && gleam test --target erlang`, and `cd gleam && gleam test --target javascript`.
- Code review should include `.review/security.md`, `.review/performance.md`, `.review/requirements.md`, and `.review/gleam.md`; add `.review/elixir.md`, `.review/ui.md`, or `.review/typescript.md` only if later slices add wrappers or prototype UI.
- No Jira issue key was provided; this work item directory is the planning source of truth until a ticket is linked.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Primary success signal: exact-form and form-aware algebraic tests pass on Erlang and JavaScript targets.
- Quality signal: tests prove form failures only appear after semantic equivalence passes.
- Compatibility signal: existing Number-input scalar representation and precision tests continue to pass.
- No new production telemetry is required. Future telemetry should prefer form outcome categories, counts, normalized hashes, and timing buckets rather than raw expressions or raw numeric fragments.

## 13. Risks & Mitigations
- Form checks accidentally replace semantic correctness: require form-aware tests where non-equivalent candidates return semantic failure, not wrong-form failure.
- Metadata loss through normalization: classify from raw candidate strings or original parsed AST, not normalized-only values.
- Scope creep into rational-expression or symbolic form checking: limit MVP to whole-answer integer, decimal, and scalar fraction literal shapes.
- Numeric scalar behavior regression: keep Number-input representation helpers separate unless shared helper extraction is covered by existing numeric tests.
- Privacy leakage through diagnostics: keep raw submitted text out of production summaries and document debug formatters as developer/test-only.
- Cross-target integer drift: avoid simplified-fraction arithmetic for unsafe integer components unless a cross-target-safe raw integer strategy is explicitly added.

## 14. Open Questions & Assumptions
### Open Questions
- Should a future authoring UI expose non-canonical fraction sign feedback separately from unsimplified fraction feedback?  ANSWER:  NO
- Should large integer literals outside the shared safe integer range be accepted as integer form with raw-only details, or rejected as unsafe form details?  ANSWER: They should be rejected

### Assumptions
- Simplified fractions require a positive denominator; `-4/5` is canonical and `4/-5` is non-canonical.
- Zero fractions are simplified only when the denominator is `1`; `0/5` is unsimplified.
- Unary plus is accepted for exact forms for parser consistency.
- Scientific notation does not satisfy decimal form in this phase.
- Fraction-only form means a whole-answer scalar integer-literal division such as `4/5`, not variable rational expressions such as `1/x`.
- Form-aware algebraic checking may reparse the candidate after semantic pass rather than widening the existing algebraic result with parsed AST payloads.

## 15. QA Plan
- Automated validation:
  - Run `cd gleam && gleam format --check src test`.
  - Run `cd gleam && gleam test --target erlang`.
  - Run `cd gleam && gleam test --target javascript`.
  - Add Gleam tests for form config validation, whole-answer form classification, integer form, fraction form, simplified fraction form, decimal form, decimal-place precision rules, stable debug formatting, and invalid config.
  - Add form-aware algebraic tests proving semantic failure remains primary and equivalent-but-wrong-form produces structured form failures.
  - Run existing numeric equality tests when shared precision or representation helpers are touched.
- Manual validation:
  - Review debug output examples for clarity and absence of production-facing feedback copy.
  - Inspect changed files for raw expression logging, raw assignment logging, and production grading integration drift.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
