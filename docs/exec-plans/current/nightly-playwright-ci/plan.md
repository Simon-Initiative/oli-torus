# Nightly Playwright CI - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/nightly-playwright-ci/prd.md`
- FDD: `docs/exec-plans/current/nightly-playwright-ci/fdd.md`
- Canonical requirements: `docs/exec-plans/current/nightly-playwright-ci/requirements.yml`
- Historical context: `docs/exec-plans/current/nightly-playwright-ci/dependency-discovery.md`; its reverted experiment is not implementation evidence.
- Repository contract: `AGENTS.md`, `ARCHITECTURE.md`, `harness.yml`, `docs/STACK.md`, `docs/TOOLING.md`, `docs/TESTING.md`, `docs/PRODUCT_SENSE.md`, `docs/FRONTEND.md`, `docs/BACKEND.md`, `docs/OPERATIONS.md`, `docs/CODEREVIEW.md`, `docs/ISSUE_TRACKING.md`.
- Tracking reference: MER-5918. This plan requires no Jira mutation; any later ticket change follows the installed CLI and exact-draft approval rules.

## Scope

Deliver a shared `MIX_ENV=playwright` environment for ephemeral PR tests and a durable nightly release, separate startup/liveness and readiness probes, and an ordered nightly build/publish → accepted GitOps update → public identity check → tagged browser execution pipeline. The durable target is `https://nightly-playwright.plasma.oli.cmu.edu`. Provisioning and probe/drain manifests are separately reviewed changes in `oli-torus-gitops`; recurring CI updates only image/source metadata.

Preserve PR triggers, tested checkout, `@pr` coverage and disposable services, and preserve the independent `nightly-scenarios` job. Include all current `@nightly` cases, including adaptive, Canvas and Moodle LTI, and Dot. Keep production captcha behavior and compile-time test-route exclusions intact. No domain schema change, production UI redesign, database reset, automatic migration rollback, new feature flag, asset-versioning system, scheduled cleanup service, or custom results validator is included.

Per `harness.yml`, telemetry is delivered through stage summaries, provenance and standard Playwright reports. Existing AppSignal monitoring remains unchanged. Security and performance review apply throughout; throughput benchmarks, custom timing instrumentation and performance budgets are excluded by the approved design. Timeouts and probe lifecycle correctness remain mandatory. Browser helper changes follow `assets/automation/AGENTS.md`; new domain scenarios are needed only if implementation expands into domain workflow behavior.

## Clarifications & Default Assumptions

- No design questions remain open. Provisioning values and operational evidence are implementation gates, not reasons to reopen approved decisions or claim completion early.
- Preserve daily `17 5 * * *` and manual dispatch. Scheduled runs select current `refs/heads/master` once after acquiring the target lock; manual runs use the selected branch's exact dispatch SHA. Manual reruns retain that SHA; a new dispatch selects the branch again. Record workflow SHA separately from source SHA.
- Use `build-playwright` → `deploy-plasma` → `nightly-playwright` jobs with workflow-level group `nightly-playwright-plasma` and `cancel-in-progress: false`. The scenario job stays dependency-independent within each run; overlapping workflow runs queue together. A newer pending run may replace an older pending run; an active run completes. The lock spans source selection and build through finalization. There is no separate GitOps preflight or check for previous runs' PRs.
- Default merge wait is 15 minutes; readiness is 20 minutes with 10-second polling and a maximum 10-second request timeout, all clamped to the remaining deadline. Keep finite job/browser timeouts, one Chrome worker and one retry.
- GitOps maintainers own deployment/secrets/branch policy; QA/test owners own private assets and Canvas/Moodle/Dot fixtures; Torus maintainers own application/workflows/automation credentials, triage and stale-data cleanup.
- When Phase 5 needs a local GitOps checkout, request its location if unknown. Use it only for that session and never persist the local path. GitOps file paths below are relative to that repository root. Planning does not require accessing that checkout.
- Supply actual external URLs, credentials and the protected GitOps destination branch during provisioning. Configure `nightly-ui` branch rules to permit trusted repository branches for manual runs as well as unattended master runs. Canvas must launch into nightly Torus; Dot uses its existing scenario setup to create its course and student there during the test run. No tagged integration may be silently excluded to unblock launch.
- A public version/SHA observation does not prove all-replica convergence or distinguish same-source rebuilds. Retain the digest as provenance; no post-test identity check is required.
- Checked tasks describe recorded implementation evidence. Keep operational gates open until their actual checks pass; document validation and historical experiments do not satisfy operational acceptance criteria.

