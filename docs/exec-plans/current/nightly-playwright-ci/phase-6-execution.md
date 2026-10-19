# Phase 6 Execution Record

Work item: `docs/exec-plans/current/nightly-playwright-ci`
Phase: 6 — Verify the nightly workflow end to end
Status: Complete under the operator-approved 2026-10-16 scope.

## Scope from plan.md

Verify that the implemented workflow builds and publishes the selected source,
accepts its GitOps deployment, checks public readiness and identity, executes the
tagged browser tests, and retains reports with the correct outcome. Separate bug work owns
repairs to unrelated Playwright tests, fixtures, and application failures. A green test
suite is not required to demonstrate that the workflow works.

## Implementation Blocks

- [x] Build, deployment, readiness, reporting, and integration-input wiring.
- [x] Signed protected PR updates using a pinned PR action and GitHub CLI; App
  credentials are confined to deployment. No queued auto-merge or direct-push fallback.
- [x] Accepted deployment-record comparison and bounded public `curl`/`jq` readiness
  polling before browser execution from the selected build SHA.
- [x] Standard nightly Playwright invocation, retained failure status, both artifact
  uploads, and final stage/provenance summary.
- [x] Operator instructions, including existing schedule/manual dispatch, cancellation,
  stale PR recovery, and readiness-consumer documentation.

Runtime follow-ups needed for the hosted run aligned the nightly proxy/request
import timeouts and set `NODE_ENV=production` in the release container. The latter
prevents the Node bridge from reloading and retaining the bundled rules module on
every evaluation. These fixes are already included in the verified revision.

## Minimal Feature-Branch Verification

