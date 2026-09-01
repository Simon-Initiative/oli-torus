# MER-5821: Aggregate Child Learning Objective Proficiency into Parent Learning Objectives - Product Requirements Document

## 1. Overview

Torus calculates learner proficiency at the Sub-Objective (Sub-LO) level from tagged activity
evidence. When a Learning Objective (LO) has one or more Sub-LOs, its own proficiency should
reflect a weighted combination of its Sub-LOs' proficiency (and any evidence tagged directly to
the parent), rather than only its own directly-tagged evidence. Today this rollup either behaves
inconsistently across the codebase or does not happen at all in some surfaces, so a parent LO with
only Sub-LO-tagged activity shows "not enough data" even when its Sub-LOs have ample evidence.

This work item introduces a single, algorithm-agnostic weighted-aggregation function and unifies
the authoring- and delivery-side call sites that need it, so that parent LO proficiency reflects
its Sub-LOs consistently everywhere it is shown, while remaining a runtime projection (not a
persisted, write-time calculation) and remaining reusable by both the current naive proficiency
algorithm and the forthcoming LKT-AOA learner model (`MER-5846`).

## 2. Background & Problem Statement

The Jira ticket `MER-5821` originally asked for equal-weight aggregation and was ambiguous about
whether aggregation should move from a runtime projection to a persisted calculation. Review
comments from Darren Siegel resolved both points: timing stays a runtime projection, and the
formula is a weighted average, weighted by the amount of evidence available per Sub-LO — not
equal weighting. Darren also asked that every place in the system performing this rollup, both
authoring and delivery, be found and updated together, rather than patched one at a time.

A code audit (see `informal.md` in this directory) found that the rollup is inconsistent today:

- Delivery, student-facing proficiency (`Metrics.aggregate_raw_proficiency/1`) already pools
  evidence across a parent's children before dividing, so it already behaves like a weighted
  average, but it is coded directly against the naive first-attempt formula.
- The Instructor Dashboard Learning Objectives tab, the instructor's per-student view, and the
  Learning Objectives CSV export (`Sections.get_objectives_and_subobjectives/2`) do not combine a
  parent's Sub-LOs at all — a parent LO's displayed proficiency comes only from its own direct
  evidence, which is usually absent because authors tag activities at the Sub-LO level.
  Existing test coverage (`test/oli/delivery/sections_test.exs:3450-3498`) documents and asserts
  this gap as current behavior.
- A new delivery-side page element (`PageElement.maybe_proficiency/5`) also does not combine
  Sub-LOs.

Separately, epic `MER-5843` ("Learning Proficiency Model Improvements") is replacing the naive
proficiency algorithm with LKT-AOA (`MER-5846`) behind a `learning_model_version` switch already
implemented in code (`MER-5845`). `MER-5846`'s own acceptance criteria explicitly exclude LO
aggregation from its scope, and the LKT-AOA technical definition
(`docs/exec-plans/current/epics/learning_model_v2/lkt_technical_notes.docx.md`, section 6) already
specifies its own weighted-average rollup rule. This work item's aggregation function must serve
both the current naive algorithm and this future LKT-AOA rollup without depending on either one's
internals.

## 3. Goals & Non-Goals

### Goals
- Provide a single, algorithm-agnostic weighted-aggregation function that produces a parent LO's
  proficiency score from `(proficiency, count)` pairs contributed by its Sub-LOs (and, when
  present, its own directly-tagged evidence).
- Make the function's `count` contract explicit: the caller supplies a count consistent with
  whichever algorithm computed that child's proficiency (naive: first-attempt count; LKT-AOA:
  total/opportunity count), and the function documents this responsibility rather than guessing.
- Audit and update every runtime call site that rolls up (or should roll up) Sub-LO proficiency
  into a parent LO — both authoring-facing and delivery-facing — so they all consume the shared
  function instead of duplicating or omitting the rollup.
- Always combine a parent LO's own directly-tagged evidence with its Sub-LOs' evidence in the
  weighted average whenever the parent has evidence of its own — never excluding it because the
  parent has Sub-LOs, and never treating it as a fallback used only when Sub-LOs lack evidence.
  This supersedes the original Jira ticket's own AC (an activity tagged to both a parent LO and
  one of its Sub-LOs must count only once, at the Sub-LO); Darren Siegel confirmed on Slack
  (2026-09-01) that always combining ("Option B") is "the simplest thing that we can (and should)
  do," accepting the resulting double-counting risk when an activity is tagged to both levels. See
  `parent_evidence_aggregation_options.md` for the alternatives considered and their trade-offs.
