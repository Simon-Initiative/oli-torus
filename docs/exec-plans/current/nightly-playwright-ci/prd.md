# Nightly Playwright CI - Product Requirements Document

## 1. Overview

Build and publish a dedicated Torus image, advance a durable Plasma deployment through GitOps, verify its public readiness and build identity, and run nightly Playwright tests from the same source revision. PR and nightly CI share a standalone `MIX_ENV=playwright` configuration.

This continues [MER-5918](https://eliterate.atlassian.net/browse/MER-5918). The prior test audit and fixes have landed; this work covers execution infrastructure and the targeted test-helper changes needed for it.

## 2. Background & Problem Statement

The nightly workflow currently tests an externally configured server without building or deploying it. Its separate backend scenario job does not supply that server. PR CI builds a disposable `ci_e2e` server; nightly needs a durable target with persistent data and integrations.

Without coordinating deployment and readiness, nightly tests can run against an older revision. The current database-dependent `/healthz` serves both liveness and readiness but exposes no build identity. Split those responsibilities and verify the expected version/SHA before tests, without Argo CD or Kubernetes credentials.

## 3. Goals & Non-Goals

### Goals

- Give engineers a repeatable, attributable nightly result for a known source revision.
- Share `config/playwright.exs` between PR and nightly CI, replacing the development-derived `ci_e2e` environment while preserving the PR suite and disposable service lifecycle.
- Enable token-protected mailbox access, local email capture, and secret-protected deterministic reCAPTCHA in both workflows through application values set directly in `config/playwright.exs`. Supply the test verifier token at runtime.
- Automate image publication, GitOps reference updates, application readiness checks, and test execution in order.
- Use `/healthz` for startup/liveness and `/readyz` for readiness and CI build identity. Include application lifecycle state and reviewed GitOps probe/drain configuration in this work.
- Retain a stable public hostname and durable test integrations across application updates.
- Make setup, readiness, and test failures distinguishable and actionable.
- Use `@nightly` tags as the sole source of suite membership. Fail collection/import errors, zero matching tests, missing selected-test configuration; report which tests ran.

### Non-Goals

- Re-auditing or broadly rewriting the existing Playwright tests. Targeted captcha form-helper updates, including registration, enrollment and payment, are in scope.
- Replacing the ephemeral PR suite or changing its trigger, source selection, or coverage; its compile environment and startup configuration migrate to `playwright`.
- Changing the independent nightly backend scenario job.
- Creating a fresh nightly namespace/database on each run, deploying production, or adding registry image-watching controllers. PR CI retains its disposable database.
- Introducing infrastructure OAuth login, Argo CD/Kubernetes credentials, or a machine-authentication path for readiness checks.
- Proving complete Kubernetes rollout or exact image-digest identity through `/readyz`, or adding an extra build/run identifier to that response.
- Automatically rolling back persistent database migrations after failures.

## 4. Users & Use Cases

- Engineers receive scheduled regression results tied to the application source and test revision, and manually rerun the workflow for diagnosis.
- QA inspects failed tests, reports, and the stable nightly environment without rebuilding a local server.
- GitOps maintainers provision the durable deployment, install runtime secrets, and maintain the GitOps deployment policy.
- QA/test owners maintain private assets, answer keys, Canvas accounts/registration and Dot fixtures.
- Torus maintainers own automation credentials and stale test-data/mailbox cleanup procedures. These responsibilities are role-based; named individuals are not required.
- Maintainers diagnose which stage failed and can stop subsequent runs while repairing the target.

## 5. UX / UI Requirements

No production UI changes. In the Playwright environment, captcha-protected forms omit the external widget and Google script while preserving token submission.

GitHub Actions is the operator interface: named stages, a source/deployment summary, and report links. Public ingress bypasses infrastructure login; Torus account and test API authentication remain required.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Reliability: bound stages and stop downstream work after failure. Default to 15 minutes for GitOps merge, then 20 minutes for readiness, polling every 10 seconds with a maximum 10-second request timeout.
- Consistency: serialize target updates and testing. The pre-test identity check observes version/SHA at the public URL; it does not prove all-replica convergence or image-digest identity. No post-test identity check is required.
- Security/privacy: keep secrets outside images and committed configuration; exclude credentials and sensitive test data from public responses and diagnostics. Retain production test-route exclusions and restrict retained reports.
- Compatibility: preserve PR triggers, source selection, `@pr` coverage, and disposable lifecycle. Token submission and trace/attachment protection change as required by the shared captcha contract.
- Performance: guidance is advisory. No benchmarks, custom timing instrumentation, throughput SLA or performance-budget enforcement are required until needed. Failure-handling timeouts and probe correctness remain requirements.
- Accessibility/internationalization: use readable summaries in the existing CI interface.

## 9. Data, Interfaces & Dependencies

| Probe | Endpoint | Contract |
| --- | --- | --- |
| Startup/liveness | `/healthz` | Local startup state and HTTP response only. Return 503 `starting` before initialization completes, then 200 `Ayup!`, including during draining or database outage. |
| Readiness | `/readyz` | Require startup complete, not draining, critical local services available, and bounded `SELECT 1` through `Oli.Repo`. Return 200 `ready` or 503 `not_ready`, both with compiled string `version` and `sha` only in `MIX_ENV=playwright` builds. Other builds return only status; runtime settings cannot enable metadata. |

Both endpoints are unauthenticated, support pod HTTP without redirects and public HTTPS, and send `Cache-Control: no-store`. Readiness has a one-second total database checkout/query budget. Exclude the NodeJS evaluator pool, external integrations, queue depth, cluster membership and cache warming. Startup has a generous allowance; shutdown marks draining before services stop. The FDD defines lifecycle and probe timing details.

Both workflows supply the same runtime `PLAYWRIGHT_RECAPTCHA_TOKEN` to their server and runner. Only an exact nonempty match succeeds; all other responses fail locally, with no Google verification or keys. PR generates a job-scoped token; nightly uses a dedicated secret. Production retains normal captcha behavior. Never embed the token in the image or publicly served configuration.

Both builds use `Swoosh.Adapters.Local` and token-protected `/test/emails` endpoints. Use unique recipients and one nightly application replica. Each deployment starts a fresh instance-local mailbox; no scheduled mailbox cleanup service is required.

Dependencies are GHCR, GitHub Actions, cross-repository credentials, Argo CD, persistent PostgreSQL/MinIO, private archives/answer keys, and test credentials. Initial coverage includes all tagged cases: adaptive, Canvas LTI and Dot. Canvas launches into nightly Torus; Dot uses a dedicated fixture there. Supply external URLs and credentials during provisioning; both integrations must work before unattended launch.

Use existing archives and answer keys without new versioning infrastructure. QA/test owners maintain them together and avoid changes during active runs. Same-commit reruns may use updated assets; revisit pinning if historical reproduction becomes necessary.

In `oli-torus-gitops`, the target is `deployments/nightly-playwright.yml`; the updater is `scripts/update_deployment_record.py`. These are repository-relative paths. If the local checkout location is unknown, prompt the engineer and use the supplied path only for the current session; never persist it. The inspected draft is disabled with a bootstrap image; provisioning remains required.

## 10. Repository & Platform Considerations

- Torus scope: nightly orchestration, PR migration, release/runtime configuration, lifecycle/probe endpoints, and targeted browser-helper changes. The FDD maps these to files.
- Both workflows use standalone `config/playwright.exs`, with direct compile-time settings for scenarios, mailbox access, the captcha verifier and local mail adapter. Runtime secrets and service addresses remain required.
- Delete `config/ci_e2e.exs` and migrate active references. Retain no compatibility alias, wrapper or fallback; do not import `dev.exs`.
- Add runtime-token submission to registration, replace enrollment/payment placeholder tokens, and audit other tested captcha forms. Missing runner token configuration fails before submission. Production captcha interaction is unchanged.
- GitOps scope: provision the target and review probe/drain manifests separately. Recurring bot PRs change only image/source metadata, merge automatically after required checks, and precede readiness polling. Argo CD deploys; there is no direct-commit fallback.
- Apply `docs/CODEREVIEW.md` during implementation. Jira remains the tracking source; this work does not update the ticket.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

Before enabling unattended runs, provision secrets/assets/integrations, verify bot permissions and branch rules allow automatic merge without per-run human approval, approve deployment configuration, and complete a manual run. Preserve the daily 05:17 UTC schedule and manual dispatch; both select protected master once. Per-master-push execution is future work.

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
- Incorrect GitOps permissions or integration targets can block execution: verify provisioning and policy before launch; fail setup rather than bypass checks.

## 14. Open Questions & Assumptions

No unresolved design questions remain. Approved decisions and implementation deferrals are recorded in the Decision Log.

### Assumptions

- The durable target is `https://nightly-playwright.plasma.oli.cmu.edu`.
- `@nightly` tags are the sole membership source. Verify the eight audited adaptive cases retain their tags; future membership changes follow normal code review.
- The reverted dependency experiment is historical context in [dependency-discovery.md](dependency-discovery.md), not current implementation proof. The FDD and requirements define the current work.

## 15. QA Plan

The FDD testing strategy maps implementation checks to canonical acceptance criteria. Required coverage includes shared configuration and PR migration, production exclusions, token submission/privacy, probe lifecycle and bounded readiness, GitOps updates/concurrency, tag-based execution and failure/report handling.

Two audits are deferred to implementation and required before unattended launch:

- Torus maintainers verify probe/drain behavior, runtime fixtures, mailbox reset, and unattended `nightly-ui` permissions.
- GitOps maintainers verify deployment/probe configuration and the single-replica setting.

After provisioning, demonstrate manual and scheduled runs, failed readiness preventing tests, serialization, durable fixture preservation, and safe/useful artifacts. Performance measurements are not required. Document validation and static GitOps checks do not contact a cluster or count as implementation proof.

## 16. Definition of Done

- [x] PRD sections complete with explicit scope, approved decisions, limitations, and recorded implementation deferrals.
- [x] requirements.yml captured with proposed, testable requirements and acceptance criteria.
- [x] PRD and requirements validation pass.
- [ ] Before implementation is considered complete, complete the deferred operational and release audits, verify the canonical acceptance criteria, and demonstrate manual and scheduled runs against the provisioned target.

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
