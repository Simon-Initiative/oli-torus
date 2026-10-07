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

Preserve PR triggers, tested checkout, `@pr` coverage and disposable services, and preserve the independent `nightly-scenarios` job. Include all current `@nightly` cases, including adaptive, Canvas LTI and Dot. Keep production captcha behavior and compile-time test-route exclusions intact. No domain schema change, production UI redesign, database reset, automatic migration rollback, new feature flag, asset-versioning system, scheduled cleanup service, or custom results validator is included.

Per `harness.yml`, telemetry is delivered through stage summaries, provenance and standard Playwright reports. Existing AppSignal monitoring remains unchanged. Security and performance review apply throughout; throughput benchmarks, custom timing instrumentation and performance budgets are excluded by the approved design. Timeouts and probe lifecycle correctness remain mandatory. Browser helper changes follow `assets/automation/AGENTS.md`; new domain scenarios are needed only if implementation expands into domain workflow behavior.

## Clarifications & Default Assumptions

- No design questions remain open. Provisioning values and operational evidence are implementation gates, not reasons to reopen approved decisions or claim completion early.
- Preserve daily `17 5 * * *` and manual dispatch. Both select protected `refs/heads/master` once after acquiring the target lock; manual reruns select current master anew. Record workflow SHA separately from source SHA.
- Use one `nightly-playwright` job, group `nightly-playwright-plasma`, and `cancel-in-progress: false`. A newer pending run may replace an older pending run; an active run completes. The lock spans preflight through finalization.
- Default merge wait is 15 minutes; readiness is 20 minutes with 10-second polling and a maximum 10-second request timeout, all clamped to the remaining deadline. Keep finite job/browser timeouts, one Chrome worker and one retry.
- GitOps maintainers own deployment/secrets/branch policy; QA/test owners own private assets and Canvas/Dot fixtures; Torus maintainers own application/workflows/automation credentials, triage and stale-data cleanup.
- When Phase 5 needs a local GitOps checkout, request its location if unknown. Use it only for that session and never persist the local path. GitOps file paths below are relative to that repository root. Planning does not require accessing that checkout.
- Supply actual external URLs, credentials and protected branch during provisioning. Canvas must launch into nightly Torus; Dot initially uses a dedicated existing fixture there. Neither integration may be silently excluded to unblock launch.
- A public version/SHA observation does not prove all-replica convergence or distinguish same-source rebuilds. Retain the digest as provenance; no post-test identity check is required.
- Every task below starts incomplete. Keep requirements proposed and proofs empty until actual implementation evidence is recorded; document validation and historical experiments do not satisfy operational acceptance criteria.

## Phase 1: Application lifecycle and probe contracts

- Goal: Establish the application contract consumed by PR startup, GitOps probes and nightly identity polling.
- Coverage: FR-005 — AC-012, AC-013, AC-014, AC-039, AC-040, AC-042; application prerequisites for AC-041.
- Tasks:
  - [ ] Add documented `Oli.Health` APIs in `lib/oli/health.ex` for starting/running/draining state, liveness and readiness. Reset on each application start, mark complete after successful supervision and mandatory initialization, and never overwrite a requested drain with startup completion.
  - [ ] Wire `lib/oli/application.ex` startup and `prep_stop/1`; expose idempotent drain through a local release function in `lib/oli/release.ex`, with no HTTP mutation endpoint.
  - [ ] Check only named `Oli.Repo`, `Oli.PubSub` and `Oli.Vault` availability plus a normal-pool `SELECT 1`. Bound checkout and query together to one second, cancel expired work and recheck draining before returning ready. Exclude NodeJS and external dependencies.
  - [ ] Replace the existing health controller/view response with local-only 503 `starting` or 200 `ok`; add `/readyz` controller/view returning 200 `ready` or 503 `not_ready`, each with only compiled string version/SHA. Add unauthenticated routes, no-store headers and both HTTP probe exemptions in `lib/oli_web/plugs/ssl.ex`.
  - [ ] Inventory readiness consumers of `/healthz`; assign PR migration to Phase 2 and GitOps migration to Phase 5. Preserve rollout ordering: capable images precede activation of new readiness probes.
- Testing Tasks:
  - [ ] Add focused ExUnit coverage for exact bodies/status/headers, unauthenticated HTTP without redirects, compiled identity and absence of dependency calls from liveness. An old but ready build returns 200 with its own identity.
  - [ ] Exercise startup/reset, missing/recovered required services, NodeJS unavailability, exhausted DB pool, disconnection/query errors/timeouts and drain during a query. Assert the total DB budget and absence of accumulating work; isolate lifecycle mutations and capture intentional logs.
  - [ ] Verify actual graceful release shutdown marks draining while HTTP remains available; repeat operational termination checks in Phase 7.
  - Commands: `mix format --check-formatted` and targeted `mix test` for health, readiness, SSL and lifecycle modules. Add `mix test` in full if shared test support/configuration changes. Run Mix commands with scoped escalation under the Codex repository contract.
- Definition of Done:
  - Exact public contracts and lifecycle transitions pass focused tests; liveness stays healthy during database outage/draining, and readiness fails safely within its budget.
- Gate: G1 — application probe contract verified; no infrastructure consumer is switched ahead of a capable image.
- Dependencies: None.
- Parallelizable Work: Phase 2 configuration/helper drafting and Phase 4 runner work can start against the documented contract; coordinate shared router, release and test files.

## Phase 2: Shared Playwright configuration and atomic PR migration

- Goal: Replace `ci_e2e` with a standalone shared environment while retaining the full PR suite and strengthening the captcha contract.
- Coverage: FR-001, FR-002 — AC-003, AC-005, AC-006, AC-032, AC-033, AC-034, AC-035, AC-036, AC-037, AC-038; PR consumer portion of AC-042.
- Tasks:
  - [ ] Add `config/playwright.exs` with direct compile-time scenario/mailbox enablement, `Oli.Playwright.Recaptcha`, `Swoosh.Adapters.Local`, release assets and `env: :playwright`. Disable development debug/reload/watch settings without importing `dev.exs`; retain normal origin checks and exclude preview QA defaults.
  - [ ] Extend release runtime/SSL branches, `mix.exs` permanence and endpoint static gzip handling for `:playwright`. Load scenario/mailbox and captcha tokens only at runtime; fail boot for absent/empty required tokens. Permit PR boot without private-assets configuration; asset-dependent operations still fail clearly when unavailable.
  - [ ] Implement constant-time exact nonempty token verification with locally rejected invalid/malformed inputs and no Google fallback. Route remaining direct captcha calls through compile-selected `Oli.Recaptcha`; preserve production selection regardless of runtime test-token presence.
  - [ ] Omit Google widgets/scripts only in Playwright while retaining submission fields. Add a Torus-origin-scoped shared helper under `assets/automation/src/core/` for standard and LiveView forms. Migrate registration in `CredentialAccountPO.ts`, enrollment in `StudentCoursePO.ts` and payment support; audit other exercised protected forms, including invitation/LTI flows.
  - [ ] Redact captcha fields in request logs and prevent token-bearing traces/attachments in both CI paths. Avoid token values in helper step decorators, assertions and error messages; missing runner configuration fails before submission.
  - [ ] Migrate `.github/workflows/pr-playwright.yml` with explicit disposable database, local HTTP, signing/encryption and storage boot inputs; generate separate job-scoped scenario and captcha secrets using at least 32 random bytes. Build frontend/server/Tailwind/digested assets through the release pipeline before `mix phx.server`, and wait on `/readyz`.
  - [ ] Delete `config/ci_e2e.exs` and migrate active scripts/config/docs/cache references in the same landing change. Retain no alias, wrapper or fallback. Preserve PR triggers, checkout, `@pr`, create/migrate/seed and runner-owned teardown.
  - [ ] Key compile caches by environment, configuration, toolchain and lockfiles; separate PR, trusted nightly and production namespaces. Prevent broad restore fallbacks from loading incompatible compile artifacts.
- Testing Tasks:
  - [ ] Test matching/wrong/missing/empty/non-string captcha responses, absent server token, rotation without rebuild, no Google calls, compile-time immutability and production behavior. Check standard/LiveView token submission, origin restrictions and missing-runner-token failure.
  - [ ] Verify local mail retrieval by unique recipient/ID, optional subject filtering and missing/wrong-token rejection; confirm messages are never sent through SES/SMTP and diagnostics omit email/reset content.
  - [ ] Run clean and cached PR builds, mutate compile configuration to verify invalidation, and run the complete existing `@pr` suite including registration/confirmation/reset plus affected enrollment/payment specs with their required fixtures.
  - [ ] Audit active `ci_e2e` references and dev imports; historical migration notes may retain the retired name. Confirm PR requires no nightly secrets, private assets, publish or GitOps access.
  - Commands: affected ExUnit modules and formatting; frontend targeted `yarn test`/`yarn lint` from `assets/` as applicable; `npm ci`, `npx playwright install --with-deps chrome`, and `npx playwright test --grep @pr` from `assets/automation/` with explicit local runtime inputs. Run full `mix test` whenever shared test support/configuration changes and require clean ExUnit output.
- Definition of Done:
  - Shared compile selections, runtime secret boundaries, mailbox authorization and token helpers pass; the full PR suite works with its original isolation and source selection.
- Gate: G2 — land configuration, captcha helpers, PR migration and environment deletion together only after G1 and PR verification pass.
- Dependencies: G1 for PR startup waiting and integrated lifecycle verification.
- Parallelizable Work: Server verifier and browser helper work can proceed against the same token contract, but merge and verify together. Phase 4 dependency work can proceed independently.

## Phase 3: Release packaging and build isolation

- Goal: Produce a release that boots with the same capabilities and can serve every selected test's runtime fixtures without embedding secrets.
- Coverage: FR-002, FR-003, FR-009 — AC-004, AC-005, AC-006, AC-007, AC-034, AC-036, AC-025, AC-026.
- Tasks:
  - [ ] Update `Dockerfile` and `.dockerignore` for standalone Playwright builds, full source SHA and configuration-sensitive layers, preserving the production default. Keep `_build` isolated by environment/trust boundary and exclude dependencies/reports/downloaded assets/local secrets from the build context as required by the FDD.
  - [ ] Audit selected PR/nightly fixture paths in scenario/support-asset endpoints. Package only demonstrated public fixture needs under `priv/` and resolve application paths while preserving local behavior. Keep private archives in object storage; do not add `test/support` or preview seeds to Playwright compilation paths.
  - [ ] Build source/version OCI metadata and define the unique `sha-<full SHA>-playwright-<run ID>-<attempt>` publication interface in the existing GHCR repository. Verify compiled identity before publication; collision checks and push failure handling integrate in Phase 6.
  - [ ] Supply runtime ExAws/bucket/service credentials through deployment inputs; retain release setup migrations and persistent services. Document mailbox reset on process restart and the one-replica requirement for Phase 5.
- Testing Tasks:
  - [ ] Build clean and cached Playwright and production images independently, including configuration/source invalidation. Boot Playwright against disposable services with runtime secrets; verify identity, authenticated scenarios/private assets/mailbox and required files/modules.
  - [ ] Build production with no capability flags and boot with a runtime test token present: routes remain excluded and normal captcha remains selected. Inspect image history/layers and metadata for secret leakage and correct full SHA/version.
  - [ ] Restart the release and verify a fresh instance-local mailbox while database/object storage and integration fixture data persist; reject absent tokens and unauthorized asset/mailbox requests.
  - Commands: `docker build --build-arg MIX_ENV=playwright --build-arg SHA="$SOURCE_SHA" -t torus-playwright-smoke .` and a separate `MIX_ENV=prod` image build; isolated release smoke harness added during implementation. Never provide runtime secrets as build arguments.
- Definition of Done:
  - Actual release smoke evidence resolves the deferred fixture and mailbox audits; clean/cached production isolation is demonstrated.
- Gate: G3 — release artifact is ready for registry publication and separately reviewed deployment provisioning.
- Dependencies: G1 and G2.
- Parallelizable Work: Phase 4 runner configuration and Phase 5 static GitOps preparation; live provisioning verification waits for this release.

## Phase 4: Nightly runner configuration, dependencies and diagnostics

- Goal: Execute tags directly with explicit integration configuration and useful, private reports.
- Coverage: FR-008, FR-009, FR-010 — AC-021, AC-022, AC-023, AC-024, AC-030, AC-031, AC-026, AC-027, AC-028.
- Tasks:
  - [ ] Declare `json-rules-engine` directly in automation and regenerate `package-lock.json` through npm. Recheck product `assets/yarn.lock` and align resolved versions (6.1.2 at discovery).
  - [ ] Add `playwright.nightly.config.ts` extending shared settings with line plus HTML (`open: never`) reporters, Chrome, one worker, one retry and traces disabled, preserving Dot trace-off behavior. Disable any other attachments demonstrated to contain secrets.
  - [ ] Audit the eight adaptive cases' tags once and retain current Canvas/Dot inclusion. Use source tags alone: no manifest, separate `--list` step, custom results validator or blanket skip-failure rule.
  - [ ] Implement nightly required-configuration checks at the relevant runner/setup boundary. Require exact nightly origins, scenario and automation API credentials; validate authenticated access/formats for the eight archives and seven answer files documented in adaptive setup. Missing selected-test inputs fail setup, preserving optional local behavior.
  - [ ] Require explicit Canvas account/API/instructor/tool/launch configuration and dedicated Torus admin credentials with matching Torus origin. Require Dot's protected parameter URL, validate its target and existing-fixture mode, freeze the document in restricted runner temporary storage and consume that same file without a second download.
  - [ ] Delete secret parameter/private download files after use; upload only explicit diagnostic paths. Retain run-specific fixture identities and visible bounded cleanup warnings.
  - [ ] Update `assets/automation/tests/resources/nightly-ci.md` and adaptive setup documentation with configuration ownership, tag selection, asset/answer-key maintenance together and unchanged during active runs, report access and cleanup policy.
- Testing Tasks:
  - [ ] From a clean temporary checkout without parent `assets/node_modules`, run `npm ci` and verify engine parity/import success through direct execution. Prove import errors, zero matches and missing required inputs fail; temporarily tag a fixture test to demonstrate selection without changing another inventory.
  - [ ] Exercise wrong Canvas/Dot origin, missing asset/authentication and changed remote Dot configuration after freezing; ensure failure messages identify the consumer/key without secret content.
  - [ ] Verify reports identify spec/title/project, failures/skips/retries and correct output directories; inspect representative files for tokens, captured emails and private content.
  - Commands from `assets/automation/`: `npm ci`, `npx playwright install --with-deps chrome`, `npx playwright test --config playwright.nightly.config.ts --grep @nightly`. Use isolated fixtures for negative cases and the provisioned target for final full-suite evidence in Phase 7.
- Definition of Done:
  - Direct invocation and setup failures are verified; dependency isolation, target rules, secret handling and standard reporting are covered without a second suite-membership source.
- Gate: G4 — runner is ready to integrate; provisioned Canvas/Dot and full nightly execution remain launch gates.
- Dependencies: G2 for shared captcha behavior; G3 for release-based asset/mailbox verification. Dependency/configuration development may start earlier.
- Parallelizable Work: Runner dependencies/reporters can proceed alongside Phases 1–3; integrate shared captcha fixture edits with Phase 2.

## Phase 5: GitOps update contract and target provisioning

- Goal: Establish a reviewed deployment and a bounded, content-preserving bot-PR update path.
- Coverage: FR-004, FR-005, FR-007, FR-009 — AC-009, AC-010, AC-011, AC-041, AC-042, AC-020, AC-025, AC-026; provisioning for AC-023 and AC-034.
- Tasks:
  - [ ] Obtain the GitOps checkout path when needed, read its local instructions and inspect current files. In `scripts/update_deployment_record.py`, preserve comments/unrelated content and limit automated changes to `imageTag`, `metadata.sourceRef`, `metadata.commitSha` in `deployments/nightly-playwright.yml`.
  - [ ] Add preflight validation for app/slug, enabled state, staging overlay, public access and exact hostname. Recurring updates pass only record/image/source/SHA options and never create, enable or repair infrastructure.
  - [ ] Establish the configured protected branch, required checks and scoped GitHub App permissions for automatic bot-PR merge. Implement accepted-branch reread, conflicts/revalidation, a 15-minute default deadline, run-owned PR cleanup on cancellation/timeout and stale-prior-PR reconciliation before new intent. No direct-commit fallback.
  - [ ] Separately provision persistent database/object storage, public HTTPS ingress, runtime secrets, image pull access, one replica and Canvas/Dot fixtures. Verify `nightly-ui` supports unattended runs and privileged credentials remain unavailable to PRs/forks.
  - [ ] Review application/setup-container image parity and probe/drain manifests. Initial startup `/healthz`: period 5s, timeout 2s, failure threshold 60; liveness `/healthz`: 15s/2s/3; readiness `/readyz`: 5s/2s/2; all success thresholds 1. Startup gates normal probes; remove redundant initial delays.
  - [ ] Set 60s termination grace, a local release drain RPC bounded to 5s and 10s propagation wait. Activate `/readyz` only after a capable image, including every affected overlay. Keep unrelated deployments out of an unsafe base-manifest migration.
  - [ ] Record operator ownership: pause new runs and wait for active completion before manual updates; preserve durable fixtures during repair, with no resets or automatic migration reversal.
- Testing Tasks:
  - [ ] Fixture-test exact allowed diffs and comment preservation; disabled/wrong target records, conflicts, denied checks, merge timeout, cancellation, raced/late merges and stale PRs all prevent unsafe downstream execution.
  - [ ] Run `python3 scripts/validate_deployments.py`, `python3 scripts/validate_gitops_policy.py` and that repository's required static render/check commands; inspect probes/hooks, replicas, image parity and all affected overlays without cluster contact.
  - [ ] In an authorized disposable deployment, demonstrate slow boot, database outage/recovery and graceful termination; no dependency-induced liveness restarts. Verify actual bot/environment permissions and fixture connectivity before unattended launch.
- Definition of Done:
  - GitOps changes are reviewed, the target is provisioned and compatible, and branch/environment policy plus update lifecycle are verified; static checks alone do not satisfy operational evidence.
- Gate: G5 — safe deployment writer and provisioned target are available. Missing infrastructure inputs hold this gate while independent Torus work continues.
- Dependencies: G1/G3 before activating new probes or completing live checks; G4 defines integration configuration needs.
- Parallelizable Work: Static updater/manifests and secret/fixture preparation may run alongside Phases 2–4; reviewed live activation follows capable release availability.

## Phase 6: Serialized build-to-test orchestration

- Goal: Connect the verified boundaries in one trusted job with bounded failure handling and attributable results.
- Coverage: FR-001, FR-003, FR-004, FR-006, FR-007, FR-008, FR-010 — AC-001, AC-002, AC-003, AC-007, AC-008, AC-009, AC-010, AC-011, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020, AC-024, AC-027, AC-028, AC-031.
- Tasks:
  - [ ] Add testable command functions in `scripts/ci/nightly_playwright.py` and focused tests under `scripts/ci/tests/` for provenance, preflight, public readiness and sanitized summaries. Validate input URLs/refs/paths and pass separate subprocess arguments rather than interpolating shell source.
  - [ ] Preserve triggers and the independent scenario job; restrict privileged manual execution to protected master. Acquire the job-level target lock, resolve/checkout master once, record source version/full SHA plus workflow SHA/run/attempt and reject unresolved prior updates before publication.
  - [ ] Order clean automation dependency install, build/metadata verification, unique-tag collision check and publish/digest capture, validated GitOps bot PR/merge confirmation, public readiness, authenticated target setup, Chrome install and direct tagged invocation. Failed publication leaves GitOps unchanged; failed prerequisites prevent tests.
  - [ ] Implement readiness input validation and monotonic deadline bounds. Require HTTPS at the configured host, no userinfo/redirects/TLS bypass/cookies/infrastructure auth; accept only 200 JSON with exact string status/version/full SHA. Store only bounded categories and allowlisted identities, never raw bodies.
  - [ ] Scope publish permissions and obtain GitOps credentials only for necessary record/PR operations; remove them before browser execution. Disable persisted checkout credentials and pin newly introduced actions to reviewed immutable revisions. Configure caches per Phase 2/3 trust boundaries.
  - [ ] Keep a finite browser step and preserve its exit status through `if: always()` summary/artifact attempts. Upload available `assets/automation/playwright-report/` as `playwright-report` and `assets/automation/test-results/` as `playwright-test-results`, each for 14 days. Pre-test failure reports skipped browser execution, without fabricating results.
  - [ ] Report every stage outcome, source/workflow identity, image tag/digest, accepted GitOps commit, expected/observed readiness and report links. Use the FDD wording that the expected version/commit was observed before testing. Clean temporary secrets and settle pending bot PRs within finalization while retaining the target lock.
- Testing Tasks:
  - [ ] Local HTTP fixtures/fake clocks cover valid identity, wrong version/SHA, missing/non-string fields, malformed JSON, login HTML/redirects, non-200, connection errors, TLS policy and remaining-deadline clamping. Assert browser command is never invoked on readiness/setup failure.
  - [ ] Test immutable tag collision, build/push/check/merge failures, master advancing after resolution, non-master dispatch, cancellation/late merge and runner-loss stale-update recovery. Verify downstream calls and final stage statuses.
  - [ ] Inject nonzero Playwright exit/timeout and summary/upload success/failure; verify the original browser failure remains visible. Check artifact paths/names/retention and no report override removes HTML.
  - [ ] Lint workflows and compare PR triggers/checkout/selection plus the full scenario job against baseline. Test job-scoped concurrency configuration without serializing the backend scenario job.
  - Commands: `python3 -m unittest discover -s scripts/ci/tests`, `actionlint .github/workflows/nightly-playwright.yml .github/workflows/pr-playwright.yml`, applicable formatting checks and `git diff --check`. Harness tests use fixture subprocess/HTTP boundaries; they do not deploy to the durable target.
- Definition of Done:
  - Ordered execution, single source selection, credential boundaries, failure preservation and finalization are verified locally; external services remain the deployment actors specified by the design.
- Gate: G6 — integrated workflow is ready for a provisioned manual run; unattended rollout remains gated on Phase 7.
- Dependencies: G1–G5 for integrated completion. Helper unit tests and workflow drafting may proceed earlier against fixed contracts.
- Parallelizable Work: Readiness/summary helper tests can proceed alongside GitOps implementation; one owner integrates workflow mutations and run-owned PR cleanup.

## Phase 7: Operational proof, review and launch

- Goal: Demonstrate actual end-to-end behavior and establish a usable operator handoff before declaring implementation complete.
- Coverage: All FR-001 through FR-010; operational closure of AC-003, AC-004, AC-010, AC-019, AC-020, AC-021, AC-022, AC-023, AC-025, AC-026, AC-027, AC-028, AC-029, AC-034, AC-035, AC-040, AC-041, AC-042.
- Tasks:
  - [ ] Complete the FDD's deferred probe/drain, fixture/mailbox, single-replica and unattended-permission audits using actual releases/deployments. Capture sanitized evidence with source/image/GitOps identities and run links.
  - [ ] Run the full manual workflow against the provisioned target, including every tagged integration. Review reports and retained artifacts for usefulness/access/privacy before enabling unattended execution; fix missing configuration rather than skipping integrations.
  - [ ] Enable and observe the scheduled entry point after the manual gate passes. Record one manual and one scheduled successful end-to-end run, including selected tests and their outcomes.
  - [ ] Complete `assets/automation/tests/resources/nightly-ci.md` with stage triage, pending policy, pause/wait/manual-update procedure, failed-run cleanup preserving fixtures, mailbox restart behavior, asset ownership, PR cancellation recovery and reviewed rollback with database-compatibility assessment.
  - [ ] Apply `docs/CODEREVIEW.md`: delegate security/performance and relevant Elixir/TypeScript/UI checklists to dedicated reviewers, consolidate findings and resolve them. Add requirements review if PRD changes and Gleam review only if relevant source/configuration changes. Run tests before implementation commits.
  - [ ] Record actual proofs against nested acceptance criteria in `requirements.yml` and reconcile documentation if implementation drifts. Do not mark criteria verified solely from prose or static validation.
