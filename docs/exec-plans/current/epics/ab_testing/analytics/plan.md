# Outcome Analytics And Research Visibility - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/ab_testing/analytics/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/analytics/fdd.md`
- Requirements: `docs/exec-plans/current/epics/ab_testing/analytics/requirements.yml`

## Scope
Deliver MVP analytics and monitoring for native A/B testing through approved `Oli.Experiments` read APIs. The plan covers scoped aggregate reads for assignments, exposures, outcomes, rewards, timestamp and scope semantics, data-quality monitoring, Thompson Sampling policy-state visibility, telemetry, privacy controls, targeted UI or export wiring, and verification.

Guardrails:
- Do not query private `Oli.Experiments.Schemas` modules from LiveViews, controllers, exports, `Oli.Analytics`, or delivery code.
- Do not import or display legacy UpGrade analytics as native experiment evidence.
- Do not put analytics reads on learner delivery hot paths.
- Do not build UpGrade metric-query-language parity or a broad warehouse product in this slice.
- Do not add a feature flag by default; `harness.yml` defaults feature flags to excluded and the PRD states no feature flags are present.
- Keep learner-level detail disabled by default and omit learner names, emails, LMS IDs, raw responses, and full activity payloads from analytics responses.

## Clarifications & Default Assumptions
- Default MVP data source is PostgreSQL-backed native `experiment_*` records through `Oli.Experiments`; ClickHouse projection is deferred until direct aggregate query pressure proves the need.
- Default MVP reporting surface is backend read APIs plus the minimum product-selected LiveView/export surface. If product has not selected a surface, implement backend APIs first and leave UI/export behind a small follow-up.
- Default data-quality grace periods should be constants or options in the analytics query layer until product approves configurable thresholds.
- Assignment imbalance defaults should be conservative and documented in code/tests; final product thresholds can be adjusted without changing response shape.
- Telemetry, code review, and issue tracking are planned explicitly because `harness.yml` includes them by default.
- Performance requirements are handled through query shape, index review, and phase gates rather than a separate formal performance budget document.

## Phase 1: Analytics Query Contract And Scope Foundation
- Goal: Establish the additive analytics query contract and shared scoped query helpers for FR-001, FR-002, FR-003, AC-001, AC-002, and AC-003.
- Tasks:
  - [ ] Extend `Oli.Experiments.AnalyticsQuery` additively with optional date window, grouping, data-quality, and detail flags needed by the FDD.
  - [ ] Extract analytics query construction into `Oli.Experiments` private helpers or an internal `Oli.Experiments.Analytics` module if it reduces `lib/oli/experiments.ex` complexity.
  - [ ] Preserve existing public APIs: `experiment_summary/1`, `assignment_counts/1`, `exposure_counts/1`, `reward_counts/1`, and `policy_state_snapshot/1`.
  - [ ] Add shared scope validation for project, institution, publication, section, user, and enrollment filters before aggregate reads.
  - [ ] Add event timestamp filtering semantics for assignment `assigned_at`, exposure `exposed_at`, outcome `observed_at`, reward `processed_at`, and policy update `inserted_at`.
  - [ ] Keep all private schema access inside `Oli.Experiments`.
- Testing Tasks:
  - [ ] Expand `test/oli/experiments/analytics_test.exs` for additive query fields and date-window filtering by event type.
  - [ ] Add tests proving out-of-scope experiment, section, publication, user, and enrollment queries reject without leaking evidence.
  - [ ] Add or update private-schema leakage tests if existing persistence tests do not cover analytics callers.
  - Command(s): `mix test test/oli/experiments/analytics_test.exs test/oli/experiments/persistence_test.exs`
- Definition of Done:
  - Analytics query options are additive and existing callers continue to pass.
  - Scope and timestamp semantics from the FDD are represented in tested query helpers.
  - Non-domain code still cannot depend on private experiment schemas.