- Preserve incomplete-coverage semantics: a Sub-LO with insufficient evidence is represented in
  the aggregation rather than silently excluded, so the parent reflects incomplete coverage
  instead of behaving as though only the attempted Sub-LOs exist.
- Keep the aggregated result flowing through the same bucketing behavior naive callers use today
  (`Metrics.proficiency_range/2`), so the Not Enough Information / Low / Medium / High
  distribution shown for a parent LO reflects its combined evidence.

### Non-Goals
- Changing when aggregation happens. It remains a runtime projection computed when proficiency is
  read, not persisted at attempt-evaluation time.
- Implementing the LKT-AOA learner model itself (`MER-5846`) or its `learning_state` data path.
- Implementing or changing the `learning_model_version` project/section switch (`MER-5845`); it
  already exists in code and this work item only needs to be safe to call regardless of which
  version is active.
- Implementing the Confidence metric (`MER-5847`).
- Designing or building the coverage-gap-indicator UI described in the LKT-AOA technical notes
  (section 6.3); that needs separate UX design work.
- Reworking the whole-class "Average Class Proficiency" aggregation
  (`data_snapshot/projections/summary/projector.ex` and its CSV helper) or its pre-existing
  20/60/100 vs. 30/60/90 bucket-weight inconsistency; that aggregates across students, not across
  an LO hierarchy, and is a separate concern.
- Changing `Oli.InstructorDashboard.Oracles.ProgressProficiency`'s page/container-scoped
  proficiency calculation; it does not perform LO parent/Sub-LO rollup.

## 4. Users & Use Cases

- Instructor: views the Learning Objectives tab of the Instructor Dashboard and expects a parent
  LO's proficiency distribution to reflect the combined evidence of all its Sub-LOs, not just
  activity tagged directly to the parent.
- Instructor: exports the Learning Objectives CSV and expects the same combined proficiency values
  as the on-screen tab.
- Instructor: views a single student's proficiency on the per-student instructor view and expects
  the same combined parent-LO behavior.
- Student: views their own proficiency (prologue, lesson, and review pages) for a parent LO and
  expects it to reflect their performance across that LO's Sub-LOs.
- Author/researcher (indirect, future): the LKT-AOA implementation (`MER-5846`) will call the same
  aggregation function once it exists, so it does not need to reimplement parent-LO rollup.

## 5. UX / UI Requirements

- No new UI. Existing surfaces (Instructor Dashboard Learning Objectives tab, per-student
  instructor view, Learning Objectives CSV export, student prologue/lesson/review proficiency
  displays, and the `"learning_objectives"` page element) should start showing a combined parent
  LO value where they previously showed "not enough data" or an un-aggregated direct-only value.
- No copy changes are required by this work item. If the resulting values differ visibly from
  today's (e.g., a parent LO that previously showed "Not enough data" now shows a computed
  proficiency), no additional UI treatment is required beyond what each surface already renders
  for that bucket.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Reliability: the aggregation function must produce a deterministic result for a given set of
  `(proficiency, count)` inputs and must not raise on the boundary cases already covered by
  existing tests (no children, all children below the minimum-evidence threshold, a child with a
  `nil`/unset proficiency).
- Performance: updated call sites (in particular the Instructor Dashboard tab and its CSV export,
  which operate over a full section roster) must continue to use set-based, per-section queries
  rather than issuing one query per learner or per objective, consistent with
  `docs/BACKEND.md` and the existing query shape in `Sections.get_objectives_and_subobjectives/2`.
- Compatibility: the change must not alter the meaning of `Metrics.proficiency_range/2`'s existing
  thresholds or the naive model's current behavior for LOs that have no Sub-LOs (i.e., leaf LOs
  keep their current single-node calculation unchanged).

## 9. Data, Interfaces & Dependencies

- `Oli.Resources.Revision.children` (objective hierarchy) and `Oli.Resources.Revision.objectives`
  (activity-to-objective tagging) are the source of the parent/Sub-LO relationship and evidence
  attribution; no schema changes are introduced by this work item.
- `Oli.Analytics.Summary.ResourceSummary` remains the source of naive-model evidence counts
  (`num_first_attempts`, `num_first_attempts_correct`).
