# UpGrade Data-Capture Parity - Product Requirements Document

## 1. Overview

Restore native A/B testing data capture to at least the post-processing analytics capability Torus `v0.33.0` provided through UpGrade. Researchers and learning engineers must be able to reconstruct a documented, export-ready enrollment-to-condition and timestamped correctness dataset while retaining native weighted-random assignment scopes and the full Thompson Sampling reward and policy-state model.

## 2. Background & Problem Statement

The native experiment runtime durably records assignments and exposures, and Thompson Sampling records accepted assessment rewards and policy updates. The analytics path does not yet guarantee that learner interactions and evaluated activity outcomes remain reliably attributable and joinable across assignment, condition, enrollment, intervention, section, publication, and immutable content provenance.

UpGrade historically treated each section enrollment as a pseudonymous experimental participant, recorded condition assignment and application, and emitted continuous correctness (`score / out_of`) for evaluated activities throughout experiment-enabled sections. Native evidence is richer but incomplete for reproducing that analysis: weighted-random experiments have no reward evidence, events can occur asynchronously after rendering, section-wide evaluated activities may lack stable experiment joins, and binary Thompson Sampling rewards do not replace continuous outcomes.

MER-5883 adds a required compatibility boundary. Weighted-random experiments may assign independently per intervention or reuse one canonical condition assignment per experiment, participating section, and enrollment. Data capture must preserve that assignment scope while retaining intervention-specific exposure and content provenance. Thompson Sampling remains intervention-scoped.

## 3. Goals & Non-Goals

### Goals

- Capture a durable, documented evidence chain from section enrollment through assignment, exposure, attributed interaction, and evaluated outcome.
- Preserve a separate complete Thompson Sampling chain from eligible finalized outcome through accepted reward, atomic posterior update, and policy-update evidence.
- Capture continuous correctness-compatible outcomes for both causally attributed experimental content and the section-wide activity stream historically logged through UpGrade.
- Make evidence semantics consistent across live xAPI emission, direct ingestion, Lambda ingestion, S3 replay, backfill, and ClickHouse projection.
- Preserve both weighted-random assignment scopes, intervention-specific exposures, historical compatibility, tenant boundaries, privacy constraints, and immutable content provenance.
- Prove that an UpGrade-compatible dataset can be reconstructed from supported analytics stores without private PostgreSQL knowledge or current mutable authoring content.

### Non-Goals

- Build a dataset download UI, export API, export job, or other user-facing export workflow. This work must nevertheless design and document the captured data for expected future export compatibility.
- Migrate historical UpGrade assignments or analytics data.
- Change condition selection, weighted-random allocation, assignment-scope defaults, section participation, Thompson Sampling reward eligibility, or posterior-update behavior.
- Guarantee recovery of xAPI statements lost before durable analytics persistence or introduce an experiment-specific transactional outbox.
- Provide arbitrary UpGrade metric-query language parity, statistical inference, significance testing, confidence intervals, or causal estimates.
- Rewrite historical published content or require republishing solely for attribution.

## 4. Users & Use Cases

- Researchers and learning engineers: reconstruct enrollment-to-condition mappings, continuous correctness histories, interactions, outcomes, rewards, and policy transitions with documented join keys.
- Authors: continue configuring weighted-random experiments with either supported assignment scope without data capture changing experimental behavior.
- Learners: generate correct experiment evidence as they render selected alternatives, interact with nested content, navigate, consume media, and complete activities without exposing direct identifiers.
- Operators and administrators: diagnose missing exposure, attribution, projection, ingestion, and allocation evidence through bounded operational signals and analytics queries.
- Engineers and analysts: replay or backfill durable events and obtain the same logical evidence as direct production ingestion without duplicates or mutable-content reconstruction.

## 5. UX / UI Requirements

No new learner-, author-, or researcher-facing UI is required. Existing experiment configuration and delivery behavior must remain unchanged. Field semantics and stable join keys must be documented for the future supported export surface, but that surface is out of scope.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Evidence creation, enrichment, ingestion, replay, backfill, and querying must be idempotent at their documented logical boundaries.
- Attribution must be derived from durable assignment and immutable publication/revision provenance; it must not depend on current mutable authoring content or transient page-render state.
- Queries, payloads, telemetry metadata, and projection work must remain bounded and avoid unscoped scans or unbounded policy/content data.
- Analytics evidence must preserve institution, project, section, enrollment, experiment, and authorization boundaries and must exclude learner names, email addresses, LMS identifiers, raw responses, and free-form content.
- Additive xAPI and ClickHouse changes must tolerate historical statements and rows, including evidence without `assignment_scope`.
- Assignment, exposure, outcome, reward, and policy-update timestamps must retain distinct, documented occurrence semantics; ingestion time is operational metadata only.
- The existing accepted asynchronous xAPI crash window remains unchanged and must be documented rather than presented as recoverable.