- Testing Tasks:
  - [ ] Exercise old-revision polling, readiness deadline and setup failure: browser execution must not start against an unintended target. Observe expected identity from public HTTPS and both endpoints over pod HTTP.
  - [ ] Overlap manual/scheduled dispatches to verify the active interval cannot overlap and the documented pending policy holds. Demonstrate cancellation/stale-PR recovery and the manual operator procedure without changing a deployment during tests.
  - [ ] Verify database/object storage/integration fixtures survive updates, mailbox resets, unique-recipient isolation and visible cleanup failures. Recheck slow startup, outage recovery and graceful termination evidence with the reviewed manifests.
  - [ ] Re-run affected test targets after fixes; full `mix test` is required for changes to shared test support/configuration. Preserve clean ExUnit output and the existing PR suite. No benchmark or new domain scenario is required absent expanded scope.
  - [ ] Run the plan/traceability checks below and inspect operational proof coverage independently of script success.
- Definition of Done:
  - Manual and scheduled runs execute all selected cases against the expected source with attributable outcomes; negative cases, concurrency, durability and artifact privacy are evidenced; required reviews are resolved and operators have a runbook.
- Gate: G7 — implementation and launch complete only when AC-029 and all remaining acceptance criteria have actual proof. External provisioning or missing scheduled evidence keeps completion pending.
- Dependencies: G1–G6; unattended scheduling follows a successful manual run and artifact review.
- Parallelizable Work: Review and runbook completion may proceed while awaiting the scheduled run; live deployment/test/incident exercises remain serialized.

## Parallelization Notes

- The critical path is G1 → G2 → G3 → G5 → G6 → G7, with G4 feeding G5/G6. Early independent work includes automation dependency/reporting changes, local readiness helper tests and GitOps static preparation.
- Configuration, captcha/server helpers and PR workflow migration form one landing unit. Coordinate shared router, runtime, release, fixtures and workflow files instead of merging partial contracts.
- Separate Torus and GitOps review boundaries; use relative GitOps paths and record reviewed commits as evidence. Static preparation can overlap, but deploying new probes requires a capable image.
- Serialize all mutations and tests on the durable target, including operational fault exercises. Independent disposable environments may be used for failure testing.

## Phase Gate Summary

| Gate | Exit evidence | Unlocks |
| --- | --- | --- |
| G1 | Probe/lifecycle tests and consumer inventory | PR readiness integration and release checks |
| G2 | Shared environment, secure helpers and unchanged full PR coverage | Shared release packaging |
| G3 | Real release fixture/mailbox smoke tests and production/cache isolation | Deployment activation and publication |
| G4 | Clean dependency install, direct selection, configuration/privacy/report checks | Nightly execution integration |
| G5 | Reviewed GitOps contract/manifests, live provisioning and permission checks | Accepted automated deployment updates |
| G6 | Ordered workflow and negative/finalization tests | Manual end-to-end launch validation |
| G7 | Manual and scheduled proof, operational failures/durability, reviews and runbook | Complete implementation and unattended operation |

## Plan Validation

Resolve `HARNESS_SKILLS_ROOT` to the installed harness directory containing `plan/`, `requirements/` and `validate/`, independently of the repository working directory. Run:

```sh
python3 "$HARNESS_SKILLS_ROOT/requirements/scripts/requirements_trace.py" docs/exec-plans/current/nightly-playwright-ci --action verify_plan
python3 "$HARNESS_SKILLS_ROOT/requirements/scripts/requirements_trace.py" docs/exec-plans/current/nightly-playwright-ci --action master_validate --stage plan_present
python3 "$HARNESS_SKILLS_ROOT/validate/scripts/validate_work_item.py" docs/exec-plans/current/nightly-playwright-ci --check plan
git diff --check
```

The installed traceability script reads top-level acceptance criteria, while this work item's criteria are nested under requirements. Supplement its checks by traversing every requirement's `acceptance_criteria`, verifying all 42 IDs are referenced in both FDD and plan, and checking for unknown/duplicate IDs. Inspect each numbered phase for goal, tasks, testing, definition of done, gate, dependencies and parallelization. These checks validate planning artifacts only.
