# Nightly Playwright CI - Functional Design Document

## 1. Executive Summary

Extend `.github/workflows/nightly-playwright.yml` with a serialized build → Plasma deployment → browser test job chain for the durable target at `https://nightly-playwright.plasma.oli.cmu.edu`. Select one source commit (master for scheduled runs, the dispatch commit for manual runs), build a dedicated `MIX_ENV=playwright` release, publish a unique GHCR tag, update the reviewed GitOps deployment record, wait for the public application version/SHA, and execute Playwright from the same source SHA. Argo CD remains the deployment actor. Migrate the PR workflow from `ci_e2e` to the same `playwright` Mix environment, preserving its triggers, source selection and test coverage. Preserve the independent backend scenario job.

Split probes by purpose: `/healthz` serves dependency-free startup/liveness, and `/readyz` checks application readiness and returns compiled `version`/`sha` only in Playwright builds. Include startup completion, draining and reviewed GitOps probe/lifecycle changes in this work. CI’s pre-test `/readyz` check observes the expected public source identity; it does not establish replica convergence or distinguish same-source rebuilds.

The GitOps update path uses validated bot PRs with automatic merge after required checks pass and repository rules permit it. Verify branch rules and bot permissions during implementation before launch. Integration provisioning remains a launch gate; maintenance responsibilities are assigned by role in section 4.3. Deferred implementation audits are summarized in section 16. Initial delivery includes all currently tagged nightly tests, including adaptive, Canvas LTI and Dot coverage; tags remain the sole source of membership.

## 2. Requirements & Assumptions

`docs/exec-plans/current/nightly-playwright-ci/requirements.yml` is canonical. All requirements remain proposed; the table maps design and future verification, not implementation proofs.

| Requirement | Acceptance criteria | Design responsibility |
| --- | --- | --- |
| FR-001 | AC-001, AC-002, AC-003 | Ordered stages, fixed selected source SHA, existing workflow isolation (§4, §13) |
| FR-002 | AC-004, AC-005, AC-006, AC-032, AC-033, AC-034, AC-035, AC-036, AC-037, AC-038 | Shared PR/nightly compile environment, direct application settings, mailbox access, PR migration and runtime-only secrets (§4–6, §8, §12–14) |
| FR-003 | AC-007, AC-008 | Unique tag per attempt, digest provenance, publish-before-update (§4–5) |
| FR-004 | AC-009, AC-010, AC-011 | Narrow record change, validated branch acceptance, Argo CD ownership (§5, §7) |
| FR-005 | AC-012, AC-013, AC-014, AC-039, AC-040, AC-041, AC-042 | Separate probes, startup/drain state, bounded database readiness, metadata and GitOps configuration (§4–5, §9–14) |
| FR-006 | AC-015, AC-016, AC-017, AC-018 | Public HTTPS identity polling with bounded failures and precise claims (§5, §10–11) |
| FR-007 | AC-019, AC-020 | One target lock through testing/finalization and controlled writers (§4, §7) |
| FR-008 | AC-021, AC-022, AC-023, AC-024, AC-030, AC-031 | Tag-based execution, configuration checks, dependency fix and result reporting (§4–5, §13) |
| FR-009 | AC-025, AC-026 | Persistent services, isolated fixtures, visible cleanup failures (§6–7) |
| FR-010 | AC-027, AC-028, AC-029 | Stage/provenance summary, diagnostics, manual and scheduled launch proof (§11, §13) |

Assumptions and scope:

- Keep the daily `17 5 * * *` schedule and manual dispatch. Scheduled runs resolve `refs/heads/master` once after obtaining the target lock. Manual runs check out `${{ github.sha }}` from the selected dispatch branch/ref, never its moving tip. Build, deployment and browser jobs reuse this fixed commit. A manual rerun retains the original dispatch SHA; a new dispatch selects the branch again. Record the workflow SHA separately if it differs from the selected source SHA.
- Both PR and nightly use `MIX_ENV=playwright`; their shared configuration directly enables scenarios and mailbox access. Both select a token-authorized captcha verifier at compile time; captcha and scenario/mailbox access require separate runtime secrets. PR continues to test its existing pull-request checkout with disposable services.
- Use the existing GHCR repository `ghcr.io/simon-initiative/oli-torus` with a distinct Playwright image tag namespace; the GitOps record only accepts an image tag, not a different repository or digest field.
- Include all currently tagged nightly tests in initial delivery, including Canvas and Moodle LTI and Dot. Missing integration configuration blocks unattended launch. Provision Canvas and Moodle to launch into the nightly Torus deployment and Dot with a dedicated fixture on that deployment; supply external URLs and credentials during provisioning.
- The deployment is enabled through the separately reviewed Phase 5 GitOps provisioning. Recurring CI cannot change lifecycle, access policy, overlay, hostname, or infrastructure.
- No production UI or domain schema changes, new feature flags, or throughput SLA. Playwright preserves application captcha markup and hooks, blocks Google scripts in runner contexts, and requires a valid runtime credential for protected submissions. CI summaries provide telemetry; implementation retains required review and Jira traceability.

## 3. Repository Context Summary

The table below describes the starting point before implementation. Current execution
records supersede those observations: Phases 1–4 implemented probes, shared configuration,
packaging/build outputs, and nightly runner configuration. Phase 5 delivered the GitOps
updater, nightly-only manifests, and live target/integration provisioning. The initial
PR lifecycle helper is superseded by the standard tooling described below.
G5 is complete under the operator-approved 2026-10-15 scope. Phase 6 connects those pieces
and owns all remaining live verification plus the launch checklist formerly in Phase 7.
The Phase 6 workflow now implements deployment/readiness dependencies and the nightly config invocation; hosted and operational verification remain pending.

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

The GitOps record `deployments/nightly-playwright.yml` is enabled with the published Playwright image. Phase 5 verified the applied nightly-only probe/drain manifests, live health/readiness identity, persistent services, private asset delivery, and installed policy/credentials; GitOps PRs #7–#9 are merged. Actual bot operation, automated integration execution, persistence/mailbox behavior through updates, and operational fault/drain checks remain Phase 6 requirements. The shared base remains unchanged for other deployments.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

Use separate `build-playwright`, `deploy-plasma` and `nightly-playwright` jobs linked by `needs`. Build outputs carry the source ref, fixed source SHA/version, image tag/reference and digest. Deployment consumes that identity and succeeds only after the GitOps update is accepted and public readiness observes the expected version/SHA; browser execution needs both build and deployment and checks out the build's SHA. Scope package publication permissions to build. After publication, deployment uses one App for its record-only PR and immediate merge. No separate GitOps preflight or check for previous runs' PRs is required. Keep all GitOps credentials and App keys in deployment; build and browser jobs need no GitOps access.

Use workflow-level concurrency group `nightly-playwright-plasma`, independent of branch, with `cancel-in-progress: false`, so the lock spans the entire job chain without gaps. Do not repeat that lock on individual jobs. `nightly-scenarios` retains its existing implementation and no dependency on the build/deploy/test chain; it runs in parallel within a run, while overlapping workflow runs queue together. This replaces the earlier single-job design at the user's request. Use the default pending policy: a newer pending run may replace an older pending run; active runs are not automatically canceled. GitHub documents this behavior in [Concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency).

