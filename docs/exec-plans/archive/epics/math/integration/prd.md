# Math Evaluation Integration - Product Requirements Document

## 1. Overview

Integrate the shared Gleam-based Torus Math evaluator into the existing standard activity evaluation flow for Short Answer and Multi Input math-capable parts. The integration must preserve Torus' existing response model: responses carry score and feedback, all responses for a part are evaluated, the highest-scoring matching response wins, and response order only breaks ties.

New authored math inputs should use a unified `math_expression` input type and response-level `matchConfig` objects. Existing `numeric` and `math` activities must continue to evaluate correctly at runtime without database migration. When authors edit and save old `numeric` or `math` content, the authoring layer should convert those parts to `math_expression` and persist `matchConfig` instead of legacy rule-backed math responses.

## 2. Background & Problem Statement

Torus currently evaluates standard activity responses through string rules interpreted by `lib/oli/delivery/evaluation/rule.ex` and selected by `lib/oli/delivery/evaluation/evaluator.ex`. That system is deeply connected to activity scoring and feedback behavior, and it must remain the policy layer for which feedback and score a learner receives.

The math roadmap has introduced Gleam-based parsing, normalization, equality, exact-form, algebraic equivalence, and unit-aware comparison primitives. Those capabilities now need a production integration path that avoids duplicating math semantics in Elixir or TypeScript while preserving current content and learner-facing behavior.

The main gap is a compatibility and matching boundary. New math expression responses need to match through `matchConfig` rather than legacy `rule`, while old `numeric` and `math` responses need runtime translation from existing rules into equivalent math evaluator configurations.

## 3. Goals & Non-Goals

### Goals

- Preserve current standard response scoring semantics, including highest-scoring matching response selection.
- Add response-level `matchConfig` support for new math expression responses without serializing legacy `rule` on those responses.
- Add part/input metadata needed to distinguish `math_expression`, existing `numeric`, existing `math`, and non-math inputs.
- Route math expression response matching through a single server-side math evaluation boundary backed by Gleam.
- Provide runtime compatibility for existing `numeric` and `math` rule-backed content without database migration.
- Convert edited legacy `numeric` and `math` authoring content to the new `math_expression` plus `matchConfig` shape on save.
- Keep score, feedback, targeted triggers, lifecycle persistence, and rollup behavior owned by existing Torus evaluation code.

### Non-Goals

- Replacing the full activity evaluation engine.
- Changing adaptive page rule evaluation or `AdaptivePartEvaluation`.
- Migrating all existing activity JSON in the database.
- Keeping `rule` serialized on new math expression responses.
- Exposing raw math diagnostics directly to learners.
- Building a new activity type solely for math expression questions.
- Replacing non-math text, dropdown, or multiple-choice rule matching.

## 4. Users & Use Cases

- Authors: create new math expression responses with algebraic equivalence, exact-form, unit-aware, partial-credit, and catch-all configurations.
- Authors editing old content: open existing Number or Math inputs, make changes, and save them into the new `math_expression`/`matchConfig` model without manual migration work.
- Students: submit math answers and receive the same scoring and feedback behavior Torus already provides, with richer math matching where configured.
- Instructors and support staff: rely on existing published content continuing to grade correctly even if authors never edit it.
- Torus engineers and QA: validate a single math evaluation boundary across server, browser, authoring, preview, and delivery workflows.

## 5. UX / UI Requirements

- New authoring controls should expose a unified `math_expression` input type for math-capable Short Answer and Multi Input parts.
- New math expression authoring should create response-level `matchConfig` data and omit serialized `rule`.
- Authoring should no longer create new legacy `numeric` or `math` rule-backed configurations for math work.
- Existing `numeric` and `math` activities should remain editable, but saving them should convert the edited content to `math_expression` and `matchConfig`.
- Author preview should not add new diagnostic surfaces in this work item; it should continue to show existing preview/evaluation behavior and authored feedback.
- Learner delivery should continue to show authored response feedback, not raw math engine diagnostics.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Reliability: existing rule-backed `numeric` and `math` content must continue to grade without migration.
- Determinism: Gleam math outcomes must be deterministic across BEAM and JavaScript targets where shared behavior is used.
- Privacy: production logs and telemetry must not include raw learner math answers, raw sampled assignments, or detailed internal diagnostics by default.
- Performance: matching must remain bounded and appropriate for the existing per-response evaluation loop.
- Maintainability: Elixir and TypeScript integration must use public math boundaries rather than duplicating Gleam semantics.
- Accessibility: math expression authoring and learner input UI changes must preserve keyboard and screen-reader expectations for existing activity surfaces.

## 9. Data, Interfaces & Dependencies

