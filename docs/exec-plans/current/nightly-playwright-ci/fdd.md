# Nightly Playwright CI - Functional Design Document

## 1. Executive Summary

Extend `.github/workflows/nightly-playwright.yml` with a serialized build-to-test job for the durable target at `https://nightly-playwright.plasma.oli.cmu.edu`. Resolve one master commit, build a dedicated `MIX_ENV=playwright` release, publish a unique GHCR tag, update the reviewed GitOps deployment record, wait for the public application version/SHA, and execute Playwright from the same checkout. Argo CD remains the deployment actor. Migrate the PR workflow from `ci_e2e` to the same `playwright` Mix environment, preserving its triggers, source selection and test coverage. Preserve the independent backend scenario job.

Split probes by purpose: `/healthz` serves dependency-free startup/liveness, and `/readyz` checks application readiness and returns compiled `version`/`sha`. Include startup completion, draining and reviewed GitOps probe/lifecycle changes in this work. CI’s initial and final `/readyz` checks observe the expected public source identity; they do not establish replica convergence or distinguish same-source rebuilds.

GitOps branch policy, integration provisioning, and operational ownership remain launch gates in section 16. The provisional design retains all ten currently tagged cases, including the eight required adaptive cases, and uses validated bot PRs with automatic merge subject to repository rules.

## 2. Requirements & Assumptions

`docs/exec-plans/current/nightly-playwright-ci/requirements.yml` is canonical. All requirements remain proposed; the table maps design and future verification, not implementation proofs.

| Requirement | Acceptance criteria | Design responsibility |
| --- | --- | --- |
| FR-001 | AC-001, AC-002, AC-003 | Ordered stages, fixed master SHA, existing workflow isolation (§4, §13) |
| FR-002 | AC-004, AC-005, AC-006, AC-032, AC-033, AC-034, AC-035, AC-036, AC-037, AC-038 | Shared PR/nightly compile environment, explicit build inputs, mailbox access, PR migration and runtime-only secrets (§4–6, §8, §12–14) |
| FR-003 | AC-007, AC-008 | Unique immutable tag, digest provenance, publish-before-update (§4–5) |
| FR-004 | AC-009, AC-010, AC-011 | Narrow record change, validated branch acceptance, Argo CD ownership (§5, §7) |
| FR-005 | AC-012, AC-013, AC-014, AC-039, AC-040, AC-041, AC-042 | Separate probes, startup/drain state, bounded database readiness, metadata and GitOps configuration (§4–5, §9–14) |
| FR-006 | AC-015, AC-016, AC-017, AC-018 | Public HTTPS identity polling with bounded failures and precise claims (§5, §10–11) |
| FR-007 | AC-019, AC-020 | One target lock through final check and controlled writers (§4, §7) |
| FR-008 | AC-021, AC-022, AC-023, AC-024, AC-030, AC-031 | Tag-based selection, configuration/collection gates, dependency fix and result reporting (§4–5, §13) |
| FR-009 | AC-025, AC-026 | Persistent services, isolated fixtures, visible cleanup failures (§6–7) |
| FR-010 | AC-027, AC-028, AC-029 | Stage/provenance summary, diagnostics, manual and scheduled launch proof (§11, §13) |

Assumptions and scope:

- Keep the daily `17 5 * * *` schedule and manual dispatch. Both nightly entry points resolve `refs/heads/master` once after obtaining the target lock. Manual dispatch is restricted to the protected master workflow; arbitrary branch/SHA deployments are outside initial scope. Record the workflow SHA separately if it differs from the selected source SHA.
- Both PR and nightly use `MIX_ENV=playwright`; their scenario and mailbox build inputs are enabled. Both select secret-protected deterministic reCAPTCHA at compile time, with distinct runtime tokens. PR continues to test its existing pull-request checkout with disposable services.
- Use the existing GHCR repository `ghcr.io/simon-initiative/oli-torus` with a distinct nightly tag namespace; the GitOps record only accepts an image tag, not a different repository or digest field.
- Propose all ten current nightly cases as required. Until scope is confirmed, missing Canvas/Dot configuration blocks launch rather than implicitly reducing coverage.
- The deployment is currently disabled in the inspected GitOps draft. Provisioning and enabling it are separate reviewed GitOps work. Recurring CI cannot change lifecycle, access policy, overlay, hostname, or infrastructure.
- No UI, domain schema, new feature flags, or application throughput SLA. Per `harness.yml`, include telemetry, review and Jira traceability; CI summaries provide orchestration telemetry without new AppSignal instrumentation.

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
| `lib/oli_web/controllers/playwright_mailbox_controller.ex`, `lib/oli/playwright/recaptcha.ex` | Mailbox requests already require the scenario token; captured email uses instance-local Swoosh memory. Deterministic reCAPTCHA currently supports the PR account suite. Preserve those behaviors through explicit build settings. |
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
| `.github/workflows/pr-playwright.yml` | Switch to shared compile environment and explicit capability/runtime inputs; retain existing PR triggers, checkout, suite and disposable lifecycle |
| `config/playwright.exs` (new), `config/runtime.exs`, `mix.exs`, `Dockerfile`, `lib/oli_web/endpoint.ex` | Shared compile-time settings, build-argument forwarding, release-style assets and runtime configuration; retire `config/ci_e2e.exs` |
| `assets/automation/src/core/` shared form helper; `CredentialAccountPO.ts`, `StudentCoursePO.ts`, `tests/torus/student_payment/support.ts` | Read the runtime captcha token, support standard/LiveView submission, replace placeholders and add missing registration support |
| `lib/oli/health.ex` (new), `lib/oli/application.ex` | Own node-local startup/drain state and bounded readiness checks; wire actual application startup/shutdown transitions |
| Existing health controller/view, new readiness controller/view, router, SSL plug and tests | Local-only `/healthz`; `/readyz` with readiness status/metadata, HTTP 503 failures, direct pod HTTP and no-store responses |
| `assets/automation/package.json`, `package-lock.json` | Direct engine dependency aligned with product lockfile |
| `assets/automation/scripts/nightly-suite.ts` (new) | Validate collection success/nonzero selection, selected-test configuration and execution outcomes; report per-test results without maintaining a test catalog |
| `assets/automation/playwright.nightly.config.ts` (new) | Extend shared settings with explicit CI reporters and privacy settings without altering local/PR defaults |
| `assets/automation/tests/resources/nightly-ci.md` | Operator setup, tag-based selection, integration target policy, cleanup and incident procedures |
| GitOps updater/record checks in `oli-torus-gitops` | Content-preserving allowlisted update and policy-conforming merge; separate repository ownership |
| GitOps application deployment manifests in `oli-torus-gitops` | Reviewed startup/liveness/readiness probe and shutdown-drain configuration, independently of recurring image updates |

