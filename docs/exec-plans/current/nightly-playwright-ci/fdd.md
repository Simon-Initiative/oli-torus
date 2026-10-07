# Nightly Playwright CI - Functional Design Document

## 1. Executive Summary

Extend `.github/workflows/nightly-playwright.yml` with a serialized build-to-test job for the durable target at `https://nightly-playwright.plasma.oli.cmu.edu`. Resolve one master commit, build a dedicated `MIX_ENV=playwright` release, publish a unique GHCR tag, update the reviewed GitOps deployment record, wait for the public application version/SHA, and execute Playwright from the same checkout. Argo CD remains the deployment actor. Migrate the PR workflow from `ci_e2e` to the same `playwright` Mix environment, preserving its triggers, source selection and test coverage. Preserve the independent backend scenario job.

Split probes by purpose: `/healthz` serves dependency-free startup/liveness, and `/readyz` checks application readiness and returns compiled `version`/`sha`. Include startup completion, draining and reviewed GitOps probe/lifecycle changes in this work. CI’s pre-test `/readyz` check observes the expected public source identity; it does not establish replica convergence or distinguish same-source rebuilds.

The GitOps update path uses validated bot PRs with automatic merge after required checks pass and repository rules permit it. Verify branch rules and bot permissions during implementation before launch. Integration provisioning remains a launch gate; maintenance responsibilities are assigned by role in section 4.3. Deferred implementation audits are summarized in section 16. Initial delivery includes all currently tagged nightly tests, including adaptive, Canvas LTI and Dot coverage; tags remain the sole source of membership.

## 2. Requirements & Assumptions

`docs/exec-plans/current/nightly-playwright-ci/requirements.yml` is canonical. All requirements remain proposed; the table maps design and future verification, not implementation proofs.

| Requirement | Acceptance criteria | Design responsibility |
| --- | --- | --- |
| FR-001 | AC-001, AC-002, AC-003 | Ordered stages, fixed master SHA, existing workflow isolation (§4, §13) |
| FR-002 | AC-004, AC-005, AC-006, AC-032, AC-033, AC-034, AC-035, AC-036, AC-037, AC-038 | Shared PR/nightly compile environment, direct application settings, mailbox access, PR migration and runtime-only secrets (§4–6, §8, §12–14) |
| FR-003 | AC-007, AC-008 | Unique immutable tag, digest provenance, publish-before-update (§4–5) |
| FR-004 | AC-009, AC-010, AC-011 | Narrow record change, validated branch acceptance, Argo CD ownership (§5, §7) |
| FR-005 | AC-012, AC-013, AC-014, AC-039, AC-040, AC-041, AC-042 | Separate probes, startup/drain state, bounded database readiness, metadata and GitOps configuration (§4–5, §9–14) |
| FR-006 | AC-015, AC-016, AC-017, AC-018 | Public HTTPS identity polling with bounded failures and precise claims (§5, §10–11) |
| FR-007 | AC-019, AC-020 | One target lock through testing/finalization and controlled writers (§4, §7) |
| FR-008 | AC-021, AC-022, AC-023, AC-024, AC-030, AC-031 | Tag-based execution, configuration checks, dependency fix and result reporting (§4–5, §13) |
| FR-009 | AC-025, AC-026 | Persistent services, isolated fixtures, visible cleanup failures (§6–7) |
| FR-010 | AC-027, AC-028, AC-029 | Stage/provenance summary, diagnostics, manual and scheduled launch proof (§11, §13) |

Assumptions and scope:

- Keep the daily `17 5 * * *` schedule and manual dispatch. Both nightly entry points resolve `refs/heads/master` once after obtaining the target lock. Manual dispatch is restricted to the protected master workflow; arbitrary branch/SHA deployments are outside initial scope. Record the workflow SHA separately if it differs from the selected source SHA.
- Both PR and nightly use `MIX_ENV=playwright`; their shared configuration directly enables scenarios and mailbox access. Both select secret-protected deterministic reCAPTCHA at compile time, with distinct runtime tokens. PR continues to test its existing pull-request checkout with disposable services.
- Use the existing GHCR repository `ghcr.io/simon-initiative/oli-torus` with a distinct Playwright image tag namespace; the GitOps record only accepts an image tag, not a different repository or digest field.
- Include all currently tagged nightly tests in initial delivery, including Canvas LTI and Dot. Missing Canvas/Dot configuration blocks unattended launch. Provision Canvas to launch into the nightly Torus deployment and Dot with a dedicated fixture on that deployment; supply external URLs and credentials during provisioning.
- The deployment is currently disabled in the inspected GitOps draft. Provisioning and enabling it are separate reviewed GitOps work. Recurring CI cannot change lifecycle, access policy, overlay, hostname, or infrastructure.
- No production UI or domain schema changes, new feature flags, or throughput SLA. Playwright forms omit the external captcha widget/script. CI summaries provide telemetry; implementation retains required review and Jira traceability.

## 3. Repository Context Summary

| Existing boundary | Observed behavior and design implication |
| --- | --- |
| `.github/workflows/nightly-playwright.yml` | Browser job installs automation dependencies, uses an externally supplied URL, has a 120-minute timeout, and uploads artifacts for 14 days. Separate `nightly-scenarios` job provisions its own Postgres and runs backend scenarios. |
| `.github/workflows/pr-playwright.yml` | Currently uses `ci_e2e`, a disposable Postgres service, `mix phx.server`, and `@pr` selection. Migrate configuration/asset setup while retaining triggers, tested revision, selection and account/email behavior. |
| `Dockerfile` | Already accepts `MIX_ENV` and `SHA`, builds assets/Gleam, and assembles a release. Default is production. |
| `config/ci_e2e.exs` | Imports `dev.exs` and then disables watchers/reloading. It still inherits debug settings and development defaults. Replace it with standalone `config/playwright.exs` for both CI workflows and remove active `ci_e2e` references. |
| `config/preview.exs`, `config/runtime.exs`, `mix.exs`, `lib/oli_web/endpoint.ex` | Preview demonstrates a standalone release configuration. Runtime release/SSL branches, `start_permanent` and static gzip handling recognize production/preview and need explicit `:playwright` support. |
| `config/config.exs` | Stores version and SHA in `:oli, :build`; absent explicit `SHA`, non-development builds may fall back to a short Git hash. Nightly must provide the full SHA. |
| `lib/oli_web/controllers/api/health_controller.ex`, `lib/oli_web/views/api/health_view.ex` | `OliWeb.HealthController` runs `select 1` then renders only `status: "Ayup!"`; an existing controller test asserts that exact JSON. |
| `lib/oli/application.ex`, `lib/oli_web/plugs/ssl.ex` | Endpoint startup precedes several other children; there is no explicit probe lifecycle/drain state today. The SSL plug exempts only `/healthz`; add `/readyz` so direct pod probes do not redirect. |
| `lib/oli_web/router.ex`, `lib/oli_web/playwright_auth.ex` | Compile-time Playwright gate controls scenario/session/support routes. Scenario/private asset access retains token authentication. Preserve existing automation API authorization separately. |
| `lib/oli_web/controllers/playwright_mailbox_controller.ex`, `lib/oli/playwright/recaptcha.ex` | Mailbox requests already require the scenario token; captured email uses instance-local Swoosh memory. Deterministic reCAPTCHA currently supports the PR account suite. Preserve those behaviors through the shared compile-time application settings. |
| `lib/oli/scenarios/playwright_asset_storage.ex` | Private assets use a configured bucket and server-side ExAws credentials. Bucket/token are currently populated in dev/test configurations, not release runtime settings. |
| `assets/automation/playwright.config.ts` | One Chrome worker, one retry, HTML reporter, traces/screenshots. Current workflow's `--reporter=line` does not request HTML reporting explicitly. |
| `assets/automation/tests/torus/lti/launch.spec.ts` | Canvas defaults include a Tokamak launch URL; `PLAYWRIGHT_BASE_URL` alone cannot retarget it. |
| `assets/automation/tests/torus/dot_chatbot/dot-chatbot.spec.ts` | Loads its own target/configuration URL; disables traces and supports existing-fixture or scenario mode. Scenario mode currently has no durable-data teardown. |
| `docs/exec-plans/current/nightly-playwright-ci/dependency-discovery.md` | Captures the reverted direct `json-rules-engine` dependency fix and collection gate; historical tests are not current implementation proof. |

