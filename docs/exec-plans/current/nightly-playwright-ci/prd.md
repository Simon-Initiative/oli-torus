# Nightly Playwright CI - Product Requirements Document

## 1. Overview

Provide an unattended nightly regression run that builds a dedicated Torus image, publishes it to GHCR, advances a durable Plasma deployment through GitOps, waits for the expected application version and commit to respond publicly, and executes Playwright from the same source revision. Consolidate PR and nightly builds on one standalone `MIX_ENV=playwright` configuration with explicit compile-time capability inputs.

This work continues [MER-5918](https://eliterate.atlassian.net/browse/MER-5918). The user reports that the test audit and fixes have landed; this PRD covers the remaining execution infrastructure.

## 2. Background & Problem Statement

`.github/workflows/nightly-playwright.yml` currently installs browser-test dependencies and targets an externally configured server. It does not build or deploy the application. Its independent backend scenario job runs on another runner and does not supply a server to Playwright. The PR workflow already builds an ephemeral `ci_e2e` server, but the chosen nightly direction uses a durable Plasma environment with persistent data and integrations.

Without coordinating image selection and application readiness, a nightly run can test an older deployment while a new image is still starting. `/healthz` currently checks database connectivity and returns only `status`, so it cannot identify the source revision serving a request. The GitOps configuration currently uses that same endpoint for readiness and liveness. Split these responsibilities: `/healthz` becomes a local startup/liveness check; new `/readyz` checks startup, draining, critical local services and database availability, and returns existing build version/hash metadata. CI polls public `/readyz` without introducing Argo CD or Kubernetes machine authentication.

## 3. Goals & Non-Goals

### Goals

- Give engineers a repeatable, attributable nightly result for a known source revision.
- Share `config/playwright.exs` between PR and nightly CI, replacing the development-derived `ci_e2e` environment while preserving the PR suite and disposable service lifecycle.
- Enable token-protected mailbox access, local email capture, and secret-protected deterministic reCAPTCHA in both workflows through explicit compile-time inputs. Supply the test verifier token at runtime.
- Automate image publication, GitOps reference updates, application readiness checks, and test execution in order.
- Use `/healthz` for startup/liveness and `/readyz` for readiness and CI build identity. Include application lifecycle state and reviewed GitOps probe/drain configuration in this work.
- Retain a stable public hostname and durable test integrations across application updates.
- Make setup, readiness, and test failures distinguishable and actionable.
- Use `@nightly` tags as the sole source of suite membership. Fail collection/import errors, zero matching tests, missing selected-test configuration and unexpected skips; report which tests ran.

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
- DevOps provisions the durable namespace, secrets, assets, and integrations once, and maintains the GitOps deployment policy.
- Maintainers diagnose which stage failed and can stop subsequent runs while repairing the target.

## 5. UX / UI Requirements

No end-user UI changes. GitHub Actions is the operator interface: clearly named build, GitOps update, readiness, and test stages; a run summary with source/deployment references; and links to retained test diagnostics. Public ingress bypasses infrastructure login, while normal Torus account and test API authentication remains in place.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Reliability: each stage has a finite deadline; downstream tests cannot run after a failed prerequisite. Polling has a bounded interval and per-request timeout rather than a busy loop.
- Consistency: serialize deployment updates and testing for this target. Report readiness as observing the expected version/commit at the public URL, not as proof that all replicas run the exact newly published artifact.
- Security/privacy: public build metadata contains no credentials, account data, or environment dumps. Keep runtime credentials outside images and Git; treat reports/traces containing private course content as restricted artifacts. Production builds retain their existing test-route exclusions.
- Probe semantics: replace `/healthz` database-check behavior with dependency-free startup/liveness; move database readiness and build identity to `/readyz`. Update readiness consumers and GitOps configuration in this work rather than preserving the old combined contract. Both endpoints remain unauthenticated.
- PR compatibility: account tests retain deterministic reCAPTCHA, email confirmation/reset flows, and isolated setup/teardown after the environment migration; fixtures submit the new test token.
- Performance: `/healthz` uses only local state; `/readyz` performs cheap local checks and one database query with a one-second total checkout/query budget. Read compiled build metadata without Git/registry calls. Exclude optional integrations, background queue depth, cluster membership and cache warming from probes. Record CI stage durations; no new application throughput SLA is introduced.
- Accessibility/internationalization: no new learner-facing surface; use readable text summaries in the existing CI interface.

## 9. Data, Interfaces & Dependencies

`GET /healthz` returns HTTP 503 with `status: starting` before application initialization completes, then HTTP 200 with `status: ok` while the HTTP stack can respond. It does not query the database or external services.

`GET /readyz` returns HTTP 200 with JSON string fields `status: ready`, `version` and `sha` only after startup completes, while not draining, with critical local services available and a successful bounded `SELECT 1` through `Oli.Repo`. Otherwise it returns HTTP 503 with `status: not_ready` and compiled version/SHA; internal failure details stay out of the public body. CI compares those metadata fields with its selected source; the endpoint itself never compares against a desired revision.

Startup and liveness probes use `/healthz`; startup has a generous allowance before normal probes begin. Readiness uses `/readyz`. Probe handlers support pod-local HTTP without redirects and public HTTPS, and send `Cache-Control: no-store`. Graceful termination marks the instance draining before request-serving services shut down.

Both workflows supply a dedicated `PLAYWRIGHT_RECAPTCHA_TOKEN` to the server and test runner at runtime. Tests submit it through the captcha response field; the secret is never embedded in the image or publicly served configuration. A matching test token succeeds locally; other nonempty responses use normal Google reCAPTCHA verification so humans can use the nightly server. Empty/malformed responses fail. Nightly retains its normal captcha widget and needs valid site/server keys for its hostname.

Both Playwright builds use `Swoosh.Adapters.Local` and the existing token-protected `/test/emails` endpoints. Captured email remains instance-local and is lost on restart. Use run-specific recipients; nightly initially uses a single application replica for mailbox-based flows.

The run records source SHA/version, immutable image tag and published digest, accepted GitOps commit, expected/observed readiness metadata, and test results. The digest is for provenance, not a value inferred from the public endpoint.

Dependencies include GHCR, GitHub Actions, cross-repository GitHub credentials, Argo CD's existing reconciliation, the public HTTPS hostname, persistent PostgreSQL/MinIO, private course archives/answer keys, and scenario/automation credentials. Canvas LTI and Dot need separate target and integration configuration; `PLAYWRIGHT_BASE_URL` alone does not configure them.

In `oli-torus-gitops`, `deployments/nightly-playwright.yml` names the target and `scripts/update_deployment_record.py` updates its image/source fields. These paths are relative to that repository. The prepared record is currently disabled and uses a bootstrap image; neither it nor the private assets/integrations should be assumed operational.

## 10. Repository & Platform Considerations

- Application-owned scope: `.github/workflows/nightly-playwright.yml`, migration of `.github/workflows/pr-playwright.yml`, shared image/release configuration in `Dockerfile`, `config/playwright.exs`, `config/runtime.exs`, and relevant `mix.exs`/endpoint environment handling; application lifecycle/probe controllers and test-capability coverage; and narrow automation configuration needed for the selected tests.
- Browser-test migration includes a shared runtime-token submission helper, explicit registration support in `CredentialAccountPO.register`, replacement of enrollment/payment placeholder tokens, and an audit of other captcha-protected submissions. Missing CI token configuration fails before form submission. Preserve normal human captcha interaction.
- GitOps-owned scope: reviewed deployment intent, startup/liveness/readiness probe configuration, bounded shutdown draining and validation. CI updates only the nightly record’s image/source metadata; Argo CD performs deployment. Probe/lifecycle manifest changes and initial infrastructure provisioning are separately reviewed changes, not recurring image-update behavior.
- Both workflows use standalone `config/playwright.exs` with `MIX_ENV=playwright` and `env: :playwright`; retire `config/ci_e2e.exs` after migrating active references. Configure scenarios and mailbox access at compile time in both builds. Both compilations enable a deterministic success path for the dedicated runtime test token, with normal verification for other responses. Production retains normal verification. The FDD defines the environment-variable contract, strict parsing, defaults and build-cache isolation. Runtime service addresses and credentials remain runtime configuration.
- GitHub/GHCR credentials for publishing and GitOps writes remain necessary. The decision against machine authentication concerns public target access and readiness, not removing test API authentication or repository credentials.
- Apply `docs/CODEREVIEW.md` to implementation: security, performance, relevant backend/TypeScript, and requirements review. Jira remains the tracking source; this PRD does not update the ticket.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

Use reviewed image configuration, deployment lifecycle state, and workflow enablement as operational controls. Public access is an agreed requirement. Before scheduling the first run, provision dedicated secrets, assets, and integrations; approve the durable deployment configuration; publish a capable image; and complete a manual workflow run. Keep the existing nightly schedule/manual trigger initially. Running the full suite on every master push remains a future cadence decision.

Migrate PR CI to the shared environment and verify its existing suite before retiring `ci_e2e`. PR supplies explicit disposable database, endpoint and test credentials and builds the release-style assets; it does not gain nightly secrets or deployment permissions.

Deploy the new probe endpoints before activating `/readyz` in GitOps readiness configuration, and migrate PR/readiness consumers. Validate startup, database outage and graceful shutdown behavior. Startup/liveness must not fail solely because an external dependency becomes unavailable after boot.

Application updates preserve the nightly target's database and object storage. Existing release setup handles applicable migrations; this work introduces no new domain schema. Recovery from failed deployment or tests follows an operator decision and does not automatically undo database migrations.

## 12. Telemetry & Success Metrics

Use GitHub Actions stage outcomes, durations, summaries, and saved reports as the primary signals; no new AppSignal instrumentation is required for orchestration. Track build time, GitOps update time, readiness wait, test duration, passed/failed/skipped counts, retry outcomes, and failure stage. Identify executed tests by spec, title and project with individual outcomes. Retain the current 14-day test artifact policy unless a different policy is agreed during design.

Launch success means a configured manual run and a subsequent scheduled run reach the expected source version and execute the required cases with attributable results. Missing configuration and readiness mismatches must produce visible failures rather than apparent test success. Collect representative timings and reliability data before deciding on per-master-push execution.

## 13. Risks & Mitigations

- A combined database-dependent liveness check can trigger restarts during a database outage: separate local liveness from database readiness and test their independent outcomes. Startup completion and drain transitions must reflect the real application lifecycle.
- An old healthy instance can respond during rollout: compare version/hash after the GitOps update and reject mismatches; serialize writers. This still cannot establish all-replica convergence.
- A rebuild can share the same source metadata as a prior image: retain image provenance and explicitly accept that health polling cannot distinguish those artifacts. Do not describe it as digest verification.
- Public test capabilities can expose privileged setup operations and captured email: preserve scenario/mailbox token authorization, automation API authentication, dedicated test accounts, private asset access, and production build exclusions. Mailbox storage is instance-local and in-memory; use unique recipients and account for restart/replica behavior.
- Shared compile caches could retain disabled test capabilities: key caches by capability inputs and workflow trust boundary and verify both build configurations independently.
- Durable data accumulates or tests interfere: use existing per-run fixture isolation/cleanup and define operational cleanup ownership before launch.
- GitOps policy requires manual approval or blocks bot writes: resolve the update/merge policy before promising unattended execution; do not bypass branch rules.
- Canvas/Dot point at other deployments or lack configuration: resolve their initial coverage and target policy, then validate selected suite configuration before execution.
- Build or rollout failure consumes the test window: separate deadlines and diagnostics so the previous healthy deployment cannot silently stand in for the requested revision.

## 14. Open Questions & Assumptions

### Open Questions

- Will image updates use validated automatically merged bot PRs or direct bot commits, and what repository rules permit that unattended path?
- Does initial delivery include all current `@nightly` cases (eight adaptive cases, Canvas LTI, and Dot), or stage Canvas/Dot separately? Which exact external targets and fixtures are owned by this deployment?
- What are the GitOps merge/readiness deadlines, polling interval, and failure-notification owner/channel?
- Who provisions and maintains private assets, integration accounts, automation keys, and stale test-data cleanup? Is asset versioning required for the first release?

### Assumptions

- Initial cadence retains the existing daily 05:17 UTC schedule and manual dispatch; automatic nightly runs select master, resolved once per run. Manual source-selection policy is finalized in the FDD. PR source selection remains unchanged.
- One `playwright` Mix environment serves both workflows. Both enable scenarios and local, token-protected mailbox access; both compile a secret-protected deterministic reCAPTCHA verifier. PR generates its token per job; nightly uses a dedicated runtime secret.
- `https://nightly-playwright.plasma.oli.cmu.edu` is the durable public target. Application data and integration registrations survive image updates.
- Test-source `@nightly` tags determine suite membership; no separate expected-test list is maintained. Verify the eight audited adaptive cases are tagged during implementation. Any decision to defer currently tagged Canvas/Dot cases requires a reviewed tag change; unresolved integrations cannot silently skip.
- Public version/hash observation is the accepted readiness signal. No infrastructure API verification or additional build identity field is introduced.
- The earlier dependency/workflow fix was explored and then removed from the working tree at the user's request to keep this phase documentation-only. Its exact changes and historical verification are captured in [dependency-discovery.md](dependency-discovery.md); the corresponding criteria remain proposed. The separate GitOps draft remains prior work, not evidence that this pipeline is deployed.

## 15. QA Plan

- Shared-environment validation: compile PR and nightly capability settings separately, run the existing `@pr` account/email suite, verify mailbox authentication for both, prove malformed compile inputs fail, verify post-build environment changes do not alter compiled capabilities, and test production exclusions even with Playwright inputs set. Verify the matching test token avoids external calls, unmatched responses delegate to normal verification with success/failure preserved, and empty/malformed responses fail. Verify token redaction, runtime-secret separation and cache isolation.
- Automated validation: probe controller/lifecycle coverage for startup completion, local-only liveness, draining, required local service failure, bounded database checkout/query failure, HTTP 503, metadata, unauthenticated access, direct HTTP and no-store headers; readiness helper coverage for mismatch, malformed/missing JSON fields, network/HTTP failures, timeout, and success; workflow checks for stage ordering, same-revision checkout, concurrency, and safe record updates; build checks for nightly capabilities and unchanged production exclusions.
- Form-helper validation: exercise registration through LiveView and enrollment/payment through their existing forms with the configured runtime token. Confirm missing configuration fails before submission, no placeholder token remains, and normal human captcha responses still work through the fallback verifier.
- Test selection: prove clean dependency installation and collection with `--grep @nightly`; fail import/collection errors, zero matching tests, missing selected-test configuration and unexpected skips. Verify per-test reporting and that newly tagged tests join the suite without another list update. Validate Canvas/Dot targeting according to the resolved scope. Use focused ExUnit/Jest or script tests for local behavior; avoid new domain scenarios unless implementation crosses domain workflows.
- GitOps validation: run repository record/policy validators and static Kustomize renders, including startup/liveness/readiness timing and bounded drain configuration. Verify recurring updates still change only approved image/source fields. Do not contact a cluster during document or static validation.
- Manual validation after provisioning: complete build-to-test flow, observe an old-version response during update, verify timeouts prevent tests, overlap a manual and scheduled run to verify serialization, and inspect artifacts for useful diagnostics and inappropriate secret/content exposure.
- Validate the PRD and canonical requirements with the installed harness scripts. Implementation proof is recorded later, not asserted by document validation.

## 16. Definition of Done

- [x] PRD sections complete with explicit scope, decisions, limitations, and open questions.
- [x] requirements.yml captured with proposed, testable requirements and acceptance criteria.
- [x] PRD and requirements validation pass.
- [ ] Before implementation is considered complete, resolve launch-blocking scope/policy questions, verify the canonical acceptance criteria, and demonstrate manual and scheduled runs against the provisioned target.
