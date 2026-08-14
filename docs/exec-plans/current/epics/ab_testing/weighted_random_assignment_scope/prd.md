# Weighted Random Assignment Scope - Product Requirements Document

## 1. Overview

Allow an author to choose whether a weighted-random experiment assigns each participating learner independently at every intervention or assigns that learner once for the entire experiment within a section. In the section-and-enrollment mode, the first eligible encounter creates one durable condition assignment that every intervention in the same experiment reuses while the experiment is active.

## 2. Background & Problem Statement

The current experiment runtime makes each placed Alternatives instance a separate intervention and sticky assignment opportunity. That behavior supports intervention-specific randomization, but it cannot represent an experiment where a learner must remain in one condition across all intervention placements throughout a course section. Authors need both designs for weighted-random experiments without changing Thompson Sampling's intervention-scoped assignment and reward semantics.

This work introduces an explicit assignment-scope configuration and a canonical experiment-level assignment identity for participating section enrollments. Assignment remains distinct from exposure: one durable experiment assignment may be observed at many interventions, and every rendered intervention must retain its own exposure evidence.

## 3. Goals & Non-Goals

### Goals

- Let authorized authors select intervention-scoped or section-and-enrollment-scoped assignment for weighted-random experiments.
- Persist exactly one durable condition assignment per experiment and participating section enrollment when section-and-enrollment scope is enabled.
- Reuse that condition at every intervention belonging to the experiment while preserving intervention-specific exposure evidence.
- Preserve current intervention-scoped behavior as the default and preserve Thompson Sampling's intervention-scoped assignment model.
- Make first assignment, reuse, batching, and concurrent delivery safe and bounded.
- Keep analytics and operational evidence explicit about assignment scope and the difference between assignments and exposures.

### Non-Goals

- Enable section-and-enrollment assignment for Thompson Sampling.
- Coordinate assignments across different experiments, sections, or enrollments.
- Reassign learners when weights, content, publication snapshots, or intervention placement change.
- Guarantee that observed allocation exactly matches configured weights.
- Introduce user-wide, institution-wide, project-wide, or cross-section assignment identity.
- Change section participation eligibility or experiment-controlled Alternatives mapping semantics.
- Migrate or consolidate existing intervention-scoped assignment rows into experiment-level assignments.

## 4. Users & Use Cases

- Authors and learning engineers: choose whether a weighted-random experiment randomizes independently at each intervention or keeps each learner in one condition throughout a participating course section.
- Learners: revisit content and encounter later experiment interventions without unexpected condition changes when the experiment uses section-and-enrollment scope.
- Researchers: distinguish canonical experiment participants from intervention exposures when interpreting allocation and outcome evidence.
- Operators and administrators: diagnose assignment creation, reuse, conflicts, fallbacks, and evidence for either assignment scope without inspecting private persistence directly.

## 5. UX / UI Requirements

- The weighted-random experiment configuration must offer two assignment-scope choices with plain-language labels and explanatory help:
  - assign independently at each intervention;
  - keep the same condition throughout the participating course section.
- Intervention scope must remain the default for new weighted-random experiments.
- The scope control must be absent or non-editable for Thompson Sampling, whose assignment remains intervention-scoped.
- Experiment details must display the saved assignment scope using language that does not imply cross-section or cross-enrollment stickiness.
- The UI must explain that section-and-enrollment scope coordinates all interventions in the same experiment and that intervention exposures are still recorded separately.
- Scope validation and lifecycle errors must be shown next to the relevant configuration control and remain accessible through established LiveView form patterns.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Assignment lookup, creation, conflict resolution, and batch rendering must remain bounded PostgreSQL operations that do not scan assignment, exposure, reward, xAPI, or ClickHouse history.
- Database uniqueness and domain transactions must converge concurrent first encounters on one canonical assignment for the configured scope.
- All reads and writes must preserve institution, project, experiment, participating-section, enrollment, and author or delivery authorization boundaries.
- Telemetry and analytics evidence must avoid raw learner responses and unnecessary learner identity.
- The authoring selector and its validation states must meet established keyboard and accessibility expectations.

## 9. Data, Interfaces & Dependencies

- Experiment configuration gains a typed assignment scope with `intervention` and `section_enrollment` values. The latter is valid only for weighted random.
- For intervention scope, assignment identity remains experiment, intervention, and enrollment within the delivered section.
- For section-and-enrollment scope, assignment identity is experiment, section, and enrollment; the canonical assignment is not owned by any single intervention.
- Assignment persistence must support both identities with database-enforced uniqueness. An experiment-level assignment may omit intervention identity, while exposure evidence must always retain the intervention actually rendered.
- Weighted-random deterministic input must match the configured durable identity so retries and concurrency resolution cannot select a competing condition.
- Public experiment configuration and details DTOs must carry assignment scope. Delivery request callers continue to provide intervention identity because it is needed for applicability, rendering, and exposure even when assignment scope is broader.
- Analytics and xAPI attribution contracts must carry assignment scope and tolerate assignment evidence without an intervention ID while preserving intervention ID on exposure evidence.
- This work depends on experiment section participation, experiment-controlled Alternatives mappings, lazy weighted-random intervention materialization, and the existing assignment and exposure context APIs.