Evidence: [run 38954795747](https://github.com/Simon-Initiative/oli-torus/actions/runs/38954795747),
source commit `19a5ee09fae0194a38b11cfec1f2e13304ea7a2f`, on
`MER-6038-phase-6-integrate-verify-and-launch-the-nightly-workflow`.

| Check | Result |
| --- | --- |
| Build and publish selected source | Passed: Build Playwright image completed. |
| Accept deployment and verify expected public identity | Passed: Deploy and verify Plasma completed before browser execution. |
| Execute selected tests at the same source revision | Completed: Playwright ran all 15 selected cases; 7 passed, 8 failed, none skipped. Independent Elixir scenarios passed: 2 tests, 0 failures. |
| Retain reports and actual outcome | Passed: both artifact uploads and final summary succeeded; browser job and workflow remained failed. |

The [browser job](https://github.com/Simon-Initiative/oli-torus/actions/runs/38954795747/job/117163102433)
completed normally after approximately 81 minutes of test execution. Its failed
conclusion reflects test/setup failures, not a failure to run or report the suite.

## Runtime Observations

Resource samples cover 19:52–21:09 UTC on 2026-10-16, not the initial deployment
startup. The app, PostgreSQL, and MinIO had no container restarts, and no sampled
node memory, disk, or PID pressure. Minimum sampled host available memory was
35.36 GiB. Sampled peaks were 3,089 MiB for the app, 2,270 MiB for PostgreSQL,
and 114 MiB for MinIO.

Both Node worker process IDs remained unchanged. Maximum sampled worker RSS was
140.7 MiB, with no recurrence of the prior multi-gigabyte growth and worker crash.
These are observations from this run, not proposed resource limits.

Eight imports returned HTTP 200, including imports lasting 81.6, 82.9, and 89.1
seconds, confirming that the old 60-second proxy cutoff no longer applies.
Greenhouse Molecules returned HTTP 502 after approximately 300 seconds on each
of its two attempts. That import failure is captured for separate diagnosis; this run
does not establish whether application ingestion or the server/proxy timeout is the cause.

## Test Failure Handoff

The eight failed tests are deferred to a separate MER bug and do not create another
infrastructure phase:

- Canvas launch and Moodle launch: shared course-creation helper expects the old UI.
- Moodle grade passback: navigation waits for the Assignments link.
- Designer Planet: onboarding/lesson navigation fails.
- Plate Tectonics: manifest validation rejects a missing or empty scenario array.
- Phases of the Moon: sorting interactions fail at screens 59/64.
- Greenhouse Molecules: course ingestion returns HTTP 502 after approximately 300 seconds.
- Account linking: typing exceeds the test timeout.

These describe observed failures and initial findings, not completed diagnoses or fixes.

## Prior Verification and Review

Reuse the existing G1–G5 execution records and completed Phase 6 local checks:

- Workflow/action lint, source propagation, dependencies, credential scope, unchanged
  triggers/concurrency/scenario behavior, and nightly configuration/artifact settings.
- Temporary local fixtures for readiness identity, malformed/network responses,
  stalled streams, deadline handling, merge rejection, accepted-record mismatch,
  and cancellation. The disposable scripts were removed; no new test framework remains.
- GitOps updater tests, validators, and static manifest renders.
- Dedicated security and performance review of the workflow and its simplification,
  with no unresolved findings. Existing cache-action warnings were unrelated.
- Node bridge regression verification showed bounded module memory with production
  mode, and all 41 rules-engine tests passed before the runtime fix was committed.

The operator confirmed that the instance contains synthetic initialization and
Playwright data, so page content in public failure reports is acceptable. Credentials
must remain protected; no private repository URL is included in this record.

## Done Definition

- [x] Workflow implementation complete.
- [x] Four minimal end-to-end verification checks demonstrated by the hosted run.
- [x] Failures recorded for separate bug follow-up without masking the failed workflow result.
- [x] Plan, PRD, FDD, and requirements scope notes reconciled.

G6 is closed. First scheduled-run confirmation after normal merge remains a launch
follow-up, independent of this manual workflow proof. Keep the existing schedule;
remove temporary feature-branch environment allowances after verification.

The former live fault-injection, cancellation, overlap, persistence/mailbox, and
disposable lifecycle campaign is no longer a phase-closeout requirement. Reuse
prior component/release, policy, rendered-manifest, and local failure evidence.
Unperformed live exercises and the absent external preview smoke script remain
unverified; they are not claimed as passing evidence or blockers to G6.

## Requirements Validation

Work-item validation, plan traceability, `master_validate --stage plan_present`,
`verify_implementation`, `master_validate --stage implementation_complete`, and
`git diff --check` passed for the 2026-10-19 documentation closeout. A supplemental check
confirmed all 42 unique nested acceptance criteria are referenced in the plan and
FDD, with no unknown IDs. Implementation traceability is checked at Phase 6 closeout; scheduled confirmation
remains post-merge evidence. The installed traceability tool does not traverse
nested acceptance criteria; inspect their actual proofs rather than treating script
success as proof that all 42 criteria are verified.

## Decision Log

### 2026-10-16 — Close workflow verification; separate test repairs (phase assignment superseded)

- Change: Limit Phase 6 to the four completed workflow checks and move the eight
  browser test/setup failures into Phase 7. Remove the excessive live verification campaign.
- Reason: The operator accepted the completed run as proof of working orchestration
  and requested minimal verification, with actual test repairs handled separately.
- Evidence: Run 38954795747 and its retained browser results; existing local checks
  and earlier phase execution records.
- Impact at the time: G6 was complete and a proposed G7 required a passing suite.
  The 2026-10-19 decision removes that extra phase; first scheduled-run
  confirmation remains launch follow-up. No unperformed checks are promoted to verified.

### 2026-10-19 — Final PR limited to Phase 6

- Change: Remove Phase 7 from the infrastructure plan and capture unrelated test,
  fixture, and application defects in a standalone MER bug. Preserve the eight
  observed failures above; Greenhouse ingestion still needs root-cause diagnosis.
- Reason: The requested deliverable is working CI and Playwright infrastructure.
  Correctly reported browser failures do not prevent infrastructure closeout.
- Evidence: Completed manual run 38954795747. On 2026-10-19, GitHub reports the
  Nightly Tests workflow active, with the `17 5 * * *` schedule on master and this
  branch. Scheduled runs occurred on October 17, 18, and 19, most recently
  [run 39204782927](https://github.com/Simon-Initiative/oli-torus/actions/runs/39204782927).
  These use master's pre-integration workflow and do not establish scheduled
  build/deploy/readiness proof for the new pipeline.
- Impact: G6 remains complete and is the final implementation gate. Keep normal
  merge, first integrated scheduled-run confirmation, and temporary branch-policy
  cleanup as post-merge follow-up. No schedule mutation was needed.
- PR scope: Draft course-selection and Designer Planet fixes were removed from
  the working diff and preserved outside the repository for the separate bug.
  Their lint, collection, and 22 core-test checks were successful, but their
  affected live tests were not run; they are not part of the Phase 6 evidence.