Proposed implementation boundaries:

| File or area | Responsibility |
| --- | --- |
| `.github/workflows/nightly-playwright.yml` | Trusted entry points, target lock, permissions, stage ordering, deadlines, artifact publication |
| `.github/workflows/pr-playwright.yml` | Switch to shared compile environment and explicit runtime inputs; retain existing PR triggers, checkout, suite and disposable lifecycle |
| `config/playwright.exs` (new), `config/runtime.exs`, `mix.exs`, `Dockerfile`, `lib/oli_web/endpoint.ex` | Shared compile-time settings, Mix environment selection, release-style assets and runtime configuration; delete `config/ci_e2e.exs` with no compatibility alias or fallback |
| `assets/automation/src/core/captcha.ts`, `assets/automation/src/core/fixture/my-fixture.ts` | Configure runner-only token submission and Google script blocking; page objects retain normal form actions |
| `lib/oli/health.ex` (new), `lib/oli/application.ex` | Own node-local startup/drain state and bounded readiness checks; wire actual application startup/shutdown transitions |
| Existing health controller/view, new readiness controller/view, router, SSL plug and tests | Local-only `/healthz`; `/readyz` with readiness status and Playwright-only compiled metadata, HTTP 503 failures, direct pod HTTP and no-store responses |
| `assets/automation/package.json`, `package-lock.json` | Direct engine dependency aligned with product lockfile |
| `assets/automation/playwright.nightly.config.ts` (new) | Extend shared settings with nightly reporters and privacy controls; apply token-protection changes to PR tests to protect mailbox credentials and account links |
| `assets/automation/tests/resources/nightly-ci.md` | Operator setup, tag-based selection, integration target policy, cleanup and incident procedures |
| GitOps updater/record checks in `oli-torus-gitops` | Content-preserving allowlisted update and policy-conforming merge; separate repository ownership |
| GitOps application deployment manifests in `oli-torus-gitops` | Reviewed startup/liveness/readiness probe and shutdown-drain configuration, independently of recurring image updates |

Use existing page objects for normal form submission. GitHub Actions steps own CI orchestration and bounded readiness checks; Playwright handles selection, execution and reporting. No separate suite orchestration or results-validation helper is required.

### 4.2 State & Data Flow

1. **Resolve source:** after acquiring the lock, select current master for a scheduled run or the dispatch SHA for a manual run, check out that revision, and record its full 40-character SHA and `Mix.Project.config()[:version]`. Record `refs/heads/master` as the scheduled source ref and `github.ref` as the manual source ref. No GitOps access is needed at this stage.
2. **Validate runner dependencies:** run clean `npm ci` in `assets/automation` at the fixed source SHA in the build job. Each later job needing those dependencies installs its own copy; runner files do not cross job boundaries. Dependency installation failure stops the affected job and its dependents.
3. **Build/publish:** build the release at the fixed checkout with `MIX_ENV=playwright` and `SHA=<full SHA>`, using the shared application settings from section 5. Supply the fixed SHA and source version as build inputs, then publish the unique tag and capture its digest. Release configuration is covered by focused tests and release smoke checks; no custom verifier runs in the Dockerfile. No GitOps mutation on failure.
4. **Advance intent:** in `deploy-plasma`, authenticate with the deployment App, use the updater to validate a narrow image/source diff, submit through the agreed GitOps path, wait for accepted branch state, and record the accepted GitOps commit. GitHub enforces configured merge requirements. A failed update stops downstream work; the published image may remain unused. There is no separate preflight or scan for earlier PRs. Re-read the tracked branch to verify the actual record values.
5. **Readiness:** poll public `/readyz` until expected version/SHA is observed or deadline expires. Do not start tests on failure.
6. **Test setup:** use the existing tests to consume configured resources against the ready target, preserving their setup and skip behavior. No separate asset or configuration preflight is added.
7. **Browser execution:** install Chrome, then run `npx playwright test --config playwright.nightly.config.ts --grep @nightly` in `assets/automation` at the fixed checkout. Playwright selects tagged tests during this invocation; no separate listing step is required. Fail collection/import errors and zero matching tests; preserve existing missing-configuration behavior. Preserve one worker and one retry. Use Playwright’s exit status as the browser-step outcome and its standard reports to show which tests ran, including skips and retries.
8. **Finalize:** always attempt to upload available test reports/diagnostics and write the run summary after test execution, including on failure. Preserve the Playwright exit status; successful cleanup or upload must not turn a failed test step into a passing one. No custom results validator or post-test identity check is required.

A run provenance record contains source ref/SHA/version, workflow SHA, run ID/attempt, image tag/digest, accepted GitOps commit, the `@nightly` selector and selected Mix environment. Stage results append outcomes; existing GitHub Actions timing information can be used for diagnosis when needed. A missing downstream stage is `skipped` with its prerequisite failure, never `passed`.

### 4.3 Lifecycle & Ownership

| Owner | Responsibility |
| --- | --- |
| Torus maintainers | Workflows/helpers, release settings, application probes/lifecycle, automation credentials, failure triage and stale test-data/mailbox cleanup procedures |
| GitOps maintainers | Deployment provisioning, runtime-secret installation, branch policy, ingress, probe/drain manifests, image permissions and Argo reconciliation |
| QA/test owners | Private assets and answer keys, Canvas/Moodle accounts and registrations, and Dot fixtures |

Ownership is role-based; no named individuals or dedicated on-call rotation are required. Reporting is defined in section 11.

This workflow is the sole routine deployment writer. Operators pause new runs and wait for the active run to finish before manual image changes (AC-020).

### 4.4 Alternatives Considered

- **Separate `ci_e2e` and nightly compile environments:** preserves the development import but duplicates capability configuration and lets PR/nightly behavior drift. One standalone `playwright` environment serves both service lifecycles.
- **Importing `dev.exs` into the shared environment:** supplies convenient local defaults but also debug settings and development credentials. Declare the needed CI settings explicitly.
- **Production image with runtime-only test flags:** cannot enable compiled-out routes. A standalone `playwright` compile environment keeps production exclusions intact.
- **Argo/Kubernetes rollout polling:** offers different rollout evidence but adds infrastructure credentials and exceeds the chosen public-readiness contract.
- **Separate job-level deployment and test locks:** leave a gap between jobs in which another run could update the target. Use one workflow-level lock spanning the build, deployment and test jobs.
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

Selecting `MIX_ENV=playwright` sets these application values at compile time; runtime configuration, including scenario/mailbox and captcha tokens, is still required. Keep router `Application.compile_env` gates and capture the verifier module at compile time. `runtime.exs` and post-build process environment changes must not override these choices. Production excludes test routes and uses normal reCAPTCHA regardless of runtime verifier settings (AC-005). Preserve existing dev/test behavior; secret handling is defined below.

The PR workflow sets `MIX_ENV=playwright` before all Mix steps; the nightly Docker build selects the same environment and supplies `SHA` for build identity. Configuration changes must invalidate relevant compile caches and Docker layers (AC-036). Runtime token values are independent of the artifact. Do not publish or promote a PR artifact into the durable target.

Configure static asset manifests, info-level logging and `Swoosh.Adapters.Local` in the shared environment. Leave preview QA tools disabled. Explicitly disable reloaders, watchers, debug error pages and LiveView development checks, retain normal origin checks, and omit development credential defaults. Do not import `dev.exs`. Include `:playwright` in release-only runtime configuration, SSL defaults, `start_permanent` and endpoint static gzip behavior. PR explicitly sets `FORCE_SSL=false` for local HTTP; nightly uses HTTPS and release defaults.

### PR migration and runtime inputs

Preserve the PR checkout, disposable Postgres, `mix ecto.setup`, `mix phx.server` and `--grep @pr`; wait for HTTP 200 `/readyz` instead of `/` (AC-003, AC-035). Use `MIX_ENV=playwright` throughout and explicit runtime values below. Delete `config/ci_e2e.exs` and migrate active workflow/script/configuration/docs references together, without an alias, wrapper or fallback. Update cache names. Build frontend/server bundles, Tailwind and digested assets through the release asset pipeline before startup; `yarn run deploy` alone is insufficient. PR needs no publication, GitOps permissions or nightly credentials.

| Runtime concern | PR workflow | Durable nightly deployment |
| --- | --- | --- |
| Database | Explicit `DATABASE_URL`/`DB_NAME` for the job's disposable Postgres; create/migrate/seed locally | Dedicated persistent database; existing release setup handles migrations |
| Endpoint | `HOST=localhost`, `SCHEME=http`, `HTTP_PORT=4002`, `PORT=4002`, `FORCE_SSL=false`; matching browser base URL | Nightly HTTPS hostname, ingress/service ports and release SSL defaults |
| Signing/encryption | Explicit job-scoped `SECRET_KEY_BASE`, `LIVE_VIEW_SALT`, `CLOAK_VAULT_KEY` and any other required release runtime settings | Dedicated deployment-managed secrets |
| Scenario/mailbox and captcha tokens | Separate secrets generated per job and shared with its browser runner at runtime | Separate nonempty deployment tokens supplied to Torus and protected CI configuration |
| Storage settings | Explicit test bucket/media settings required for boot, with no real storage credentials or private asset dependency for the current `@pr` selection | Dedicated media/xAPI/test buckets, endpoints and server-side credentials |

Load `PLAYWRIGHT_SCENARIO_TOKEN` and `PLAYWRIGHT_CAPTCHA_TOKEN` at startup; missing/empty values fail boot in the Playwright environment. Load `PLAYWRIGHT_ASSETS_BUCKET` and ExAws settings at runtime. PR must boot without the private-assets bucket. Provisioning verifies nightly asset access; selected tests consume assets through their existing setup, without a separate workflow asset preflight. Asset-dependent operations fail without required storage configuration. All tokens, database credentials, signing salts and storage keys are runtime-only (AC-006): compilation needs no deployment secrets, and none enter Docker build arguments or layers.

### reCAPTCHA test contract

Compile `Oli.Recaptcha` with `Oli.Playwright.Recaptcha`, selected directly in `config/playwright.exs` (AC-037). Route all application captcha verification through this boundary, including registration, invitations, LTI, delivery and payment. The Playwright implementation accepts only the configured nonempty runtime `PLAYWRIGHT_CAPTCHA_TOKEN`, compared with `Plug.Crypto.secure_compare/2`. Missing, empty, incorrect and malformed responses fail closed; no Google request or fallback occurs. Production compiles the normal Google verifier; runtime changes to the environment or verifier setting cannot change that selection.

Supply separate scenario/mailbox and captcha secrets to the server and runner at runtime. Never put the captcha token in application HTML, public configuration, build arguments or cached artifacts. No Google test keys, public placeholder site key or deployed replacement client are required. Account authentication and token-protected scenario/mailbox/private-asset endpoints retain their existing authorization.

### Playwright form submission

For AC-038, `assets/automation/src/core/captcha.ts` configures browser contexts before navigation. The shared fixture installs it automatically; manually created contexts that submit protected forms must call `configureCaptcha` before creating pages. Keep captcha placeholders, script tags, LiveView hooks and page-object submit actions unchanged. Runner routing blocks Google reCAPTCHA scripts, so they never execute.

A capture `formdata` listener supplies `g-recaptcha-response` to protected same-origin POST forms without adding DOM inputs. Because actionless LiveView forms default to GET, a runner-only `FormData` constructor proxy adds the token to their JavaScript serialization result after native construction. Native GET submission, including direct `form.submit()`, never receives a token. Restrict injection to the configured Torus origin and forms containing existing captcha markers. Conservatively withhold it when any associated submit control overrides the destination off-origin or the method away from POST, including controls outside the form. No per-captcha conditional rendering or replacement widget is needed.

Verify accepted/rejected credentials, runtime rotation, compile-time isolation from production, and normal Google success/failure handling in backend tests. Browser coverage checks native POST, actionless LiveView serialization, DOM replacement, GET and submitter overrides, external frames, Google script blocking, and real registration rejection. Existing registration, enrollment and payment suites verify valid-token workflows. Preserve `g-recaptcha-response` log filtering. Disable traces/screenshots in CI and local runs carrying either automation token to protect credentials and confirmation/reset links.

### Mailbox contract

The shared compile settings above enable local mail capture and the mailbox API (AC-034). Preserve `GET /test/emails?to=<recipient>` and `GET /test/emails/:id`, including the existing optional subject filter and JSON contract. Both endpoints require the existing `x-playwright-scenario-token` authorization; missing/wrong tokens fail. No extra nightly-only mailbox gate is needed. Captured mail is not sent through SES/SMTP.

Tests use run-unique recipients and retrieve only the messages they created. Mailbox state is in-memory and instance-local: startup/restart begins a new mailbox, and mailbox-dependent flows initially require a single application replica. Deployment serialization keeps routine rollouts outside test execution, but restart during an email flow can still fail that flow. Do not add shared mailbox persistence or replica routing in this work item; revisit those boundaries before scaling mailbox-dependent tests. Use the fresh application process created by each nightly deployment to clear the instance-local, in-memory mailbox. No scheduled mailbox cleanup service is required initially; do not clear messages or recycle the instance during active test execution. Reports and traces must not expose captured confirmation/reset links or message bodies.

### Nightly image publication

Use tag `sha-<full SHA>-playwright-<run ID>-<attempt>` in the existing GHCR repository. Include source/version OCI labels and retain the published digest in provenance. Tags are unique per run attempt. Push directly using normal registry behavior; do not preflight tag existence or enforce tag immutability. If the tag already exists, publication may update it to the new image; record the digest returned by that push. Never publish nightly output to production tag names or `latest`. Build from a clean context before materializing runtime configuration; exclude automation dependencies, reports, downloaded assets and local secret files from the Docker context. Scope cache keys by Mix environment, toolchain, lockfiles, compile configuration and workflow trust boundary. The `build-playwright` job in `.github/workflows/nightly-playwright.yml` uses the same build-info, Docker metadata, login and build/push pattern as `package.yml` and exposes source/image identity through job outputs. Phase 6 adds the dependent Plasma deployment/readiness job before browser execution. Build metadata and publication stay in workflow steps; no Python build or metadata wrapper is required. `BUILD_SCOPE` separates Docker layer lineages. Playwright image builds require the full `SHA`; the workflow supplies `APP_VERSION` from the selected source for OCI metadata. There is no custom assembled-release verification step; production remains the default environment.

Required adaptive/scenario logic lives in `lib/`; do not add `test/support` or preview seeding modules to `playwright` `elixirc_paths`. The release fixture audit and runtime inputs are recorded in this design and `docs/exec-plans/current/nightly-playwright-ci/phase-3-execution.md`. The three existing public support endpoint fixtures are packaged under `priv/playwright` and resolved with `Application.app_dir/2`; source-tree symlinks preserve local consumers. Selected tags currently do not request these public fixtures directly. No additional automation files are packaged. Local release verification exercised the public endpoint contract as well as authenticated scenario, private-object and mailbox behavior. Private course archives remain exclusively in object storage. Initial delivery uses the existing configured archives and answer keys without a new asset-versioning mechanism. QA/test owners maintain these together and do not change them during active runs. Rerunning the same application commit may use updated assets; revisit version pinning if reproducing historical runs becomes necessary. A release smoke check must catch missing runtime files/modules rather than assuming compilation proves functionality.

### Probe contracts

Use two unauthenticated endpoints in all server environments, including production and Playwright. Startup and liveness share `/healthz`; Kubernetes uses different timing for those two probes. CI polls `/readyz` and separately checks build identity.

| Probe | Endpoint | Checks and response |
| --- | --- | --- |
| Startup | `/healthz` | HTTP responds and application initialization completed. Before completion return HTTP 503 with `{"status":"starting"}`; afterward return HTTP 200 with `{"status":"Ayup!"}`. Allow a generous startup window. |
| Liveness | `/healthz` | After startup, the HTTP stack responds and local startup state remains complete. No database or external-service calls. Draining or a database outage alone must not change its HTTP 200 response. |
| Readiness | `/readyz` | Startup complete, not draining, critical local services available, and bounded `SELECT 1` through `Oli.Repo`. Return HTTP 200 with `status: ready` on success; otherwise HTTP 503 with `status: not_ready`. Both responses include compiled string `version` and `sha` only in Playwright builds; all other builds return only status. |

Example successful readiness response in a Playwright build:

```json
{"status":"ready","version":"0.35.0","sha":"<full selected commit SHA>"}
```

The version above is illustrative. Select metadata visibility at compile time using `:build.env`, which records `Mix.env()`: only `:playwright` includes version/SHA from the compiled `:build` configuration, never the entire map. Production and all other builds return only `{"status":"ready"}` or `{"status":"not_ready"}`. Runtime application settings, process environment changes and request parameters cannot enable metadata or replace compiled identity. Failure bodies retain the environment-specific field set with `status: not_ready`; do not expose dependency errors, credentials or process internals. The endpoint never receives or compares a desired deployment SHA. A ready older revision correctly returns 200, while CI rejects the identity mismatch (AC-012–AC-014).

Add `/readyz` in the router and exempt both probe paths from application HTTPS redirects in `Oli.Plugs.SSL` so kubelet can reach them directly over pod HTTP (AC-042). Public CI continues to require HTTPS. Both handlers send `Cache-Control: private, no-store`; no login/session, CSRF token or infrastructure credentials are required. Keep these routes outside Playwright capability gates.

### Startup, local services and draining

Add a small `Oli.Health` boundary with node-local lifecycle state and functions for startup initialization/completion, entering drain, liveness status and readiness evaluation. Use explicit `starting`, `running`, and `draining` transitions; missing/uninitialized state cannot report ready. Reset on every application start, mark completion only after `Supervisor.start_link` succeeds and mandatory synchronous server initialization finishes, and prevent completion from overwriting a drain already requested. A response from the endpoint alone is insufficient because `Oli.Application` starts it before other children (AC-039, AC-040).

Readiness initially checks the named local `Oli.Repo`, `Oli.PubSub` and `Oli.Vault` services; a functioning HTTP handler establishes endpoint availability. Exclude the local NodeJS evaluator pool from all probe checks, regardless of the configured evaluator/substitution implementation. Use cheap availability checks with bounded behavior, not a full supervision-tree walk, cache warmness, queue backlog or cluster-node-count requirement. Supervision remains responsible for recovering individual local services; readiness becomes false while a required one is unavailable without making liveness restart the entire application.

After local checks pass, perform `SELECT 1` through the application’s normal `Oli.Repo` pool with a one-second total budget including pool checkout and query execution. Configure checkout/query bounds and cancellation together; setting only a query timeout after an unbounded checkout is insufficient. Pool exhaustion, checkout errors, query errors/timeouts and an unavailable repo produce 503. Ensure timed-out work is canceled and repeated probes cannot leave detached queries/tasks running. Recheck lifecycle state before returning ready so draining that starts during the query produces 503.

Keep S3/MinIO, ClickHouse, Canvas/Moodle LTI providers, reCAPTCHA, AI providers, Oban backlog and cache warming out of these probes. Monitor and test those separately. Release migrations/seeds stay in deployment setup; probes never run migrations or repeatedly scan schema versions.

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

### Readiness workflow contract

Use the fixed public HTTPS `/readyz` URL and version/full SHA from the build outputs.
A `curl`/`jq` loop requires HTTP 200, `status: ready`, and exact string version/SHA
matches. Disable redirects, TLS bypass, cookies, and infrastructure authentication.
Send no-cache headers. Limit each response to 4096 bytes and each request to 10 seconds;
retry every 10 seconds. GNU `timeout 20m` bounds the whole loop, including the final
request or sleep, so no observation after the deadline can release browser tests.
Log HTTP status and elapsed time, and the matched identity on success. Temporary
response bodies are removed and are not printed or uploaded. Timeout exits nonzero.

### GitOps update contract

For local engineering work, if the `oli-torus-gitops` checkout location is unknown, prompt the human engineer for its path before accessing the repository. Treat the supplied checkout path as session-only information: do not persist it in documentation, configuration, notes or other saved state. All documented GitOps file references must remain relative to the GitOps repository root. This local setup instruction does not add an interactive prompt to CI.

All paths in this paragraph are relative to `oli-torus-gitops`. The updater requires an existing `deployments/nightly-playwright.yml` with `app: oli-torus`, expected slug, `enabled: true`, `overlay: staging`, public access and exact nightly hostname. Call the updater with only `--record`, `--image-tag`, `--source-ref <selected source ref>`, and `--commit-sha`; never pass create, enable/disable, overlay, host or access-policy flags.