## 10. Repository & Platform Considerations

- `Oli.Experiments` owns assignment-scope validation, identity derivation, persistence, assignment reuse, and evidence contracts; LiveViews and delivery strategies must not reproduce these rules.
- PostgreSQL remains the transactional source of truth for sticky assignment. ClickHouse and xAPI remain evidence and analytics paths, not runtime assignment sources.
- Schema changes must use a conventionally generated Ecto migration with explicit `up/0` and `down/0`, partial uniqueness constraints where needed, and verified forward and rollback behavior.
- Existing publication and revision immutability must be preserved; the scope changes runtime assignment state rather than authored page content.
- Implementation review must always apply security and performance guidance and additionally apply Elixir, UI, and requirements guidance to the affected surfaces.
- Jira is the issue-tracking system of record, but Jira creation or updates require a separate reviewed proposal and explicit user approval.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

Existing experiments default to intervention scope and retain their current assignments unchanged. New and draft weighted-random experiments may select section-and-enrollment scope subject to lifecycle rules. No backfill or consolidation of existing intervention-scoped assignments is performed. Rollback must preserve dependency-safe schema behavior but is not required to transform experiment-level assignments into equivalent intervention-level history.

## 12. Telemetry & Success Metrics

- Emit bounded assignment-scope metadata for assignment creation, reuse, uniqueness-conflict resolution, fallback, and invalid-configuration events.
- Record assignment scope in assignment evidence and preserve encountered intervention identity in exposure evidence.
- Success means a participating enrollment in section-and-enrollment mode has exactly one durable experiment assignment, observes that condition at every eligible intervention, and produces distinct exposure evidence for each rendered intervention.
- Monitor duplicate-assignment conflicts, assignment-scope validation failures, missing canonical assignments, exposure attribution failures, and assignment latency in AppSignal.

## 13. Risks & Mitigations

- Risk: Persisting one row per intervention with a shared random seed can diverge after weight changes. Mitigation: persist one canonical experiment-level assignment for section-and-enrollment scope.
- Risk: Analytics may treat a missing assignment intervention ID as missing attribution. Mitigation: make assignment scope explicit and use exposure evidence for intervention-level traffic.
- Risk: Concurrent first encounters at different interventions may create competing assignments. Mitigation: enforce experiment-section-enrollment uniqueness and reload the winning row after conflicts.
- Risk: A scope change could invalidate existing sticky behavior. Mitigation: prevent assignment-scope changes after activation or assignment creation and retain intervention scope for existing experiments.
- Risk: Thompson Sampling rewards could be incorrectly attached to an experiment-level assignment. Mitigation: reject section-and-enrollment scope for Thompson Sampling at request, persistence, and activation boundaries.
- Risk: Section identity could be inferred only indirectly from enrollment and become unclear in evidence. Mitigation: include section explicitly in the durable identity, constraints, and attribution metadata.

## 14. Open Questions & Assumptions

### Open Questions

- None. The product decision is that section-and-enrollment scope creates one durable assignment for the entire weighted-random experiment within a participating section.

### Assumptions

- An enrollment belongs to exactly one section, but section remains explicit in assignment identity and evidence for auditability and tenant-safe queries.
- Condition identities and option mappings are experiment-wide, so one canonical assigned condition can be rendered at every valid intervention in the experiment.
- Assignment scope is immutable once the experiment is active or any assignment exists; later architecture work may choose the stricter draft-only edit boundary.
- Pausing, completing, or archiving an experiment does not delete or alter existing assignments.
- Section participation continues to determine whether an experiment is applicable before either new assignment or sticky reuse occurs.

## 15. QA Plan

- Automated validation:
  - ExUnit coverage for configuration validation, persistence constraints, both assignment identities, sticky reuse, cross-intervention reuse, different-enrollment and different-section isolation, concurrency, batching, lifecycle immutability, fallback, and Thompson Sampling rejection.
  - LiveView tests for selector visibility, defaults, saved values, details display, accessibility-relevant markup, and validation errors.
  - xAPI and ClickHouse contract tests proving assignment-scope attribution and intervention-specific exposure evidence.
  - Oli.Scenarios coverage for authoring, publishing, participating-section delivery, two interventions, multiple learners, and both weighted-random scopes.
- Manual validation:
  - Configure each weighted-random scope, publish or deliver through a participating section, visit and revisit multiple interventions as the same learner, and verify rendered conditions, canonical assignment counts, distinct exposures, fallback outside participation, and details-page copy.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes

