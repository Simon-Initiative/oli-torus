# GenAI Provider Health and Routing Redesign - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/features/genai-redesign/prd.md`
- FDD: `docs/exec-plans/current/features/genai-redesign/fdd.md`
- Detailed decisions and investigation: `docs/exec-plans/current/features/genai-redesign/informal.md`
- Traceability: `docs/exec-plans/current/features/genai-redesign/requirements.yml`

## Scope

Deliver independently probed Provider availability, isolated per-node ServiceConfig-tier transport pools, best-effort capacity routing, guarded backup execution, administrative controls, telemetry, and safe migration. Preserve feature/section resolution and stream correctness. Follow repository security, performance, accessibility, testing, review, migration and Jira workflows; no issue key has been supplied. This is a plan, not authorization to deploy.

## Clarifications & Default Assumptions

- A transport pool is the sole capacity authority for its tier. Occupancy observation is non-atomic; brief bounded queueing and transient imperfect selection are accepted. Do not introduce application admission counters, leases, or task registries.
- Pool-only routing is conditional on installed-version and adapter verification. If a required transport cannot meet the contract, record the limitation and resolve it before enabling that path; creating a Hackney pool alone does not isolate Claude.
- Implemented policy: checkout 1,000 ms; total inference 300,000 ms across both attempts; pre-output connection failures/inactivity and HTTP 500/502/503/504 permit one backup. Stale health is locally ineligible after two regular intervals plus deadline. Administrative capacity is four per Provider/resolved origin/node; immediate generation replacement accepts temporary overlap.
- The proposed startup policy allows pool-limited traffic while health is unknown and an immediate probe runs; confirm its interaction with stale health before activation. Probe defaults are 3-minute regular/recovery intervals, 30-second checks after the first failure, 3 consecutive failures to mark unavailable, and 2 consecutive successes to recover; all are runtime-overridable.
- Initial migration creates exactly one `OpenAI production` Provider, using keys from the lowest-ID model with keys, and associates every existing model. Audit heterogeneous legacy settings, missing keys, same-Provider backup conflicts and rollback before rollout. Different-vendor enforcement and detailed provider-specific error classification remain deferred. No real-request-triggered probes or global request/token quota enforcement are planned.
- `GENAI_HEALTH_CHECKS_ENABLED` controls monitoring only; the bounded primary-only emergency override bypasses health and secondary/backup routing. Observe-first deployment uses new canaries excluded from production ingress, followed by audited canary traffic; the emergency path uses independent primary pools. See `docs/OPERATIONS.md`.

## Phase 1: Verify transport capacity and settle the execution contract

- Goal: Establish whether the installed transports can enforce and reclaim the pool capacity on which the redesign depends.
- Tasks:
  - [x] Inspect installed Hackney and actual OpenAI call paths; document which statistic counts checked-out occupancy, whether capacity bounds active checkouts, behavior at saturation, pending checkout timeout/cancellation removal, streaming ownership, resizing, and connection reclamation after normal and killed tasks (AC-014).
  - [x] Record Claude's Anthropix/Req/Finch limitations and preserve the FDD's explicit deferral of Claude changes and runtime verification. Document HTTP/1.1 streaming and multiplexing semantics (AC-015).
  - [x] Define adapter transport context for sync and streaming, checkout timeout classification, administrative and probe pool separation, safe pool retirement and reduced-capacity behavior. Use a 1,000 ms initial checkout timeout and administrative capacity four per node. Resolve finite timeout and lifecycle choices needed by downstream work (AC-011, AC-013, AC-017).
- Testing Tasks:
  - [x] Build focused, repeatable tests against the installed dependencies and representative streaming endpoints for saturation, bounded checkout, cancellation, `:kill`, pending waiters, resizing and eventual cleanup. Include actual adapter transport usage and isolation; capture evidence and version numbers (AC-014, AC-015, AC-016).
  - Command(s): `mix test test/oli/gen_ai/` and targeted transport tests added for these behaviors; `mix format --check-formatted`.
- Definition of Done:
  - Evidence covers every installed-Hackney verification question and selected adapters' real transport semantics. The contract identifies any unsupported behavior and a viable implementation or explicit unresolved blocker.
- Evidence and integration follow-ups: `docs/exec-plans/current/features/genai-redesign/design/transport-evidence.md`; Hackney/OpenAI transport verification is complete; immediate replacement permits temporary overlap. Claude implementation and runtime verification are explicitly deferred. Production tier reconciliation and routing are Phase 2/3 tasks.
- Gate:
  - No pool-only routing or activation for an adapter until its active bounds, occupancy, waiting and cleanup semantics are established and an implementation can satisfy the design.
- Dependencies:
  - PRD, FDD, informal design, and installed dependency versions.
- Parallelizable Work:
  - Hackney investigation and Claude transport evaluation can proceed independently; agree on the shared execution contract after both report results.

## Phase 2: Provider data, health monitoring, and configuration reconciliation