Allowed semantic changes are exactly `imageTag`, `metadata.sourceRef`, and `metadata.commitSha`. Preserve other values and unrelated textual content/comments. The updater preserves existing text and validates the record. The required GitOps `validate` check runs updater tests, repository validators, and static renders before merge; Torus need not repeat the render pass. Revalidate on branch conflicts; do not force-push the tracked branch.

Use the repository-scoped GitHub App installation token with the maintained
`peter-evans/create-pull-request` action, pinned to a reviewed commit. Enable commit
signing, use a unique run/attempt branch, and restrict `add-paths` to the deployment
record. No separate bot-login setting or PR lifecycle helper is required.

GitHub CLI calls the immediate squash-merge API with the action's exact PR head SHA.
GitHub enforces required checks, signatures, and review rules. Retry requests every
10 seconds within a 15-minute step timeout; do not queue auto-merge, bypass policy,
or repair conflicting branches. After merge, read the protected branch at a fixed
commit and compare the deployment record with the prepared file. Record that commit
and proceed to readiness only on an exact match.

Use a separate one-review ruleset with a pull-request-only bypass for the deployment
App. The main ruleset retains mandatory PRs, signed commits, and required up-to-date
checks with no App bypass. The updater and PR action restrict the submitted change to
the nightly record. Keep App credentials in `deploy-plasma`; build and browser jobs
receive none. No additional App permissions are needed.

Failed or canceled runs can leave an open PR, but no merge remains queued. Operators
close stale PRs normally. Cancellation or a lost response during the immediate merge
request can leave a completed merge; inspect the PR before manual maintenance. A failed
run never starts tests. No prior-run scan or automated settlement is needed.

Land the simplified Torus workflow and finish old runs before deleting the old GitOps
helper. Verify signed PR creation, check enforcement, immediate merge, and cancellation
with a full manual run before unattended launch.

The nightly-only ApplicationSet patch retains `overlay: staging`, fixes one replica with
`Recreate` strategy to avoid overlapping instance-local mailboxes, and leaves other
records' probes unchanged. The enabled target now uses this patch. The 2026-10-13 policy
gaps were addressed by the recorded provisioning: auto-merge, required validation,
signature/review rules, and environment branch restrictions are installed. See
`docs/exec-plans/current/nightly-playwright-ci/phase-5-execution.md` for evidence.
Phase 6 explicitly allows the reviewed feature branch in both `nightly-ui` and
`nightly-deploy`, then tests the complete workflow before merging Torus `master`.
GitOps PRs still target protected GitOps `master`. App authentication, signed commits,
unattended merge, required-check enforcement, and cancellation behavior must be demonstrated by
those runs; configured policy alone does not establish that proof.

### Tag-based suite selection

The `@nightly` tags in test sources are the sole source of suite membership (AC-021). Run `npx playwright test --config playwright.nightly.config.ts --grep @nightly` at the same source checkout, with selection handled by the test invocation (AC-031). Adding or removing a tag changes selection through normal code review, without an expected-test list to update.

During implementation, verify the eight audited adaptive cases documented in `assets/automation/tests/resources/adaptive-tests-setup.md` retain their tags. Canvas LTI, Moodle LTI, Dot, and instructor/account flows are also currently tagged and included in delivery. Subsequent membership changes follow normal tag review. The setup documentation records asset/configuration needs, not a second source of test selection.

Fail collection/import errors or zero matching tests during the test invocation; do not enable a pass-with-no-tests option. Let the selected tests consume their normal configuration and resources. AC-022 preserves existing missing-configuration behavior, including skip checks. During launch verification, inspect standard reports and resolve missing configuration so intended integrations execute; skipped integrations are not launch proof. Do not add a separate environment or asset preflight. Use Playwright’s exit status to determine the browser-step outcome (AC-024). Skips and retries remain visible in standard reports; no blanket skip-failure rule, expected-results inventory or custom results validator is required. Retain the existing retry policy.

Report which tests ran using spec path, full title and project, with pass/fail/skip/interruption and retry outcomes (AC-027). Execution output and reports may be retained as run diagnostics; do not maintain or compare against a separate expected-test list.

Declare `json-rules-engine` directly in automation, regenerate its npm lockfile, and assert its resolved version equals the product Yarn resolution (6.1.2 at discovery). Validate from a clean checkout without parent `assets/node_modules`. Local installation must not conceal the dependency.

Explicit configuration:

| Consumer | Required configuration and target rules |
| --- | --- |
| Adaptive | Exact nightly `PLAYWRIGHT_BASE_URL`, nonempty scenario token and automation API key; all eight archives and seven answer files documented in `assets/automation/tests/resources/adaptive-tests-setup.md` must be accessible via authenticated Torus asset routes. Provision the scenario token explicitly rather than relying on the local `my-token` default. |
| Canvas | Explicit `CANVAS_BASE_URL`, account ID/API token, instructor credentials, tool name, and `CANVAS_TOOL_LAUNCH_URL`; `TORUS_BASE_URL` and launch origin must equal the nightly origin. Supply dedicated Torus admin credentials required by the current fixture. Provision corresponding LTI registration. Do not inherit Tokamak defaults. |
| Moodle | Supply the existing API, instructor/student, and tool settings described in `assets/automation/tests/torus/lti_moodle/moodle_playwright.md`; provision its registration and grade-passback fixture to launch into the nightly Torus origin. |
| Dot | Supply `PLAYWRIGHT_PARAMETER_CONFIG_URL` as a GitHub environment variable pointing to the private `/test/assets/dot_chatbot/config.yaml` endpoint; the loader authenticates with the runtime scenario token. Set the document's target to match `PLAYWRIGHT_BASE_URL`. Use scenario mode with the runtime scenario token and service configuration `nightly-dot`. The existing test creates its course and student and checks the streamed response; no separate manual fixture or response check is required. Torus maintainers remove completed-run Dot fixtures between runs as needed. |

Preserve the tests' existing setup, requests and skip checks without adding a nightly flag or configuration/target checks. Do not add global environment validation, archive/answer-format preflight, frozen parameter files or custom reporters. Use the existing parameter loader and fixture cleanup; retries may download updated Dot parameters. This is the user's revised Phase 4 scope: the smallest change needed to execute the tagged suite. Configuration and fixture maintenance remain provisioning responsibilities.

## 6. Data Model & Storage

No database migration or application schema change. Nightly releases run applicable migrations via the GitOps init container; persistent Postgres, MinIO and integration registrations survive image updates. Nightly CI never resets the database, deletes a namespace, or recreates shared credentials. PR CI continues to create, migrate and seed a disposable database that is destroyed with its runner.

Transient run data lives on the runner: provenance, sanitized stage diagnostics, HTML reports and permitted test diagnostics/screenshots/traces. Upload only explicit allowlisted artifacts to the GitHub Actions workflow run with 14-day retention; remove downloaded private assets and secret parameter files. GHCR stores images identified by immutable digests under mutable tags, and Git records deployment intent/provenance. Private asset contents are not new source-controlled data. Captured email is transient Swoosh memory, not part of the persistent nightly database/object-storage contract; each nightly application deployment starts with a fresh mailbox.

