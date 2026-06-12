# Math Equality Contract And Numeric Evaluation - Product Requirements Document

## 1. Overview

This work item covers Feature 1 and Feature 2 from `docs/exec-plans/current/epics/math/plan.md`: the equality contract/configuration model and the numeric scalar evaluation layer for standard/basic page Number inputs.

The primary deliverable is a type-safe, JSON-encodable Gleam algebraic data type that models the valid ways Torus can compare an expected math answer to a student answer. That configuration is intended to become the single equality contract used by future authoring UI, delivery evaluation, and both server-side and browser-side math workflows.

The first executable evaluator behavior in this work item is numeric comparison for standard/basic page response evaluation. It must preserve the comparison semantics Torus already supports for those Number inputs while adding the new tolerance and precision options needed by the unified math evaluation engine. Adaptive page evaluation remains on its existing `AdaptivePartEvaluation` path and is not incorporated into this work item.

## 2. Background / Problem Statement

Torus currently evaluates many activity responses through rule strings. The server-side reducer in `lib/oli/delivery/evaluation/evaluator.ex` iterates configured responses and calls `lib/oli/delivery/evaluation/rule.ex`, while authoring code in `assets/src/data/activities/model/rules.ts` constructs compatible rule strings. Number inputs support equality, inequality, ordered comparisons, ranges, inverse ranges, and a legacy `#precision` suffix.

That rule-string model is difficult to extend into a unified math system that also supports algebraic equivalence, unit-aware answers, richer tolerance models, and future authoring controls. The math parser foundation now exists in Gleam, so the next layer is a stable equality configuration contract and numeric evaluator that can be shared across runtime targets.

This PRD does not change feedback selection. The equality contract determines whether a student answer equals an expected answer under a configuration. Existing Torus evaluation code will continue to know which response and feedback to return when a match occurs.

## 3. Goals and Non-Goals

Goals:

- Define the public equality API shape for comparing an expected answer and a student answer under an equality configuration.
- Define a rich Gleam algebraic data type for equality configuration, with JSON encoding and decoding suitable for future storage as `equalityConfig` on Response objects.
- Model valid configuration choices in the type system so invalid or contradictory options are hard to represent.
- Reimplement current Number input comparison semantics in the new math evaluation layer.
- Add first-class tolerance, numeric representation, and decimal precision configuration for numeric equality.
- Provide deterministic diagnostics that explain why an equality check passed or failed without selecting feedback, score, or response behavior.
- Establish parity fixtures and tests that compare current numeric behavior to the new numeric evaluator.

Non-goals:

- Selecting feedback text, feedback IDs, scores, hints, or targeted feedback.
- Replacing the production activity evaluator reducers in this work item.
- Changing adaptive page evaluation or incorporating `lib/oli/delivery/attempts/activity_lifecycle/adaptive_part_evaluation.ex` behavior into the new math evaluator.
- Implementing the legacy rule-string compatibility adapter. That adapter belongs to the later Torus activity evaluation integration feature.
- Building authoring UI or delivery UI.
- Implementing algebraic normalization, algebraic equivalence, symbolic simplification, sampling-based equivalence, or unit conversion behavior.
- Migrating existing activity data.

## 4. Users and Use Cases

Authors need future controls that express how a math answer should be judged, such as exact numeric equality, a range comparison, a tolerance-based comparison, algebraic equivalence, or a unit-aware answer. This work item defines the contract those controls will eventually write.

Students need stable grading behavior where mathematically equivalent numeric answers can be accepted according to the author's configured rules.

Torus engineers need one typed equality model that can be used from Gleam, Elixir, and browser JavaScript instead of continuing to grow independent string-rule behaviors.

QA and learning designers need a readable compatibility corpus showing that existing standard/basic page Number input behavior is preserved before new math features are enabled in production evaluation.

## 5. UX / UI Requirements

This work item has no production UI.

The equality configuration model must still use concepts that can map cleanly to future authoring controls, including comparison mode, tolerance mode, numeric representation, decimal precision, algebraic comparison mode, form constraints, and unit settings.

The contract must not include feedback text, matched feedback, scoring, or activity-level response selection. Those concepts remain owned by the existing Torus activity evaluation flow.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria

Acceptance Criteria are found in requirements.yml

## 8. Non-Functional Requirements

The equality configuration must be durable JSON. Field names, enum values, and versioning must be stable enough to support long-lived course content and future compatibility adapters.

The Gleam model must prioritize type safety. Numeric, algebraic, unit-aware, form-constrained, and representation-constrained modes should be modeled so invalid state combinations are avoided at construction time where practical.

Numeric evaluation must be deterministic and cross-target safe. Server-side and JavaScript builds must agree on supported numeric comparisons for the same config and inputs.

The contract must avoid logging raw student math submissions by default. Diagnostics should be structured for tests and developer inspection without becoming production telemetry that exposes student answers.

The numeric evaluator must be lightweight enough for standard/basic page per-response evaluation loops. This PRD does not set a strict latency target, but implementation should avoid designs that scale poorly with ordinary Number input comparisons.

## 9. Data, Interfaces, and Integration Points

The core configuration and equality result types should live in Gleam under the math codebase and compile to both Erlang and JavaScript targets.

The equality config must include a JSON representation suitable for a future Response object attribute named `equalityConfig`. The JSON shape should include enough versioning or discriminators to support future evolution.

The public equality contract should accept:

- Expected answer input.
- Student answer input.
- Equality configuration.
- Deterministic evaluation options when required by future algebraic or sampling behavior.