## Phase 1: Application lifecycle and probe contracts

- Goal: Establish the application contract consumed by PR startup, GitOps probes and nightly identity polling.
- Coverage: FR-005 — AC-012, AC-013, AC-014, AC-039, AC-040, AC-042; application prerequisites for AC-041.
- Tasks:
  - [x] Add documented `Oli.Health` APIs in `lib/oli/health.ex` for starting/running/draining state, liveness and readiness. Reset on each application start, mark complete after successful supervision and mandatory initialization, and never overwrite a requested drain with startup completion.
  - [x] Wire `lib/oli/application.ex` startup and `prep_stop/1`; expose idempotent drain through a local release function in `lib/oli/release.ex`, with no HTTP mutation endpoint.
  - [x] Check only named `Oli.Repo`, `Oli.PubSub` and `Oli.Vault` availability plus a normal-pool `SELECT 1`. Bound checkout and query together to one second, cancel expired work and recheck draining before returning ready. Exclude NodeJS and external dependencies.
  - [x] Replace the existing health controller/view response with local-only 503 `starting` or 200 `Ayup!`; add `/readyz` controller/view returning 200 `ready` or 503 `not_ready`, each including compiled string version/SHA only in Playwright builds; all other builds return only status. Add unauthenticated routes, no-store headers and both HTTP probe exemptions in `lib/oli_web/plugs/ssl.ex`.
  - [x] Inventory readiness consumers of `/healthz`; assign PR migration to Phase 2 and GitOps migration to Phase 5. Preserve rollout ordering: capable images precede activation of new readiness probes.
- Testing Tasks:
  - [x] Add focused ExUnit coverage for exact bodies/status/headers, unauthenticated HTTP without redirects, Playwright-only compiled identity and absence of dependency calls from liveness. Verify runtime settings cannot change metadata visibility or identity. An old but ready Playwright build returns 200 with its own identity.
  - [x] Exercise startup/reset, missing/recovered required services, NodeJS unavailability, exhausted DB pool, disconnection/query errors/timeouts and drain during a query. Assert the total DB budget and absence of accumulating work; isolate lifecycle mutations and capture intentional logs.
  - [x] Verify actual graceful release shutdown marks draining while HTTP remains available; verify the deployed manifest behavior in Phase 5 and reuse that evidence at launch.
  - Commands: `mix format --check-formatted` and targeted `mix test` for health, readiness, SSL and lifecycle modules. Add `mix test` in full if shared test support/configuration changes. Run Mix commands with scoped escalation under the Codex repository contract.
- Definition of Done:
  - Exact public contracts and lifecycle transitions pass focused tests; liveness stays healthy during database outage/draining, and readiness fails safely within its budget.
- Gate: G1 — application probe contract verified; no infrastructure consumer is switched ahead of a capable image.
- Evidence: `docs/exec-plans/current/nightly-playwright-ci/phase-1-execution.md`.
- Dependencies: None.
- Parallelizable Work: Phase 2 configuration/helper drafting and Phase 4 runner work can start against the documented contract; coordinate shared router, release and test files.

## Phase 2: Shared Playwright configuration and atomic PR migration

