# Phase 1 Execution Record

Work item: `docs/exec-plans/current/nightly-playwright-ci`
Phase: `1 — Application lifecycle and probe contracts`

## Scope from plan.md

- Node-local startup/drain state, dependency-free liveness, bounded readiness and compiled identity.
- Application/release lifecycle integration, session-free HTTP endpoints and SSL exemptions.
- Focused failure/lifecycle verification and readiness-consumer inventory; no infrastructure activation.

## Implementation Blocks

- [x] Core behavior changes: `Oli.Health`, application startup/pre-stop and local release drain.
- [x] Data or interface changes: `/healthz` and `/readyz` status/body contracts.
- [x] Access-control or safety checks: session-free routes, exact SSL exemptions, no-store and generic errors.
- [x] Observability or operational updates: compiled identity and consumer inventory below.

## Test Blocks

- [x] Tests added or updated for lifecycle, HTTP/SSL contracts and bounded database readiness.
- [x] Required verification commands run.
- [x] Results captured.

## Work-Item Sync

- [x] All Phase 1 plan tasks are checked. The requested healthy `/healthz` status remains `Ayup!`; FDD, PRD, AC-039, plan and controller tests agree. Startup remains `starting` and readiness remains `ready`/`not_ready`. Two existing telemetry registration failures were repaired because they prevented the required application restart verification.
- [x] No new design questions.

## Readiness Consumer Inventory

| Consumer | Current behavior | Migration owner/gate |
| --- | --- | --- |
| `.github/workflows/pr-playwright.yml` | Waits on `/`, not `/healthz` | Phase 2 switches startup waiting to `/readyz` with the shared environment migration. |
| `docs/preview-environments.md` | Documents `devops/scripts/smoke-test-preview.sh` with a `/healthz` URL | Phase 5 updates the documented readiness smoke URL and verifies the external script contract after a capable preview image. |
| GitOps `apps/oli-torus/base/deployment.yaml` (prior FDD inventory) | Uses `/healthz` for both liveness and readiness | Phase 5 inspects the supplied GitOps checkout and affected overlays; deploy capable images before activating `/readyz`. No checkout or infrastructure was changed in Phase 1. |
| Nightly public identity polling | New consumer | Phase 6 uses `/readyz` after accepted deployment intent. |

A repository-wide search found no additional active `/healthz` consumers outside the existing controller/test/SSL/router and these docs. Liveness consumers continue using `/healthz`; it intentionally no longer proves database availability.

## Verification Results

- Preflight work-item validation: passed.
- Existing health-controller baseline: 1 test, 0 failures.
- Focused final suite: 23 tests, 0 failures. ExUnit output contains only progress and summary; the existing seeds deprecation warning occurs before ExUnit, and OS monitor messages occur after VM shutdown.
- `mix format --check-formatted`: passed.
- `git diff --check`: passed.
- Postflight work-item validation (`--check all`): passed.
- Disposable `MIX_ENV=test` release build and a temporary release smoke script: passed during implementation. The script used the configured local test database and loopback HTTP without migrations/data writes. It was removed afterward at the user's request; these results retain the historical validation evidence. Production/Playwright image packaging remains Phase 3.
- The release smoke held the first terminating child during actual `Application.stop(:oli)`, observed readiness 503 and liveness 200 over HTTP, allowed termination, restarted the application, then verified readiness recovery and idempotent release drain. It exposed duplicate Cowboy and feature telemetry registration; both now tolerate existing handlers. Feature telemetry regression coverage also asserts one handler per event.
- Database tests use a real normal one-connection pool. Repeated exhaustion respects the single one-second budget and leaves no linked query workers; a loopback relay stalls actual PostgreSQL responses and drops sockets, verifying failure bounds and same-pool recovery. Additional cases cover query errors, missing/recovered local service names, NodeJS pool/supervisor absence, and drain during query completion.
- HTTP tests cover exact 200/503 JSON, compiled identity unaffected by runtime metadata or client-supplied desired identity, no-store, session-free routing, and HTTP/HTTPS connection schemes. SSL tests exercise both exact exemptions with redirects enabled.
- Healthy-status follow-up: restored `Ayup!` at the user's request and reran both affected controller test modules (6 tests, 0 failures), formatting, work-item validation and `git diff --check`. The release smoke was not rerun for this response-literal change.

Reproduce focused verification:

```sh
mix test test/oli/health_test.exs test/oli/health_database_test.exs test/oli/feature_telemetry_test.exs test/oli_web/controllers/api/health_controller_test.exs test/oli_web/controllers/api/readiness_controller_test.exs test/oli_web/plugs/ssl_test.exs
mix format --check-formatted
git diff --check
```

Run the installed harness validator before and after implementation with `--check all`, resolving the skills root outside the repository as instructed by `plan.md`. No shared test support/configuration changed, so a full ExUnit run was not required.

## Remaining Operational Gates

- Phase 2 migrates PR startup waiting; Phase 5 migrates GitOps readiness and the documented preview smoke URL only after capable images exist.
- Phase 3 verifies the production and Playwright images. The local test release does not establish their packaging or production TLS behavior.
- Phase 7 repeats graceful termination under real deployment probes/hooks and verifies public HTTPS/ingress behavior. No live deployment, GitOps record, Jira ticket or workflow was changed here.
- Requirements remain proposed until the later acceptance-proof/operational closure; Phase 1 evidence does not establish AC-041 deployment configuration or AC-042 consumer migration.

## Review Loop

- Round 1: dedicated security, performance and Elixir reviewers found no actionable findings. Performance review requested stronger stalled-query evidence; the real TCP-relay test closes that gap.
- Follow-up review: Elixir and performance reviewers accepted the release harness, real database coverage and idempotent telemetry registration fixes. No findings remain.

## Done Definition

- [x] Phase tasks complete.
- [x] Tests and verification pass.
- [x] Review completed when enabled.
- [x] Validation passes.