## 7. Consistency & Transactions

There is no distributed transaction across GHCR, GitHub, Argo and Torus. Order operations so publication precedes intent, branch acceptance precedes readiness, and readiness precedes tests. An orphaned published image is acceptable; failed publication cannot alter deployment intent. An accepted update remains deployed after test failure until an operator decides otherwise.

The workflow lock spans source selection, build, deployment, test execution, and finalization. Test fixtures retain run-specific identities and existing cleanup. Plate-tectonics currently bounds teardown and logs leaked slugs; retain those warnings in actionable diagnostics. Dot scenario mode creates run-specific users, projects, and sections without automatic teardown. Torus maintainers remove completed-run Dot fixtures and stale failed-run data between runs as needed, preserving durable integration fixtures. Document this procedure in the operator runbook; no new scheduled cleanup service is required initially. Do not convert existing best-effort cleanup to database resets or automatic migration rollback.

## 8. Caching Strategy

Use existing dependency/build caches keyed by lockfiles, toolchain, Mix environment and compile configuration. Separate PR and trusted nightly cache namespaces even though both use `playwright`; nightly must not restore PR-generated compile artifacts. Include relevant configuration files before Docker dependency/application compilation and source files before application compilation so changes invalidate the appropriate layers. Never restore `_build` from a different Mix environment or incompatible compile configuration; a broad restore fallback may recover download caches, not incompatible compiled outputs. Keep production compile caches separate. No health-response or readiness-success cache. Run the public readiness check on every run, including reruns of the same SHA, and let selected tests perform their existing setup. Do not add a separate fixture/configuration preflight. Cache artifacts may accelerate build/install but cannot substitute for clean-install dependency verification during implementation.

## 9. Performance & Scalability Posture

These are design guidelines, not performance acceptance criteria. No benchmarking, custom timing instrumentation, enforced performance budgets or scalability measurements are required for initial delivery. Investigate and measure only if runtime, reliability or resource usage becomes a practical concern.

Keep the initial execution model simple: one browser runner, one Chrome worker and the existing retry count. Consider tuning caches, concurrency or execution cadence only when needed; standard GitHub Actions timing information is available for diagnosis.

The bounded requests, polling and job timeouts specified elsewhere remain failure-handling safeguards. Probe behavior and the database timeout remain correctness requirements; this section adds no performance measurement or enforcement gates.

## 10. Failure Modes & Resilience

| Failure | Required behavior |
| --- | --- |
| Zero matches or collection/import error | Fail the test invocation; preserve its failure status through finalization. Missing configuration retains existing per-test behavior, including skips. |
| Build/push failure | Fail publication; leave GitOps record unchanged. |
| Disabled/wrong target record | The updater rejects the record with expected field names/values; never repair lifecycle automatically. |
| Validation/check/merge failure or deadline | Fail GitOps acceptance; leave the PR unqueued for operator closure; do not test a previous deployment. |
| Old identity, redirect, invalid JSON or network failure | Retry bounded readiness; fail when deadline expires. |
| Database outage after boot | `/readyz` returns 503; `/healthz` remains 200. Recover readiness when database access returns, without restarting solely for the outage. |
| Incomplete startup / draining | Readiness stays 503; startup remains unsuccessful until initialization completes, and draining leaves liveness healthy while HTTP remains available. |
| Release migration/init failure | Readiness times out; operator inspects deployment via their normal access. CI has no cluster credentials. |
| Missing asset/authentication or wrong integration target | Preserve existing test setup outcomes, including missing-configuration skips. Resolve configuration/target problems during provisioning and before accepting launch evidence; diagnostics must omit secret values and asset contents. |
| Playwright exits nonzero or the test step times out | Mark the test step failed; upload available diagnostics and preserve stage provenance. |
| Cleanup fails | Preserve warning and affected synthetic fixture identifiers for Torus maintainers; no rollback/reset. |
| Cancellation/runner loss | No validated success or queued auto-merge. Operators inspect the PR if cancellation coincides with a merge request and close any stale open PR. Artifact upload is best-effort on hard termination. |

Do not automatically retry full deployments or rerun the whole suite indefinitely. A rerun of a manual run retains its original dispatch SHA; use a new dispatch to test the branch's latest commit. Scheduled builds resolve current master each time the build job runs. Source identity is fixed across each build/deploy/test chain, while external fixtures and services can change between runs.

## 11. Observability

Always produce a GitHub step summary when the runner remains available. Include each stage's pass/fail/skipped status, expected source version/SHA, workflow SHA, image tag/digest if published, accepted GitOps commit if available, identity observed at the pre-test readiness gate, failed stage and report links. Use the Playwright step outcome for test status. Link to the standard Playwright report for test identities, individual outcomes, counts, skips and retry details; no custom result parsing or validation is required.

Use an explicit nightly reporter set: line and HTML with `open: never`. Do not override the configured reporters with `--reporter=line`. Retain `actions/upload-artifact` steps with `if: always()` to upload available reports/diagnostics even after test failure. Upload `assets/automation/playwright-report/` as `playwright-report` and `assets/automation/test-results/` as `playwright-test-results`, each with 14-day retention (AC-028). These are downloadable GitHub Actions artifacts attached to the specific workflow run, available from its summary’s Artifacts section. The HTML report is not published as a website. Pre-test failures still produce sanitized stage diagnostics and a summary; upload only files that were generated, without introducing a missing-results success gate.

Torus maintainers own failure triage. GitHub Actions failures, run summaries and reports are the initial reporting channel; no new Slack integration, custom email alerts or dedicated on-call rotation is required. Revisit additional alerting if failures go unnoticed. Existing AppSignal operational monitoring is unchanged.

## 12. Security & Privacy

- Run privileged orchestration through scheduled or authorized manual dispatch. Build/browser jobs use `nightly-ui`; only `deploy-plasma` uses `nightly-deploy`. Environment branch rules must allow master and explicitly reviewed repository branches intended for manual testing; verify those rules during provisioning. Manual branch selection executes that branch's workflow and application code with the environment's access, so only trusted repository branches are eligible. Do not expose publish/GitOps credentials to PR or fork execution. Keep the GitOps destination branch protected regardless of the selected application source branch. Both entry points deploy to the same durable target under the workflow-level lock.
- Keep package publishing permission in the build job. Obtain GitOps credentials only in `deploy-plasma` for record/PR operations and immediate merge. Build and browser jobs receive no GitOps App key or token. Persist no checkout credentials in test artifacts.
- Validate refs/URLs/record paths before passing them as separate subprocess arguments; never interpolate user-controlled text into shell source. Reference GitHub Actions using explicit version tags (for example, `actions/checkout@v5`), following the repository workflow convention.
- Public ingress is intentional; protected scenario, login, mailbox and private-asset operations retain their current authentication. Automation import/teardown retains its existing dedicated API key checks. Keep production compile-time route exclusions and test them in a separate production build.
- Both Playwright builds compile a captcha verifier requiring a separate private runtime token; account authentication and token-protected test APIs remain enforced. Production compile selection cannot be overridden at runtime. Keep mailbox credentials, captured messages and account links out of artifacts.
- Readiness publishes status in every build and compiled version/SHA only in Playwright builds; liveness publishes only status. Probe failures return generic public bodies, with no raw database errors or local process details. The lifecycle drain API is local to the release and has no public HTTP mutation endpoint. Runtime secrets are supplied by deployment secrets; the server alone holds storage credentials. Do not log parameter YAML, API headers, login bodies or raw readiness responses.
- Existing adaptive/Canvas traces can retain credentials and private course content. Disable traces in the initial nightly config until request/response sanitization is demonstrated; preserve Dot's trace-off setting. Keep reports/screenshots restricted, inspect representative artifacts before launch, and disable particular attachments if they contain secrets. Do not assume GitHub log masking sanitizes uploaded files.
- Give dedicated test accounts only the rights required by the current fixture; Canvas's Torus fixture presently requires admin access, so isolate that account and key to the nightly deployment rather than claiming every test credential is low privilege.