## 9. Data, Interfaces & Dependencies

- The canonical xAPI extension remains `context.extensions["http://oli.cmu.edu/extensions/experiment_attributions"]`, expanded with a generic interaction role and bounded assignment-backed attribution fields.
- Assignment evidence must carry experiment, assignment, condition, enrollment, section, algorithm, policy version, `assigned_at`, reuse state, and `assignment_scope`; assignment-level intervention identity is nullable for `section_enrollment` scope.
- Exposure, interaction, and causally attributed outcome evidence must join to the assignment while preserving the actual decision point, intervention, placement, selected alternative, publication, and content-revision provenance.
- Evaluated-outcome evidence must preserve activity/resource/page attempt identities, attempt number, raw score, `out_of`, evaluation time, idempotency identity, and selected-branch provenance where applicable.
- ClickHouse `raw_events` rows with `event_type = 'activity_attempt'` are the canonical analytical source for section-wide evaluated activities. They must preserve stable enrollment identity and the activity, attempt, score, denominator, and evaluation-time fields required for compatibility analysis.
- ClickHouse `experiment_attributions` is the causal attribution overlay and must join to `raw_events` through `raw_event_hash`. Absence of an attribution must not exclude an otherwise applicable activity-attempt row from the section-wide compatibility stream.
- Raw ClickHouse host-event rows and per-attribution rows must remain linked by `raw_event_hash`; direct upload, Lambda, replay, and backfill must project matching roles and values.
- Raw xAPI in S3 remains the durable replay source. PostgreSQL analytics summaries are application-oriented aggregates and are not the canonical future compatibility-export source.
- This work depends on the existing PostgreSQL experiment source of truth, publication/revision model, xAPI delivery pipeline, S3 durable event storage, ClickHouse analytics store, assignment-scope contract from MER-5883, native A/B testing foundation from MER-5795, and Lambda projection correction tracked by MER-5884.

## 10. Repository & Platform Considerations

- `Oli.Experiments` owns assignment, scope, exposure, reward, and attribution semantics; delivery code and analytics consumers must not independently reinterpret assignment identity.
- `lib/oli/analytics` and existing Python ETL/Lambda paths must share the same xAPI and ClickHouse projection contract.
- PostgreSQL remains the transactional source of truth for assignment and policy mutation; ClickHouse and xAPI are analytical evidence, not runtime decision sources.
- Learner-facing provenance must resolve against deployed publications and immutable revisions, respecting the resource/revision and multi-tenant section model.
- Schema work should remain additive and primarily analytics-focused; existing assignment-scope, assignment, intervention, condition, reward, and policy-state contracts remain intact.
- Implementation review must always apply security and performance guidance and additionally apply Elixir, UI, TypeScript, and requirements guidance only where the resulting changes touch those surfaces.
- Jira MER-5885 is the issue-tracking source for this work item; substantive scope changes require the repository Jira approval workflow.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

Roll out additive schema compatibility before or with producers of new fields. Historical xAPI and ClickHouse evidence without `assignment_scope` must be interpreted as intervention-scoped when a default is required. No historical content republishing, assignment migration, or UpGrade data migration is required. Backfill operates only on durable source events and must not create duplicate logical attribution rows.

## 12. Telemetry & Success Metrics

- Make assignment without exposure, exposure without attributed interactions or outcomes, expected-but-missing outcome attribution, accepted rewards without projected evidence, ingestion failures, ingestion lag, direct/Lambda/backfill disagreement, and assignment imbalance queryable or operationally diagnosable.
- Keep telemetry dimensions bounded and avoid learner PII, raw responses, free-form content, and unbounded policy state.
- Success means a representative repository-owned query or fixture reconstructs the historical enrollment/condition/timestamp/correctness shape from supported analytics data while retaining native assignment-scope, exposure, reward, and policy evidence.
- Success also requires direct, Lambda, replay, and backfill paths to project matching logical values without duplicates for durable source statements.

## 13. Risks & Mitigations

