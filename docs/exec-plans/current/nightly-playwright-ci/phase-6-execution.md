# Phase 6 Execution Record

Work item: `docs/exec-plans/current/nightly-playwright-ci`
Phase: 6 — Integrate, verify, and launch the nightly workflow

## Scope from plan.md

Connect publication, accepted GitOps intent, public readiness, and browser execution
at one source SHA. Verify the feature branch and operational failure cases before
normal merge and scheduled launch. Preserve the independent scenario job.

## Implementation Blocks

- [x] Workflow deployment, readiness, reporting, and input wiring.
- [x] Signed protected PR updates and deployment-only credential boundaries.
- [x] Operator instructions and readiness-consumer documentation; external preview script verification remains open.
- Data/interface changes: existing build outputs and deployment record contract; no application changes.

## Test Blocks

- [x] Local workflow/readiness checks and action lint (existing cache-action warnings only).
- [ ] Full feature-branch workflow and operational checks.
- [ ] Scheduled run after normal merge.

## Work-Item Sync

- Preflight work-item validation passed.
- The implementation includes the private parameter-loader follow-up and uses the
  existing GitOps updater. The revised PR workflow is described below.
- G1–G5 evidence remains in the preceding execution records; no prior proof is
  promoted to an unexecuted hosted or operational check.

## Review Loop

- Harness-review round 1: dedicated security and performance reviewers found no
  actionable findings. Local verification included stalled response-stream abortion
  and recovery after the performance reviewer identified the coverage gap.
- Retained build-job `npm ci` because the approved plan requires dependency failures
  to stop publication. No new dependencies are carried between jobs.
- Public-disclosure review found no literal credentials in the Phase 6 diff.
  Operational identifiers and inspection history were removed from this record.
  The operator confirmed that the instance contains synthetic initialization/Playwright
  data, so page content in public failure reports is acceptable. Credentials still
  must remain protected.

## Done Definition

- [ ] Phase tasks complete.
- [ ] Tests and operational verification pass.
- [x] Required local review complete; operational findings remain subject to review.
- [ ] Work-item and final requirements validation pass with actual proofs.

G6 remains open until feature-branch, operational, and scheduled evidence is complete.

## Local Verification

- Temporary checks during implementation passed for readiness identity, failure and
  timeout handling, stalled responses, signature rejection, PR recovery, job dependencies,
  and artifact settings. The standalone test script was removed at the operator's
  request; no workflow fixture suite is retained in the repository.
- `git diff --check` passes.
- Actionlint on nightly and PR workflows reports only existing `actions/cache@v3`
  warnings in the unchanged scenario and PR jobs. No new action/shell errors.
- Parsed YAML comparison confirms triggers, concurrency and the entire scenario job
  match the starting revision. The PR workflow is unchanged.
- Preflight and postflight work-item validation pass. No backend/test-support code
  changed, so a full ExUnit rerun is unnecessary for these workflow-only changes.
- These local checks cover code paths and static connections; they do not reproduce
  GitHub cancellation, runner termination, required-check enforcement or live integration.

## Operational State and Remaining Gates

The implementation is available for review in
[PR #6942](https://github.com/Simon-Initiative/oli-torus/pull/6942).
The initial hosted feature-branch run built the image and passed the independent
scenario tests, but failed on the old helper's bot-login representation comparison
before deployment. That helper was corrected; the simplification below replaces it.
A complete hosted run and operational verification remain pending.
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
full tagged integrations, credential handling, persistence/mailbox checks,
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

## Operator-approved simplification

- Replace custom signed-commit/PR creation with a commit-pinned
  `peter-evans/create-pull-request` action, using the existing App and one allowed file.
- Request immediate squash merges through GitHub CLI with the exact PR head SHA.
  GitHub enforces required checks, signatures, and review rules. The step retries
  within 15 minutes and never queues auto-merge.
- Compare the protected branch's accepted deployment record with the prepared file
  before readiness. Keep the content-preserving updater and required GitOps CI checks;
  remove duplicate renders from the Torus workflow.
- Replace the custom readiness JavaScript with bounded `curl`/`jq` polling and retain
  exact HTTP/status/version/SHA gating. Keep one final summary and both report uploads.
- Remove the GitOps PR lifecycle helper, its dedicated tests, and the workflow's
  bot-login setting. Open PRs left by failed runs can be closed normally. An immediate
  merge already in flight may complete during cancellation; inspect the PR if needed.
- Land the Torus workflow first and finish old runs before deleting the helper from
  GitOps `master`. New manual runs can use the simplified workflow while the unused
  helper still exists. No new PR or hosted deployment was started for this revision.

Verification of the simplification:

- Temporary command fixtures passed for pending/rejected merge requests, exact-head
  submission, accepted-record mismatch, missing/unsigned PR rejection, cancellation,
  readiness status/version/SHA/JSON/network failures, and the total deadline.
- Parsed workflow checks confirm unchanged triggers, concurrency, and scenario job.
- All seven remaining updater tests, all GitOps validators, and eight static Kustomize
  renders passed. No live Kubernetes API was contacted.
- Actionlint reports only the existing cache-action warnings in unchanged jobs.
- Harness-review security and performance reviewers found no actionable findings
  in the simplified workflow and GitOps deletions.
- Work-item validation and whitespace checks pass. Temporary fixtures are removed;
  no new test framework or script is retained.

The initial local checks above are historical evidence for the replaced implementation.
Hosted verification of the new PR action and immediate merge remains outstanding.
