# Phase 2 Execution Record

Work item: `docs/exec-plans/current/features/genai-redesign`
Phase: 2 — Provider data, health monitoring and configuration reconciliation
Status: complete within the observe-only scope; full-suite limitations are recorded below.

## Scope from plan.md

- Additive Provider configuration, reversible migration, deterministic designation,
  node-local generation reconciliation and independent observe-only monitoring.
- Preserve the legacy request execution boundary until Phase 3. Claude transport
  work remains explicitly deferred. Administrative UI integration is Phase 4.

## Implementation Blocks

- [x] Added `Oli.GenAI.Provider`, new model/ServiceConfig fields and GenAI context APIs.
  Keys are encrypted and redacted; new Provider-backed model inputs derive the
  transitional legacy connection fields. Model requests remain compatible with the
  existing dispatcher. Context validation covers Provider/capability relationships
  and positive, non-null capacities, including invalid blank/nullable inputs.
- [x] Generated `priv/repo/migrations/20261027183342_add_genai_providers_and_tier_capacity.exs`
  using `mix ecto.gen.migration add_genai_providers_and_tier_capacity --no-compile --no-deps-check`.
  The normal generator invocation hit a local dependency-task argument issue; the
  generator flags avoided compilation while retaining its generated timestamp/name.
  The migration creates exactly one **OpenAI production** Provider and copies
  ciphertext from the first keyed model; legacy fields remain intact for rollback.
  Explicit `up/0` and `down/0` are exercised in isolated PostgreSQL schemas.
- [x] Configuration transactions serialize fallback designation, flag edits, membership
  changes and deletion across connections. Direct writes publish after commit;
  nested writes avoid premature invalidation and converge via periodic reload.
  Reads are batched independently of Provider count and exclude legacy credentials.
- [x] Added `TransportPool` and `PoolManager`: atom-free physical generations, one
  resolved origin per pool, immediate replacement and accepted capacity overlap,
  safe retired-generation collection, cached-logical-handle refresh and orphan
  adoption after coordinator/manager restart, even for deleted logical keys.
- [x] Connection startup runs outside coordinators. Per-call deadlines, caller death,
  actual worker termination and an acknowledged ownership handoff fence retirement
  without application admission counters or occupied-request registries. Local
  checkout timeout/failure maps to busy/pool-unavailable rather than upstream health.
- [x] Added `HealthProbe`, `HealthMonitor`, `Runtime` and `RuntimeSupervisor`:
  independent bounded inference, isolated probe capacity, deadlines, jitter, bounded
  probe-task concurrency, thresholds and recovery, stale-result/timer rejection,
  generation cancellation, monitor-death cleanup, administrative disablement and
  the startup health-check override. Startup/reconciliation remains observe-only.
- [x] Probes reuse ordinary OpenAI endpoint-template, header and request construction,
  use Provider-owned credentials, and require a valid complete response. Response
  bodies are bounded with an oversized-prefix regression. Missing configuration and
  deferred adapters report safe operational categories instead of synthetic success.
- [x] Added safe probe, health-state, checkout, lifecycle, monitor-error and successful
  reconciliation telemetry. Runtime snapshots expose audit issues and operational
  state without returning credentials. AppSignal dashboards are later-phase work.

## Test Blocks

- [x] Focused phase gate:
  `mix test test/oli/gen_ai/ test/oli/repo/migrations/genai_provider_migration_test.exs test/oli_web/live/gen_ai/`
  — **303 tests, zero failures, 3 excluded**. ExUnit output is clean; existing
  runtime/migration/seed setup output occurs before ExUnit starts.
- [x] Transport/handoff and probe regression verification also passes separately.
- [x] Migration tests exercise forward migration and rollback using real encrypted
  values, multiple legacy adapters/endpoints, missing keys and empty installations.
  Original model data is preserved after rollback.
- [x] Separate-connection concurrency test verifies automatic designation cannot
  overwrite a later transactional administrator selection. Independent runtime
  instances converge from committed settings and missed-invalidation polling.
- [x] Real local HTTP tests exercise probe credentials, endpoint templates, completion,
  failure categories, total deadlines, response-size limits, occupied production
  capacity, replacement overlap, old-pool retirement and startup cancellation.
- [x] Regression coverage verifies caller budgets remain bounded behind a slow checkout,
  replacement does not block probe lookup, unclaimed handoff cleans up in a living
  caller, and restart adopts both current and removed-key orphan generations.
- [x] Telemetry tests assert event shape/count and redaction. A query-count test verifies
  runtime reload SELECT count does not increase with additional Providers.
- [x] Formatting of changed Elixir files and `git diff --check` pass. Preflight and
  postflight harness work-item validation pass.

### Full-suite limitations

`mix test` completed **26 doctests and 9,952 tests**, with **20 failures and 75
excluded**. None was a GenAI test. Failures were in a Playwright filesystem scan,
CSV/project expectations, LTI mock counts, and global project/brand/institution/
publisher/resource expectations affected by other full-suite data.

A fresh run of the affected project/CSV/branding/LTI files together with this phase's
coverage passed **370 tests**. A broader fresh verification including every file
that failed in the full run completed **497 tests**: all original full-run failures
passed, including the Playwright scan. It had one different failure in the unchanged
`test/oli_web/controllers/deployment_controller_test.exs:213`, whose deployment-delete
assertion queries `Institutions.get_institution!(deployment.id)` rather than the
deleted deployment. That assertion depends on unrelated ID coincidences. No unrelated
production/test behavior was changed to make those suites green.

The targeted Phase 2 gate is green; repository-wide verification remains non-green
for the recorded out-of-scope failures.

## Work-Item Sync

- [x] Plan Phase 2 tasks checked complete; phases 3 and 4 remain separate.
- [x] PRD, informal design, FDD, plan and requirements use **OpenAI production**, per
  the latest explicit FDD migration decision.
- [x] `docs/exec-plans/current/features/genai-redesign/design/phase-2-runtime.md`
  documents module ownership, additive schema/credential compatibility, nested
  transaction propagation, defaults, stale-health policy, telemetry, lifecycle and
  observe-only rollout/rollback boundaries.
- [x] Required initial tier-capacity audit and Claude limitations remain visible;
  credentials/model access are checked asynchronously by independent probes after
  structural configuration validation, not by network calls inside database locks.

## Review Loop

- Security: no actionable findings, including a final re-review of startup handoff,
  endpoint templates, disabled configuration, hashed admin keys and telemetry.
- Performance: fixed network work blocking the pool/global coordinators and caller
  budgets. The review reproduction improved from 398 ms to 11 ms within its 30 ms
  startup budget. Batched recurring queries and one fallback write resolve the
  per-Provider query-growth finding. Follow-up review found no remaining issue.
- Elixir: fixed nullable capacity/array validation and startup blocking. Follow-up
  reviews verified the ownership guardian, orphan adoption, transactional invalidation,
  transitional model defaults and oversized-response handling without new findings.
- Requirements: fixed endpoint-template mismatch, administrative disabling of an
  incomplete Provider, and missing reconciliation telemetry/contract assertions.
  Follow-up review confirmed the findings are resolved within the Phase 2 scope.

## Done Definition

- [x] Phase 2 tasks complete within the observe-only rollout boundary.
- [x] Required targeted tests and formatting pass; full-suite limitations recorded.
- [x] Required review completed and findings resolved.
- [x] Work-item docs reconciled and validation passes.