- Risk: Section-and-enrollment assignments have no owning intervention and may be treated as incomplete. Mitigation: carry `assignment_scope`, allow nullable assignment-level intervention identity, and retain actual intervention identity on every exposure and applicable interaction/outcome.
- Risk: Page-level assignment state could over-attribute unrelated content. Mitigation: require demonstrated containment in the learner's selected branch and durable placement/revision provenance; never infer attribution merely from another assignment on the page or in the section.
- Risk: Asynchronous events lose transient rendering context. Mitigation: persist or deterministically reconstruct attribution from assignment and immutable content provenance.
- Risk: Continuous outcomes are conflated with Thompson Sampling rewards. Mitigation: preserve independent identities, schemas, timestamps, and semantics even when one evaluation creates both evidence types.
- Risk: Section-wide compatibility outcomes are misrepresented as causal. Mitigation: keep the compatibility stream joinable but analytically distinct from decision-point-attributed outcomes.
- Risk: Ingestion and replay create duplicates or divergent projections. Mitigation: use stable idempotency keys/hashes and contract tests covering direct, Lambda, S3 replay, and backfill.
- Risk: Expanded evidence exposes learner or content data. Mitigation: use enrollment as the pseudonymous analysis key, enforce tenant scope, and prohibit direct identifiers, raw responses, and free-form content.
- Risk: The existing asynchronous crash window causes irrecoverable gaps. Mitigation: make the limitation explicit and provide diagnostics; stronger delivery guarantees remain out of scope.

## 14. Open Questions & Assumptions

### Open Questions

None.

### Assumptions

- Enrollment remains the pseudonymous analysis unit, so one user enrolled in two sections represents two experimental participants.
- Although implementing an export is out of scope, the captured data and documented query semantics must support a future compatibility export. Its per-assignment analysis window is half-open: `assigned_at <= observed_at < analysis_end`.
  - "Half-open" means the start boundary is included and the end boundary is excluded, preventing an event exactly on a shared boundary from being counted in two adjacent windows.
  - `assigned_at` is the original durable assignment time; `observed_at` is the activity evaluation time; and `analysis_end` is the earliest of experiment completion, experiment archival, or a requested exclusive export end. When none exists, the export execution cutoff is the exclusive end. Pausing does not split or terminate the window. Exposure is not an inclusion gate for the section-wide compatibility stream, but remains separate evidence for causal decision-point analysis.
- ClickHouse `raw_events` activity-attempt rows are the canonical analytical source for the section-wide compatibility stream. `experiment_attributions`, joined by `raw_event_hash`, supplies causal experiment attribution without gating inclusion in that stream. S3 xAPI is the durable replay source; PostgreSQL summaries are not the canonical future export source.
- New weighted-random experiments default to `section_enrollment`, explicitly configured `intervention` scope remains supported, existing experiments and historical evidence remain intervention-scoped, and Thompson Sampling requires intervention scope.
- Continuous historical correctness is `score / out_of`, with `0.0` used when score or denominator is zero or division fails; missing-value behavior will be documented consistently before implementation is considered complete.
- Successfully persisted xAPI statements in durable storage are replayable; statements lost in the accepted pre-persistence crash window are not recoverable by this work.
- Canonical `experiment_controlled` and compatible historical `upgrade_decision_point` Alternatives groups provide sufficient immutable provenance for equivalent attribution behavior.

## 15. QA Plan

- Automated validation:
  - Add focused ExUnit coverage for assignment-backed attribution, branch containment, multiple decision points, asynchronous reconstruction, timing, continuous outcome normalization, reward/outcome separation, and idempotency.
  - Add xAPI schema and ClickHouse contract tests for nullable/additive fields, both weighted-random assignment scopes, historical defaults, raw-event joins, and matching direct/Lambda/replay/backfill projection.
  - Add `Oli.Scenarios` integration coverage for real authoring, publication, participating sections, multiple enrollments, repeated page views, multiple decision points, in-branch and out-of-branch events, multiple evaluated activities, weighted random, and Thompson Sampling.
  - Add a repository-owned query or fixture that reconstructs enrollment, condition, timestamp, and correctness without private PostgreSQL schemas or mutable authoring content.
- Manual validation:
  - Inspect representative raw xAPI and ClickHouse rows for assignment, exposure, interaction, outcome, reward, and policy-update semantics across both weighted-random scopes and Thompson Sampling.
  - Compare direct ingestion, Lambda ingestion, and backfill results and exercise operational diagnostics for missing evidence and ingestion lag.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
