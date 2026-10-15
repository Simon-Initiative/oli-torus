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

- Preflight work-item validation passed on 2026-10-15.
- Feature branch: `MER-6038-phase-6-integrate-verify-and-launch-the-nightly-workflow`.
- Starting Torus commit: `c229c5c593`; includes parameter-loader follow-up `58559905f8`.
- Inspected GitOps checkout: `62854e631a2fe72c198bbc3aff23976d0a765b5c`.
- G1–G5 evidence remains in the preceding execution records; no prior proof is
  promoted to an unexecuted hosted or operational check.

## Review Loop

- Harness-review round 1: dedicated security and performance reviewers found no
  actionable findings. Added a real stalled response-stream abort/recovery fixture
  after the performance reviewer identified the coverage gap.
- Retained build-job `npm ci` because the approved plan requires dependency failures
  to stop publication. No new dependencies are carried between jobs.

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

Read-only GitHub inspection on 2026-10-15 found GitOps `master` at
`1fa4fcd50f6eda51fdf7b873e632dbf79c0e2548`. The local inspected checkout has a later
runbook commit; workflow helper signatures match the landed Phase 5 contract.
`nightly-ui` allows `master` and the Phase 5 provisioning branch; `nightly-deploy`
allows only `master`. Neither permitted the Phase 6 branch at initial inspection. No active nightly
run was found; the latest scheduled run `38686900486` failed, while provisioning run
`38613155854` succeeded. No new hosted nightly execution is claimed. The exact branch allowances were added afterward as recorded below.

The current Torus `master` still runs the older browser-only nightly workflow and has
no target concurrency lock. The operator rejected a temporary schedule pause as
unnecessary. Keep the schedule unchanged, inspect active/pending runs before dispatch,
and coordinate feature-branch verification around scheduled execution. Both environments
now allow the exact Phase 6 branch as recorded below.

Live lifecycle tests also need an explicitly authorized disposable Kubernetes context
and target under the GitOps repository contract; that information was requested.
No live Kubernetes command has been executed.

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

## Published Review State

- Implementation commit `645474c61d` was pushed to the Phase 6 feature branch and
  opened as [draft PR #6942](https://github.com/Simon-Initiative/oli-torus/pull/6942),
  based on the Phase 5 branch so review isolates this phase.
- Added only the exact Phase 6 branch to both environments, then read policies back:
  `nightly-ui` policy `63171813`, `nightly-deploy` policy `63171815`. Existing master
  access and the older provisioning-branch allowance were preserved. Remove temporary
  feature-branch allowances after successful launch verification.
- Prepared the one-line master pause as
  [draft PR #6943](https://github.com/Simon-Initiative/oli-torus/pull/6943), commit
  `d756b2c2c5`. Parsed-YAML equality proves only the scheduled browser condition
  changes; manual dispatch and scenarios remain unchanged. Security and performance
  reviewers found no issues; actionlint reports the existing cache-action warning.
  The operator rejected this pause as unnecessary. PR #6943 was closed unmerged;
  the nightly schedule remains unchanged.
- GitOps helper/updater/validation-workflow files are identical between inspected
  local revision `62854e6` and accepted `master` revision `1fa4fcd`.
- Final-phase `verify_implementation` and `master_validate --stage implementation_complete`
  commands both returned success. As documented in the plan, these scripts do not
  traverse nested criteria: the supplemental check found 42 uniquely mapped nested
  criteria and zero entries with both verified status and proof. These results do
  not close G6 or waive any live acceptance check.

Next step: ensure no old runs/reruns remain active, then dispatch the allowed Phase 6
branch without changing the schedule. Disposable lifecycle checks
remain pending the requested explicit Kubernetes context and authorization.