Use the existing Node/TypeScript execution tooling or compile the small automation helper with its installed TypeScript compiler; do not introduce another test orchestration framework. Python handles CI orchestration outside browser fixtures; Playwright helpers handle suite semantics.

### 4.2 State & Data Flow

1. **Resolve/preflight:** after acquiring the lock, resolve master to a full 40-character commit, checkout that exact revision, and record `Mix.Project.config()[:version]`. Reject non-master dispatch, wrong target configuration, missing CI inputs, disabled/wrongly targeted GitOps records, and unresolved prior bot updates before publishing or changing intent.
2. **Install/collect:** run clean `npm ci` in `assets/automation`; run `npx playwright test --grep @nightly --list` with machine-readable output consumed by the suite helper. Fail collection/import errors or zero matching tests before browser installation. The tags in this checkout determine membership; do not compare discovery with a separately maintained expected list.
3. **Build/publish:** build the release at the fixed checkout with `MIX_ENV=playwright`, `SHA=<full SHA>`, and the explicit nightly capability inputs from section 5. Verify build metadata matches expected version/SHA, then publish the unique tag and capture its digest. No GitOps mutation on failure.
4. **Advance intent:** validate a narrow image/source diff, submit through the agreed GitOps path, wait for accepted branch state, and record the accepted GitOps commit. Re-read the tracked branch to verify the actual record values.
5. **Readiness:** poll public `/readyz` until expected version/SHA is observed or deadline expires. Do not start tests on failure.
6. **Target setup gate:** validate private asset access and selected integration configuration against the ready target. Requests use existing application authentication. Fetch required archives/answer keys into restricted runner temporary storage, validate expected formats without logging bodies, and delete them after checking. Course import/setup failures remain clearly identified fixture failures.
7. **Browser execution:** install Chrome only after collection succeeds; execute the same selection and checkout using the nightly config. Preserve one worker and one retry. Validate outcomes after execution, including unexpected skips and missing results, and report the identities of tests that ran.
8. **Finalize:** whenever tests started, perform a final public identity check even after test failure, then upload generated artifacts and render the summary. Aggregate test status, execution-result validation and final identity status; all must pass for validated success. Never replace an earlier failure with a successful cleanup/upload status.

A run provenance record contains source ref/SHA/version, workflow SHA, run ID/attempt, image tag/digest, accepted GitOps commit, the `@nightly` selector and non-secret compile capability inputs. Stage results append outcomes and elapsed times. A missing downstream stage is `skipped` with its prerequisite failure, never `passed`.

### 4.3 Lifecycle & Ownership

Torus maintainers own workflow/helpers, release capabilities, probe lifecycle/readiness metadata, and selected-test execution checks. GitOps maintainers own provisioning, branch policy, ingress, secrets, probe/drain manifests, image write permissions and Argo reconciliation. QA/test owners own private fixture correctness and Canvas/Dot registrations. Named on-call/cleanup ownership is a launch gate.

The target has one routine writer: this workflow. Operators pause new target runs and wait for the active interval to finish before manual image changes. A public final check detects some interference but cannot prove uninterrupted identity or enforce a distributed lock against other repositories/operators.

### 4.4 Alternatives Considered

- **Separate `ci_e2e` and nightly compile environments:** preserves the development import but duplicates capability configuration and lets PR/nightly behavior drift. One standalone `playwright` environment serves both service lifecycles.
- **Importing `dev.exs` into the shared environment:** supplies convenient local defaults but also debug settings and development credentials. Declare the needed CI settings explicitly.
- **Production image with runtime-only test flags:** cannot enable compiled-out routes. A standalone `playwright` compile environment keeps production exclusions intact.
- **Argo/Kubernetes rollout polling:** offers different rollout evidence but adds infrastructure credentials and exceeds the chosen public-readiness contract.
- **Split deployment and test jobs:** would require a lock spanning jobs. One job gives a clear protected interval without another lock service.
- **Direct bot commits:** simpler and avoids pending auto-merge state, but only valid if branch rules explicitly permit it. Do not fall back to direct writes when PR checks fail.

## 5. Interfaces

### Release and image contract

Use one standalone `config/playwright.exs` with `MIX_ENV=playwright` and `env: :playwright` for PR and nightly CI (AC-032). Keep `nightly` for the scheduled workflow, durable deployment and image tags. Both workflows explicitly set the non-secret compile inputs below before any Mix configuration evaluation or compilation (AC-033).

| Compile-time environment variable | Application setting | PR | Nightly | Omitted value |
| --- | --- | --- | --- | --- |
| `PLAYWRIGHT_ENABLE_SCENARIOS` | `enable_playwright_scenarios` | `true` | `true` | `false` |
| `PLAYWRIGHT_ENABLE_MAILBOX` | `enable_e2e_mailbox` | `true` | `true` | `false` |
| `PLAYWRIGHT_DETERMINISTIC_RECAPTCHA` | `recaptcha_module` | `true` selects `Oli.Playwright.Recaptcha` | `true` selects `Oli.Playwright.Recaptcha` | `false` selects normal verification |

Accept only the literal strings `true` and `false` when a variable is supplied; fail configuration evaluation on empty/invalid values. Read these inputs only in the Playwright compile configuration. Keep existing router `Application.compile_env` gates and capture the selected reCAPTCHA module through the shared verifier’s compile-time configuration; `runtime.exs` must not reread or override these selections. Merely changing process environment variables after compilation must not change capabilities. Production does not consume these Playwright inputs and retains disabled test routes and normal reCAPTCHA even if all three variables are supplied as `true` (AC-005). Existing dev/test behavior need not change.

`Dockerfile` declares and forwards these non-secret build arguments before compile configuration/dependency compilation. The PR workflow exports the same inputs before all Mix steps; the nightly build passes them explicitly rather than relying on the runner environment reaching Docker. Include their effective values in build diagnostics and cache keys. Both workflows use the same capability combination; artifacts still differ by source revision and build. Runtime token values are independent of the artifact. Do not publish or promote a PR artifact into the durable target.

Configure static asset manifests, info-level logging and `Swoosh.Adapters.Local` in the shared environment. Leave preview QA tools disabled. Explicitly disable reloaders, watchers, debug error pages and LiveView development checks, retain normal origin checks, and omit development credential defaults. Do not import `dev.exs`. Include `:playwright` in release-only runtime configuration, SSL defaults, `start_permanent` and endpoint static gzip behavior. PR explicitly sets `FORCE_SSL=false` for local HTTP; nightly uses HTTPS and release defaults.

### PR migration and runtime inputs

The existing PR workflow continues using its pull-request checkout, disposable Postgres service, `mix ecto.setup`, `mix phx.server` and `--grep @pr`; change its server wait from `/` to HTTP 200 `/readyz`. Sharing the Mix environment does not require registry publication or GitOps operations (AC-003, AC-035). Set `MIX_ENV=playwright` throughout, update cache names and explanatory comments, and retire `config/ci_e2e.exs` and active references after migration. Replace development-derived startup values with an explicit job configuration. Build frontend and server-side bundles plus Tailwind/digested assets through the supported release asset pipeline before startup; `yarn run deploy` alone is not the design contract for a release-style endpoint.

| Runtime concern | PR workflow | Durable nightly deployment |
| --- | --- | --- |
| Database | Explicit `DATABASE_URL`/`DB_NAME` for the job's disposable Postgres; create/migrate/seed locally | Dedicated persistent database; existing release setup handles migrations |
| Endpoint | `HOST=localhost`, `SCHEME=http`, `HTTP_PORT=4002`, `PORT=4002`, `FORCE_SSL=false`; matching browser base URL | Nightly HTTPS hostname, ingress/service ports and release SSL defaults |
| Signing/encryption | Explicit job-scoped `SECRET_KEY_BASE`, `LIVE_VIEW_SALT`, `CLOAK_VAULT_KEY` and any other required release runtime settings | Dedicated deployment-managed secrets |
| Scenario/mailbox token | Generated per job and shared with its browser runner at runtime | Nonempty deployment token supplied to Torus and protected CI configuration |
| Storage settings | Explicit test bucket/media settings required for boot, with no real storage credentials or private asset dependency for the current `@pr` selection | Dedicated media/xAPI/test buckets, endpoints and server-side credentials |
| reCAPTCHA token | Generate a dedicated job-scoped `PLAYWRIGHT_RECAPTCHA_TOKEN`, shared by server and runner | Dedicated `PLAYWRIGHT_RECAPTCHA_TOKEN` deployment/CI secret, separate from the scenario/mailbox token |
| Human reCAPTCHA | Automated cases use the secret path without Google; local manual use may configure normal keys | Valid `RECAPTCHA_SITE_KEY`/`RECAPTCHA_PRIVATE_KEY` for the nightly hostname; preserve the normal widget and verification fallback |

Load `PLAYWRIGHT_SCENARIO_TOKEN` into the existing application key at runtime and fail startup if empty/missing when scenario or mailbox capabilities are compiled in. Load `PLAYWRIGHT_ASSETS_BUCKET` and ExAws settings at runtime. The shared environment must permit PR startup without a private-assets bucket; nightly preflight requires that bucket and checks authenticated access before tests. Missing storage configuration remains an error when an asset-dependent operation is invoked. Tokens, database credentials, signing salts and storage keys are runtime inputs, never Docker build arguments or compile-time configuration values (AC-006). Keep both workflow startup commands and build contexts consistent with that separation; compilation must succeed without deployment secrets.

### reCAPTCHA test-token and human verification contract

Replace the unconditional success behavior in `Oli.Playwright.Recaptcha` with token verification for both workflows (AC-037). Compile `Oli.Recaptcha` with the module selected by `PLAYWRIGHT_DETERMINISTIC_RECAPTCHA`. Route remaining direct calls to `Oli.Utils.Recaptcha.verify/1` through `Oli.Recaptcha.verify/1`, preserving production’s normal implementation and response contract. This keeps registration, invitations, LTI, delivery and other captcha-protected entry points consistent.

When the test implementation is selected, require a nonempty `PLAYWRIGHT_RECAPTCHA_TOKEN` at runtime and fail startup on missing/empty configuration. For a nonempty string `g-recaptcha-response`, compare with that token using `Plug.Crypto.secure_compare/2`. A match returns `{:success, true}` without contacting Google. A nonmatching response delegates directly to `Oli.Utils.Recaptcha.verify/1` and preserves its result, including verification failure or timeout; do not recurse through the wrapper. Missing, empty or non-string responses return `{:success, false}`. The test secret authorizes only the deterministic path and does not replace account or API authentication. Keep the normal captcha widget for humans and configure nightly with valid Google site/server keys for its hostname. A mistyped test token cannot grant deterministic success; it follows ordinary verification.