- Goal: Replace `ci_e2e` with a standalone shared environment while retaining the full PR suite and simplifying captcha handling.
- Coverage: FR-001, FR-002 — AC-003, AC-005, AC-006, AC-032, AC-033, AC-034, AC-035, AC-036, AC-037, AC-038; PR consumer portion of AC-042.
- Tasks:
  - [x] Add `config/playwright.exs` with direct compile-time scenario/mailbox enablement, `Oli.Playwright.Recaptcha`, `Swoosh.Adapters.Local`, release assets and `env: :playwright`. Disable development debug/reload/watch settings without importing `dev.exs`; retain normal origin checks and exclude preview QA defaults.
  - [x] Extend release runtime/SSL branches, `mix.exs` permanence and endpoint static gzip handling for `:playwright`. Load separate scenario/mailbox and captcha tokens only at runtime; fail boot when either is absent/empty. Permit PR boot without private-assets configuration; asset-dependent operations still fail clearly when unavailable.
  - [x] Require the configured nonempty captcha token with constant-time comparison; reject missing/empty/incorrect/malformed responses without Google requests. Route application verification through compile-selected `Oli.Recaptcha`; preserve production selection regardless of runtime configuration.
  - [x] Preserve captcha templates and LiveView hooks; block Google scripts in runner contexts. Centralize token submission in context setup for native POST and LiveView FormData, with destination/method safeguards and no DOM fields, deployed client substitute or per-captcha branches. Audit manually created contexts and protected forms.
  - [x] Redact captcha fields in request logs and prevent mailbox credentials/account links from entering traces or attachments in both CI paths.
  - [x] Migrate `.github/workflows/pr-playwright.yml` with explicit disposable database, local HTTP, signing/encryption and storage boot inputs; generate a job-scoped scenario secret using at least 32 random bytes. Build frontend/server/Tailwind/digested assets through the release pipeline before `mix phx.server`, and wait on `/readyz`.
  - [x] Delete `config/ci_e2e.exs` and migrate active scripts/config/docs/cache references in the same landing change. Retain no alias, wrapper or fallback. Preserve PR triggers, checkout, `@pr`, create/migrate/seed and runner-owned teardown.
  - [x] Key compile caches by environment, configuration, toolchain and lockfiles; separate PR, trusted nightly and production namespaces. Prevent broad restore fallbacks from loading incompatible compile artifacts.
- Testing Tasks:
  - [x] Test correct-token acceptance, invalid-token rejection, missing-secret startup failure, no Google calls, immutable compile selection and normal production verification. Verify real standard/LiveView form success and rejection plus native GET, submitter override and external-frame safety.
  - [x] Verify local mail retrieval by unique recipient/ID, optional subject filtering and missing/wrong-token rejection; confirm messages are never sent through SES/SMTP and diagnostics omit email/reset content.
  - [x] Run clean and cached PR builds, mutate compile configuration to verify invalidation, and run the complete existing `@pr` suite including registration/confirmation/reset plus affected enrollment/payment specs with their required fixtures.
  - [x] Audit active `ci_e2e` references and dev imports; historical migration notes may retain the retired name. Confirm PR requires no nightly secrets, private assets, publish or GitOps access.
  - Commands: affected ExUnit modules and formatting; frontend targeted `yarn test`/`yarn lint` from `assets/` as applicable; `npm ci`, `npx playwright install --with-deps chrome`, and `npx playwright test --grep @pr` from `assets/automation/` with explicit local runtime inputs. Run full `mix test` whenever shared test support/configuration changes and require clean ExUnit output.
- Definition of Done:
  - Shared compile selections, runtime secret boundaries, mailbox authorization and simplified captcha flows pass; the full PR suite works with its original isolation and source selection.
- Verification status: review follow-up local verification passed (26 doctests, 9,617 backend tests, 0 failures; 32 browser tests passed). See `docs/exec-plans/current/nightly-playwright-ci/phase-2-execution.md`. G2 still requires hosted PR checks on the follow-up revision before landing.
- Gate: G2 — land configuration, captcha behavior, PR migration and environment deletion together only after G1 and PR verification pass.
- Evidence: `docs/exec-plans/current/nightly-playwright-ci/phase-2-execution.md` (local build/browser/backend verification; hosted CI and packaged images remain later validation).
- Dependencies: G1 for PR startup waiting and integrated lifecycle verification.
- Parallelizable Work: Backend token verification and runner context setup can proceed independently, but merge and verify together. Phase 4 dependency work can proceed independently.

## Phase 3: Release packaging and build isolation

