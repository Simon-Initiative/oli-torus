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
allows only `master`. Neither currently permits the Phase 6 branch. No active nightly
run was found; the latest scheduled run `38686900486` failed, while provisioning run
`38613155854` succeeded. No new hosted execution or remote policy change is claimed.

The current Torus `master` still runs the older browser-only nightly workflow and has
no target concurrency lock. Before feature-branch dispatch, pause that job through a
reviewed temporary `if: ${{ github.event_name == 'workflow_dispatch' }}` condition
on `nightly-playwright`, preserving the scenario job and manual trigger. The runbook's
`build-playwright` condition applies after the integrated workflow reaches master.
Allow the exact Phase 6 branch in both environments, retain `master`, and inspect
active/pending runs before dispatch. A default-branch pause is needed to prevent the
older workflow from running against the target during verification.

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
