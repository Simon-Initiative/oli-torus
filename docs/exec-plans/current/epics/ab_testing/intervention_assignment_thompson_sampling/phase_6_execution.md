# Phase 6 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling`
Phase: `6 - Complete Authoring Surfaces, Policy Reporting, and Content Contract`

## Scope from plan.md

- Deliver strategy-isolated Alternatives Group management on the retained Alternatives and Experiments routes.
- Complete draft multi-decision-point configuration and lifecycle-aware reporting.
- Add bounded Thompson Sampling policy snapshots and the final Alternatives placement schema contract.

## Implementation Blocks

- [x] Core behavior changes: shared strategy-specific group cards, canonical insertion filtering, bounded policy reporting, and schema tightening.
- [x] Creation/configuration UX follow-up: creation collects only assignment policy, name, slug, and initial decision point; server defaults seed weights and adaptive policy values, which remain editable as structured draft fields on details and become read-only after draft. The redundant raw policy JSON display was removed.
- [x] Policy persistence follow-up: supported decision-point policy settings now use constrained typed columns initialized to product defaults; per-condition prior overrides, definition/decision-point policy JSON, and redundant policy-state prior JSON were removed without migrating existing policy values.
- [x] Data or interface changes: added authorized `policy_snapshot/2` report DTO and retained legacy placement strategy compatibility.
- [x] Access-control or safety checks: policy reporting requires accepted authoring access; icon controls have required accessible names.
- [x] Observability or operational updates when needed: policy status includes lifecycle, guardrail mode, configured thresholds, progress, and imbalance warnings.

## Test Blocks

- [x] Tests added or updated: policy snapshot draft/non-draft formula assertions and invalid zero `alternatives_id` schema coverage.
- [x] Required verification commands run
- [x] Results captured: focused context/schema/LiveView suite passed (78 tests); targeted Jest passed (2 tests); compile, formatting, Prettier, ESLint, diff check, and work-item validation passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged: no contract divergence identified.
- [x] Open questions added to docs when needed: none.

## Review Loop

- Round 1 findings: authorization missing at the report boundary; redundant graph reads; configured rather than effective guardrail status; transition-time pattern-match crash; inline JavaScript; unnamed icon buttons; heading-level mismatch; missing refresh feedback; duplicated untyped strategy classification; incomplete guardrail details and test proof.
- Round 1 fixes: added authoring authorization, reused loaded authoring views, derived effective modes from current counts, handled snapshot errors, removed inline JavaScript, required icon labels, parameterized heading level, added refresh feedback, centralized typed strategies, and rendered thresholds/progress/affected conditions.
- Round 2 findings: mixed-policy report visibility, title preservation, misleading condition-level guardrail text, malformed client indices, duplicate DOM IDs, non-draft candidate loading, quadratic form parsing, and mount error handling.
- Round 2 fixes: report visibility now follows the bounded snapshot; summaries show decision-point policies; titles are preserved; guardrail explanations are decision-point scoped; indices are parsed safely; DOM IDs include decision-point identity; non-drafts load referenced candidates only; parsers prepend/reverse; and candidate errors remain in the normal mount error path.
- UX follow-up review findings: hidden Thompson defaults lacked guidance, one JSON-removal assertion did not match the former DOM, and a weighted-random test still submitted removed fields.
- UX follow-up fixes: added adaptive-default review guidance, asserted the actual details surface has no raw policy JSON, removed stale creation params, and proved equal default weights plus structured adaptive defaults on details. Security and performance re-review found no issues.
- Deferred optimization: assignment-share reporting still performs one bounded-query-count aggregate over experiment assignments. A persisted projection or covering index should be evaluated with production-scale `EXPLAIN ANALYZE` before Phase 9 deployment readiness; this does not alter Phase 6 report correctness.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