- Goal: Produce a release that boots with the same capabilities and can serve every selected test's runtime fixtures without embedding secrets.
- Coverage: FR-002, FR-003, FR-009 — AC-004, AC-005, AC-006, AC-007, AC-034, AC-036, AC-025, AC-026.
- Tasks:
  - [x] Update `Dockerfile` and `.dockerignore` for standalone Playwright builds, full source SHA and configuration-sensitive layers, preserving the production default. Keep `_build` isolated by environment/trust boundary and exclude dependencies/reports/downloaded assets/local secrets from the build context as required by the FDD.
  - [x] Audit selected PR/nightly fixture paths in scenario/support-asset endpoints. Package only demonstrated public fixture needs under `priv/` and resolve application paths while preserving local behavior. Keep private archives in object storage; do not add `test/support` or preview seeds to Playwright compilation paths.
  - [x] Build source/version OCI metadata and define the unique `sha-<full SHA>-playwright-<run ID>-<attempt>` publication interface in the existing GHCR repository. Supply source SHA/version as build inputs; verify release configuration through focused tests and smoke checks; push failure handling integrates with downstream jobs in Phase 6; no existing-tag preflight check is required.
  - [x] Supply runtime ExAws/bucket/service credentials through deployment inputs; retain release setup migrations and persistent services. Document mailbox reset on process restart and the one-replica requirement for Phase 5.
- Testing Tasks:
  - [x] Build clean and cached Playwright and production images independently, including configuration/source invalidation. Boot Playwright against disposable services with runtime secrets; verify identity, authenticated scenarios/private assets/mailbox and required files/modules. Check both readiness statuses against actual compiled Playwright/production releases: metadata appears only for Playwright and runtime build-setting changes cannot alter visibility or identity.
  - [x] Build production with no capability flags and boot with runtime verifier overrides attempted: routes remain excluded, normal captcha remains selected and readiness returns only status. Inspect image history/layers and metadata for secret leakage and correct full SHA/version.
  - [x] Restart the release and verify a fresh instance-local mailbox while database/object storage and integration fixture data persist; reject absent tokens and unauthorized asset/mailbox requests.
  - Commands: `docker build --platform linux/amd64 --build-arg MIX_ENV=playwright --build-arg BUILD_SCOPE=nightly-playwright --build-arg SHA="$SOURCE_SHA" --build-arg APP_VERSION="$APP_VERSION" -t torus-playwright-smoke .` and a separate `MIX_ENV=prod` image build; GitHub packaging is the `build-playwright` job in `.github/workflows/nightly-playwright.yml`; see the FDD runtime configuration and release packaging sections. Never provide runtime secrets as build arguments.
- Definition of Done:
  - Actual release smoke evidence resolves the deferred fixture and mailbox audits; clean/cached production isolation is demonstrated.
- Evidence: `docs/exec-plans/current/nightly-playwright-ci/phase-3-execution.md`.
- Gate: G3 — release artifact is ready for registry publication and separately reviewed deployment provisioning.
- Dependencies: G1 and G2.
- Parallelizable Work: Phase 4 runner configuration and Phase 5 static GitOps preparation; live provisioning verification waits for this release.

## Phase 4: Minimal nightly runner configuration

- Goal: Run the existing tagged tests directly with working dependencies and standard reports.
- Coverage: FR-008, FR-009, FR-010 — AC-021, AC-022, AC-023, AC-024, AC-030, AC-031, AC-026, AC-027, AC-028.
- Scope adjustment: The user requested the smallest changes necessary to run nightly automation. Resources and credentials are exercised by the tests themselves; no nightly flag, added configuration/target checks, asset preflight, parameter freezing, custom reporting or additional integration framework. Existing tests, including their pre-existing skip checks, remain unchanged.
- Tasks:
  - [x] Declare `json-rules-engine` directly, aligned with product resolution 6.1.2, and regenerate the npm lockfile.
  - [x] Extend the shared Playwright config with line and HTML (`open: never`) reporting and disabled trace/screenshots/video. Inherit Chrome, one worker and one retry.
  - [x] Preserve all source tags and existing test behavior, including missing-key skip checks.
  - [x] Document invocation and integration configuration; retain existing loaders, requests and fixture cleanup.
- Testing Tasks:
  - [x] Verify dependency parity and import/selection from an isolated `npm ci` installation without parent product dependencies.
  - [x] Exercise direct success/failure, existing missing-key skips, and zero matching tests; verify standard reports are generated.
  - [x] Run targeted existing tests, formatting/lint checks, required review and work-item validation.
  - Commands from `assets/automation/`: `npm ci`, `npx playwright install --with-deps chrome`, `npx playwright test --config playwright.nightly.config.ts --grep @nightly`. Full provisioned execution remains part of the Phase 6 launch checklist.
- Definition of Done:
  - Direct tag execution, normal failure behavior, dependency isolation and standard reporting are verified. No separate suite inventory or resource validation layer.
- Evidence: `docs/exec-plans/current/nightly-playwright-ci/phase-4-execution.md`.
- Gate: G4 — minimal runner is ready for workflow integration; live integrations, report access/privacy inspection and full-suite execution remain launch gates.
- Dependencies: G2 for shared captcha behavior; G3 for release-based asset/mailbox verification.
- Parallelizable Work: Runner dependency/configuration work can proceed independently of target provisioning.

## Phase 5: GitOps update contract and target provisioning

- Goal: Provide a verified GitOps update path and a provisioned nightly target.
- Coverage: FR-004, FR-005, FR-007, FR-009 — AC-009, AC-010, AC-011, AC-041, AC-042, AC-020, AC-025, AC-026; provisioning for AC-023 and AC-034.
- Tasks:
  - [x] Inspect the GitOps checkout and implement content-preserving updates in `scripts/update_deployment_record.py`. Limit nightly edits to `imageTag`, `metadata.sourceRef`, and `metadata.commitSha`; require the enabled staging/public target and exact hostname. Reject create, lifecycle, or infrastructure changes.
  - [x] Implement `scripts/nightly_deployment_pr.py` bounded merge waiting, accepted-commit/branch verification, conflict rejection, and run-owned cleanup. Default merge wait is 15 minutes; cancellation/timeout gets 60 seconds for cleanup. Do not scan for prior runs' PRs; no direct-commit fallback.
  - [x] Prepare nightly-only probes: startup `/healthz` at 5s/2s/60, liveness `/healthz` at 15s/2s/3, and readiness `/readyz` at 5s/2s/2 (period/timeout/failure threshold). All success thresholds are 1; startup gates normal probes without fixed initial delays.
  - [x] Prepare one replica with `Recreate`, application/setup image parity, 60s termination grace, a local drain RPC bounded to 5s, and a 10s propagation wait. Other deployments keep their existing probes.
  - [x] Record provisioning and pause/wait/manual-update procedures in GitOps `docs/handbook/runbooks/nightly-playwright.md`, preserving durable fixtures without database resets or automatic migration reversal.
  - [ ] Review and land the GitOps changes with passing hosted validation. Configure protected `master`, required up-to-date `validate` checks, signed bot commits, and unattended automatic squash merge. Provision one GitOps App in `nightly-deploy` for PR operations and cleanup. Verify actual App permissions and trusted-branch policies for `nightly-ui` and `nightly-deploy`; build/browser and PR/fork jobs receive no GitOps credentials.
  - [ ] Provision persistent database/object storage, HTTPS ingress, runtime secrets, image pull access, private assets, and all tagged integration fixtures, including Canvas, Moodle, and Dot. In a separate reviewed change, enable the record with a capable published Playwright image before activating `/readyz` and draining. The application source branch never changes the GitOps destination branch.
- Testing Tasks:
  - [x] Run 18 local automation tests covering allowed diffs/comments, invalid targets, conflicts/denied review, bounded waits, cancellation/late merge, current-run PR ownership, and accepted-branch checks.
  - [x] Run `python3 scripts/validate_deployments.py`, `python3 scripts/validate_gitops_policy.py`, `python3 scripts/validate_followups.py`, and required static Kustomize renders. Check probes/hooks, replicas, image parity, persistent volumes, and unaffected overlays without cluster contact.
  - [ ] Demonstrate actual bot merge/check enforcement and cleanup under the configured policy. Verify fixture connectivity and durable storage/mailbox behavior. In an explicitly authorized disposable deployment, verify slow boot, database outage/recovery without liveness restarts, and graceful termination. Record evidence for reuse in Phase 6.
- Definition of Done:
  - Local changes are reviewed and landed; the target is enabled with compatible configuration; live permissions, integrations, persistence, and lifecycle checks pass. Static tests alone do not close the phase.
- Gate: G5 — provisioned target and verified GitOps permissions/update path. It remains open.
- Evidence: `docs/exec-plans/current/nightly-playwright-ci/phase-5-execution.md`; the GitOps runbook lists the remaining closeout steps and owners.
- Policy audit (2026-10-13): auto-merge is disabled, no validation check is required, and existing `master` rules require signed commits and one approval. `nightly-ui` has no branch restrictions. These observations are provisioning gaps, not current launch evidence.
- Dependencies: G1/G3 before activating new probes; G4 defines runner configuration. Phase 6 workflow implementation may proceed while provisioning is incomplete, but live launch cannot.
- Parallelizable Work: GitOps policy/secrets/fixture provisioning and Phase 6 local workflow integration; serialize live target changes.

## Phase 6: Integrate, verify, and launch the nightly workflow

- Goal: Connect the existing build and browser jobs through GitOps deployment and public readiness, then prove the complete workflow is ready for unattended use.
- Coverage: All FR-001 through FR-010. Integration and launch cover AC-001, AC-002, AC-003, AC-004, AC-007, AC-008, AC-009, AC-010, AC-011, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020, AC-021, AC-022, AC-023, AC-024, AC-025, AC-026, AC-027, AC-028, AC-029, AC-030, AC-031, AC-034, AC-035, AC-040, AC-041, AC-042. Reuse earlier proof for unchanged application/release behavior.
- Existing implementation to retain: `build-playwright` publishes full-SHA/run/attempt images with source/version/digest outputs; scheduled/manual source selection, workflow-level locking, browser checkout at the build SHA, finite job timeouts, and both 14-day artifact uploads exist. `playwright.nightly.config.ts` already supplies line/HTML reporting and privacy settings. The browser workflow does not yet use that config or wait for deployment/readiness. Preserve the independent `nightly-scenarios` job and the existing PR workflow.
- Manual `publish_only` dispatch supports initial provisioning: build/publish runs while browser and scenario tests are skipped. When adding `deploy-plasma`, skip it for this mode as well. The input defaults to false and does not change scheduled runs.
- Tasks:
  - [ ] In `build-playwright`, run clean automation dependency installation under the existing workflow lock. Keep scheduled master resolution and manual dispatch-SHA/rerun behavior; record workflow SHA separately. Build and publish without GitOps preflight or credentials.
  - [ ] Add `deploy-plasma` with `needs: build-playwright` and environment `nightly-deploy`. Use the existing App for PR operations and cleanup. Do not add a preflight stage or check for earlier bot PRs. A failed deployment may leave an unused published image. Consume existing source/image outputs, fetch reviewed GitOps `master`, and use the existing updater to prepare only the allowed record diff. Run GitOps validation, create a signed run-owned bot branch/PR, and call the existing wait/settle helper. Recover the PR by its unique branch if creation returns an uncertain result. Revalidate a fresh PR after conflicts; do not duplicate helper logic or force-push. Obtain GitOps credentials only in this job and retain finalization under the workflow lock, including failures before merge waiting starts.
  - [ ] After accepted GitOps intent, poll the public HTTPS `/readyz` endpoint at the exact nightly host. Require HTTP 200 JSON with string `status: ready` and exact expected version/full SHA. Reject redirects, userinfo, TLS bypass, cookies, and infrastructure authentication. Use a monotonic 20-minute deadline, 10-second polling, and at most 10 seconds per request, clamped to remaining time. Keep diagnostics bounded; never store raw bodies. Implement ordinary workflow steps with local fixture checks; no new CI framework or script directory.
  - [ ] Set browser dependencies to both build and deployment, retain the build-SHA checkout, install Chrome, and invoke `npx playwright test --config playwright.nightly.config.ts --grep @nightly`. Remove the `--reporter=line` override. Let existing tests perform setup and retain their skip behavior; add no asset/configuration preflight, suite inventory, or custom result validator.
  - [ ] Finish always-attempted stage summaries and PR cleanup without masking build/deploy/browser failures. Retain existing artifact names/paths and 14-day retention. Report source/workflow identities, image tag/digest, accepted GitOps commit, readiness observation, stage outcomes, and report links. Say the expected version/commit was observed before testing; do not claim continuous or all-replica identity. Pre-test failure reports browser execution as skipped.
  - [ ] Complete the Torus operator instructions in `assets/automation/tests/resources/nightly-ci.md` for workflow triage, cancellation/stale PR recovery, pending-run policy, private artifacts, and failed-run cleanup. Link to the GitOps provisioning/maintenance runbook instead of duplicating it. Document how to pause scheduled execution while retaining manual verification and the independent scenario job; preserve the existing daily schedule and manual trigger for launch.