- Goal: Provide durable configuration and independent node-local Provider health without directing production traffic based on it yet.
- Tasks:
  - [x] Add Provider configuration with encrypted credentials, administrative state and probe settings; associate RegisteredModels and add editable `health_check`; retain model-specific request timeouts. Validate same-Provider distinct primary/secondary, and distinct backup Provider (AC-001, AC-002).
  - [x] Generate migrations with explicit `up/0` and `down/0`, implement the specified single-Provider initial migration, and preserve data needed for safe rollback. Design explicit handling of absent keys and heterogeneous existing endpoint/adapter data; audit ServiceConfigs and tier sizing without silently splitting the initial Provider (AC-020).
  - [x] Persist one capacity per configured ServiceConfig tier and implement cross-node reconciliation on committed changes and restart; retain independent tier, probe and administrative transport identities. Use Phase 1 evidence to implement immediate generation replacement with accepted overlap, visible retirement and a request-start fence that prevents stale handles recreating retired pools (AC-008, AC-013, AC-017).
  - [x] Implement deterministic lowest-ID flagged probe selection and transactional fallback designation; coordinate model/flag edits, deletion and membership changes without overwriting newer administrator choices (AC-003).
  - [x] Add supervised per-node Provider monitors with isolated probe transport, tiny real inference, deadlines, one in-flight probe per Provider, runtime-overridable schedules and thresholds, jitter, concurrency cap, stale-result protection and safe status snapshots. Implement health-check override and restart-to-unknown behavior; no user outcome changes Provider health (AC-004, AC-005, AC-006, AC-007).
  - [x] Emit probe and reconciliation telemetry without sensitive content; ensure credential rotation invalidates old probe generations and revalidates connection (AC-001, AC-019).
- Testing Tasks:
  - [x] Test migration and rollback with multiple models, no keys, heterogeneous legacy settings and invalid post-migration configs; test encryption and redaction (AC-020).
  - [x] Test selection ordering, concurrent edits, no-model state, health thresholds/recovery without traffic, probe failures and timeouts, stale results, monitor restart, override disable/re-enable and node reconciliation (AC-003 through AC-007, AC-013).
  - Command(s): `mix test test/oli/gen_ai/` plus the relevant migration and multi-node reconciliation tests created in this phase; `mix format --check-formatted`.
- Definition of Done:
  - Migration and rollback pass; configuration reconciles across nodes; independent probes produce correct operational state and telemetry without diverting production traffic.
- Evidence: `docs/exec-plans/current/features/genai-redesign/execution/phase-2.md` and `docs/exec-plans/current/features/genai-redesign/design/phase-2-runtime.md`. Targeted tests pass; unrelated full-suite limitations are recorded.
- Gate:
  - Phase 1's transport decision supports the pool and probe paths used here; migration edge cases and observe-first deployment mechanism are documented before production activation.
- Dependencies:
  - Phase 1 transport contract and evidence; existing feature and section resolution.
- Parallelizable Work:
  - Schema/migration work and monitor state-machine tests may proceed concurrently after agreeing on Provider and probe interfaces; integrate before the phase gate.

## Phase 3: Pool routing, execution, and stream lifecycle

- Goal: Connect Provider eligibility and actual tier transport pools to real requests, with bounded races and guarded backup.
- Tasks:
  - [x] Replace model/shared-pool admission and workload-driven breaker routing with best-effort occupancy checks: eligible primary first, secondary when primary appears full, busy if both appear full or secondary is absent; check eligible backup only when main is unavailable (AC-008, AC-009, AC-010).
  - [x] Pass selected ServiceConfig, tier and exact transport handle through routing plan and completion dispatch for both generate and stream. A finite checkout timeout returns local busy without health mutation, a second secondary attempt, or backup failover for contention (AC-011, AC-014, AC-015).
  - [x] Implement at most one eligible backup attempt before any output or tool-call fragment, subject to backup health, pool capacity and total deadline including SDK retries. Classify cancellation, invalid input and application errors separately; return interrupted stream after output (AC-012).
  - [x] Correct adapter completion/error semantics, including OpenAI SSE errors, truncation and exceptions; leave deferred Anthropix changes for future work; ensure normal completion, cancellation, errors and task death reclaim connections. Preserve active work and occupancy through endpoint/model changes, pool restart and capacity reductions as established by Phase 1 (AC-013, AC-016).
  - [x] Add routing, occupancy/capacity, checkout wait/timeouts, available queue depth, cleanup and lifecycle telemetry, request outcomes and backup attempts. Remove obsolete admission accounting and per-model breaker reporting only after all paths use replacement behavior (AC-004, AC-019, AC-021).
- Testing Tasks:
  - [x] Test primary-full selection of secondary, both-full and missing-secondary busy, independent ServiceConfigs and backup, shared ServiceConfig pools, main outage, backup saturation and probe isolation (AC-008 through AC-010).
  - [x] Force concurrent selection races with real pool checkout; verify bounded waiting, pending cancellation, local busy classification, no Provider failover from contention, and no post-timeout secondary retry (AC-011, AC-014).
  - [x] Test stream completion, cancellation, `:kill`, errors, truncation and inactivity for the in-scope OpenAI adapter; test retry boundaries before and after output/tool fragments and exercise lifecycle changes while streams are active (AC-012, AC-013, AC-015, AC-016).
  - Command(s): `mix test test/oli/gen_ai/` and the relevant adapter, dialogue cancellation and transport integration tests created or updated here; `mix format --check-formatted`.
