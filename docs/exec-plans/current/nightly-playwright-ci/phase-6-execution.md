# Phase 6 Execution Record

Work item: `docs/exec-plans/current/nightly-playwright-ci`
Phase: 6 — Integrate, verify, and launch the nightly workflow

## Scope from plan.md

Connect publication, accepted GitOps intent, public readiness, and browser execution
at one source SHA. Verify the feature branch and operational failure cases before
normal merge and scheduled launch. Preserve the independent scenario job.

## Implementation Blocks

- [x] Workflow deployment, readiness, reporting, and input wiring.
- [x] Run-owned PR cleanup and credential boundaries.
- [x] Operator instructions and readiness-consumer documentation; external preview script verification remains open.
- Data/interface changes: existing build outputs and GitOps helper contracts only.

## Test Blocks

- [x] Targeted workflow/readiness fixtures and action lint (existing cache-action warnings only).
- [ ] Full feature-branch workflow and operational checks.
- [ ] Scheduled run after normal merge.

## Work-Item Sync

- Preflight work-item validation passed.
- The implementation includes the private parameter-loader follow-up and uses the
  existing GitOps updater and PR lifecycle contracts.
- G1–G5 evidence remains in the preceding execution records; no prior proof is
  promoted to an unexecuted hosted or operational check.

## Review Loop

- Harness-review round 1: dedicated security and performance reviewers found no
  actionable findings. Added a real stalled response-stream abort/recovery fixture
  after the performance reviewer identified the coverage gap.
- Retained build-job `npm ci` because the approved plan requires dependency failures
  to stop publication. No new dependencies are carried between jobs.
- Public-disclosure review found no literal credentials in the Phase 6 diff.
  Operational identifiers and inspection history were removed from this record.
  Failure-report privacy remains an open launch check; disabling visual recordings
  does not sanitize page snapshots or error messages.

## Done Definition

- [ ] Phase tasks complete.
- [ ] Tests and operational verification pass.
- [x] Required local review complete; operational findings remain subject to review.
- [ ] Work-item and final requirements validation pass with actual proofs.

G6 remains open until feature-branch, operational, and scheduled evidence is complete.

## Local Verification

- `node --test .github/scripts/nightly-playwright.test.cjs`: 10 tests pass. Exercises
  the inline workflow code, including matching/old/malformed identity, HTTP/redirect/
  network failures, deadline clamping, late success rejection, stalled stream abortion,
  signature rejection, ambiguous PR recovery, dependency gates and artifact settings.
- Prettier check for the new fixture passes; `git diff --check` passes.
- Actionlint on nightly and PR workflows reports only existing `actions/cache@v3`
  warnings in the unchanged scenario and PR jobs. No new action/shell errors.
- Parsed YAML comparison confirms triggers, concurrency and the entire scenario job
  match the starting revision. The PR workflow is unchanged.
- Preflight and postflight work-item validation pass. No backend/test-support code
  changed, so a full ExUnit rerun is unnecessary for these workflow-only changes.
- Fixture tests prove local code paths and static connections; they do not reproduce
  GitHub cancellation, runner termination, required-check enforcement or live integration.

## Operational State and Remaining Gates

The implementation is available for review in
[PR #6942](https://github.com/Simon-Initiative/oli-torus/pull/6942).
Hosted feature-branch execution and operational verification remain pending.
Keep the existing schedule unchanged, check active runs before dispatch, and
coordinate verification around scheduled execution. Verify environment access
through the private operational configuration before running deployment tests.

Live lifecycle tests require an explicitly authorized disposable context and target.
No live lifecycle test has been executed for this phase.

Readiness consumer reconciliation: the PR workflow uses `/readyz`; the nightly
identity step uses public HTTPS `/readyz`; startup/liveness remains `/healthz`.
Nightly GitOps probes were provisioned in Phase 5. Other deployment probes are not
changed here. `docs/preview-environments.md` now documents the HTTP-200/`ready`
contract and capable-image ordering. Its external `devops/scripts/smoke-test-preview.sh`
is absent from both inspected repositories, so that script's behavior remains unverified.

G6 stays open for the complete feature-branch run, App/check/merge/cancellation proof,
full tagged integrations, artifact privacy/access, persistence/mailbox checks,
disposable lifecycle tests, serialization/rerun/failure exercises, normal Torus merge,
and successful scheduled execution. No nested acceptance criterion is marked verified
by these local checks alone.

## Requirements Validation

Final-phase `verify_implementation` and `master_validate --stage implementation_complete`
commands both returned success. As documented in the plan, these scripts do not
traverse nested criteria: the supplemental check found 42 uniquely mapped nested
criteria and zero entries with both verified status and proof. These results do
not close G6 or waive any live acceptance check.

Next step: ensure no old runs/reruns remain active, then dispatch the allowed Phase 6
branch without changing the schedule. Disposable lifecycle checks
remain pending the requested explicit Kubernetes context and authorization.