The separately inspected `oli-torus-gitops` checkout contains `deployments/nightly-playwright.yml`, a disabled staging/public record, and `scripts/update_deployment_record.py`. Its image tags must begin with `sha-`. The updater reserializes YAML and loses comments; preserving unrelated record content requires a narrow GitOps-side change or surgical field editing with equivalent validation. The base deployment currently sends both liveness and readiness to `/healthz`, has no startup probe or explicit drain hook, and runs `Oli.Release.setup` in an init container and uses the same image substitution for application and setup containers. Local inspection does not establish remote branch protections, merge privileges, registry permissions, or live service readiness.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

Keep one `nightly-playwright` job so a job-level concurrency lock covers every mutation and test. Leave `nightly-scenarios` independent; do not place the whole workflow behind the target lock. Use group `nightly-playwright-plasma`, independent of branch, with `cancel-in-progress: false`. Use the default pending policy: a newer pending run may replace an older pending run; active runs are not automatically canceled. This intentionally favors a recent regression run over an unbounded backlog. GitHub documents this behavior in [Concurrency](https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency).

Proposed implementation boundaries:

| File or area | Responsibility |
| --- | --- |
| `.github/workflows/nightly-playwright.yml` | Trusted entry points, target lock, permissions, stage ordering, deadlines, artifact publication |
| `scripts/ci/nightly_playwright.py` (new) | Small Python CLI for run metadata, target/record preflight, bounded public readiness, and sanitized stage summary; keep command functions testable, with focused tests under `scripts/ci/tests/` |
| `.github/workflows/pr-playwright.yml` | Switch to shared compile environment and explicit runtime inputs; retain existing PR triggers, checkout, suite and disposable lifecycle |
| `config/playwright.exs` (new), `config/runtime.exs`, `mix.exs`, `Dockerfile`, `lib/oli_web/endpoint.ex` | Shared compile-time settings, Mix environment selection, release-style assets and runtime configuration; delete `config/ci_e2e.exs` with no compatibility alias or fallback |
| `assets/automation/src/core/` shared form helper; `CredentialAccountPO.ts`, `StudentCoursePO.ts`, `tests/torus/student_payment/support.ts` | Read the runtime captcha token, support standard/LiveView submission, replace placeholders and add missing registration support |
| `lib/oli/health.ex` (new), `lib/oli/application.ex` | Own node-local startup/drain state and bounded readiness checks; wire actual application startup/shutdown transitions |
| Existing health controller/view, new readiness controller/view, router, SSL plug and tests | Local-only `/healthz`; `/readyz` with readiness status/metadata, HTTP 503 failures, direct pod HTTP and no-store responses |
| `assets/automation/package.json`, `package-lock.json` | Direct engine dependency aligned with product lockfile |
| `assets/automation/playwright.nightly.config.ts` (new) | Extend shared settings with nightly reporters and privacy controls; apply token-protection changes to PR tests as specified in the captcha contract |
| `assets/automation/tests/resources/nightly-ci.md` | Operator setup, tag-based selection, integration target policy, cleanup and incident procedures |
| GitOps updater/record checks in `oli-torus-gitops` | Content-preserving allowlisted update and policy-conforming merge; separate repository ownership |
| GitOps application deployment manifests in `oli-torus-gitops` | Reviewed startup/liveness/readiness probe and shutdown-drain configuration, independently of recurring image updates |

Use existing automation tooling for the shared form helper. Python handles CI orchestration; Playwright handles selection, execution and reporting. No separate suite orchestration or results-validation helper is required.

### 4.2 State & Data Flow

1. **Resolve/preflight:** after acquiring the lock, resolve master to a full 40-character commit, checkout that exact revision, and record `Mix.Project.config()[:version]`. Reject non-master dispatch, wrong target configuration, missing CI inputs, disabled/wrongly targeted GitOps records, and unresolved prior bot updates before publishing or changing intent.
2. **Install dependencies:** run clean `npm ci` in `assets/automation`. Dependency installation failure stops the run.
3. **Build/publish:** build the release at the fixed checkout with `MIX_ENV=playwright` and `SHA=<full SHA>`, using the shared application settings from section 5. Verify build metadata matches expected version/SHA, then publish the unique tag and capture its digest. No GitOps mutation on failure.
4. **Advance intent:** validate a narrow image/source diff, submit through the agreed GitOps path, wait for accepted branch state, and record the accepted GitOps commit. Re-read the tracked branch to verify the actual record values.
5. **Readiness:** poll public `/readyz` until expected version/SHA is observed or deadline expires. Do not start tests on failure.
6. **Target setup gate:** validate private asset access and selected integration configuration against the ready target. Requests use existing application authentication. Fetch required archives/answer keys into restricted runner temporary storage, validate expected formats without logging bodies, and delete them after checking. Course import/setup failures remain clearly identified fixture failures.
7. **Browser execution:** install Chrome, then run `npx playwright test --config playwright.nightly.config.ts --grep @nightly` in `assets/automation` at the fixed checkout. Playwright selects tagged tests during this invocation; no separate listing step is required. Fail collection/import errors, zero matching tests and missing selected-test configuration. Preserve one worker and one retry. Use Playwright’s exit status as the browser-step outcome and its standard reports to show which tests ran, including skips and retries.
8. **Finalize:** always attempt to upload available test reports/diagnostics and write the run summary after test execution, including on failure. Preserve the Playwright exit status; successful cleanup or upload must not turn a failed test step into a passing one. No custom results validator or post-test identity check is required.

A run provenance record contains source ref/SHA/version, workflow SHA, run ID/attempt, image tag/digest, accepted GitOps commit, the `@nightly` selector and selected Mix environment. Stage results append outcomes; existing GitHub Actions timing information can be used for diagnosis when needed. A missing downstream stage is `skipped` with its prerequisite failure, never `passed`.

### 4.3 Lifecycle & Ownership