- New shared function (exact module/function name to be decided during planning/implementation)
  consumed by:
  - `Oli.Delivery.Metrics.aggregate_raw_proficiency/1` /
    `proficiency_for_student_per_learning_objective/3` (`lib/oli/delivery/metrics.ex`)
  - `Oli.Delivery.Sections.get_objectives_and_subobjectives/2` (`lib/oli/delivery/sections.ex`),
    via `Metrics.proficiency_per_student_for_objective/3`
  - `Oli.Delivery.LearningObjectives.PageElement.maybe_proficiency/5`
    (`lib/oli/delivery/learning_objectives/page_element.ex`)
- Depends on (does not implement): `Oli.LearningModel.ModelVersion` and the
  `learning_model_version` field on `Oli.Authoring.Course.Project` /
  `Oli.Delivery.Sections.Section` (already implemented via `MER-5845`/the `data_model` work item).
- Depends on, does not block on: `MER-5846` (LKT-AOA learner model) for the eventual LKT-AOA
  caller of this function; `MER-5847` (Confidence) for any future coverage/confidence signal.
- Reference: `docs/exec-plans/current/epics/learning_model_v2/lkt_technical_notes.docx.md`
  section 6 is the authoritative source for the LKT-AOA-side weighting rule this function's
  contract is designed to also support.

## 10. Repository & Platform Considerations

- Backend-only change in Elixir (`lib/oli/delivery/`), per `docs/BACKEND.md` domain boundaries;
  no `assets/src` (React/TypeScript) changes are expected since no aggregation logic exists on the
  frontend today (all call sites consume already-aggregated backend data).
- Follows `docs/TESTING.md`: cover the new aggregation function with ExUnit unit tests, and cover
  the updated call sites with the existing test types already used for them (ExUnit for
  `Sections`/`Metrics`, `Phoenix.LiveViewTest` for the LiveView-driven surfaces where behavior
  changes are user-visible).
- `test/oli/delivery/sections_test.exs:3450-3498` currently asserts the pre-aggregation behavior
  for `get_objectives_and_subobjectives/2` and must be updated to reflect the new aggregated
  result rather than deleted or ignored.
- `setup_objectives_and_activities_test/0` (`test/oli/delivery/sections_test.exs:3711`) already
  builds a 2-level Sub-LO hierarchy with parent- and child-tagged activities and is the expected
  fixture base for new aggregation test coverage.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

## 12. Telemetry & Success Metrics

- No new telemetry events are introduced by this work item. Existing AppSignal/Phoenix telemetry
  around the updated LiveViews and controller action (`delivery_controller.ex`'s
  `download_learning_objectives/2`) continues to apply unchanged.
- Success signal: the Instructor Dashboard Learning Objectives tab, its CSV export, the per-student
  instructor view, and student-facing proficiency displays show a non-"not enough data" parent LO
  value whenever its Sub-LOs collectively have sufficient evidence, even when the parent itself has
  no directly-tagged activity.

## 13. Risks & Mitigations