- Gate:
  - Phase 1 is complete only when scoped analytics and schema-boundary tests pass.
- Dependencies:
  - Existing native `Oli.Experiments` context and analytics placeholder APIs.
- Parallelizable Work:
  - Phase 3 response-shape design can be drafted in parallel, but implementation should wait for the final query contract.

## Phase 2: Aggregate Assignment, Exposure, Outcome, And Reward Reads
- Goal: Complete release-ready aggregate reporting for FR-001, FR-002, AC-001, and AC-002.
- Tasks:
  - [ ] Harden `assignment_counts/1` and `exposure_counts/1` to return experiment, decision point, condition ID/code, count, and optional time bucket where requested.
  - [ ] Add `outcome_counts/1` grouped by experiment, decision point, condition, activity resource, and optional time bucket.
  - [ ] Harden or extend `reward_counts/1` to distinguish reward count, success/failure totals, reward source, and optional time bucket.
  - [ ] Update `experiment_summary/1` to include outcomes and clear event category totals.
  - [ ] Keep aggregate responses as public maps or structs, not Ecto schemas.
  - [ ] Review query plans and add migrations for narrowly justified indexes only if existing indexes do not support scoped aggregate reads.
- Testing Tasks:
  - [ ] Add controlled data setup for multiple conditions, assignments, exposures, outcomes, rewards, and attempts.
  - [ ] Test assignment/exposure/outcome/reward aggregate grouping by experiment, decision point, and condition.
  - [ ] Test reward success/failure and reward source aggregation.
  - [ ] If indexes are added, add migration tests or schema assertions for key constraints/indexes where local patterns support them.
  - Command(s): `mix test test/oli/experiments/analytics_test.exs test/oli/experiments/runtime_test.exs`
- Definition of Done:
  - Release reviewers can inspect assignments, exposures, outcomes, and rewards through context-owned aggregate APIs.
  - Aggregates preserve scope and avoid learner-identifying fields by default.
  - Any new index is justified by the aggregate query shape and covered by review.
- Gate:
  - Phase 2 is complete only when aggregate tests pass and query/index review has no unresolved blocker.
- Dependencies:
  - Phase 1 query contract and scope helpers.
- Parallelizable Work:
  - Test data builders and fixture helpers can be prepared while query functions are implemented.

## Phase 3: Data-Quality And Thompson Sampling Monitoring
- Goal: Add monitoring summaries for FR-004, FR-005, AC-004, and AC-005.
- Tasks:
  - [ ] Implement `exposure_quality_summary/1` for assignments without exposure, exposure lag, and exposure-to-assignment ratios.
  - [ ] Implement `reward_quality_summary/1` for outcomes without rewards, delayed rewards, absent policy updates, and policy update failure evidence where available.
  - [ ] Implement `assignment_balance/1` for condition shares, expected share when known, absolute/relative imbalance, and threshold status.
  - [ ] Implement `thompson_sampling_summary/1` with algorithm version, prior config, posterior state, reward counts, assignment count/share, last update provenance, and guardrail status.
  - [ ] Define grace-period and imbalance defaults in one place with names that make product tuning straightforward.
  - [ ] Ensure warning states are reported, not acted on; analytics must not pause or mutate experiments directly.
- Testing Tasks:
  - [ ] Add tests for missing exposure, missing outcome, missing reward, delayed reward, and absent policy update summaries.
  - [ ] Add tests for balanced and imbalanced assignment distributions across conditions.
  - [ ] Add Thompson Sampling summary tests for posterior alpha/beta or success/failure values, reward counts, assignment share, last update provenance, and guardrail status.
  - Command(s): `mix test test/oli/experiments/analytics_test.exs`
- Definition of Done:
  - Operators and researchers can see data-quality warnings and Thompson Sampling state without private database inspection.
  - Data-quality calculations are read-only and tested against explicit timestamp semantics.
  - Threshold defaults are documented in code/tests and surfaced in response metadata where useful.