| Owner | Responsibility |
| --- | --- |
| Torus maintainers | Workflows/helpers, release settings, application probes/lifecycle, automation credentials, failure triage and stale test-data/mailbox cleanup procedures |
| GitOps maintainers | Deployment provisioning, runtime-secret installation, branch policy, ingress, probe/drain manifests, image permissions and Argo reconciliation |
| QA/test owners | Private assets and answer keys, Canvas accounts/registration and Dot fixtures |

Ownership is role-based; no named individuals or dedicated on-call rotation are required. Reporting is defined in section 11.

This workflow is the sole routine deployment writer. Operators pause new runs and wait for the active run to finish before manual image changes (AC-020).

### 4.4 Alternatives Considered

- **Separate `ci_e2e` and nightly compile environments:** preserves the development import but duplicates capability configuration and lets PR/nightly behavior drift. One standalone `playwright` environment serves both service lifecycles.
- **Importing `dev.exs` into the shared environment:** supplies convenient local defaults but also debug settings and development credentials. Declare the needed CI settings explicitly.
- **Production image with runtime-only test flags:** cannot enable compiled-out routes. A standalone `playwright` compile environment keeps production exclusions intact.
- **Argo/Kubernetes rollout polling:** offers different rollout evidence but adds infrastructure credentials and exceeds the chosen public-readiness contract.
- **Split deployment and test jobs:** would require a lock spanning jobs. One job gives a clear protected interval without another lock service.
- **Direct bot commits:** not selected. Bot PRs retain required validation and visible deployment history. Do not fall back to direct writes when PR checks fail.

## 5. Interfaces

### Release and image contract

Use one standalone `config/playwright.exs` with `MIX_ENV=playwright` for PR and nightly CI (AC-032). Keep `nightly` for the scheduled workflow and durable deployment; use `playwright` in image tags to identify the build configuration. Set the shared application values directly at compile time (AC-033):

```elixir
config :oli,
  env: :playwright,
  enable_playwright_scenarios: true,
  enable_e2e_mailbox: true,
  recaptcha_module: Oli.Playwright.Recaptcha

config :oli, Oli.Mailer, adapter: Swoosh.Adapters.Local
```

Selecting `MIX_ENV=playwright` sets these application values at compile time; runtime configuration, including the shared server/runner `PLAYWRIGHT_RECAPTCHA_TOKEN`, is still required. Keep router `Application.compile_env` gates and capture the verifier module at compile time. `runtime.exs` and post-build process environment changes must not override these choices. Production excludes test routes and uses normal reCAPTCHA even with a runtime test token present (AC-005). Preserve existing dev/test behavior; secret handling is defined below.

The PR workflow sets `MIX_ENV=playwright` before all Mix steps; the nightly Docker build selects the same environment and supplies `SHA` for build identity. Configuration changes must invalidate relevant compile caches and Docker layers (AC-036). Runtime token values are independent of the artifact. Do not publish or promote a PR artifact into the durable target.

Configure static asset manifests, info-level logging and `Swoosh.Adapters.Local` in the shared environment. Leave preview QA tools disabled. Explicitly disable reloaders, watchers, debug error pages and LiveView development checks, retain normal origin checks, and omit development credential defaults. Do not import `dev.exs`. Include `:playwright` in release-only runtime configuration, SSL defaults, `start_permanent` and endpoint static gzip behavior. PR explicitly sets `FORCE_SSL=false` for local HTTP; nightly uses HTTPS and release defaults.

### PR migration and runtime inputs

Preserve the PR checkout, disposable Postgres, `mix ecto.setup`, `mix phx.server` and `--grep @pr`; wait for HTTP 200 `/readyz` instead of `/` (AC-003, AC-035). Use `MIX_ENV=playwright` throughout and explicit runtime values below. Delete `config/ci_e2e.exs` and migrate active workflow/script/configuration/docs references together, without an alias, wrapper or fallback. Update cache names. Build frontend/server bundles, Tailwind and digested assets through the release asset pipeline before startup; `yarn run deploy` alone is insufficient. PR needs no publication, GitOps permissions or nightly credentials.

| Runtime concern | PR workflow | Durable nightly deployment |
| --- | --- | --- |
| Database | Explicit `DATABASE_URL`/`DB_NAME` for the job's disposable Postgres; create/migrate/seed locally | Dedicated persistent database; existing release setup handles migrations |
| Endpoint | `HOST=localhost`, `SCHEME=http`, `HTTP_PORT=4002`, `PORT=4002`, `FORCE_SSL=false`; matching browser base URL | Nightly HTTPS hostname, ingress/service ports and release SSL defaults |
| Signing/encryption | Explicit job-scoped `SECRET_KEY_BASE`, `LIVE_VIEW_SALT`, `CLOAK_VAULT_KEY` and any other required release runtime settings | Dedicated deployment-managed secrets |
| Scenario/mailbox token | Generated per job and shared with its browser runner at runtime | Nonempty deployment token supplied to Torus and protected CI configuration |
| Storage settings | Explicit test bucket/media settings required for boot, with no real storage credentials or private asset dependency for the current `@pr` selection | Dedicated media/xAPI/test buckets, endpoints and server-side credentials |
| reCAPTCHA token | Generate a dedicated job-scoped `PLAYWRIGHT_RECAPTCHA_TOKEN`, shared by server and runner | Dedicated `PLAYWRIGHT_RECAPTCHA_TOKEN` deployment/CI secret, separate from the scenario/mailbox token |

Load `PLAYWRIGHT_SCENARIO_TOKEN` into its existing application key at startup; missing/empty tokens fail boot when scenario/mailbox routes are compiled in. Load `PLAYWRIGHT_ASSETS_BUCKET` and ExAws settings at runtime. PR must boot without the private-assets bucket; nightly validates it and authenticated access before tests. Asset-dependent operations fail without required storage configuration. All tokens, database credentials, signing salts and storage keys are runtime-only (AC-006): compilation needs no deployment secrets, and none enter Docker build arguments or layers.

### reCAPTCHA test-token contract

Replace the unconditional success behavior in `Oli.Playwright.Recaptcha` with token verification for both workflows (AC-037). Compile `Oli.Recaptcha` with `Oli.Playwright.Recaptcha`, selected directly in `config/playwright.exs`. Route remaining direct calls to `Oli.Utils.Recaptcha.verify/1` through `Oli.Recaptcha.verify/1`, preserving production’s normal implementation and response contract. Apply this boundary to registration, invitations, LTI, delivery and other captcha-protected entry points.

When the test implementation is selected, require a nonempty `PLAYWRIGHT_RECAPTCHA_TOKEN` at runtime and fail startup on missing/empty configuration. For a nonempty string `g-recaptcha-response`, compare with that token using `Plug.Crypto.secure_compare/2`. A match returns `{:success, true}` without contacting Google. Nonmatching, missing, empty or non-string responses return `{:success, false}` locally. No Playwright verification path calls Google or falls back to the normal verifier. The test secret does not replace account or API authentication. Neither PR nor nightly requires Google reCAPTCHA site/server keys or human widget support. Normal production verification remains unchanged.

PR generates a cryptographically random job-scoped token; nightly provisions a separate random secret shared only by the target and authorized test runner. Never reuse the scenario/mailbox token for captcha. Both tokens remain runtime-only so rotation requires configuration/process restart, not a rebuild. Require at least 32 random bytes for provisioned/generated test tokens.