## 13. Testing Strategy

The table maps required evidence across the work item; it is not a requirement to repeat every check in the final phase. Execution records already contain local application, release, runner, and GitOps helper results. Phase 5 closes on completed provisioning, installed policy/credentials, and initial readiness/private-asset evidence. Phase 6 owns all remaining operational tests: actual App permissions and PR lifecycle, authenticated integrations, deployed persistence/mailbox behavior, and slow-boot/outage/drain behavior, alongside workflow integration and launch. Reuse valid earlier proof; rerun checks when the affected behavior changes or the earlier evidence does not cover the deployed configuration. No performance measurements are required.

Phase 6 first requires a complete manual run from the reviewed feature branch with `publish_only: false`, actual failure/cancellation/concurrency and lifecycle checks, and report access/privacy review. Include the existing private Dot loader follow-up and wire the provisioned Canvas/Moodle inputs into the browser job; allow that exact branch in both GitHub environments. No Torus `master` merge is required to perform these checks. After the feature-branch checks pass, merge normally and verify a scheduled run from `master`. Verify the intended integrations execute despite preserved per-test skip guards. Record source/image/GitOps identities and results in the Phase 6 execution record; neither G5 closure, documentation validation, nor a passing run with missing-configuration skips proves launch readiness.

| Layer | Verification |
| --- | --- |
| Probe HTTP contracts | AC-012–AC-014, AC-039, AC-042: update health controller tests and add readiness controller tests for status/body fields, Playwright-only compiled metadata, 200/503, unauthenticated pod HTTP without redirects, public HTTPS and no-store headers. Prove liveness performs no DB/external requests and readiness excludes optional dependencies. Keep runtime metadata-override checks in the normal controller tests. Verify Playwright metadata inclusion, production omission and immutable identity against actual compiled releases in the Phase 3 smoke tests; do not recompile source inside embedded test scripts. Preserve clean ExUnit logs. |
| Lifecycle and bounded readiness | AC-013, AC-040: test startup before/after full initialization, restart reset, required local service absence/recovery, drain during a query and actual graceful shutdown before endpoint stop. Exercise database disconnection, exhausted pool, query failure and timeout; assert the total budget and no accumulating work. Verify DB failure leaves liveness healthy and NodeJS evaluator pool unavailability alone does not change probe status. Isolate lifecycle mutation so test state cannot leak. |
| Probe deployment | AC-041: static render checks for all probe paths/timings, startup gating, drain hook bounds and termination grace. In an authorized disposable deployment, demonstrate slow boot, database outage/recovery and termination; readiness changes without dependency-triggered liveness restarts. |
| Readiness loop | Temporary command fixtures cover valid identity, wrong version/SHA, missing/non-string fields, malformed JSON, redirect/login HTML, non-200, connection errors, TLS verification policy, deadline bounds and pre-test identity mismatch. Prove downstream test command is not invoked on failure. |
| Release | Build `MIX_ENV=playwright` and `MIX_ENV=prod` separately; smoke boot the Playwright release against disposable services with runtime secrets, check both probe contracts and readiness/full SHA plus authenticated scenario/private-asset/mailbox behavior, and verify absent-token denial. Production build must retain gated-route exclusion and status-only readiness responses. Check required fixture files, metadata, image layers and default production settings. |
| Shared compile environment | AC-032, AC-033, AC-036: build the shared configuration through both PR server startup and nightly release paths from clean/cached states; assert direct scenario/mailbox/reCAPTCHA and local mail adapter settings without extra capability flags, and that post-build env changes have no effect. Verify configuration changes invalidate relevant compile caches/layers and nightly cannot restore PR compile artifacts. Build production with runtime verifier overrides attempted and prove test routes remain absent and normal reCAPTCHA selected. Verify no dev import/debug defaults, that `config/ci_e2e.exs` is absent, and that no active workflow, script, configuration or documentation reference depends on `ci_e2e`. Verify no compatibility alias, wrapper or fallback remains. |
| PR migration | AC-003, AC-035: run the full existing `@pr` suite, including registration/confirmation/password reset, using explicit local runtime inputs and complete assets. Verify no nightly credentials/private assets/publication access are needed and disposal retains isolation. |
| reCAPTCHA verifier | AC-037: only the current nonempty runtime captcha token succeeds locally; missing/empty/incorrect/malformed inputs fail without Google. Missing/empty runtime configuration fails startup. Verify shared call sites, immutable compile selection, and normal Google success/failure behavior in production. |
| Form submission | AC-038: existing registration LiveView, enrollment and payment flows complete using a runner-supplied token without DOM inputs or deployed client substitution. Verify unauthorized submissions fail and credentials cannot enter native GET URLs or external destinations. Audit remaining protected submissions and run affected browser specs plus the existing `@pr` suite. |
| Mailbox | AC-034: under each PR/nightly build, capture a local message, retrieve it by unique recipient and ID with the correct token, reject missing/invalid tokens and verify recipient filtering. Exercise restart behavior and inspect diagnostics for email/reset-token disclosure. |
| Dependency/selection | Clean temporary checkout with no parent dependencies: `npm ci`, direct execution with the nightly config and `--grep @nightly`, and engine-version parity. Verify initial adaptive tags; exercise import/collection errors, zero matches and existing missing-key skip behavior. Confirm a newly tagged test is selected during execution without updating another list or running a separate collection step. |
| Reports | Verify standard Playwright reports show test identities, outcomes, skips and retries. Verify HTML/report output paths, GitHub Actions artifact names and 14-day retention, plus upload/summary execution after test failure. |
| GitOps contract | Fixture tests for exact allowed keys, comments/unrelated content, disabled record, hostname/overlay/access mismatch, conflict, denied checks, timeout and late merge. Run record/policy validators and static Kustomize rendering with no cluster contact; ensure app/init container image parity and reviewed probe/drain settings. |
| Workflow | YAML/action lint plus orchestration tests for scheduled master checkout, manual dispatch-SHA checkout and rerun stability, stage dependencies, no production tags, bounded failures, workflow-scoped lock across the job chain, preserved PR triggers/checkout/coverage, unchanged backend scenario job and preservation of Playwright failure status through artifact upload/summary steps. Exercise cancellation with a pending bot PR. |
| Provisioned target | One manual then one scheduled full run, all required cases, retained diagnostics, and reviewed artifacts. Observe old-revision polling and readiness timeout. Overlap dispatches to confirm serialization and pending policy; verify the operator procedure prevents manual updates during testing. Confirm durable fixtures/services survive image updates. |