- Gate:
  - Phase 3 is complete only when all data-quality and Thompson Sampling summary tests pass.
- Dependencies:
  - Phase 2 aggregate reads and existing Thompson Sampling policy-state persistence.
- Parallelizable Work:
  - Telemetry event names and metadata tests from Phase 4 can be developed alongside this phase.

## Phase 4: Telemetry, Privacy, And Performance Hardening
- Goal: Make analytics reads observable and reviewable for latency, failures, privacy, and performance.
- Tasks:
  - [ ] Wrap public analytics reads with telemetry events for start, stop, exception, data-quality summary, and export if export is implemented.
  - [ ] Normalize telemetry metadata to non-sensitive IDs and tags: experiment_id, project_id, section_id, publication_id, algorithm, lifecycle state, query name, result count, data-quality status, and error type.
  - [ ] Add bounded logging only where analytics failures require operational diagnosis.
  - [ ] Add privacy assertions or response normalizers so aggregate APIs do not include learner names, emails, LMS IDs, raw responses, or activity payloads.
  - [ ] Inspect aggregate query plans for expected high-volume section and experiment shapes.
  - [ ] Prepare AppSignal/telemetry notes for PR review and Jira execution tracking.
- Testing Tasks:
  - [ ] Add telemetry handler tests for analytics query success, failure, and data-quality event metadata.
  - [ ] Add privacy tests for aggregate and optional detail responses.
  - [ ] Add performance-oriented query review notes or targeted tests for bounded aggregate paths.
  - Command(s): `mix test test/oli/experiments/analytics_test.exs`
- Definition of Done:
  - Analytics reads emit useful PII-safe telemetry and are ready for AppSignal observation.
  - Privacy and schema-boundary tests cover the default aggregate responses.
  - Performance review has no unresolved query-shape or indexing blocker.
- Gate:
  - Phase 4 is complete only when telemetry/privacy tests pass and performance review notes are complete.
- Dependencies:
  - Phases 1 through 3.
- Parallelizable Work:
  - UI/export work can consume stable public response shapes while telemetry tests are finalized.

## Phase 5: Product Surface Or Export Integration
- Goal: Expose the approved MVP read surface for researchers, authors, instructors, or operators while preserving the context boundary.
- Tasks:
  - [ ] Confirm the selected MVP surface before implementation: author/research LiveView, admin/operator monitoring view, CSV export, or a limited combination.
  - [ ] Implement the selected surface as a caller of public `Oli.Experiments` analytics APIs only.
  - [ ] Show assignments, exposures, outcomes, rewards, data-quality warnings, and Thompson Sampling state as distinct categories.
  - [ ] Enforce existing authorization and scope rules at the LiveView/controller boundary before building `AnalyticsQuery`.
  - [ ] Keep default display aggregate-only; include detail rows only if explicitly approved and authorized.
  - [ ] Add empty, no-access, loading, and error states appropriate to the selected surface.
  - [ ] If CSV export is selected, stream or page large exports and include generated timestamp, scope, and filters.
- Testing Tasks:
  - [ ] Add LiveView/controller tests for authorization, scoped rendering, category distinction, warnings, empty state, and error state if a UI surface is built.
  - [ ] Add CSV/export tests for content minimization, scope metadata, and large-result handling if export is built.
  - [ ] Re-run analytics context tests to verify UI/export work did not bypass public APIs.
  - Command(s): `mix test test/oli/experiments/analytics_test.exs`
  - Command(s): `mix test <targeted LiveView or controller export test file>`
- Definition of Done:
  - The product-selected read surface exposes MVP analytics without private schema coupling.
  - Instructor-facing or author-facing views avoid unnecessary learner data.
  - Export/UI states are covered by targeted tests.
- Gate:
  - Phase 5 is complete only when product-selected surface tests pass and privacy review has no unresolved issue.
- Dependencies:
  - Stable public analytics APIs from Phases 1 through 4.