In the Playwright environment, omit the external captcha widget and its Google script dependency while retaining the response field and form submission behavior. Shared browser fixtures/helpers submit the runtime test token through that field, including LiveView form events. Keep the normal widget and verification behavior in production. Scope injection to the configured Torus origin; do not send it to Canvas or external captcha endpoints. The application must never render the expected token in HTML, JavaScript or public configuration. Redact `g-recaptcha-response` from server request logs, avoid token values in assertions/errors, and disable token-bearing traces/attachments in PR and nightly until sanitization is demonstrated. Audit existing helper placeholder responses so no tested flow depends on unconditional success. Add negative verification cases rather than silently treating every submitted form as authorized.

### Browser form-helper migration

AC-038 explicitly includes the missing client support in this work item. Add one shared helper under `assets/automation/src/core/` that receives the target form locator, reads the nonempty `PLAYWRIGHT_RECAPTCHA_TOKEN` from the runner environment, and sets a single effective `g-recaptcha-response` value before submission. Pass the token into browser evaluation as an argument; do not hardcode it or embed it in browser bundles. Support normal HTTP forms and Phoenix LiveView serialization/events, and scope the operation to the configured Torus origin. Missing configuration must fail before the form is submitted with a message naming the variable but never its value.

Migrate these confirmed call sites:

| Existing helper | Current gap | Required change |
| --- | --- | --- |
| `assets/automation/src/systems/torus/pom/home/CredentialAccountPO.ts`, `register` | Supplies no captcha response and relies on unconditional server success | Invoke the shared helper before the registration LiveView submit and verify the token reaches the server |
| `assets/automation/src/systems/torus/pom/course/StudentCoursePO.ts`, `fillAutomationRecaptchaResponse` | Injects `playwright-test-token` and suggests development keys/load-testing mode on failure | Replace injection with the shared helper and update the failure message for runtime token configuration |
| `assets/automation/tests/torus/student_payment/support.ts`, `submitPaymentCode` | Injects `playwright-test-token` into the payment form | Use the shared helper before payment-code submission |

Migrate any other protected submissions exercised by the suites, including invitation/LTI flows, together with the verifier. Forms without captcha need no token injection. Verify correct token submission and rejection of missing/incorrect responses under the contract above.

### Mailbox contract

The shared compile settings above enable local mail capture and the mailbox API (AC-034). Preserve `GET /test/emails?to=<recipient>` and `GET /test/emails/:id`, including the existing optional subject filter and JSON contract. Both endpoints require the existing `x-playwright-scenario-token` authorization; missing/wrong tokens fail. No extra nightly-only mailbox gate is needed. Captured mail is not sent through SES/SMTP.

Tests use run-unique recipients and retrieve only the messages they created. Mailbox state is in-memory and instance-local: startup/restart begins a new mailbox, and mailbox-dependent flows initially require a single application replica. Deployment serialization keeps routine rollouts outside test execution, but restart during an email flow can still fail that flow. Do not add shared mailbox persistence or replica routing in this work item; revisit those boundaries before scaling mailbox-dependent tests. Use the fresh application process created by each nightly deployment to clear the instance-local, in-memory mailbox. No scheduled mailbox cleanup service is required initially; do not clear messages or recycle the instance during active test execution. Reports and traces must not expose captured confirmation/reset links or message bodies.

### Nightly image publication

Use tag `sha-<full SHA>-playwright-<run ID>-<attempt>` in the existing GHCR repository. Include source/version OCI labels and retain the published digest in provenance. A pre-existing tag is a collision: fail publication before changing GitOps intent. Never overwrite or reuse it for this run. Never publish nightly output to production tag names or `latest`. Build from a clean context before materializing runtime configuration; exclude automation dependencies, reports, downloaded assets and local secret files from the Docker context. Scope cache keys by Mix environment, toolchain, lockfiles, compile configuration and workflow trust boundary.

Required adaptive/scenario logic lives in `lib/`; do not add `test/support` or preview seeding modules to `playwright` `elixirc_paths`. Existing support asset endpoints resolve paths from the source tree, which a final release does not retain. During implementation, verify every selected case's support-asset needs; package any required public fixtures under release `priv/` and resolve them via application paths, with existing local behavior retained. Private course archives remain exclusively in object storage. Initial delivery uses the existing configured archives and answer keys without a new asset-versioning mechanism. QA/test owners maintain these together and do not change them during active runs. Rerunning the same application commit may use updated assets; revisit version pinning if reproducing historical runs becomes necessary. A release smoke check must catch missing runtime files/modules rather than assuming compilation proves functionality.

### Probe contracts

Use two unauthenticated endpoints in all server environments, including production and Playwright. Startup and liveness share `/healthz`; Kubernetes uses different timing for those two probes. CI polls `/readyz` and separately checks build identity.

| Probe | Endpoint | Checks and response |
| --- | --- | --- |
| Startup | `/healthz` | HTTP responds and application initialization completed. Before completion return HTTP 503 with `{"status":"starting"}`; afterward return HTTP 200 with `{"status":"Ayup!"}`. Allow a generous startup window. |
| Liveness | `/healthz` | After startup, the HTTP stack responds and local startup state remains complete. No database or external-service calls. Draining or a database outage alone must not change its HTTP 200 response. |
| Readiness | `/readyz` | Startup complete, not draining, critical local services available, and bounded `SELECT 1` through `Oli.Repo`. Return HTTP 200 with `status: ready` on success; otherwise HTTP 503 with `status: not_ready`. Both responses include compiled string `version` and `sha`. |

Example successful readiness response:

```json
{"status":"ready","version":"0.35.0","sha":"<full selected commit SHA>"}
```

The version above is illustrative. Pass only version/SHA from existing compiled `:build` configuration, not the entire map. Failure body has the same fields with `status: not_ready`; do not expose dependency errors, credentials or process internals. The endpoint never receives or compares a desired deployment SHA. A ready older revision correctly returns 200, while CI rejects the identity mismatch (AC-012–AC-014).

Add `/readyz` in the router and exempt both probe paths from application HTTPS redirects in `Oli.Plugs.SSL` so kubelet can reach them directly over pod HTTP (AC-042). Public CI continues to require HTTPS. Both handlers send `Cache-Control: no-store`; no login/session, CSRF token or infrastructure credentials are required. Keep these routes outside Playwright capability gates.

### Startup, local services and draining

Add a small `Oli.Health` boundary with node-local lifecycle state and functions for startup initialization/completion, entering drain, liveness status and readiness evaluation. Use explicit `starting`, `running`, and `draining` transitions; missing/uninitialized state cannot report ready. Reset on every application start, mark completion only after `Supervisor.start_link` succeeds and mandatory synchronous server initialization finishes, and prevent completion from overwriting a drain already requested. A response from the endpoint alone is insufficient because `Oli.Application` starts it before other children (AC-039, AC-040).

Readiness initially checks the named local `Oli.Repo`, `Oli.PubSub` and `Oli.Vault` services; a functioning HTTP handler establishes endpoint availability. Exclude the local NodeJS evaluator pool from all probe checks, regardless of the configured evaluator/substitution implementation. Use cheap availability checks with bounded behavior, not a full supervision-tree walk, cache warmness, queue backlog or cluster-node-count requirement. Supervision remains responsible for recovering individual local services; readiness becomes false while a required one is unavailable without making liveness restart the entire application.

