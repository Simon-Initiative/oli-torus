# Nightly Playwright CI - Product Requirements Document

## 1. Overview

Build and publish a dedicated Torus image, advance a durable Plasma deployment through GitOps, verify its public readiness and build identity, and run nightly Playwright tests from the same source revision. PR and nightly CI share a standalone `MIX_ENV=playwright` configuration.

This continues [MER-5918](https://eliterate.atlassian.net/browse/MER-5918). The prior test audit and fixes have landed; this work covers execution infrastructure and the targeted test-helper changes needed for it.

## 2. Background & Problem Statement

The original nightly workflow tested an externally configured server without building or deploying it. The implemented workflow now builds and deploys the shared Playwright release, checks public readiness and source identity, and runs browser tests against that revision. Its independent backend scenario job does not supply that server.

The durable target and integration inputs are provisioned. The completed manual workflow demonstrates deployment/readiness gating before browser execution, without Argo CD or Kubernetes credentials in CI. It also exposes test failures for targeted follow-up.

Phase 5 is complete as provisioning. Phase 6 is complete as workflow integration and minimal manual end-to-end verification. Unrelated test, fixture, and application defects move to a separate bug; there is no Phase 7 in this infrastructure work item. First scheduled-run confirmation after normal merge remains a launch follow-up; Phase 6 closure does not claim a green suite or scheduled proof.

## 3. Goals & Non-Goals

### Goals

- Give engineers a repeatable, attributable nightly result for a known source revision.
- Share `config/playwright.exs` between PR and nightly CI, replacing the development-derived `ci_e2e` environment while preserving the PR suite and disposable service lifecycle.
- Enable token-protected mailbox access, local email capture, and token-authorized Playwright reCAPTCHA verification in both workflows through application values set directly in `config/playwright.exs`. Production retains Google verification.
- Automate image publication, GitOps reference updates, application readiness checks, and test execution in order.
- Use `/healthz` for startup/liveness and `/readyz` for readiness and CI build identity. Include application lifecycle state and reviewed GitOps probe/drain configuration in this work.
- Retain a stable public hostname and durable test integrations across application updates.
- Make setup, readiness, and test failures distinguishable and actionable.
- Use `@nightly` tags as the sole source of suite membership. Fail collection/import errors and zero matching tests; preserve existing per-test setup and skip behavior. Report which tests ran and resolve missing integration configuration before unattended launch.

### Non-Goals

- Repairing Playwright tests, fixtures, or application defects unrelated to CI infrastructure. Track the observed failures separately; centralized captcha credential submission remains in scope.
- Replacing the ephemeral PR suite or changing its trigger, source selection, or existing coverage; its compile environment and startup configuration migrate to `playwright`.
- Changing the independent nightly backend scenario job.
- Creating a fresh nightly namespace/database on each run, deploying production, or adding registry image-watching controllers. PR CI retains its disposable database.
- Introducing infrastructure OAuth login, Argo CD/Kubernetes credentials, or a machine-authentication path for readiness checks.
- Proving complete Kubernetes rollout or exact image-digest identity through `/readyz`, or adding an extra build/run identifier to that response.
- Automatically rolling back persistent database migrations after failures.

## 4. Users & Use Cases

- Engineers receive scheduled regression results tied to the application source and test revision, and manually dispatch a selected branch for diagnosis, building and testing the same commit.
- QA inspects failed tests, reports, and the stable nightly environment without rebuilding a local server.
- GitOps maintainers provision the durable deployment, install runtime secrets, and maintain the GitOps deployment policy.
- QA/test owners maintain private assets, answer keys, Canvas/Moodle accounts and registrations, and Dot fixtures.
- Torus maintainers own automation credentials and stale test-data/mailbox cleanup procedures. These responsibilities are role-based; named individuals are not required.
- Maintainers diagnose which stage failed and can stop subsequent runs while repairing the target.

## 5. UX / UI Requirements

No production UI changes. Captcha markup and LiveView hooks stay unchanged. The compile-selected Playwright backend requires a private runtime token. The runner supplies it during form serialization and blocks Google scripts; no captcha fields or deployed replacement client are needed.

GitHub Actions is the operator interface: named stages, a source/deployment summary, and report links. Public ingress bypasses infrastructure login; Torus account and test API authentication remain required.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Reliability: bound stages and stop downstream work after failure. Default to 15 minutes for GitOps merge, then 20 minutes for readiness, polling every 10 seconds with a maximum 10-second request timeout.
- Consistency: serialize active workflow runs through target updates and testing. Do not scan for PRs left by prior runs; operators handle orphaned PRs after interrupted runs. The pre-test identity check observes version/SHA at the public URL; it does not prove all-replica convergence or image-digest identity. No post-test identity check is required.
- Security/privacy: keep secrets outside images and committed configuration; exclude credentials and sensitive test data from public responses and diagnostics. Retain production test-route exclusions and restrict retained reports.
- Compatibility: preserve PR triggers, source selection, `@pr` coverage, and disposable lifecycle. Keep mailbox credentials and account links out of traces and attachments.
- Performance: guidance is advisory. No benchmarks, custom timing instrumentation, throughput SLA or performance-budget enforcement are required until needed. Failure-handling timeouts and probe correctness remain requirements.
- Accessibility/internationalization: use readable summaries in the existing CI interface.

## 9. Data, Interfaces & Dependencies

| Probe | Endpoint | Contract |
| --- | --- | --- |
| Startup/liveness | `/healthz` | Local startup state and HTTP response only. Return 503 `starting` before initialization completes, then 200 `Ayup!`, including during draining or database outage. |
| Readiness | `/readyz` | Require startup complete, not draining, critical local services available, and bounded `SELECT 1` through `Oli.Repo`. Return 200 `ready` or 503 `not_ready`, both with compiled string `version` and `sha` only in `MIX_ENV=playwright` builds. Other builds return only status; runtime settings cannot enable metadata. |

Both endpoints are unauthenticated, support pod HTTP without redirects and public HTTPS, and send `Cache-Control: private, no-store`. Readiness has a one-second total database checkout/query budget. Exclude the NodeJS evaluator pool, external integrations, queue depth, cluster membership and cache warming. Startup has a generous allowance; shutdown marks draining before services stop. The FDD defines lifecycle and probe timing details.

Both workflows compile `Oli.Playwright.Recaptcha`, which accepts only the configured nonempty `PLAYWRIGHT_CAPTCHA_TOKEN` using constant-time comparison, without contacting Google. Missing, empty, incorrect and malformed responses fail. The server and runner receive this secret only at runtime; missing or empty server configuration prevents startup. No Google key, injected DOM field or deployed replacement client is required. Production keeps normal captcha verification regardless of runtime verifier settings. Account authentication and scenario/mailbox token authorization remain required.

Both builds use `Swoosh.Adapters.Local` and token-protected `/test/emails` endpoints. Use unique recipients and one nightly application replica. Each deployment starts a fresh instance-local mailbox; no scheduled mailbox cleanup service is required.

Dependencies are GHCR, GitHub Actions, cross-repository credentials, Argo CD, persistent PostgreSQL/MinIO, private archives/answer keys, and test credentials. Coverage includes every current tagged case, including adaptive, Canvas and Moodle LTI, Dot, instructor, and account tests. Canvas and Moodle launch into nightly Torus; Dot uses a dedicated fixture there. Supply external URLs and credentials during provisioning; all tagged integrations must be configured and selected for unattended execution; unrelated test failures are reported and tracked separately.

Use existing archives and answer keys without new versioning infrastructure. QA/test owners maintain them together and avoid changes during active runs. Same-commit reruns may use updated assets; revisit pinning if historical reproduction becomes necessary.

In `oli-torus-gitops`, the target is `deployments/nightly-playwright.yml`; the updater is `scripts/update_deployment_record.py`. These are repository-relative paths. If the local checkout location is unknown, prompt the engineer and use the supplied path only for the current session; never persist it. The target is enabled with the published Playwright image; the Phase 5 execution record contains its provisioning evidence.

## 10. Repository & Platform Considerations

- Torus scope: nightly orchestration, PR migration, release/runtime configuration, lifecycle/probe endpoints, and targeted browser-helper changes. The FDD maps these to files.
- Both workflows use standalone `config/playwright.exs`, with direct compile-time settings for scenarios, mailbox access, the captcha verifier and local mail adapter. Runtime secrets and service addresses remain required.
- Delete `config/ci_e2e.exs` and migrate active references. Retain no compatibility alias, wrapper or fallback; do not import `dev.exs`.
- Keep credential injection centralized in the Playwright context setup, with no per-captcha branches or page-object helpers. Preserve application templates/hooks, block Google scripts in runner contexts, and verify real registration, enrollment and payment flows with the runtime token. Verify rejection without a valid credential and prevent token submission through GET URLs or external destinations. Production captcha interaction is unchanged.
- GitOps scope: provision the target and review probe/drain manifests separately. Recurring bot PRs change only image/source metadata, merge automatically after required checks, and precede readiness polling. Argo CD deploys; there is no direct-commit fallback.
- Apply `docs/CODEREVIEW.md` during implementation. Jira remains the tracking source; create the separate test-failure bug only after approval of its exact draft.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item.

Phase 6 requires only a completed manual workflow showing build/publication, accepted deployment with matching readiness, tagged test execution, and retained reports with the correct outcome. A test failure does not invalidate that workflow proof. A passing browser suite is not an infrastructure closeout requirement; observed test/import failures are tracked separately. Reuse earlier component, release, policy, and local failure checks; no additional live fault-injection campaign is required. Confirm the first scheduled run after normal merge separately, retaining the existing schedule.

Before enabling unattended runs, provision secrets/assets/integrations, verify bot permissions and branch rules allow automatic merge without per-run human approval, approve deployment configuration, and complete a manual run. Preserve the daily 05:17 UTC schedule and manual dispatch. Scheduled runs select current master once after acquiring the target lock; manual runs use the exact commit selected by GitHub dispatch for the chosen branch. Build, Plasma deployment and browser tests all use that same source commit. A rerun of a manual run retains its original commit; a new dispatch selects the branch again. Both entry points share the durable Plasma target and the same concurrency lock. Explicitly allow the reviewed feature branch in both `nightly-ui` and `nightly-deploy`, retaining unattended master access and excluding PR/fork access. Per-master-push execution is future work.

Land PR migration and removal of `ci_e2e` together. PR supplies disposable database/endpoint credentials and release-style assets without nightly secrets or deployment permissions. Deploy probe-capable images before activating `/readyz` in GitOps; migrate PR waiting and other readiness consumers.

Preserve nightly database/object storage and integration fixtures. Run applicable release migrations and retain per-test cleanup. Torus maintainers clean stale failed-run data between runs as needed. No scheduled cleanup service, database reset or automatic migration rollback is required.

## 12. Telemetry & Success Metrics

Torus maintainers triage failures through GitHub Actions status, run summaries and standard Playwright reports. Record source version/SHA, image tag/digest, accepted GitOps revision, expected/observed readiness identity and stage outcomes. Reports identify tests by spec/title/project, including skips and retries.

Use Playwright’s exit status; no custom results validator or blanket skip-failure rule. Always attempt summary generation and upload available `playwright-report` and `playwright-test-results` artifacts after execution, including failure, with 14-day retention. These attach to the workflow run rather than a hosted report site.

No new Slack/email integration, dedicated on-call rotation or AppSignal/timing instrumentation is required. Use existing timings for diagnosis; revisit alerting if failures go unnoticed.

Launch success requires one manual and one scheduled run reaching the expected revision and executing the selected tests with attributable results.

## 13. Risks & Mitigations

- Dependency-dependent liveness can cause unnecessary restarts: separate local liveness from bounded database readiness.
- Old or mixed replicas can respond during rollout: compare public version/SHA before tests and serialize writers. This observation cannot distinguish same-source rebuilds or prove continuous/all-replica identity; retain digest provenance.
- Test endpoints and reports can expose privileged operations or secrets: enforce existing authentication, dedicated credentials, production exclusions and artifact privacy controls.
- Shared caches can carry incompatible configuration: isolate by Mix environment and workflow trust boundary; invalidate for configuration changes.
- Persistent data can accumulate or interfere: retain fixture isolation and the cleanup policy in section 11.
- Incorrect GitOps permissions or integration targets can block execution: verify provisioning and policy before launch; resolve missing configuration rather than accepting skipped integrations as launch proof.

## 14. Open Questions & Assumptions

No unresolved design questions remain. Approved decisions and implementation deferrals are recorded in the Decision Log.

### Assumptions

- The durable target is `https://nightly-playwright.plasma.oli.cmu.edu`.
- `@nightly` tags are the sole membership source. Verify the eight audited adaptive cases retain their tags; future membership changes follow normal code review.
- The reverted dependency experiment is historical context in [dependency-discovery.md](dependency-discovery.md), not current implementation proof. The FDD and requirements define the current work.

## 15. QA Plan

The FDD testing strategy maps implementation checks to canonical acceptance criteria. Required coverage includes shared configuration and PR migration, production exclusions, authorized Playwright captcha acceptance and rejection and mailbox/account privacy, probe lifecycle and bounded readiness, GitOps updates/concurrency, tag-based execution and failure/report handling.

Reuse the component, release, rendered-manifest, policy, and local failure evidence in earlier execution records. The minimal Phase 6 checklist verifies build/publication, accepted deployment/readiness, tagged execution, and reporting in one manual run. Separate bug work owns test repairs and their verification. First scheduled-run confirmation remains the launch follow-up. Additional live fault injection, overlapping dispatches, persistence/mailbox drills, and disposable lifecycle exercises are not closeout requirements. This scope reduction does not assert that those live exercises occurred. Performance measurements are not required.

## 16. Definition of Done

- [x] PRD sections complete with explicit scope, approved decisions, limitations, and recorded implementation deferrals.
- [x] requirements.yml captured with proposed, testable requirements and acceptance criteria.
- [x] PRD and requirements validation pass.
- [x] Phase 6 workflow integration and minimal manual verification complete; see `phase-6-execution.md`.
- [x] Final implementation scope ends at Phase 6; unrelated test repairs are excluded.
- [ ] First scheduled run confirmed after normal merge, with requirements evidence reconciled at work-item closeout.

## Decision Log

| Date | Topic | Approved decision and rationale |
| --- | --- | --- |
| 2026-10-06 | GitOps update path | Bot PRs merge automatically after required checks, without per-run human approval or a direct-commit fallback. Verify branch rules/permissions before launch. Preserves validation and deployment history. |
| 2026-10-06 | Initial nightly suite and integration targets | Include all tagged tests; tags remain the sole membership source. Canvas launches into nightly Torus and Dot uses a dedicated fixture there. Provision both integrations before launch to preserve coverage. |
| 2026-10-06 | Merge and readiness timeout defaults | Default to 15 minutes for merge, then 20 minutes for readiness, with 10-second polling and a maximum 10-second request timeout. These bound failures, not performance. |
| 2026-10-06 | Failure triage and reporting | Torus maintainers triage GitHub Actions failures using summaries/reports. No new Slack/email integration or on-call rotation. Revisit alerting if failures go unnoticed. |
| 2026-10-06 | Provisioning and maintenance ownership | GitOps maintains deployment/secret installation; QA/test owners maintain assets and Canvas/Dot fixtures; Torus maintains automation credentials and cleanup. Role-based ownership needs no named individuals. |
| 2026-10-06 | Initial asset versioning | Use existing archives/answer keys, maintained together and unchanged during active runs. No new versioning mechanism; same-commit reruns may use newer assets. Revisit pinning for historical reproduction. |
| 2026-10-06 | Initial cleanup and mailbox retention | Retain per-test cleanup and fresh mailboxes on deployment. Torus maintainers clean stale failed-run data between runs as needed, preserving durable fixtures. No scheduled cleanup service or database reset. |
| 2026-10-06 | Operational verification | Deferred to implementation, required before launch. Torus verifies application probes/draining and unattended nightly-ui permissions; GitOps verifies deployment configuration. No performance measurements required. |
| 2026-10-06 | Release fixture and mailbox audit | Deferred to implementation, required before launch. Torus verifies runtime paths, packages demonstrated fixture needs and checks mailbox reset; GitOps verifies one replica. Requires an implemented release. |
| 2026-10-07 | Readiness metadata visibility | Expose compiled version/SHA only in Playwright builds for CI identity checks. Other builds retain unauthenticated status-only readiness; runtime settings cannot enable metadata. |
| 2026-10-13 | Manual branch execution | Allow manual dispatch of a selected repository branch at its exact dispatch SHA; schedules continue selecting master. Build, deployment and browser checkout share that identity and the same target lock. Manual reruns retain their SHA; environment branch permissions are verified during provisioning. |
| 2026-10-14 | Reconcile remaining delivery | Phase 5 completes provisioning; Phase 6 integrates and launches, absorbing former Phase 7. Preserve existing per-test setup/skips while requiring intended integrations, including Moodle, to execute for launch proof. Reuse valid prior evidence; all operational acceptance criteria still apply. |
| 2026-10-14 | Simplify GitOps orchestration | Use one deployment App with no standalone preflight or scan for prior bot PRs. Retain current-run validation, merge verification, and cleanup; operators handle orphaned PRs after interruptions. |
| 2026-10-15 | Close provisioning; verify on the feature branch | Phase 5 closes on installed and initially checked provisioning. Phase 6 owns all remaining live checks and full feature-branch workflow verification before Torus merge, then scheduled proof afterward. This changes phase ownership, not acceptance criteria or the requirement to prove readiness before unattended launch. |
| 2026-10-16 | Separate workflow verification from test repairs | Operator approved closing Phase 6 on the completed end-to-end workflow run, even when Playwright reports test failures. The proposed Phase 7 owned those test/import repairs; this assignment is superseded by the 2026-10-19 decision. Reuse existing component, release, policy, and local failure checks; remove the additional live fault-injection campaign from closeout. Confirm the first scheduled run after normal merge as a separate launch follow-up. |
| 2026-10-19 | Close infrastructure scope at Phase 6 | Operator removed Phase 7 and moved unrelated test, fixture, and application failures to a separate MER bug. Keep the full tagged suite and honest failure reporting. Scheduling is already active at 05:17 UTC; first execution of the integrated pipeline from master remains post-merge evidence. Greenhouse import diagnosis remains open; no claim is made that its cause is unrelated to infrastructure. |