PR generates a cryptographically random job-scoped token; nightly provisions a separate random secret shared only by the target and authorized test runner. Never reuse the scenario/mailbox token for captcha. Both tokens remain runtime-only so rotation requires configuration/process restart, not a rebuild. Require at least 32 random bytes for provisioned/generated test tokens.

Update shared browser fixtures/helpers to suppress the external captcha widget only in automated test flows and submit the runtime test token through the existing response field, including LiveView form events. Normal human sessions retain the widget. Scope injection to the configured Torus origin; do not send it to Canvas or external captcha endpoints. The application must never render the expected token in HTML, JavaScript or public configuration. Redact `g-recaptcha-response` from server request logs, avoid token values in assertions/errors, and disable token-bearing traces/attachments in PR and nightly until sanitization is demonstrated. Audit existing helper placeholder responses so no tested flow depends on unconditional success. Add negative verification cases rather than silently treating every submitted form as authorized.

### Browser form-helper migration

AC-038 explicitly includes the missing client support in this work item. Add one shared helper under `assets/automation/src/core/` that receives the target form locator, reads the nonempty `PLAYWRIGHT_RECAPTCHA_TOKEN` from the runner environment, and sets a single effective `g-recaptcha-response` value before submission. Pass the token into browser evaluation as an argument; do not hardcode it or embed it in browser bundles. Support normal HTTP forms and Phoenix LiveView serialization/events, and scope the operation to the configured Torus origin. Missing configuration must fail before the form is submitted with a message naming the variable but never its value.

Migrate these confirmed call sites:

| Existing helper | Current gap | Required change |
| --- | --- | --- |
| `assets/automation/src/systems/torus/pom/home/CredentialAccountPO.ts`, `register` | Supplies no captcha response and relies on unconditional server success | Invoke the shared helper before the registration LiveView submit and verify the token reaches the server |
| `assets/automation/src/systems/torus/pom/course/StudentCoursePO.ts`, `fillAutomationRecaptchaResponse` | Injects `playwright-test-token` and suggests development keys/load-testing mode on failure | Replace injection with the shared helper and update the failure message for runtime token configuration |
| `assets/automation/tests/torus/student_payment/support.ts`, `submitPaymentCode` | Injects `playwright-test-token` into the payment form | Use the shared helper before payment-code submission |

Audit remaining protected form submissions and add the helper where necessary, including any invitation/LTI flows exercised by the selected suites. Update fixtures together with the verifier so no existing test is left dependent on accepting a missing/arbitrary response. Tests that do not submit a captcha-protected form need no token injection. Keep widget suppression within the automation fixture; never disable the normal widget application-wide. An explicit fallback-verification test may omit the helper to exercise human behavior.

### Mailbox contract

Both workflows compile `enable_e2e_mailbox: true` and use `Swoosh.Adapters.Local` (AC-034). Preserve `GET /test/emails?to=<recipient>` and `GET /test/emails/:id`, including the existing optional subject filter and JSON contract. Both endpoints require the existing `x-playwright-scenario-token` authorization; missing/wrong tokens fail. No extra nightly-only mailbox gate is needed. Captured mail is not sent through SES/SMTP.

Tests use run-unique recipients and retrieve only the messages they created. Mailbox state is in-memory and instance-local: startup/restart begins a new mailbox, and mailbox-dependent flows initially require a single application replica. Deployment serialization keeps routine rollouts outside test execution, but restart during an email flow can still fail that flow. Do not add shared mailbox persistence or replica routing in this work item; revisit those boundaries before scaling mailbox-dependent tests. Define bounded mailbox retention or controlled instance recycling between runs in the operator runbook; do not clear all messages during active test execution. Reports and traces must not expose captured confirmation/reset links or message bodies.

### Nightly image publication

Use tag `sha-<full SHA>-nightly-<run ID>-<attempt>` in the existing GHCR repository. Include source/version OCI labels and retain the published digest in provenance. Treat a pre-existing tag as a collision: fail or reuse the already published digest without rebuilding/overwriting it. Never publish nightly output to production tag names or `latest`. Build from a clean context before materializing runtime configuration; exclude automation dependencies, reports, downloaded assets and local secret files from the Docker context. Scope cache keys by environment/toolchain/locks and all compile capability inputs.

Required adaptive/scenario logic lives in `lib/`; do not add `test/support` or preview seeding modules to `playwright` `elixirc_paths`. Existing support asset endpoints resolve paths from the source tree, which a final release does not retain. During implementation, verify every selected case's support-asset needs; package any required public fixtures under release `priv/` and resolve them via application paths, with existing local behavior retained. Private course archives remain exclusively in object storage. A release smoke check must catch missing runtime files/modules rather than assuming compilation proves functionality.

### Probe contracts

Use two unauthenticated endpoints in all server environments, including production and Playwright. Startup and liveness share `/healthz`; Kubernetes uses different timing for those two probes. CI polls `/readyz` and separately checks build identity.

| Probe | Endpoint | Checks and response |
| --- | --- | --- |
| Startup | `/healthz` | HTTP responds and application initialization completed. Before completion return HTTP 503 with `{"status":"starting"}`; afterward return HTTP 200 with `{"status":"ok"}`. Allow a generous startup window. |
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

Readiness initially checks the named local `Oli.Repo`, `Oli.PubSub` and `Oli.Vault` services; a functioning HTTP handler establishes endpoint availability. Include the local NodeJS evaluator pool only when configured as the request-serving evaluator/substitution implementation. Use cheap availability checks with bounded behavior, not a full supervision-tree walk, cache warmness, queue backlog or cluster-node-count requirement. Supervision remains responsible for recovering individual local services; readiness becomes false while a required one is unavailable without making liveness restart the entire application.

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