After local checks pass, perform `SELECT 1` through the application’s normal `Oli.Repo` pool with a one-second total budget including pool checkout and query execution. Configure checkout/query bounds and cancellation together; setting only a query timeout after an unbounded checkout is insufficient. Pool exhaustion, checkout errors, query errors/timeouts and an unavailable repo produce 503. Ensure timed-out work is canceled and repeated probes cannot leave detached queries/tasks running. Recheck lifecycle state before returning ready so draining that starts during the query produces 503.

Keep S3/MinIO, ClickHouse, Canvas/LTI providers, reCAPTCHA, AI providers, Oban backlog and cache warming out of these probes. Monitor and test those separately. Release migrations/seeds stay in deployment setup; probes never run migrations or repeatedly scan schema versions.

Expose drain only through a local release function, not a public route. Wire `Oli.Application.prep_stop/1` to mark draining before supervision shuts down. The GitOps `preStop` hook calls the idempotent local drain function through release RPC before a bounded propagation wait; the HTTP endpoint stays available during that wait. A draining node returns readiness 503 and liveness 200. Shutdown does not clear drain back to ready; a new application start resets lifecycle state. Validate this sequence under actual graceful termination, not just by manually changing a test flag.

### GitOps probe and termination configuration

As separately reviewed infrastructure changes, configure these initial values in the applicable application deployment manifests (AC-041):

| Probe | Path | Period | Request timeout | Failure threshold | Success threshold |
| --- | --- | --- | --- | --- | --- |
| Startup | `/healthz` | 5 seconds | 2 seconds | 60 (approximately 5-minute allowance) | 1 |
| Liveness | `/healthz` | 15 seconds | 2 seconds | 3 | 1 |
| Readiness | `/readyz` | 5 seconds | 2 seconds | 2 | 1 |