- Testing Tasks:
  - [ ] Fixture-test the new readiness step against matching/old/malformed identity, HTTP/network failures, redirects/TLS policy, and deadline clamping. Check that failed deployment or readiness prevents browser invocation.
  - [ ] Test the new workflow connections: failed build/push or record validation does not update GitOps; failed merge does not start readiness/tests; PR creation uncertainty and cancellation reach settlement; failed or timed-out tests remain failures after summary/upload attempts. Reuse GitOps helper tests for its internal cases.
  - [ ] Lint workflows and check source propagation, job dependencies, action versions, credential scope, shared concurrency, unchanged PR/scenario behavior, nightly config invocation, and artifact settings. Use targeted checks for the changed wiring; repeat existing component tests only after relevant changes or when evidence is insufficient.
  - Commands: `actionlint .github/workflows/nightly-playwright.yml .github/workflows/pr-playwright.yml`, applicable formatting, targeted workflow fixtures, and `git diff --check`. Apply `docs/CODEREVIEW.md` to changed surfaces and resolve findings. Full `mix test` is required when shared test support/configuration changes; no benchmark or new domain scenario is needed for workflow-only work.
- Launch Checklist:
  - [ ] Confirm G1–G5 are satisfied and record the exact source/image/GitOps identities. Reuse valid release, probe/drain, mailbox, fixture, and permission evidence from earlier phases; rerun only changed or previously unverified behavior.
  - [ ] Run the full workflow manually and verify every intended tagged integration executes, including adaptive, Canvas, Moodle, and Dot. Inspect normal reports for skipped configuration-dependent cases and fix missing provisioning before accepting launch evidence. This is an operator review, not a new blanket skip-failure rule. Review artifact access, diagnostic usefulness, and sensitive content before scheduled execution.
  - [ ] Exercise the connected workflow's readiness mismatch/timeout, failed prerequisites, cancellation/late-merge recovery, and overlapping runs. Verify tests never start against the wrong revision and updates cannot occur during another run's test interval. Demonstrate a non-master manual dispatch keeps the same source ref/SHA through build, deployment, readiness, and browser checkout; verify rerun stability. Check durable fixtures and mailbox behavior after the actual deployment, reusing valid Phase 5 evidence where applicable.
  - [ ] After the manual checks pass, permit the existing scheduled entry point and record one successful scheduled end-to-end run. Preserve the shared concurrency/pending-run policy and the independent scenario job. Missing scheduled evidence keeps the phase open.
  - [ ] Finish the operator handoff, record actual proofs for every nested acceptance criterion in `requirements.yml`, reconcile docs, and run work-item plus final requirements verification. Static validation alone is not operational proof.
- Definition of Done:
  - The workflow builds, deploys, verifies, and tests one source revision; failures and cleanup behave correctly; manual and scheduled runs execute the intended suite with useful private diagnostics. Required review, evidence, and operator handoff are complete.
- Gate: G6 — implementation and launch complete, including AC-029 and all remaining acceptance criteria. Local integration checks permit a controlled manual run after G5; they do not close G6 or authorize unattended launch by themselves.
- Dependencies: G1–G5 for live launch. Local integration and fixture checks may proceed earlier against the fixed contracts.
- Parallelizable Work: Workflow integration, targeted checks, and runbook preparation; serialize live deployment/test exercises and complete review while awaiting scheduled evidence.

## Parallelization Notes

