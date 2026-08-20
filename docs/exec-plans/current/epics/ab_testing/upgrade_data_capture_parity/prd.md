# UpGrade Data-Capture Parity - Product Requirements Document

## 1. Overview

Restore two missing analytics capabilities for native experiments:

1. Existing non-`page_viewed` xAPI producers carry experiment attribution when a persisted
   assignment and selected Alternatives branch establish the relationship.
2. Analytics preserve the section-wide evaluated-activity dataset previously sent to UpGrade in
   Torus v0.33.0: enrollment, assigned condition, evaluation timestamp, score, denominator, and
   derivable correctness.

These capabilities are independent. An evaluated activity must remain in the section-wide stream
even when it has no causal experiment attribution.

## 2. Historical Behavior And Problem

In v0.33.0, `Oli.Delivery.Experiments.LogWorker` logged every evaluated activity attempt in an
experiment-enabled section. It used the section enrollment as the participant identifier and sent
continuous correctness derived from `score / out_of`. Native experiments already emit assignment
and exposure evidence on page views, but attribution on other existing xAPI statements is
incomplete and the ClickHouse activity stream does not yet guarantee every field needed to
reconstruct the former dataset.

## 3. Goals

- Attach assignment-backed attribution to the concrete non-page producers already present in the
  application: evaluated part/activity/page attempts and video/media events.
- Use persisted realized page-attempt content for delayed attempt events and the server-resolved
  deployed page revision for resource-only media events.
- Preserve every applicable evaluated activity in the raw analytics stream, regardless of branch
  membership or whether attribution succeeds.
- Reconstruct enrollment, condition, evaluation timestamp, score, denominator, and correctness
  from supported analytics data.
- Keep direct upload, Lambda ingestion, and replay/backfill consistent for the fields required by
  these two goals.
- Preserve existing Thompson Sampling outcome, reward, policy-update, idempotency, and concurrency
  behavior.

## 4. Non-Goals

- A universal attribution resolver or generic event-provenance framework.
- Navigation or nested-content attribution without a concrete existing xAPI producer.
- New interaction-role taxonomy beyond roles required by current producers.
- A user-facing export UI, API, or job.
- Historical UpGrade data migration, content republishing, or assignment migration.
- Statistical analysis, causal inference, or arbitrary UpGrade query-language parity.
- Stronger xAPI delivery guarantees or correction of the existing asynchronous publication lookup;
  exact attempt-time publication remains tracked separately by MER-5889.
- A broad operational diagnostics suite beyond existing pipeline signals and focused failure logs.

## 5. Functional Requirements

Requirements and acceptance criteria are maintained in `requirements.yml`.

## 6. Product And Data Semantics

- Section enrollment is the pseudonymous participant identity. The same user in two sections is
  represented by two distinct participants.
- `raw_events` activity-attempt rows are the complete section-wide outcome stream.
- `experiment_attributions` is an optional causal overlay. Its absence never excludes a raw
  activity-attempt row.
- A non-page host statement receives attribution only when the scoped assignment agrees with the
  selected branch preserved in realized content.
- `score` and `out_of` are stored without compatibility normalization. The compatibility query
  computes correctness and applies the documented v0.33.0 zero/error fallback.
- Condition is obtained from durable assignment/exposure evidence keyed by section and enrollment;
  it is not inferred from current mutable authoring content.
- Existing assignment-scope semantics remain unchanged: weighted random supports intervention and
  section-enrollment scopes; Thompson Sampling remains intervention-scoped.

## 7. Non-Functional Requirements

- Host-event emission must not fail or be suppressed because attribution cannot be resolved.
- Attribution queries must be scoped by project, section, user, and enrollment and must use
  server-resolved attempt or deployed-revision data.
- New payloads and projections must exclude names, emails, LMS identifiers, raw responses, and
  free-form content.
- Schema and projection changes must be additive and tolerate historical missing fields.
- Work on non-page attribution must not add queries to unrelated activity statements when the
  realized page contains no experiment-controlled Alternatives placement.

## 8. Verification Strategy

- Producer tests prove attributed and unattributed behavior for attempt and media statements.
- Regression tests prove Thompson outcome/reward/policy evidence remains unchanged.
- Projection tests prove all ingestion paths preserve the required raw activity and attribution
  fields.
- A repository-owned compatibility query or fixture reconstructs the v0.33.0 tuple:
  `enrollment_id`, `condition`, `timestamp`, and `correctness`.
- End-to-end coverage includes multiple enrollments, in-branch and out-of-branch activities, both
  weighted-random scopes, and Thompson Sampling.

## 9. Definition Of Done

- Both focused producer attribution and section-wide outcome parity pass independently.
- The compatibility dataset does not require mutable authoring content or direct learner identity.
- Existing experiment runtime behavior and ordinary xAPI host statements remain intact.

## Decision Log

### 2026-08-19 - Separate Attribution From UpGrade Outcome Parity
- Change: Reduced the feature to focused non-page producer attribution plus an unconditional
  section-wide evaluated-activity stream.
- Reason: v0.33.0 parity did not require universal branch-level causal provenance, and the earlier
  design coupled raw outcome capture to a speculative generic resolver.
- Evidence: `v0.33.0:lib/oli/delivery/experiments/log_worker.ex` and the rollback to commit
  `aab6c72c5f9e459b436917525335327bafcb38ef`.
- Impact: Navigation/nested speculative work, universal provenance, broad diagnostics, and expanded
  role taxonomy are removed from scope.