- Definition of Done:
  - Both completion paths use their selected real transport pools; capacity and retry behavior match the FDD, cleanup is demonstrated, and telemetry distinguishes health from request outcomes.
- Evidence: `docs/exec-plans/current/features/genai-redesign/design/phase-3-execution.md` and `docs/exec-plans/current/features/genai-redesign/execution/phase-3.md`; installed-Hackney timing scope and deferred Claude compatibility remain explicit.
- Gate:
  - No routing activation until required transport and stream tests pass for the in-scope OpenAI adapter and open timeout/fallback decisions are documented. Phase 2 configuration and monitoring must be integrated.
- Dependencies:
  - Phases 1 and 2.
- Parallelizable Work:
  - Adapter stream corrections and router/execution changes can proceed concurrently against the agreed interface; reconcile integration and end-to-end tests before the gate.

## Phase 4: Administration, rollout, and operational verification

- Goal: Make the redesign operable and safely transition existing deployments.
- Tasks:
  - [x] Update authorized Provider, RegisteredModel and ServiceConfig administration: selected probe model, editable flag, administrative and observed health, disabled/unknown/stale and missing-model states, safe diagnostics, tier capacities and Hackney's checked-out connection label. Replace obsolete model breaker and shared-pool controls (AC-001, AC-003, AC-018, AC-021).
  - [x] Route administrative test calls through the relevant ServiceConfig production pool or explicit administrative pool, and verify access controls and secret handling (AC-017, AC-018).
  - [x] Complete observable staged rollout and rollback instructions: audit migrated ServiceConfigs and combined per-node allocations, run probes in observe-only mode, then enable health-based routing only after transport and migration gates. Specify mixed-version deployment order, old state retirement and rollback; the runtime use of `GENAI_ROUTING_PRIMARY_ONLY` is restored as a bounded emergency path (AC-007, AC-020, AC-021).
  - [x] Update `docs/design-docs/genai.md` and operational guidance for pool semantics, probe defaults, override, capacity limits, alerts, node-local state, credentials, and recovery; connect telemetry to existing AppSignal conventions (AC-019, AC-021).
- Testing Tasks:
  - [x] Test admin authorization, model flag and Provider configuration, capacity labels, test-call transport selection, redacted errors and telemetry; manually inspect accessibility and disabled, unknown, stale and missing-model states (AC-017, AC-018, AC-019).
  - [x] Exercise migration and rollback with realistic legacy data and a staged outage/recovery under production-like streaming; verify health override preserves capacity routing and independent probes survive saturated production pools (AC-005, AC-007, AC-020, AC-021).
  - [x] Run relevant backend and LiveView suites, formatting, required security/performance and requirements reviews, and resolve findings. Apply broader tests when shared support or configuration changes require them.
  - Command(s): `mix test test/oli/gen_ai/` and relevant `test/oli_web/live/gen_ai/` and migration tests; `mix format --check-formatted`; `mix test` when required by repository shared-test-support policy.
- Definition of Done:
  - Administrative and operational workflows are verified, rollback and observe-first cutover are actionable, old controls are retired, documentation is reconciled, and required reviews and tests pass.
- Evidence: `docs/exec-plans/current/features/genai-redesign/execution/phase-4.md` records 365 passing targeted tests, reviews, traceability and known full-suite limits. Rendered HTML/HEEx was inspected; physical-browser and deployment connectivity/quota checks remain operator gates.
- Gate:
  - Release only after all prior gates, cross-node behavior, migration/rollback, adapter isolation, monitoring and review evidence are complete. Deployment follows the normal release process and any separate authorization required for that action.
- Dependencies:
  - Phases 1–3; administrative work may start earlier against stable interfaces but cutover depends on their completion.
- Parallelizable Work:
  - UI, operational documentation and rollout rehearsal can proceed concurrently once configuration and transport interfaces stabilize; coordinate final integration and review.

## Parallelization Notes

- Keep phases ordered as integration gates, while allowing the independent investigations and implementation tracks listed above to overlap. Do not merge incompatible transport assumptions or claim pool-only guarantees for deferred Claude traffic.
- Coordinate shared schema, adapter callback and reconciliation changes before parallel edits. Keep migration, monitoring and routing evidence available for the final security, performance and requirements reviews.

## Phase Gate Summary

- Gate 1: Installed transport behavior and an adapter-specific isolation strategy are evidenced; unsupported paths remain blocked.
- Gate 2: Provider configuration, reversible migration, per-node reconciliation and independently observed health work without diverting traffic.
- Gate 3: Actual selected pools enforce bounded routing and verified stream cleanup, including backup and cancellation boundaries.
- Gate 4: Administration, observability, rollout/rollback, documentation and required verification are complete before release.