- Parallelizable Work:
  - UI markup and route/controller wiring can be developed in parallel with export serialization if both surfaces are approved.

## Phase 6: Workflow Coverage And Release Readiness
- Goal: Prove the analytics slice supports native release review and is ready for implementation review.
- Tasks:
  - [ ] Add or update workflow-level coverage using `Oli.Scenarios` if the selected implementation spans authoring, publishing, section delivery, learner exposure, evaluated attempt, reward handoff, and analytics verification.
  - [ ] Use the repo-local `build_scenario` skill for scenario authoring if scenario coverage is added.
  - [ ] Cover at least one non-adaptive native experiment and one Thompson Sampling experiment when scenario DSL support can express both.
  - [ ] Run targeted analytics, runtime, reward handoff, and selected UI/export tests.
  - [ ] Run `mix format`.
  - [ ] Perform security review focused on authorization, cross-scope reads, learner data exposure, telemetry metadata, and export content.
  - [ ] Perform performance review focused on aggregate query plans, index use, streaming/paging, and absence from delivery hot paths.
  - [ ] Record unresolved product decisions in the PR or execution record: selected surface, imbalance threshold, grace periods, learner-level export scope, and ClickHouse projection timing.
- Testing Tasks:
  - [ ] Validate scenario files with `Oli.Scenarios.validate_file/1` while authoring.
  - [ ] Run the targeted scenario ExUnit module or scenario runner if scenario coverage is added.
  - [ ] Run all targeted tests from previous phases.
  - [ ] Run harness validation after implementation docs are updated.
  - Command(s): `mix test test/oli/experiments/analytics_test.exs test/oli/experiments/runtime_test.exs test/oli/delivery/experiments/reward_handoff_test.exs`
  - Command(s): `mix test <targeted LiveView, controller, export, or scenario test file>`
  - Command(s): `mix format`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/analytics --action verify_plan`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/ab_testing/analytics --check plan`
- Definition of Done:
  - FR-001 through FR-005 and AC-001 through AC-005 have implementation proof through targeted tests and, where appropriate, workflow coverage.
  - Security, privacy, telemetry, performance, and issue-tracking expectations are documented for review.
  - Harness validation passes.
- Gate:
  - Phase 6 is complete only when targeted tests, formatting, scenario validation/execution if applicable, security review, performance review, and harness validation pass.
- Dependencies:
  - Phases 1 through 5.
- Parallelizable Work:
  - PR evidence, Jira notes, and review notes can be assembled while final test runs execute.

## Parallelization Notes
- Phase 1 query-contract work and Phase 3 response-shape planning can proceed together, but data-quality implementation should wait for shared timestamp and scope helpers.
- Phase 2 aggregate tests can be prepared while Phase 1 helpers are implemented.
- Phase 3 data-quality calculations and Phase 4 telemetry/privacy tests can run in parallel once public response names are stable.
- Phase 5 UI and export work can split by surface after product confirms the MVP surface.
- Phase 6 scenario coverage can start after Phases 2 and 3 provide stable backend evidence; final assertions depend on the selected Phase 5 surface only if the scenario verifies UI/export behavior.
- Security and performance checks should be updated throughout Phases 2 through 6 rather than saved for the final gate.

## Phase Gate Summary
- Gate A: Analytics query contract is additive, scoped, timestamp-aware, and private-schema-safe.
- Gate B: Assignment, exposure, outcome, and reward aggregate APIs satisfy AC-001 and AC-002.
- Gate C: Data-quality and Thompson Sampling summaries satisfy AC-004 and AC-005.
- Gate D: Analytics telemetry, privacy assertions, and performance review pass.
- Gate E: Product-selected UI/export surface uses only public analytics APIs and passes targeted tests.
- Gate F: Workflow coverage where applicable, targeted tests, `mix format`, security review, performance review, issue-tracking notes, and harness validation all pass.