The startup probe gates normal liveness/readiness probing; remove redundant fixed initial delays and revisit the startup allowance only if operational behavior warrants it. Init-container migration time is separate from this application-container startup allowance. See [Kubernetes probe behavior](https://kubernetes.io/docs/concepts/workloads/pods/probes/).

Set an initial 60-second termination grace period. Bound the local drain RPC to 5 seconds and allow a 10-second endpoint-removal propagation wait in `preStop`, leaving the remaining grace period for normal shutdown; revisit these values only if shutdown behavior warrants it. Bound failures rather than letting the hook hang indefinitely, and retain `prep_stop/1` as the application-level transition for graceful exits outside Kubernetes. The wait aids propagation and does not prove all ingress connections have drained. Render/check the hook and probe settings for affected overlays; do not activate `/readyz` for images without the route. Recurring CI retains its image/source-only update contract and does not rewrite these manifests.

### Readiness helper contract

Inputs: fixed public HTTPS `/readyz` URL, expected version, expected full lowercase SHA, total deadline, request timeout, polling interval, diagnostic output path. Validate inputs before requests. Approved defaults: 20-minute readiness deadline after GitOps merge, 10-second maximum per request, 10-second interval; clamp request/sleep duration to remaining monotonic deadline. No redirects, TLS bypass, cookies or infrastructure auth header. Reject URLs with userinfo or a hostname other than the configured nightly target.

Accept only HTTP 200 with JSON object containing string `status`, `version`, `sha`, `status == "ready"`, and exact version/SHA equality. Missing/malformed fields, login HTML, 3xx, other HTTP codes, network errors and old identities are failed observations and retried until deadline. Disable intermediary probe caching through deployment configuration and send no-cache request headers. Record only bounded status/category and allowlisted identity fields, not arbitrary response bodies. Exit nonzero on timeout/invalid input and write expected/last-observed identity with elapsed time.

Run this identity check before tests; do not repeat it after execution. Summary wording: “Observed expected version/commit at the public endpoint before testing.”

### GitOps update contract

For local engineering work, if the `oli-torus-gitops` checkout location is unknown, prompt the human engineer for its path before accessing the repository. Treat the supplied checkout path as session-only information: do not persist it in documentation, configuration, notes or other saved state. All documented GitOps file references must remain relative to the GitOps repository root. This local setup instruction does not add an interactive prompt to CI.

All paths in this paragraph are relative to `oli-torus-gitops`. Preflight requires an existing `deployments/nightly-playwright.yml` with `app: oli-torus`, expected slug, `enabled: true`, `overlay: staging`, public access and exact nightly hostname. Call the updater with only `--record`, `--image-tag`, `--source-ref refs/heads/master`, and `--commit-sha`; never pass create, enable/disable, overlay, host or access-policy flags.

Allowed semantic changes are exactly `imageTag`, `metadata.sourceRef`, and `metadata.commitSha`. Preserve other values and unrelated textual content/comments. The current `yaml.safe_dump` writer needs a content-preserving adjustment verified by fixture tests before use under AC-009. Run `scripts/validate_deployments.py`, `scripts/validate_gitops_policy.py` and the repository's required static renders/checks. Revalidate on branch conflicts; do not force-push the tracked branch.

Use a repository-scoped GitHub App installation token to create a bot branch/PR and enable automatic merge after required checks pass and branch rules permit it. Target a configured protected branch; record the accepted commit and confirm the record at that branch before polling. Approved merge-wait deadline: 15 minutes by default, configurable. On timeout/cancellation, disable auto-merge and close any unmerged run-owned PR; if merge raced closure, reconcile and record the accepted state. A subsequent run must reject or settle outstanding prior run PRs before changing intent, including PRs left by a hard runner termination. Do not leave an unattended update capable of merging during a later test interval. During implementation, verify the target branch, required checks and installation permissions support this lifecycle without per-run human approval before scheduling is enabled. Direct commits are not an alternative or fallback.

### Tag-based suite selection

The `@nightly` tags in test sources are the sole source of suite membership (AC-021). Run `npx playwright test --config playwright.nightly.config.ts --grep @nightly` at the same source checkout, with selection handled by the test invocation (AC-031). Adding or removing a tag changes selection through normal code review, without an expected-test list to update.

During implementation, verify the eight audited adaptive cases documented in `assets/automation/tests/resources/adaptive-tests-setup.md` retain their tags. Canvas LTI and Dot are also currently tagged and included in initial delivery. Subsequent membership changes follow normal tag review. The setup documentation records asset/configuration needs, not a second source of test selection.

Fail collection/import errors or zero matching tests during the test invocation; do not enable a pass-with-no-tests option. Validate configuration required by the selected tests; absent credentials, assets or integration settings must fail setup rather than cause a silent skip (AC-022). Use Playwright’s exit status to determine the browser-step outcome (AC-024). Skips and retries remain visible in standard reports; no blanket skip-failure rule, expected-results inventory or custom results validator is required. Retain the existing retry policy.

Report which tests ran using spec path, full title and project, with pass/fail/skip/interruption and retry outcomes (AC-027). Execution output and reports may be retained as run diagnostics; do not maintain or compare against a separate expected-test list.

Declare `json-rules-engine` directly in automation, regenerate its npm lockfile, and assert its resolved version equals the product Yarn resolution (6.1.2 at discovery). Validate from a clean checkout without parent `assets/node_modules`. Local installation must not conceal the dependency.

Explicit configuration:

| Consumer | Required configuration and target rules |
| --- | --- |
| Adaptive | Exact nightly `PLAYWRIGHT_BASE_URL`, nonempty scenario token and automation API key; all eight archives and seven answer files documented in `assets/automation/tests/resources/adaptive-tests-setup.md` must be accessible via authenticated Torus asset routes. No default `my-token` fallback in nightly. |
| Canvas | Explicit `CANVAS_BASE_URL`, account ID/API token, instructor credentials, tool name, and `CANVAS_TOOL_LAUNCH_URL`; `TORUS_BASE_URL` and launch origin must equal the nightly origin. Supply dedicated Torus admin credentials required by the current fixture. Provision corresponding LTI registration. Do not inherit Tokamak defaults. |
| Dot | Require protected `PLAYWRIGHT_PARAMETER_CONFIG_URL`; validate downloaded YAML without logging it and require its `target.base_url` to equal the nightly origin. Use existing-fixture mode initially, with a dedicated enrolled test user/section on the nightly deployment and working Dot service configuration; scenario mode needs an explicit cleanup policy before adoption. |

Missing selected integration configuration is a setup failure. Freeze the validated Dot parameter document in runner temporary storage for the test invocation so a second download cannot change its target; add a narrow loader option for this local file if needed. Do not include secrets in test output or upload that file. Configuration validation is a nightly-specific gate, preserving optional local test behavior.

## 6. Data Model & Storage

No database migration or application schema change. Nightly releases run applicable migrations via the GitOps init container; persistent Postgres, MinIO and integration registrations survive image updates. Nightly CI never resets the database, deletes a namespace, or recreates shared credentials. PR CI continues to create, migrate and seed a disposable database that is destroyed with its runner.

Transient run data lives on the runner: provenance, sanitized stage diagnostics, HTML reports and permitted test diagnostics/screenshots/traces. Upload only explicit allowlisted artifacts to the GitHub Actions workflow run with 14-day retention; remove downloaded private assets and secret parameter files. GHCR stores immutable images, and Git records deployment intent/provenance. Private asset contents are not new source-controlled data. Captured email is transient Swoosh memory, not part of the persistent nightly database/object-storage contract; each nightly application deployment starts with a fresh mailbox.

## 7. Consistency & Transactions

There is no distributed transaction across GHCR, GitHub, Argo and Torus. Order operations so publication precedes intent, branch acceptance precedes readiness, and readiness precedes tests. An orphaned published image is acceptable; failed publication cannot alter deployment intent. An accepted update remains deployed after test failure until an operator decides otherwise.

The job lock spans preflight through test execution and finalization. Test fixtures retain run-specific identities and existing cleanup. Plate-tectonics currently bounds teardown and logs leaked slugs; retain those warnings in actionable diagnostics. Dot existing-fixture mode avoids adding a new scenario's users/projects nightly, but conversations/attempts may still accumulate. Torus maintainers clean stale data from failed runs between runs as needed, preserving durable integration fixtures. Document this procedure in the operator runbook; no new scheduled cleanup service is required initially. Do not convert existing best-effort cleanup to database resets or automatic migration rollback.

## 8. Caching Strategy

Use existing dependency/build caches keyed by lockfiles, toolchain, Mix environment and compile configuration. Separate PR and trusted nightly cache namespaces even though both use `playwright`; nightly must not restore PR-generated compile artifacts. Include relevant configuration files before Docker dependency/application compilation and source files before application compilation so changes invalidate the appropriate layers. Never restore `_build` from a different Mix environment or incompatible compile configuration; a broad restore fallback may recover download caches, not incompatible compiled outputs. Keep production compile caches separate. No health-response or readiness-success cache. Re-run readiness checks and fixture/configuration checks on every run, including reruns of the same SHA. Cache artifacts may accelerate build/install but cannot substitute for clean-install dependency verification during implementation.

## 9. Performance & Scalability Posture

These are design guidelines, not performance acceptance criteria. No benchmarking, custom timing instrumentation, enforced performance budgets or scalability measurements are required for initial delivery. Investigate and measure only if runtime, reliability or resource usage becomes a practical concern.

Keep the initial execution model simple: one runner, one Chrome worker and the existing retry count. Consider tuning caches, concurrency or execution cadence only when needed; standard GitHub Actions timing information is available for diagnosis.

The bounded requests, polling and job timeouts specified elsewhere remain failure-handling safeguards. Probe behavior and the database timeout remain correctness requirements; this section adds no performance measurement or enforcement gates.

## 10. Failure Modes & Resilience

| Failure | Required behavior |
| --- | --- |
| Missing selected-test configuration, zero matches or collection/import error | Fail setup or the test invocation; preserve its failure status through finalization. |
| Build/push/collision | Fail publication; leave GitOps record unchanged. |
| Disabled/wrong target record | Fail preflight with expected field names/values; never repair lifecycle automatically. |
| Validation/check/merge failure or deadline | Fail GitOps acceptance; settle the run-owned pending PR; do not test a previous deployment. |
| Old identity, redirect, invalid JSON or network failure | Retry bounded readiness; fail when deadline expires. |
| Database outage after boot | `/readyz` returns 503; `/healthz` remains 200. Recover readiness when database access returns, without restarting solely for the outage. |
| Incomplete startup / draining | Readiness stays 503; startup remains unsuccessful until initialization completes, and draining leaves liveness healthy while HTTP remains available. |
| Release migration/init failure | Readiness times out; operator inspects deployment via their normal access. CI has no cluster credentials. |
| Missing asset/authentication or wrong integration target | Fail setup with consumer/key identifier, without secret values or asset contents. |
| Playwright exits nonzero or the test step times out | Mark the test step failed; upload available diagnostics and preserve stage provenance. |
| Cleanup fails | Preserve warning and affected synthetic fixture identifiers for Torus maintainers; no rollback/reset. |
| Cancellation/runner loss | No validated success; next run settles stale bot PRs and rechecks intent/configuration. Artifacts and cleanup are best-effort on hard termination. |

Do not automatically retry full deployments or rerun the whole suite indefinitely. A manual rerun selects current master anew and records that selection; exact-source replay is not promised by initial manual policy.

## 11. Observability

Always produce a GitHub step summary when the runner remains available. Include each stage's pass/fail/skipped status, expected source version/SHA, workflow SHA, image tag/digest if published, accepted GitOps commit if available, identity observed at the pre-test readiness gate, failed stage and report links. Use the Playwright step outcome for test status. Link to the standard Playwright report for test identities, individual outcomes, counts, skips and retry details; no custom result parsing or validation is required.

Use an explicit nightly reporter set: line and HTML with `open: never`. Do not override the configured reporters with `--reporter=line`. Retain `actions/upload-artifact` steps with `if: always()` to upload available reports/diagnostics even after test failure. Upload `assets/automation/playwright-report/` as `playwright-report` and `assets/automation/test-results/` as `playwright-test-results`, each with 14-day retention (AC-028). These are downloadable GitHub Actions artifacts attached to the specific workflow run, available from its summary’s Artifacts section. The HTML report is not published as a website. Pre-test failures still produce sanitized stage diagnostics and a summary; upload only files that were generated, without introducing a missing-results success gate.

Torus maintainers own failure triage. GitHub Actions failures, run summaries and reports are the initial reporting channel; no new Slack integration, custom email alerts or dedicated on-call rotation is required. Revisit additional alerting if failures go unnoticed. Existing AppSignal operational monitoring is unchanged.

## 12. Security & Privacy

- Run privileged orchestration only from protected master and the configured `nightly-ui` environment. Do not expose publish/GitOps credentials to PR or fork execution. Configure environment rules to support the approved unattended schedule.
- Grant `contents: read` and `packages: write` only to the publishing job as needed; use a separately scoped GitHub App credential for GitOps. Obtain that credential only for record/PR operations and clear it before browser execution. Persist no checkout credentials in test artifacts.
- Validate refs/URLs/record paths before passing them as separate subprocess arguments; never interpolate user-controlled text into shell source. Pin any newly introduced actions to reviewed immutable revisions.
- Public ingress is intentional; protected scenario, login, mailbox and private-asset operations retain their current authentication. Automation import/teardown retains its existing dedicated API key checks. Keep production compile-time route exclusions and test them in a separate production build.
- Both Playwright builds compile the secret-protected deterministic verifier; neither accepts arbitrary captcha responses. Keep its token separate from scenario/mailbox credentials and out of public HTML/configuration, logs, traces and screenshots. Mailbox tokens authorize access to sensitive confirmation/reset messages; exclude their contents from artifacts.
- Readiness publishes only status and compiled version/SHA; liveness publishes only status. Probe failures return generic public bodies, with no raw database errors or local process details. The lifecycle drain API is local to the release and has no public HTTP mutation endpoint. Runtime secrets are supplied by deployment secrets; the server alone holds storage credentials. Do not log parameter YAML, API headers, login bodies or raw readiness responses.
- Existing adaptive/Canvas traces can retain credentials and private course content. Disable traces in the initial nightly config until request/response sanitization is demonstrated; preserve Dot's trace-off setting. Keep reports/screenshots restricted, inspect representative artifacts before launch, and disable particular attachments if they contain secrets. Do not assume GitHub log masking sanitizes uploaded files.
- Give dedicated test accounts only the rights required by the current fixture; Canvas's Torus fixture presently requires admin access, so isolate that account and key to the nightly deployment rather than claiming every test credential is low privilege.

## 13. Testing Strategy

This documentation change runs only design/traceability checks. Operational verification is deferred to implementation, required before unattended launch: Torus maintainers verify application probe/drain behavior and that the `nightly-ui` GitHub environment permits unattended runs; GitOps maintainers verify deployment configuration. No performance measurements are required. The release fixture and mailbox audit is also deferred to implementation, required before unattended launch: Torus maintainers verify selected PR/nightly runtime paths, package only demonstrated fixture requirements and verify mailbox reset on deployment; GitOps maintainers verify the single-replica setting. Implementation must supply the following evidence:

| Layer | Verification |
| --- | --- |
| Probe HTTP contracts | AC-012–AC-014, AC-039, AC-042: update health controller tests and add readiness controller tests for status/body fields, compiled metadata, 200/503, unauthenticated pod HTTP without redirects, public HTTPS and no-store headers. Prove liveness performs no DB/external requests and readiness excludes optional dependencies. Preserve clean ExUnit logs. |
| Lifecycle and bounded readiness | AC-013, AC-040: test startup before/after full initialization, restart reset, required local service absence/recovery, drain during a query and actual graceful shutdown before endpoint stop. Exercise database disconnection, exhausted pool, query failure and timeout; assert the total budget and no accumulating work. Verify DB failure leaves liveness healthy and NodeJS evaluator pool unavailability alone does not change probe status. Isolate lifecycle mutation so test state cannot leak. |
| Probe deployment | AC-041: static render checks for all probe paths/timings, startup gating, drain hook bounds and termination grace. In an authorized disposable deployment, demonstrate slow boot, database outage/recovery and termination; readiness changes without dependency-triggered liveness restarts. |
| Readiness helper | Local HTTP fixture/fake clock covers valid identity, wrong version/SHA, missing/non-string fields, malformed JSON, redirect/login HTML, non-200, connection errors, TLS verification policy, deadline bounds and pre-test identity mismatch. Prove downstream test command is not invoked on failure. |
| Release | Build `MIX_ENV=playwright` and `MIX_ENV=prod` separately; smoke boot the Playwright release against disposable services with runtime secrets, check both probe contracts and readiness/full SHA plus authenticated scenario/private-asset/mailbox behavior, and verify absent-token denial. Production build must retain gated-route exclusion. Check required fixture files, metadata, image layers and default production settings. |
| Shared compile environment | AC-032, AC-033, AC-036: build the shared configuration through both PR server startup and nightly release paths from clean/cached states; assert direct scenario/mailbox/reCAPTCHA and local mail adapter settings without extra capability flags, and that post-build env changes have no effect. Verify configuration changes invalidate relevant compile caches/layers and nightly cannot restore PR compile artifacts. Build production with the runtime test token present and prove test routes remain absent and normal reCAPTCHA selected. Verify no dev import/debug defaults, that `config/ci_e2e.exs` is absent, and that no active workflow, script, configuration or documentation reference depends on `ci_e2e`. Verify no compatibility alias, wrapper or fallback remains. |
| PR migration | AC-003, AC-035: run the full existing `@pr` suite, including registration/confirmation/password reset, using explicit local runtime inputs and complete assets. Verify no nightly credentials/private assets/publication access are needed and disposal retains isolation. |
| reCAPTCHA verifier | AC-037: only the matching test token succeeds; incorrect/absent/empty/non-string responses fail, and no path calls Google. Verify missing server secret blocks startup, shared verifier use for formerly direct call sites, post-build token rotation, production ignoring the test token, and no token disclosure in logs/artifacts. Verify PR and nightly work without Google reCAPTCHA keys; production retains normal verification and widget behavior. |
| Form-helper migration | AC-038: registration LiveView, enrollment and payment flows submit the configured runtime token using the shared helper and complete through the deterministic verifier. Verify missing token fails before submission, no hardcoded placeholder fallback, correct form field/event behavior, Torus-origin scoping, and submission without Google widget interaction in the Playwright environment. Audit remaining captcha-protected submissions; run affected browser specs plus the existing `@pr` suite. |
| Mailbox | AC-034: under each PR/nightly build, capture a local message, retrieve it by unique recipient and ID with the correct token, reject missing/invalid tokens and verify recipient filtering. Exercise restart behavior and inspect diagnostics for email/reset-token disclosure. |
| Dependency/selection | Clean temporary checkout with no parent dependencies: `npm ci`, direct execution with the nightly config and `--grep @nightly`, and engine-version parity. Verify initial adaptive tags; exercise import/collection errors, zero matches, missing API key/asset and incorrect integration target. Confirm a newly tagged test is selected during execution without updating another list or running a separate collection step. |
| Reports | Verify standard Playwright reports show test identities, outcomes, skips and retries. Verify HTML/report output paths, GitHub Actions artifact names and 14-day retention, plus upload/summary execution after test failure. |
| GitOps contract | Fixture tests for exact allowed keys, comments/unrelated content, disabled record, hostname/overlay/access mismatch, conflict, denied checks, timeout and late merge. Run record/policy validators and static Kustomize rendering with no cluster contact; ensure app/init container image parity and reviewed probe/drain settings. |
| Workflow | YAML/action lint plus orchestration tests for fixed nightly checkout, stage dependencies, no production tags, bounded failures, job-scoped lock, preserved PR triggers/checkout/coverage, unchanged backend scenario job and preservation of Playwright failure status through artifact upload/summary steps. Exercise cancellation with a pending bot PR. |
| Provisioned target | One manual then one scheduled full run, all required cases, retained diagnostics, and reviewed artifacts. Observe old-revision polling and readiness timeout. Overlap dispatches to confirm serialization and pending policy; verify the operator procedure prevents manual updates during testing. Confirm durable fixtures/services survive image updates. |

Run focused ExUnit and script/automation checks appropriate to implementation, then required review under `docs/CODEREVIEW.md`: security/performance plus backend/TypeScript lenses where changed; requirements review applies if PRD changes. A full `mix test` is mandatory if shared test support/configuration changes. No new domain scenario test is necessary for this orchestration design unless implementation crosses domain workflows.

Record actual launch results and proof artifacts against canonical acceptance criteria later. Document validation and historical dependency experiments do not satisfy AC-029.

## 14. Backwards Compatibility

The probe contract intentionally changes: deploy a capable image before switching GitOps readiness to `/readyz`, and migrate PR waiting and other readiness consumers. See section 5 for response and rollout details.

Land shared configuration, PR asset/runtime setup and deletion of `ci_e2e` together, with passing `@pr` verification. Preserve PR triggers, source selection, test coverage and disposable lifecycle, while applying the documented token-submission and trace/attachment protections. Keep other shared browser-runner defaults and the independent backend scenario job unchanged. Nightly configuration supplies reporting, target and required-configuration checks; it adds no custom coverage validator.

Keep unattended runs gated on provisioning and the audits in section 13. Pause scheduling during incidents; any rollback uses reviewed GitOps changes and a database-compatibility assessment. Do not automatically reverse migrations. Historical notes may retain old names when clearly marked as superseded.

## 15. Risks & Mitigations

| Risk | Mitigation / accepted limitation |
| --- | --- |
| Same-commit rebuild or mixed replicas | Keep digest provenance but state the public observation's limits. The pre-test identity check does not prove continuous or all-replica identity. |
| Auto-merge proceeds after cancellation | Run-owned PR lifecycle, next-run stale-update gate, branch ownership and a cancellation/late-merge test before unattended launch. |
| GitOps updater rewrites comments | Add content-preserving updates and exact fixture/diff checks before adopting the existing writer. |
| PR migration loses inherited settings or assets | Explicit runtime input table, release-style asset builds, existing account/email suite and disposable-database verification. |
| Shared cache carries Playwright settings into production | Mix environment and configuration-sensitive keys, separate trusted/untrusted cache namespaces and fresh PR/nightly/production build checks. |
| Mailbox messages disappear or grow indefinitely | Single-instance mailbox tests, run-unique recipients and restart-aware setup; each nightly application deployment starts with a fresh mailbox. |
| Incorrect startup/drain state | Set completion after initialization, enter drain before service shutdown, reset state on app restart and verify real lifecycle transitions. |
| Probe change restarts or removes healthy instances | Bound readiness work, keep dependencies out of liveness, allow slow startup and validate database-outage behavior and rendered probe timing. |
| Release omits development-only config/files | Standalone Playwright release settings, explicit runtime branches and packaged-fixture smoke checks. |
| Privileged public test endpoints or secret traces | Retain authentication, dedicated target credentials, default nightly traces off and restricted artifact inspection. |
| Slow cleanup/data accumulation | Preserve bounded teardown warnings, use Dot existing-fixture mode, with Torus maintainers cleaning stale failed-run data between runs as needed. |
| Integration target drift | Explicit Canvas launch/Torus origins, frozen Dot configuration, tag-based selection and setup failures for missing required configuration. |
| Longer CI runtime | Keep one worker initially; investigate timings and tune only if runtime becomes a practical concern. |

## 16. Open Questions & Follow-ups

No unresolved design questions remain. Operational verification and the release fixture/mailbox audit are explicitly deferred to implementation and remain required before unattended launch. Responsibilities and verification scope are recorded in section 13 and the Decision Log.

## 17. References

Repository paths are relative to the named repository root.

- `docs/exec-plans/current/nightly-playwright-ci/prd.md`, `requirements.yml`, `dependency-discovery.md` in that directory.
- `ARCHITECTURE.md`, `harness.yml`, `docs/STACK.md`, `docs/TOOLING.md`, `docs/TESTING.md`, `docs/PRODUCT_SENSE.md`, `docs/FRONTEND.md`, `docs/BACKEND.md`, `docs/DESIGN.md`, `docs/OPERATIONS.md`, `docs/CODEREVIEW.md`, `docs/ISSUE_TRACKING.md`.
- `docs/design-docs/core-beliefs.md`, `docs/design-docs/high-level.md`.
- `.github/workflows/nightly-playwright.yml`, `.github/workflows/pr-playwright.yml`, `Dockerfile`, `.dockerignore`, `mix.exs`, `config/config.exs`, `config/runtime.exs`, `config/preview.exs`, `config/ci_e2e.exs` (migration source), `lib/oli/release.ex`, `lib/oli/application.ex`, `lib/oli_web/endpoint.ex`, `lib/oli_web/plugs/ssl.ex`.
- `lib/oli_web/controllers/api/health_controller.ex`, `lib/oli_web/views/api/health_view.ex`, `lib/oli_web/router.ex`, `lib/oli_web/playwright_auth.ex`, `lib/oli_web/controllers/playwright_mailbox_controller.ex`, `lib/oli/playwright/recaptcha.ex`, `lib/oli/recaptcha.ex`, `lib/oli/utils/recaptcha.ex`, `lib/oli_web/controllers/playwright_support_asset_controller.ex`, `lib/oli/scenarios/playwright_asset_storage.ex`.
- `assets/automation/playwright.config.ts`, `assets/automation/tests/resources/nightly-ci.md`, `assets/automation/tests/resources/adaptive-tests-setup.md`, `assets/automation/tests/torus/lti/launch.spec.ts`, `assets/automation/tests/torus/dot_chatbot/dot-chatbot.spec.ts`.
- In `oli-torus-gitops`: `deployments/nightly-playwright.yml`, `scripts/update_deployment_record.py`, `scripts/validate_deployments.py`, `scripts/validate_gitops_policy.py`, `apps/oli-torus/base/deployment.yaml`.
- [GitHub Actions concurrency](https://docs.github.com/en/actions/concepts/workflows-and-actions/concurrency) and [Playwright CLI](https://playwright.dev/docs/test-cli), checked during design.
- [MER-5918](https://eliterate.atlassian.net/browse/MER-5918), tracking reference from the PRD; no Jira mutation is part of this task.

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