Run focused ExUnit and script/automation checks appropriate to implementation, then required review under `docs/CODEREVIEW.md`: security/performance plus backend/TypeScript lenses where changed; requirements review applies if PRD changes. A full `mix test` is mandatory if shared test support/configuration changes. No new domain scenario test is necessary for this orchestration design unless implementation crosses domain workflows.

Record actual launch results and proof artifacts against canonical acceptance criteria later. Document validation and historical dependency experiments do not satisfy AC-029.

## 14. Backwards Compatibility

The probe contract intentionally changes: deploy a capable image before switching GitOps readiness to `/readyz`, and migrate PR waiting and other readiness consumers. See section 5 for response and rollout details.

Land shared configuration, PR asset/runtime setup and deletion of `ci_e2e` together, with passing `@pr` verification. Preserve PR triggers, source selection, test coverage and disposable lifecycle, while retaining mailbox/account credential privacy in traces and attachments. Keep other shared browser-runner defaults and the independent backend scenario job unchanged. Nightly configuration supplies standard reporting and privacy settings. Existing tests own setup and missing-configuration behavior; it adds no target/configuration preflight or custom coverage validator.

Keep unattended runs gated on provisioning and the manual verification/artifact review in Phase 6; a successful scheduled run then closes the final launch checklist. The existing schedule is retained, with its pause/resume procedure documented for rollout. Pause scheduling during incidents; any rollback uses reviewed GitOps changes and a database-compatibility assessment. Do not automatically reverse migrations. Historical notes may retain old names when clearly marked as superseded.

## 15. Risks & Mitigations

| Risk | Mitigation / accepted limitation |
| --- | --- |
| Same-commit rebuild or mixed replicas | Keep digest provenance but state the public observation's limits. The pre-test identity check does not prove continuous or all-replica identity. |
| Cancellation during immediate merge | No auto-merge is queued. Inspect the PR to resolve an in-flight request whose response was lost; a failed run cannot start tests. |
| GitOps updater rewrites comments | Add content-preserving updates and exact fixture/diff checks before adopting the existing writer. |
| PR migration loses inherited settings or assets | Explicit runtime input table, release-style asset builds, existing account/email suite and disposable-database verification. |
| Shared cache carries Playwright settings into production | Mix environment and configuration-sensitive keys, separate trusted/untrusted cache namespaces and fresh PR/nightly/production build checks. |
| Mailbox messages disappear or grow indefinitely | Single-instance mailbox tests, run-unique recipients and restart-aware setup; each nightly application deployment starts with a fresh mailbox. |
| Incorrect startup/drain state | Set completion after initialization, enter drain before service shutdown, reset state on app restart and verify real lifecycle transitions. |
| Probe change restarts or removes healthy instances | Bound readiness work, keep dependencies out of liveness, allow slow startup and validate database-outage behavior and rendered probe timing. |
| Release omits development-only config/files | Standalone Playwright release settings, explicit runtime branches and packaged-fixture smoke checks. |
| Privileged public test endpoints or secret traces | Retain authentication, dedicated target credentials, default nightly traces off and restricted artifact inspection. |
| Slow cleanup/data accumulation | Preserve bounded teardown warnings; Torus maintainers remove completed-run Dot scenario fixtures and stale failed-run data between runs as needed. |
| Integration target drift | Provision Canvas and Dot targets to use the nightly deployment; retain existing integration behavior without adding runtime target checks. |
| Longer CI runtime | Keep one worker initially; investigate timings and tune only if runtime becomes a practical concern. |

## 16. Open Questions & Follow-ups

No unresolved design questions remain. Phase 5 provisioning is complete; all remaining deployed-target and integrated operational checks belong to Phase 6's feature-branch verification and launch checklists. Reuse completed local release fixture/mailbox evidence, while verifying untested deployed behavior before unattended launch. Responsibilities and verification scope are recorded in section 13 and the Decision Log.

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
| 2026-10-07 | Readiness metadata visibility | Expose compiled version/SHA only in Playwright builds for CI identity checks. Other builds retain unauthenticated status-only readiness; runtime settings cannot enable metadata. |
| 2026-10-07 | Readiness pool contention | Defer additional rate limiting, single-flight or caching until observed contention or exhaustion warrants it. The probe uses a lightweight `SELECT 1` with a one-second checkout/query budget and cancellation. This bounds each check, not aggregate concurrency; revisit if probe traffic affects application requests. |
| 2026-10-13 | Manual branch execution | Allow manual dispatch of a selected repository branch at its exact dispatch SHA; schedules continue selecting master. Build, deployment and browser checkout share that identity and the same target lock. Manual reruns retain their SHA; environment branch permissions are verified during provisioning. |
| 2026-10-14 | Reconcile integration and launch | Phase 6 reuses existing build, lock, runner, artifacts, and GitOps helpers and absorbs former Phase 7 as a launch checklist. The separate build-preflight credential proposal is superseded by the decision below. Existing tests retain setup/skips under AC-022, with all tagged integrations, including Moodle, required for launch evidence. No new preflight/results framework or repeated unchanged component testing. |
| 2026-10-14 | Use one GitOps App | Use one App in `nightly-deploy` and no GitOps credentials in build/browser jobs. The intermediate proposal to move preflight into deployment is superseded by the decision below. Workflow wiring remains Phase 6 work. |
| 2026-10-14 | Remove GitOps preflight | User requested no check for unsettled prior bot PRs. Remove the preflight command and its tests; retain current-record validation, GitHub merge enforcement, current-run verification and cleanup. Operators handle orphaned PRs after interrupted runs. |
| 2026-10-14 | Separate review ruleset | User selected a pull-request-only App bypass on a review-only ruleset. Keep PR, signature, and validation requirements in the main ruleset without an App bypass. No auto-approval workflow; actual bot merge remains a provisioning gate. |
| 2026-10-15 | Provisioning and feature-branch verification | Operator closed Phase 5 on completed setup and moved every remaining live test to Phase 6, superseding prior phase assignments. Phase 6 verifies the full workflow on an explicitly allowed feature branch before Torus merge, including actual bot operation, integrations, persistence/mailbox and lifecycle checks; scheduled proof follows merge. All acceptance criteria remain required. |

The 2026-10-15 operator-approved simplification supersedes earlier wait/settle and
auto-merge lifecycle decisions: retain protected signed PRs and exact revision gating,
use a maintained PR action plus GitHub CLI, and remove custom lifecycle machinery.