The public equality contract should return:

- Equality outcome.
- Structured failure or diagnostic reasons.
- Normalized or interpreted values only where safe and useful for debugging.

The contract must not return feedback text, feedback IDs, score values, or final activity evaluation decisions.

Numeric behavior must cover the current standard response-rule operators defined by `assets/src/data/activities/model/rules.ts` and interpreted by `lib/oli/delivery/evaluation/rule.ex`: equal, not equal, greater than, greater than or equal to, less than, less than or equal to, between, and not between.

Adaptive page numeric behavior currently handled by `lib/oli/delivery/attempts/activity_lifecycle/adaptive_part_evaluation.ex` remains separate and must continue to execute as it does today. This PRD does not require the new Gleam math evaluator to represent or execute adaptive-page-specific numeric checks.

The future production integration point is the standard/basic page reducer flow in `lib/oli/delivery/evaluation/evaluator.ex` and the surrounding activity lifecycle evaluation code that calls it. That integration is intentionally out of scope for this PRD except that this work must produce a contract suitable for it. The adaptive page branch is not an integration target for this work item.

## 10. Repository Integration and Review Considerations

Implementation should follow the existing Gleam math foundation and expose small Elixir and TypeScript boundaries only where needed for tests and future integration.

Gleam code should use liberal function-level and code-level comments where the reason for a type, configuration option, or numeric comparison rule is not obvious. Comments should explain why the behavior exists, especially where it preserves legacy Torus semantics.

Automated tests should include Gleam tests, JSON round-trip fixtures, numeric comparison fixtures, and wrapper tests where Elixir or TypeScript adapters are introduced.

Code review should include security and performance review. Elixir and frontend review guidelines apply if this PRD produces Elixir or TypeScript changes.

No Jira issue was provided for this work item.

## 11. Feature Flags

No feature flags present in this work item

## 12. Telemetry & Success Metrics

This work item should not introduce production telemetry for raw math submissions.

Success is measured by:

- A validated PRD and requirements file for the contract work item.
- A JSON-encodable equality configuration model that can express planned math equality modes.
- Numeric evaluator parity with current standard/basic page Number input behavior.
- Automated JSON round-trip and numeric comparison tests.
- Clear separation between equality outcome and feedback or scoring behavior.

Future production integration may add aggregate telemetry for configuration usage and evaluation outcomes, but that is outside the scope of this PRD.

## 13. Risks and Mitigations

Risk: The equality configuration is modeled too loosely and allows invalid combinations.
Mitigation: Center the work on Gleam sum and product types, with JSON decoders rejecting invalid structures.

Risk: Current numeric behavior is not preserved.
Mitigation: Build a parity corpus from the existing rule-string operators, range syntax, scientific notation behavior, and `#precision` semantics.

Risk: Legacy significant-figure precision and new decimal precision become conflated.
Mitigation: Model them as separate configuration concepts and document the compatibility behavior explicitly.

Risk: Scope expands into algebraic equivalence or units.
Mitigation: The config may model future algebraic and unit options, but executable behavior in this work item is numeric scalar evaluation only.

Risk: Future stored JSON cannot evolve safely.
Mitigation: Include explicit discriminators and versioning strategy in the config JSON.

## 14. Open Questions & Assumptions

Open questions:

- What exact JSON versioning field and discriminator names should be considered stable for long-lived Response data?
- Should the initial JSON schema expose all future algebraic and unit options immediately, or should some variants remain internal until their evaluator behavior is implemented?
- How should future authoring UI name the distinction between legacy significant-figure precision and new decimal-place precision?
- Which Elixir module should own the first server wrapper around the equality contract?

Assumptions:

- The parser foundation in `docs/exec-plans/current/epics/math/parser` is available for expression parsing needs.
- Feedback selection remains outside the equality contract.
- Existing rule-string compatibility will be handled later at production evaluator integration time.
- Current standard/basic page Number input operators must remain behaviorally compatible before new numeric configuration options are used in production.
- Adaptive page evaluation remains outside this unified math evaluator and continues to use the current adaptive evaluation branch.

## 15. QA / Validation Plan

Validation must include automated structure checks for the work item documentation and requirements.

Implementation validation should include:

- Gleam tests for equality configuration constructors, JSON encoders, JSON decoders, and numeric evaluation.
- JavaScript-target Gleam build verification for config and numeric evaluator modules that must run in the browser.
- JSON golden fixtures for every supported numeric config family.
- Numeric parity tests for each current standard response-rule comparison operator.
- Edge case tests for range inclusivity, inverse ranges, reversed bounds, scientific notation, decimal notation, legacy `#precision`, tolerance behavior, decimal precision behavior, and parse failures.
- Elixir wrapper tests if server-side adapters are introduced.
- TypeScript wrapper or build tests if browser adapters are introduced.

Manual validation should compare a representative set of existing rule strings against equivalent JSON configs and confirm that equality outcomes match.

## 16. Definition of Done

The PRD and requirements file exist under `docs/exec-plans/current/epics/math/contract` and pass harness validation.

The equality configuration requirements clearly prioritize the Gleam algebraic data type and JSON encoding contract.

The numeric evaluation requirements explicitly include all current standard/basic page Number input comparison operators and explicitly exclude adaptive page numeric comparison behavior.

The requirements exclude feedback, scoring, production evaluator integration, UI, algebraic equivalence execution, and unit conversion execution from this work item.

The work item is ready for architecture planning.