- New math expression responses store `matchConfig` and do not serialize `rule`.
- `Oli.Activities.Model.Response` must preserve optional `matchConfig` and tolerate missing serialized `"rule"` when `matchConfig` is present.
- Parsed parts need input metadata that preserves existing vocabulary: `numeric`, `math`, `text`, `dropdown`, and new `math_expression`.
- Runtime matching depends on a server-side boundary such as `Oli.Delivery.Evaluation.ResponseMatcher` plus math-specific and legacy-adapter modules.
- The math matcher depends on the public Gleam `torus_math` boundary through Elixir wrappers under `lib/oli/math*`.
- Authoring changes affect TypeScript activity schemas and editors under `assets/src/components/activities/short_answer`, `assets/src/components/activities/multi_input`, and shared response/rule utilities.

## 10. Repository & Platform Considerations

- Backend evaluation changes belong under `lib/oli/delivery/evaluation*` and related activity model parsing modules.
- Shared math behavior belongs under `gleam/src/math*` and should be exposed only through stable public functions in `gleam/src/torus_math.gleam`.
- Frontend authoring changes should extend existing Short Answer and Multi Input activity components rather than introducing a new activity shell.
- Delivery, preview, and test-eval entry points should use the same matcher to avoid divergent grading behavior.
- Code review should include security and performance by default, plus Elixir, Gleam, TypeScript/UI, and requirements review for the implementation slices that touch those areas.
- No Jira issue was provided for this work item; this directory is the planning source of truth until one is linked.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

This work should avoid database-wide migration. Runtime compatibility handles unedited legacy content. Edit-time conversion moves touched `numeric` and `math` content forward to `math_expression` and `matchConfig`.

## 12. Telemetry & Success Metrics

- Success is measured by existing numeric and math activities continuing to evaluate correctly without migration.
- Success is measured by new math expression activities supporting full-credit, partial-credit, unit-aware, exact-form, and catch-all response matching through `matchConfig`.
- If telemetry is added during implementation, it should use aggregate categories such as input type, config mode, outcome category, and timing buckets. It must not record raw learner answers or raw math diagnostic details by default.
- AppSignal and existing Phoenix telemetry should be used for operational visibility if production rollout reveals latency or error-rate concerns.

## 13. Risks & Mitigations

- Risk: new math expression responses accidentally fall back to stale or empty legacy rules. Mitigation: omit serialized `rule`, make the matcher prefer `matchConfig`, and test that empty in-memory rules are not evaluated for math expression responses.
- Risk: existing `numeric` and `math` content regresses. Mitigation: keep runtime adapters for old input types and add compatibility tests for existing rule shapes.
- Risk: authoring save converts old content incorrectly. Mitigation: add focused TypeScript tests and end-to-end workflow coverage for edited legacy numeric/math activities.
- Risk: math diagnostics leak student answers. Mitigation: keep diagnostics structured, route learner feedback through authored responses, and restrict production logging to aggregate-safe categories.
- Risk: evaluation latency increases in response-heavy activities. Mitigation: keep matching bounded, reuse decoded configs where practical, and include targeted performance review before release.
- Risk: adaptive activity behavior is accidentally changed. Mitigation: explicitly exclude adaptive rule evaluation from this work and verify adaptive paths remain unchanged.

## 14. Open Questions & Assumptions

### Open Questions

- None for this PRD.

### Assumptions

- Highest-scoring matching response selection is intentional and must be preserved.
- Existing `numeric` and `math` input type strings remain valid for runtime compatibility and should not be renamed in parsed models.
- New math expression responses should omit serialized `rule`; only parsed in-memory structs may use an empty rule placeholder for compatibility.
- The new authored input type string is `math_expression`.
- The response-level stored matcher field is `matchConfig`.
- Legacy Math direct comparison must preserve the behavior that is actually implemented today, including any whitespace normalization performed by the current `input equals` rule path.
- Author preview diagnostics remain unchanged in this work item; richer author-facing diagnostics are deferred to future work.
- Adaptive activity evaluation remains outside this integration.
- Existing published content may remain rule-backed indefinitely if authors never edit it.

## 15. QA Plan

- Automated validation:
  - Run targeted ExUnit tests for response parsing, part metadata parsing, response matching, legacy numeric compatibility, legacy Math compatibility, preview/test evaluation, and standard delivery evaluation.
  - Run Gleam tests on Erlang and JavaScript targets for match config decoding, math expression matching, exact-form matching, unit-aware matching, and catch-all matching.
  - Run relevant Jest tests for Short Answer and Multi Input authoring conversion behavior.
  - Add scenario or integration coverage for authoring -> publish -> delivery workflows where a learner receives correct, partial-credit, and catch-all feedback from math expression responses.
- Manual validation:
  - Author new `math_expression` Short Answer and Multi Input activities and verify preview and delivery behavior.
  - Edit existing numeric and Math activities, save them, and inspect that JSON changes to `math_expression` plus `matchConfig` without serialized `rule`.
  - Validate old unedited numeric and Math activities still grade correctly in delivery.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
