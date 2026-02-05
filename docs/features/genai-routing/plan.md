# Backpressure-Aware GenAI Routing & Circuit Breakers — Plan

References:
- PRD: `docs/features/genai-routing/prd.md`
- FDD: `docs/features/genai-routing/fdd.md`

## Scope
Deliver backpressure-aware routing and circuit breakers for GenAI requests, with per-ServiceConfig routing parameters, ETS-backed admission control, per-model breaker state, telemetry, and a targeted ServiceConfig admin UI extension. No provider adapter redesign and no new standalone dashboards.

## Non-Functional Guardrails
- Router decision p50 < 2ms, p95 < 5ms at 2k concurrent requests.
- Fast rejection within 200ms when hard limits exceeded.
- No PII in logs/telemetry.
- Feature-flag gated rollout with rollback plan.
- Multi-tenant isolation preserved (no cross-section leakage in counters).

## Clarifications (defaults if not resolved)
- **PRD migration mismatch**: PRD section 11 mentions a `genai_routing_policies` table; FDD uses ServiceConfig fields. Default to FDD (ServiceConfig fields) and update PRD accordingly.
- **Single-node vs multi-node**: assume per-node counters/breakers for v1; document behavior and add telemetry to detect divergence.
- **Default policy values**: use conservative defaults (low streaming limits, moderate hard limits) until product defines exact values.
- **Counters scope**: per ServiceConfig; optional per-section counters deferred unless needed for fairness.

---

## Phase 0: Alignment & Spec Hygiene (Complete)
Goal: Resolve spec mismatches and lock implementation assumptions.

Tasks:
- [x] Reconcile PRD section 11 to match FDD data model (ServiceConfig fields, no policy table).
- [x] Confirm default policy values (soft/hard, streaming, breaker thresholds, timeouts) with product/infra.
- [x] Confirm behavior in multi-node deployment and add explicit notes in FDD if needed.

Definition of Done:
- PRD/FDD are consistent on data model and rollout assumptions.
- Default policy values documented in FDD.

Gate:
- Spec sign-off from product/tech lead.

---

## Phase 1: Data Model & Validation
Goal: Persist routing policy parameters on ServiceConfig with constraints and defaults.

Tasks:
- [ ] Add new routing policy fields to `completions_service_configs` per FDD.
- [ ] Backfill existing ServiceConfig rows with conservative defaults.
- [ ] Add CHECK constraints for min/max and soft <= hard limits.
- [ ] Extend `ServiceConfig.changeset/2` validations for routing fields.
- [ ] Update GenAI context functions if needed to include new fields.
- [ ] Write migration tests to verify defaults and constraints.

Tests:
- [ ] Migration tests (forward + rollback) via `mix test` for migration helpers.
- [ ] Changeset validation tests (invalid thresholds, soft>hard, negative values).

Definition of Done:
- Migrations run cleanly and backfill defaults.
- ServiceConfig changeset rejects invalid values.

Gate:
- `mix test` passes for migration + changeset tests.

Parallelizable:
- Phase 2 can start after schema fields are defined (even before migration PR merges) with feature-flagged runtime scaffolding.

---

## Phase 2: Runtime Router, Admission Control, and Breakers (Complete)
Goal: Build the core routing system and integrate with existing Completions.

Tasks:
- [x] Implement `Oli.GenAI.AdmissionControl` with ETS tables and atomic counters.
- [x] Implement `Oli.GenAI.BreakerSupervisor`, `BreakerRegistry`, and per-model `Breaker` GenServer.
- [x] Implement `Oli.GenAI.Router` and `RoutingPlan` struct with reason codes.
- [x] Implement `Oli.GenAI.Execution` wrapper calling `Oli.GenAI.Completions.generate/stream`.
- [x] Add application supervision entries for AdmissionControl and BreakerSupervisor.
- [x] Provide fallback behavior and fast rejection path when hard limits exceeded.

Tests:
- [x] Unit tests for router decisions (load, health, streaming vs non-streaming).
- [x] Property tests for breaker state transitions.
- [x] Concurrency tests for ETS counters (increment/decrement, no negative counts).
- [x] Execution tests for fallback behavior when primary fails.

Definition of Done:
- Router returns deterministic RoutingPlan under test conditions.
- AdmissionControl counters are correct under concurrency.
- Breaker transitions correctly on simulated errors and cooldowns.

Gate:
- All router/breaker tests pass; no performance regressions in unit suite.

Parallelizable:
- Phase 3 (integration) can start once `Execution` API is stable.

---

## Phase 3: Integration with GenAI Entry Points (Complete)
Goal: Route all GenAI calls through `Execution` and increment counters correctly.

Tasks:
- [x] Update `Oli.GenAI.Dialogue.Server` to use `Oli.GenAI.Execution.stream`.
- [x] Update any synchronous GenAI calls to use `Oli.GenAI.Execution.generate`.
- [x] Ensure streaming sessions increment/decrement the streaming counters at start/finish.
- [x] Add fast failure responses when router rejects admission.

Tests:
- [x] LiveView/Dialogue integration tests for streaming request flow.
- [x] Failure injection tests for 429/timeouts (breaker opens, fallback used).

Definition of Done:
- All GenAI entry points go through Execution layer.
- Streaming counters reflect active sessions accurately.

Gate:
- Integration tests pass.

Parallelizable:
- Phase 4 (UI) can run in parallel once schema changes are merged.

---

## Phase 4: Admin UI Extension (ServiceConfig Editor) (Complete)
Goal: Expose routing policy parameters and health indicators in existing UI.

Tasks:
- [x] Extend `OliWeb.GenAI.ServiceConfigsView` form to include routing fields.
- [x] Add read-only health indicators (breaker state + counters) sourced from ETS.
- [x] Validate inputs and surface errors inline (WCAG AA).
- [x] Add throttled refresh of health indicators (e.g., poll every 5–10s).

Tests:
- [x] LiveView tests for create/edit with routing fields.
- [x] Accessibility checks for new form fields and indicator labels.

Definition of Done:
- Admin can edit routing parameters in ServiceConfig UI.
- Health indicators display without DB queries on each render.

Gate:
- LiveView tests pass; manual UI pass in dev.

---

## Phase 5: Telemetry and Observability
Goal: Instrument routing decisions and enable safe rollout.

Tasks:
- [x] Add telemetry events from Router/Execution/Breaker (per FDD).
- [x] Add AppSignal metrics and dashboards (decision reasons, breaker opens, rejections).
- [x] NO FEATURE FLAG INTEGRATION
- [x] Add structured logs for routing plan summary.

Tests:
- [x] Unit tests verifying telemetry event emission.
- [x] No flag gating tests required (feature flags not used).

Definition of Done:
- Telemetry verified in dev

Gate:
- Telemetry tests pass; dashboard definitions documented.

Parallelizable:
- This phase can run in parallel with Phase 4.

---

## Phase 6: Documentation
Goal: Ensure that developers, when looking at code, understand how the new backpressure dynamic routing works

Tasks:
- [ ] Ensure useful moduledoc documentation present in EVERY new module
- [ ] Ensure all public functions in new modules have function level docs explaining purpose
- [ ] Make necessary edits and improvements to guides/design/genai.md, incorporating backpressure and dynamic routing

## Risks & Dependencies
- **Risk**: Multi-node divergence in breaker state leads to inconsistent routing.
  - Mitigation: document, monitor, and consider cross-node coordination in future iteration.
- **Risk**: Thresholds too aggressive; UX impact.
  - Mitigation: conservative defaults + telemetry-driven tuning.
- **Dependency**: ServiceConfig migrations must precede UI and router parameter usage.