The startup probe gates normal liveness/readiness probing; remove redundant fixed initial delays and tune the startup allowance from measured boot time. Init-container migration time is separate from this application-container startup allowance. See [Kubernetes probe behavior](https://kubernetes.io/docs/concepts/workloads/pods/probes/).

Set an initial 60-second termination grace period. Bound the local drain RPC to 5 seconds and allow a 10-second endpoint-removal propagation wait in `preStop`, leaving the remaining grace period for normal shutdown; tune after measuring connection behavior. Bound failures rather than letting the hook hang indefinitely, and retain `prep_stop/1` as the application-level transition for graceful exits outside Kubernetes. The wait aids propagation and does not prove all ingress connections have drained. Render/check the hook and probe settings for affected overlays; do not activate `/readyz` for images without the route. Recurring CI retains its image/source-only update contract and does not rewrite these manifests.

### Readiness helper contract

Inputs: fixed public HTTPS `/readyz` URL, expected version, expected full lowercase SHA, total deadline, request timeout, polling interval, diagnostic output path. Validate inputs before requests. Initial defaults: 20-minute readiness deadline, 10-second maximum per request, 10-second interval; clamp request/sleep duration to remaining monotonic deadline. No redirects, TLS bypass, cookies or infrastructure auth header. Reject URLs with userinfo or a hostname other than the configured nightly target.

Accept only HTTP 200 with JSON object containing string `status`, `version`, `sha`, `status == "ready"`, and exact version/SHA equality. Missing/malformed fields, login HTML, 3xx, other HTTP codes, network errors and old identities are failed observations and retried until deadline. Disable intermediary probe caching through deployment configuration and send no-cache request headers. Record only bounded status/category and allowlisted identity fields, not arbitrary response bodies. Exit nonzero on timeout/invalid input and write expected/last-observed identity with elapsed time.

The final `/readyz` check uses the same parser with a 30-second bound; an observed mismatch fails immediately, transient request errors may retry within that bound, and inability to establish identity fails the run. Summary wording: “Observed expected version/commit at the public endpoint.”

### GitOps update contract

All paths in this paragraph are relative to `oli-torus-gitops`. Preflight requires an existing `deployments/nightly-playwright.yml` with `app: oli-torus`, expected slug, `enabled: true`, `overlay: staging`, public access and exact nightly hostname. Call the updater with only `--record`, `--image-tag`, `--source-ref refs/heads/master`, and `--commit-sha`; never pass create, enable/disable, overlay, host or access-policy flags.

Allowed semantic changes are exactly `imageTag`, `metadata.sourceRef`, and `metadata.commitSha`. Preserve other values and unrelated textual content/comments. The current `yaml.safe_dump` writer needs a content-preserving adjustment verified by fixture tests before use under AC-009. Run `scripts/validate_deployments.py`, `scripts/validate_gitops_policy.py` and the repository's required static renders/checks. Revalidate on branch conflicts; do not force-push the tracked branch.

Proposed transport: a repository-scoped GitHub App installation token creates a bot branch/PR and enables automatic merge only after required checks and branch rules permit it. Target a configured protected branch; record the accepted commit and confirm the record at that branch before polling. Acceptance deadline: 15 minutes, configurable. On timeout/cancellation, disable auto-merge and close any unmerged run-owned PR; if merge raced closure, reconcile and record the accepted state. A subsequent run must reject or settle outstanding prior run PRs before changing intent, including PRs left by a hard runner termination. Do not leave an unattended update capable of merging during a later test interval. Branch policy must support this lifecycle before scheduling is enabled.

### Tag-based suite selection

The `@nightly` tags in test sources are the sole source of suite membership (AC-021). Use `npx playwright test --grep @nightly` for collection and execution at the same source checkout. Adding or removing a tag changes selection through normal code review, without an expected-test list to update.

During implementation, verify the eight audited adaptive cases documented in `assets/automation/tests/resources/adaptive-tests-setup.md` retain their tags. Canvas LTI and Dot are also currently tagged; they execute unless a reviewed tag change explicitly defers them. The setup documentation records asset/configuration needs, not a second source of test selection.

Fail collection/import errors or zero matching tests before browser installation (AC-031). Validate configuration required by the selected tests; absent credentials, assets or integration settings must fail setup rather than cause a silent skip (AC-022). All tests in the initial nightly selection are expected to run, so a skip is unexpected and fails the run even if Playwright exits zero (AC-024). Reject failed/interrupted execution, absent result files or zero executed tests. A retry that passes may pass the run under the current retry policy, but must be reported as flaky with its attempts.

Report which tests ran using spec path, full title and project, with pass/fail/skip/interruption and retry outcomes (AC-027). Collection and execution output may be retained as run diagnostics; do not maintain or compare against a separate expected-test list.

Declare `json-rules-engine` directly in automation, regenerate its npm lockfile, and assert its resolved version equals the product Yarn resolution (6.1.2 at discovery). Validate from a clean checkout without parent `assets/node_modules`. Local installation must not conceal the dependency.

Explicit configuration:

| Consumer | Required configuration and target rules |
| --- | --- |
| Adaptive | Exact nightly `PLAYWRIGHT_BASE_URL`, nonempty scenario token and automation API key; all eight archives and seven answer files documented in `assets/automation/tests/resources/adaptive-tests-setup.md` must be accessible via authenticated Torus asset routes. No default `my-token` fallback in nightly. |
| Canvas | Explicit `CANVAS_BASE_URL`, account ID/API token, instructor credentials, tool name, and `CANVAS_TOOL_LAUNCH_URL`; `TORUS_BASE_URL` and launch origin must equal the nightly origin. Supply dedicated Torus admin credentials required by the current fixture. Provision corresponding LTI registration. Do not inherit Tokamak defaults. |
| Dot | Require protected `PLAYWRIGHT_PARAMETER_CONFIG_URL`; validate downloaded YAML without logging it and require its `target.base_url` to equal the nightly origin. Prefer existing-fixture mode for initial durable use, with a dedicated enrolled test user/section and working Dot service configuration; scenario mode needs an explicit cleanup policy before adoption. |

Missing selected integration configuration is a setup failure. Freeze the validated Dot parameter document in runner temporary storage for the test invocation so a second download cannot change its target; add a narrow loader option for this local file if needed. Do not pass secrets to collection output or upload that file. Configuration validation is a nightly-specific gate, preserving optional local test behavior.

## 6. Data Model & Storage

No database migration or application schema change. Nightly releases run applicable migrations via the GitOps init container; persistent Postgres, MinIO and integration registrations survive image updates. Nightly CI never resets the database, deletes a namespace, or recreates shared credentials. PR CI continues to create, migrate and seed a disposable database that is destroyed with its runner.

Transient run data lives on the runner: provenance, sanitized stage diagnostics, test JSON/HTML and permitted screenshots/traces. Upload only explicit allowlisted artifacts with 14-day retention; remove downloaded private assets and secret parameter files. GHCR stores immutable images, and Git records deployment intent/provenance. Private asset contents are not new source-controlled data. Captured email is transient Swoosh memory, not part of the persistent nightly database/object-storage contract; operation must bound its accumulation between runs.

## 7. Consistency & Transactions

There is no distributed transaction across GHCR, GitHub, Argo and Torus. Order operations so publication precedes intent, branch acceptance precedes readiness, and readiness precedes tests. An orphaned published image is acceptable; failed publication cannot alter deployment intent. An accepted update remains deployed after test failure until an operator decides otherwise.

The job lock spans preflight through final identity check and diagnostics. Test fixtures retain run-specific identities and existing cleanup. Plate-tectonics currently bounds teardown and logs leaked slugs; retain those warnings in actionable diagnostics. Dot existing-fixture mode avoids adding a new scenario's users/projects nightly, but conversations/attempts may still accumulate and need operator retention. Named cleanup ownership and an inventory/retention procedure are required before launch. Do not convert existing best-effort cleanup to database resets or automatic migration rollback.

## 8. Caching Strategy

Use existing dependency/build caches keyed by lockfiles, toolchain, Mix environment and all compile capability inputs. Separate PR and trusted nightly cache namespaces even though both use `playwright`; nightly must not restore PR-generated compile artifacts. Include these inputs before Docker dependency/application compilation so changes invalidate the relevant layers. Never restore `_build` from a different capability combination; a broad restore fallback may recover download caches, not incompatible compiled outputs. Keep production compile caches separate. No health-response or readiness-success cache. Re-run readiness checks and fixture/configuration checks on every run, including reruns of the same SHA. Cache artifacts may accelerate build/install but cannot substitute for clean-install dependency verification during implementation.

## 9. Performance & Scalability Posture

Start with one runner, one Chrome worker and the existing retry count. Proposed stage ceilings: 15 minutes install/collection, 60 minutes build/publication, 15 minutes GitOps acceptance, 20 minutes readiness, 10 minutes target setup, 10 minutes browser installation, 120 minutes browser execution, and 10 minutes finalization. Use a 270-minute job timeout to allow these stages and runner overhead. Enforce the browser deadline within the job so finalization normally retains time; a hard job timeout cannot guarantee artifact upload.

Measure actual stage durations before tuning budgets or adding parallel workers. Collection before browser installation avoids wasted downloads on dependency failures. The liveness handler reads local state only. Readiness uses a narrow local-service check and one database query with a one-second total checkout/query budget, below the two-second Kubernetes readiness timeout. No external integration checks or repeated migration/schema scans run in probes. Do not introduce background probe polling or a response cache. Under pool exhaustion, fail readiness promptly rather than accumulating probe tasks.

## 10. Failure Modes & Resilience

| Failure | Required behavior |
| --- | --- |
| Missing selected-test configuration, zero matches or collection/import error | Fail setup/collection before browsers and before deployment intent changes where detectable locally. |
| Build/push/collision | Fail publication; leave GitOps record unchanged. |
| Disabled/wrong target record | Fail preflight with expected field names/values; never repair lifecycle automatically. |
| Validation/check/merge failure or deadline | Fail GitOps acceptance; settle the run-owned pending PR; do not test a previous deployment. |
| Old identity, redirect, invalid JSON or network failure | Retry bounded readiness; fail when deadline expires. |
| Database outage after boot | `/readyz` returns 503; `/healthz` remains 200. Recover readiness when database access returns, without restarting solely for the outage. |
| Incomplete startup / draining | Readiness stays 503; startup remains unsuccessful until initialization completes, and draining leaves liveness healthy while HTTP remains available. |
| Release migration/init failure | Readiness times out; operator inspects deployment via their normal access. CI has no cluster credentials. |
| Missing asset/authentication or wrong integration target | Fail setup with consumer/key identifier, without secret values or asset contents. |
| Selected test failure/unexpected skip or result file absent | Mark run failed; preserve partial results and stage provenance. |
| Identity changes or cannot be verified after tests | Fail final validation regardless of browser result. |
| Cleanup fails | Preserve warning and affected synthetic fixture identifiers for the named operator; no rollback/reset. |
| Cancellation/runner loss | No validated success; next run settles stale bot PRs and rechecks intent/configuration. Artifacts and cleanup are best-effort on hard termination. |

Do not automatically retry full deployments or rerun the whole suite indefinitely. A manual rerun selects current master anew and records that selection; exact-source replay is not promised by initial manual policy.

## 11. Observability

Always produce a GitHub step summary when the runner remains available. Include each stage's pass/fail/skipped status and duration, expected source version/SHA, workflow SHA, image tag/digest if published, accepted GitOps commit if available, last observed identity, failed gate and report links. Mark skipped tests as not executed, never as a successful browser stage. Include passed/failed/skipped/interrupted/flaky counts and retry attempts, plus each executed test’s spec path, full title, project and outcome. Generated discovery/results are per-run diagnostics, not a separately maintained source of suite membership.

Use an explicit nightly reporter set: line, HTML with `open: never`, and JSON to a stable result path. Playwright supports explicit reporter selection through the [CLI](https://playwright.dev/docs/test-cli); do not rely on the shared HTML reporter surviving a `--reporter=line` override. Upload reports/results after test failure and sanitized stage diagnostics after pre-test failure, with 14-day retention. Missing browser artifacts before tests is expected; missing results after a nominally successful execution is a failure.

GitHub Actions outcomes are the initial failure signal. Named notification ownership/channel remains a launch gate; no new Slack/email integration is assumed. Existing AppSignal operational monitoring is unchanged.

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

This documentation change runs only design/traceability checks. Implementation must supply the following evidence:

| Layer | Verification |
| --- | --- |
| Probe HTTP contracts | AC-012–AC-014, AC-039, AC-042: update health controller tests and add readiness controller tests for status/body fields, compiled metadata, 200/503, unauthenticated pod HTTP without redirects, public HTTPS and no-store headers. Prove liveness performs no DB/external requests and readiness excludes optional dependencies. Preserve clean ExUnit logs. |
| Lifecycle and bounded readiness | AC-013, AC-040: test startup before/after full initialization, restart reset, required local service absence/recovery, drain during a query and actual graceful shutdown before endpoint stop. Exercise database disconnection, exhausted pool, query failure and timeout; assert the total budget and no accumulating work. Verify DB failure leaves liveness healthy. Isolate lifecycle mutation so test state cannot leak. |
| Probe deployment | AC-041: static render checks for all probe paths/timings, startup gating, drain hook bounds and termination grace. In an authorized disposable deployment, demonstrate slow boot, database outage/recovery and termination; readiness changes without dependency-triggered liveness restarts. |
| Readiness helper | Local HTTP fixture/fake clock covers valid identity, wrong version/SHA, missing/non-string fields, malformed JSON, redirect/login HTML, non-200, connection errors, TLS verification policy, deadline bounds and final mismatch. Prove downstream test command is not invoked on failure. |
| Release | Build `MIX_ENV=playwright` and `MIX_ENV=prod` separately; smoke boot the Playwright release against disposable services with runtime secrets, check both probe contracts and readiness/full SHA plus authenticated scenario/private-asset/mailbox behavior, and verify absent-token denial. Production build must retain gated-route exclusion. Check required fixture files, metadata, image layers and default production settings. |
| Shared compile environment | AC-032, AC-033, AC-036: build PR and nightly settings from clean/cached states; assert effective scenario/mailbox/reCAPTCHA settings, missing/invalid input behavior, and that post-build env changes have no effect. Build production with all inputs true and prove test routes remain absent and normal reCAPTCHA selected. Verify no dev import/debug defaults and no active ci_e2e references. |
| PR migration | AC-003, AC-035: run the full existing `@pr` suite, including registration/confirmation/password reset, using explicit local runtime inputs and complete assets. Verify no nightly credentials/private assets/publication access are needed and disposal retains isolation. |
| reCAPTCHA verifier | AC-037: matching test token succeeds without external verification; unmatched nonempty strings delegate to the normal verifier with both success and failure/timeout preserved; absent/empty/non-string responses fail. Verify missing server secret blocks startup, shared delegation for formerly direct call sites, post-build token rotation, production ignoring the test token, and no token disclosure in logs/artifacts. Verify the human widget remains available with nightly Google configuration. |
| Form-helper migration | AC-038: registration LiveView, enrollment and payment flows submit the configured runtime token using the shared helper and complete through the deterministic verifier. Verify missing token fails before submission, no hardcoded placeholder fallback, correct form field/event behavior and Torus-origin scoping. Audit remaining captcha-protected submissions; run affected browser specs plus the existing `@pr` suite. |
| Mailbox | AC-034: under each PR/nightly build, capture a local message, retrieve it by unique recipient and ID with the correct token, reject missing/invalid tokens and verify recipient filtering. Exercise restart behavior and inspect diagnostics for email/reset-token disclosure. |
| Dependency/selection | Clean temporary checkout with no parent dependencies: `npm ci`, `--grep @nightly` collection and engine-version parity. Verify initial adaptive tags; exercise import/collection errors, zero matches, missing API key/asset and incorrect integration target. Confirm a newly tagged test is selected without updating another list and collection precedes browser installation. |
| Results | Feed representative Playwright JSON to execution-result validation: pass, fail, unexpected skip, absent results, interrupted and retry-passed. Zero executed tests or missing results cannot pass. Verify spec/title/project reporting, individual outcomes, HTML/JSON paths and 14-day artifact retention. |
| GitOps contract | Fixture tests for exact allowed keys, comments/unrelated content, disabled record, hostname/overlay/access mismatch, conflict, denied checks, timeout and late merge. Run record/policy validators and static Kustomize rendering with no cluster contact; ensure app/init container image parity and reviewed probe/drain settings. |
| Workflow | YAML/action lint plus orchestration tests for fixed nightly checkout, stage dependencies, no production tags, bounded failures, job-scoped lock, preserved PR triggers/checkout/coverage, unchanged backend scenario job and final-check failure propagation. Exercise cancellation with a pending bot PR. |
| Provisioned target | One manual then one scheduled full run, all required cases, retained diagnostics, and reviewed artifacts. Observe old-revision polling and readiness timeout. Overlap dispatches to confirm serialization and pending policy; deliberately change identity to verify final failure. Confirm durable fixtures/services survive image updates. |

Run focused ExUnit and script/automation checks appropriate to implementation, then required review under `docs/CODEREVIEW.md`: security/performance plus backend/TypeScript lenses where changed; requirements review applies if PRD changes. A full `mix test` is mandatory if shared test support/configuration changes. No new domain scenario test is necessary for this orchestration design unless implementation crosses domain workflows.

Record actual launch results and proof artifacts against canonical acceptance criteria later. Document validation and historical dependency experiments do not satisfy AC-029.

## 14. Backwards Compatibility

`/healthz` intentionally changes to local-only startup/liveness with `status: ok` after initialization. `/readyz` owns database readiness and version/SHA metadata. Migrate readiness consumers, PR startup waiting and GitOps probes as part of this work; do not retain the combined database-dependent liveness contract. Both routes remain unauthenticated. Review shared GitOps overlays so the new readiness path is activated only with capable images. Production uses the unchanged default Docker environment and retains route exclusions. PR moves to the shared Mix environment with its triggers, source selection, `@pr` coverage and disposable lifecycle preserved. Shared browser-runner defaults and independent nightly backend scenario triggers/test behavior stay intact. A nightly-specific config/helper applies stricter coverage and target checks only to the durable job.

Land shared compile/runtime configuration together with the PR workflow migration, asset setup and passing `@pr` verification; then remove `config/ci_e2e.exs` and remaining active references. Historical discovery notes may retain the old name. Deploy a probe-capable image, then activate the reviewed GitOps probe/drain configuration and complete provisioning/branch policy plus dedicated assets/accounts before the manual nightly run and scheduled proof. Keep automatic execution operationally gated until launch prerequisites are met. Stop scheduling during incidents; choose any image rollback through reviewed GitOps changes with database compatibility assessed separately. Do not automatically reverse migrations.

## 15. Risks & Mitigations

| Risk | Mitigation / accepted limitation |
| --- | --- |
| Same-commit rebuild or mixed replicas | Keep digest provenance but state the public observation's limits. Before/after identity checks do not prove continuous or all-replica identity. |
| Auto-merge proceeds after cancellation | Run-owned PR lifecycle, next-run stale-update gate, branch ownership and a cancellation/late-merge test before unattended launch. |
| GitOps updater rewrites comments | Add content-preserving updates and exact fixture/diff checks before adopting the existing writer. |
| PR migration loses inherited settings or assets | Explicit runtime input table, release-style asset builds, existing account/email suite and disposable-database verification. |
| Shared cache retains disabled test capabilities | Capability-sensitive keys, separate trusted/untrusted cache namespaces and fresh PR/nightly/production build checks. |
| Mailbox messages disappear or grow indefinitely | Single-instance mailbox tests, run-unique recipients, restart-aware setup and a documented mailbox retention/recycling procedure. |
| Incorrect startup/drain state | Set completion after initialization, enter drain before service shutdown, reset state on app restart and verify real lifecycle transitions. |
| Probe change restarts or removes healthy instances | Bound readiness work, keep dependencies out of liveness, allow slow startup and validate database-outage behavior and rendered probe timing. |
| Release omits development-only config/files | Standalone Playwright release settings, explicit runtime branches and packaged-fixture smoke checks. |
| Privileged public test endpoints or secret traces | Retain authentication, dedicated target credentials, default nightly traces off and restricted artifact inspection. |
| Slow cleanup/data accumulation | Preserve bounded teardown warnings, prefer Dot existing-fixture mode, and require a named cleanup/retention operator. |
| Integration target drift | Explicit Canvas launch/Torus origins, frozen Dot configuration, tag-based selection and no silent skips. |
| Longer CI runtime | Bounded stages, one worker initially and measured durations; defer cadence increases. |

## 16. Open Questions & Follow-ups

These items do not prevent documenting the architecture but must be resolved before unattended launch:

1. **GitOps merge policy:** confirm bot PR automatic merge, required checks/approvals, branch name and installation permissions. If direct commits are selected instead, document the permitted branch-rule path and revise PR lifecycle handling; never silently bypass policy.
2. **Initial suite scope:** confirm the proposed ten cases or explicitly stage Canvas/Dot later while retaining all eight adaptive cases. A staged decision must update test-source tags and operator docs, identify deferred coverage, and keep canonical AC-021 satisfied.
3. **Provisioning and ownership:** name owners for deployment enablement, runtime secrets, private assets/answer keys, automation key, Canvas registration, Dot fixture/service, failed runs and stale-data cleanup. Confirm retention and whether pinned/versioned asset keys are required initially.
4. **Operational policy:** accept or tune proposed stage deadlines after first timings; name the notification channel/owner. Validate proposed probe/drain timing against measured startup and shutdown. Confirm the `nightly-ui` environment can execute unattended under repository policy.
5. **Release fixture audit:** verify selected PR and nightly runtime paths, including support assets resolved today from the source tree; package only demonstrated requirements. Confirm mailbox retention/recycling ownership and the initial single-replica deployment setting.

Technical defaults selected here: master-only manual/scheduled source, full SHA supplied to build, shared standalone `playwright` Mix environment with scenarios/mailbox enabled for PR and nightly and secret-protected deterministic reCAPTCHA for both, unique `sha-…-nightly-…` tags, a job-scoped target lock with newest pending replacement, `/healthz` startup/liveness and `/readyz` readiness/identity with a one-second DB budget, 20-minute CI readiness/10-second request/10-second interval, one browser worker/retry, a single instance for mailbox-dependent flows, and 14-day artifacts. These are design decisions subject to implementation verification, not claims about deployed configuration.

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