- The critical path is G1 → G2 → G3 → G5 → G6, with G4 feeding G5/G6. Early independent work includes automation dependency/reporting changes, local readiness step checks and GitOps static preparation.
- Configuration, captcha/server behavior and PR workflow migration form one landing unit. Coordinate shared router, runtime, release, fixtures and workflow files instead of merging partial contracts.
- Separate Torus and GitOps review boundaries; use relative GitOps paths and record reviewed commits as evidence. Static preparation can overlap, but deploying new probes requires a capable image.
- Serialize all mutations and tests on the durable target, including operational fault exercises. Independent disposable environments may be used for failure testing.

## Phase Gate Summary

| Gate | Exit evidence | Unlocks |
| --- | --- | --- |
| G1 | Probe/lifecycle tests and consumer inventory | PR readiness integration and release checks |
| G2 | Shared environment, secure helpers and unchanged full PR coverage | Shared release packaging |
| G3 | Real release fixture/mailbox smoke tests and production/cache isolation | Deployment activation and publication |
| G4 | Clean dependency install, direct selection, normal failure behavior and standard reports | Nightly execution integration |
| G5 | Reviewed GitOps contract/manifests, live provisioning and permission checks | Accepted automated deployment updates |
| G6 | Integrated workflow, manual/scheduled proof, failure handling, reviews, and operator handoff | Complete implementation and unattended operation |

## Plan Validation

Resolve `HARNESS_SKILLS_ROOT` to the installed harness directory containing `plan/`, `requirements/` and `validate/`, independently of the repository working directory. Run:

```sh
python3 "$HARNESS_SKILLS_ROOT/requirements/scripts/requirements_trace.py" docs/exec-plans/current/nightly-playwright-ci --action verify_plan
python3 "$HARNESS_SKILLS_ROOT/requirements/scripts/requirements_trace.py" docs/exec-plans/current/nightly-playwright-ci --action master_validate --stage plan_present
python3 "$HARNESS_SKILLS_ROOT/validate/scripts/validate_work_item.py" docs/exec-plans/current/nightly-playwright-ci --check plan
git diff --check
```

The installed traceability script reads top-level acceptance criteria, while this work item's criteria are nested under requirements. Supplement its checks by traversing every requirement's `acceptance_criteria`, verifying all 42 IDs are referenced in both FDD and plan, and checking for unknown/duplicate IDs. Inspect each numbered phase for goal, tasks, testing, definition of done, gate, dependencies and parallelization. These checks validate planning artifacts only.

At final Phase 6 closeout, also run:

```sh
python3 "$HARNESS_SKILLS_ROOT/requirements/scripts/requirements_trace.py" docs/exec-plans/current/nightly-playwright-ci --action verify_implementation
python3 "$HARNESS_SKILLS_ROOT/requirements/scripts/requirements_trace.py" docs/exec-plans/current/nightly-playwright-ci --action master_validate --stage implementation_complete
```

Because the installed script does not traverse nested criteria, separately inspect all
42 nested entries for verified status and actual proof before declaring launch complete.
The documentation reconciliation does not promote statuses or manufacture proof.

## Decision Log

| Date | Decision | Reason and evidence |
| --- | --- | --- |
| 2026-10-14 | Fold former Phase 7 into Phase 6's launch checklist; G6 is the final gate. Split completed Phase 5 code from remaining provisioning. | User approved reconciliation with the implemented build workflow, nightly config, GitOps helpers, and execution records. Reuse valid component evidence while retaining manual/scheduled runs and failure/privacy checks. |
| 2026-10-14 | Preserve test-owned setup/skips and include all current tagged integrations. The earlier build-preflight credential proposal is superseded by the next decision. | Aligns AC-022 with the approved Phase 4 scope. |
| 2026-10-14 | Use one App in `nightly-deploy`; remove the second App/read-only credential requirement. | Build and browser jobs have no GitOps access. The intermediate deployment-preflight proposal is superseded below. Phase 6 owns workflow wiring. |
| 2026-10-14 | Remove standalone GitOps preflight and checks for earlier bot PRs. | User requested simpler deployment orchestration. Retain current-record validation, GitHub merge enforcement, current-run acceptance verification and cleanup; orphaned PR recovery is manual. |
| 2026-10-14 | Support manual publish-only provisioning. | Initial target needs a published Playwright image before browser tests can run. Add a default-off dispatch input that skips tests; Phase 6 must also skip deployment for that mode. Normal schedules and manual runs retain the full pipeline. |