- Risk: an activity tagged to both a parent LO and one of its Sub-LOs is double-counted (its
  evidence contributes once via the parent's own row and again via the Sub-LO's row), since the
  parent's own evidence and its Sub-LOs' evidence are always combined (Option B). Mitigation:
  **none — this is an accepted risk, not mitigated by this work item.** Darren Siegel confirmed on
  Slack (2026-09-01) that always combining is "the simplest thing that we can (and should) do,"
  explicitly choosing this over three alternatives that would avoid or reduce the double-counting
  (see `parent_evidence_aggregation_options.md`) because those alternatives either require
  materially more engineering effort (querying raw attempt data instead of the pre-aggregated
  `ResourceSummary` rows this work item's other call sites rely on) or their own worse trade-offs
  (silently discarding a parent's real evidence in other scenarios). How common double-tagging
  actually is in existing OLI/Torus courses remains unknown; if it turns out to be prevalent, this
  risk may need to be revisited in a follow-up work item.
- Risk: mismatching `count` semantics between the naive and a future LKT-AOA caller could silently
  skew the weighted average. Mitigation: the function's documentation states the contract
  explicitly and assigns responsibility to the caller; naive callers are updated in this work item
  to supply `num_first_attempts` consistently.
- Risk: unifying three call sites that currently behave differently (one already
  weighted-average-like, two with no aggregation at all) could change displayed values for
  existing sections in ways instructors notice. Mitigation: this is the intended, requested
  behavior change (per Darren Siegel's ticket comments); no additional mitigation beyond correct
  implementation and test coverage is in scope here.
- Risk: `Sections.get_objectives_and_subobjectives/2` is used for full-roster, per-section
  Instructor Dashboard reads; adding aggregation could reintroduce N+1 query behavior if
  implemented naively per-learner/per-objective. Mitigation: keep the aggregation set-based,
  consistent with the function's existing query shape (see Non-Functional Requirements).
- Risk: the exact API LKT-AOA (`MER-5846`) will use to supply its `count` value is not yet built,
  so this work item cannot add a real LKT-AOA caller yet. Mitigation: the shared function's
  contract is designed against the confirmed LKT-AOA technical specification (section 6.2) so that
  wiring in the eventual LKT-AOA caller is additive once `MER-5846` exists.

## 14. Open Questions & Assumptions

### Open Questions
- The exact data-access API `MER-5846` (LKT-AOA) will expose for a Sub-LO's total
  "opportunity"/attempt count is not yet defined, since that model has not been implemented. The
  aggregation rule itself (weighted by opportunities) is confirmed by the LKT-AOA technical notes
  section 6.2; only the concrete Elixir interface to read that count from the eventual
  `learning_state`-backed implementation remains open, and is `MER-5846`'s responsibility to
  expose, not this work item's to guess.
- Whether the shared aggregation function should also return enough information (e.g., per-child
  coverage) for a future coverage-gap indicator (LKT-AOA technical notes section 6.3), or whether
  that is added later when the indicator's UX is designed, is not yet decided. This work item
  assumes the minimal contract (aggregate score + total count) is sufficient for now, since the
  indicator's visual design is explicitly not ready.

### Assumptions
- The naive algorithm's per-child weight is `num_first_attempts`, matching that algorithm's own
  proficiency calculation, which already uses only first attempts.
- The LKT-AOA algorithm's per-child weight will be its total attempt ("opportunity") count, per
  the LKT-AOA technical notes section 6.2 (`Σ opportunities`), once `MER-5846` exists.
- Bucketing (mapping a weighted score to Not Enough Information / Low / Medium / High) stays
  owned by each algorithm's caller rather than being embedded in the shared aggregation function,
  because the two algorithms' minimum-evidence eligibility rules differ (naive: 3 first attempts
  on the pooled result; LKT-AOA per its technical notes: 3 attempts per Sub-LO). The naive caller
  continues to use the existing `Metrics.proficiency_range/2`.
- No database schema changes are required; this is a pure computation/query-composition change
  over existing data.

## 15. QA Plan

- Automated validation:
  - Run Harness requirements capture, requirements structure validation, and PRD validation.
  - New ExUnit unit tests for the shared aggregation function covering: multiple Sub-LOs with
    different evidence counts, a parent with both directly-tagged evidence and Sub-LOs, a Sub-LO
    with zero/insufficient evidence (coverage not silently dropped), and an activity tagged to
    both parent and Sub-LO (counted once).
  - Updated/added ExUnit coverage in `test/oli/delivery/sections_test.exs` for
    `get_objectives_and_subobjectives/2`, replacing the assertion at lines 3450-3498 that
    currently documents the un-aggregated behavior.
  - Updated/added coverage for `Metrics.aggregate_raw_proficiency/1` and
    `proficiency_for_student_per_learning_objective/3` if their signature or behavior changes
    during extraction to the shared function.
  - `Phoenix.LiveViewTest` coverage for `instructor_dashboard_live.ex`, `student_dashboard_live.ex`,
    `prologue_live.ex`, `lesson_live.ex`, and `review_live.ex` where the rendered proficiency value
    is user-visible and expected to change for fixtures with Sub-LOs.
  - Run the affected `mix test` targets and `mix format`; run the broader `mix test` suite as
    implementation risk warrants, per `docs/TESTING.md`.
- Manual validation:
  - Inspect the Instructor Dashboard Learning Objectives tab and its CSV export for a section with
    a parent LO that has Sub-LOs and no direct evidence, confirming a combined value now appears
    instead of "not enough data".
  - Inspect student prologue/lesson/review proficiency displays for the same fixture from the
    student's perspective.
  - Confirm a leaf LO (no Sub-LOs) is unaffected and shows the same value as before.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
