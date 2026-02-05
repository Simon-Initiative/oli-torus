# Backpressure-Aware GenAI Routing & Circuit Breakers — PRD

## 1. Overview

Summary: Introduce a centralized, backpressure-aware routing layer with three-tier model selection (Primary → Secondary → Backup), per-RegisteredModel admission caps, and dual hackney pools (fast/slow). This enables proactive load shedding, preserves capacity for fast models during GPT‑5 spikes, and routes to Backup only during provider-level outages. Admins manage model selection in existing ServiceConfig screens and adjust pool sizes within the RegisteredModel admin view.

Links: Informal PRD in this feature folder; no external links provided.

## 2. Background & Problem Statement
Current GenAI routing is static: a Primary model is used until error/timeout, then Backup is used. This reactive behavior fails under sustained load and provider degradation, causing hackney pool exhaustion, long blocking waits (30s+), and poor UX for streaming features (e.g., DOT chatbot).

Who is affected: Students and Instructors experience stalled or failed GenAI interactions; Authors and Admins cannot reliably trial models; Platform operations faces cascading failures during provider throttling.

Why now: GenAI usage and streaming workloads are increasing; without proactive admission control and health-aware routing, availability and responsiveness will degrade further.

## 3. Goals & Non-Goals
Goals:
- Provide dynamic routing between Primary, Secondary, and Backup models based on provider health and per-model capacity.
- Apply explicit admission control with per-model caps and per-pool caps to prevent pool exhaustion and long waits.
- Enable graceful degradation by overflowing from slow Primary to fast Secondary under load.
- Centralize routing logic for consistent behavior across features.
- Make routing decisions observable and explainable.

Non-Goals:
- No new dashboards for breaker health beyond targeted indicators in existing GenAI admin UIs.
- No new standalone routing policy screen; routing remains configured via Service Configs.
- No major UI redesigns; changes must mirror existing GenAI admin views (Registered Models, Service Configs) with minimal additions.
- No redesign of provider adapters.
- No token-level cost optimization.
- No multi-provider traffic balancing beyond Primary/Secondary/Backup.

## 4. Users & Use Cases
Primary Users / Roles:
- Students (LTI Learner): consume GenAI features in delivery.
- Instructors (LTI Instructor): use GenAI features for course delivery support.
- Authors (Torus Author): configure features using existing admin flows.
- Admins (Torus Admin): manage service configs and operational policies.

Use Cases / Scenarios:
- A GPT‑5-heavy chat surge begins. The Primary model reaches its per-model cap, so new requests are routed to a faster Secondary model, preserving responsiveness and avoiding pool stalls.
- OpenAI experiences a broad outage (error/429 spike). The Primary and Secondary breakers open, and the router routes requests to the Backup model until health recovers.
- An Admin configures fast/slow pool sizes to reserve capacity for fast models; pool caps prevent total saturation even when slow models spike.

## 5. UX / UI Requirements
Key Screens/States:
- Extend the existing ServiceConfig editor to include Primary/Secondary/Backup model selection.
- Extend the RegisteredModel editor to include pool class (fast/slow) and max concurrent cap (editable).
- Add a small, admin-only section at the top of the RegisteredModel view to display and update fast/slow pool sizes.
- Minimal, targeted additions within existing ServiceConfig screens to surface read-only health signals for all three models.

Navigation & Entry Points:
- GenAI Admin area: Service Configs editor is the entry point for model selection.

Accessibility:
- Any UI additions must meet WCAG 2.1 AA. Health indicators and error messages must be accessible when displayed in existing UI.

Screenshots/Mocks:
- None provided.

## 6. Functional Requirements
| ID | Description | Priority | Owner |
|---|---|---|---|
| FR-001 | Introduce a centralized GenAI router that consumes resolved ServiceConfig and produces a RoutingPlan per request (selected model, tier, pool, reason codes). | P0 | Backend |
| FR-002 | Implement admission control using ETS-backed counters for per-RegisteredModel inflight counts and per-pool inflight counts with atomic try-admit. | P0 | Backend |
| FR-003 | Implement per-RegisteredModel circuit breakers with closed/open/half_open states, tracking error rate, 429 rate, and latency spikes. | P0 | Backend |
| FR-004 | Enforce three-tier routing: Primary preferred; if Primary breaker open or at cap → Secondary when configured; Backup is used when both Primary and Secondary breakers are open, or when Secondary is not configured and Primary is over capacity; Secondary over-cap rejects fast. | P0 | Backend |
| FR-005 | RegisteredModel defines pool class (`fast`/`slow`) and optional max_concurrent cap; pool sizes are configurable via env and adjustable via admin UI. | P0 | Backend |
| FR-006 | Emit telemetry for routing decisions/outcomes with tier, pool_class/pool_name, selected model, and outcome; routing decisions include reason codes. | P0 | Backend |
| FR-007 | Preserve existing FeatureServiceConfig resolution and section overrides; routing uses the resolved ServiceConfig. | P0 | Backend |
| FR-008 | Each RegisteredModel owns editable breaker thresholds and provider timeouts; ServiceConfig only selects Primary/Secondary/Backup models. | P0 | Backend |
| FR-009 | Expose read-only routing health (breaker state, recent error/429/latency signals) within existing ServiceConfig UI without adding a new dashboard. | P1 | Backend |
| FR-010 | Extend ServiceConfig editor to allow Primary/Secondary/Backup selection; extend RegisteredModel editor to allow pool_class, max_concurrent, breaker thresholds, and provider timeouts. | P1 | Backend |
| FR-011 | Add admin-only pool size controls (fast/slow) in the RegisteredModel view and log/telemetry for breaker/counter inspection. | P1 | Backend |

## 7. Acceptance Criteria
- Note: Routing does not distinguish stream vs generate requests in this phase; there are no stream-specific admission criteria.
- AC-001 (FR-001) — Given a resolved ServiceConfig with Primary/Secondary/Backup models, When a GenAI request is initiated, Then the router produces a RoutingPlan that includes selected model, tier, pool, and reason codes within 5ms p95.
- AC-002 (FR-002, FR-004) — Given the Primary model is healthy but at its max_concurrent cap, When a new request arrives, Then the router selects Secondary (if healthy and under cap) and records reason `primary_over_capacity`.
- AC-003 (FR-004) — Given Primary and Secondary breakers are open, When a new request arrives, Then the router selects Backup (if healthy and under cap) and records reason `backup_outage`.
- AC-004 (FR-004) — Given Secondary is healthy but at cap, When a new request arrives, Then the request is rejected with no pool wait.
- AC-004b (FR-004) — Given Secondary is not configured and Primary is at cap, When a new request arrives, Then the router selects Backup (if healthy and under cap) and records reason `primary_over_capacity`.
- AC-005 (FR-003) — Given a RegisteredModel returns 429s above the breaker threshold within the rolling window, When subsequent requests arrive, Then the breaker transitions to open and the router avoids that model.
- AC-006 (FR-006) — Given any GenAI request, When it completes (success/failure), Then a telemetry event is emitted with selected model, tier, pool_class/pool_name, duration, and outcome.
- AC-007 (FR-007) — Given a section with a FeatureServiceConfig override, When a request is issued from that section, Then the router uses the resolved ServiceConfig for that section.
- AC-008 (FR-009) — Given an Admin views an existing ServiceConfig screen, When routing health data is available, Then read-only health indicators for Primary/Secondary/Backup are shown inline and no new top-level navigation item is introduced.
- AC-009 (FR-010) — Given an Admin edits a ServiceConfig, When they update model selection, Then the changes are saved and used by the router on subsequent requests.
- AC-010 (FR-011) — Given an Admin updates fast/slow pool sizes in RegisteredModels view, When they submit the form, Then the pool max connections change at runtime and the new values are displayed.

## 8. Non-Functional Requirements
Performance & Scale:
- Routing decision p95 < 5ms and p50 < 2ms under 2,000 concurrent requests.
- Admission control and counter checks must be O(1), ETS-based.
- For rejected requests, end-to-end response remains fast with no pool wait.
- LiveView responsiveness unaffected: any GenAI-triggering LV events must respond within 150ms for routing decision.
- Fast/slow pool caps must prevent slow models from starving fast models.

Reliability:
- Circuit breaker windows and counters must be resilient to node restarts (in-memory reset acceptable; documented).
- Retry behavior limited to 1 fallback attempt; avoid cascading retries.
- Graceful degradation must be deterministic and never block on full pools.

Security & Privacy:
- Enforce existing authZ; only server-side routes and contexts may invoke router.
- No PII in routing logs or telemetry; identifiers should be hashed or internal IDs.

Compliance:
- WCAG 2.1 AA for any surfaced errors in existing UI.

Observability:
- AppSignal counters for routing decisions (tagged by tier and pool_class), breaker state changes, rejection count, and latency distribution.
- Structured logs for routing plan summary with reason codes.
- Router telemetry is scoped by service_config_id and registered_model_id (no section/institution identifiers).

## 9. Data Model & APIs
Ecto Schemas & Migrations:
- ServiceConfig persists only Primary/Secondary/Backup selection; breaker thresholds and provider timeouts live on RegisteredModel. Exact schema/migration details are defined in `fdd.md`.
- ServiceConfig includes `secondary_model_id` (nullable) between Primary and Backup.
- RegisteredModel includes `pool_class` (`fast`/`slow`) and optional `max_concurrent` cap.

Context Boundaries:
- `Oli.GenAI`: Router and breaker runtime.
- `Oli.GenAI.ServiceConfig`: policy resolution.
- `Oli.Delivery` or entry-point contexts: call router for requests.

APIs / Contracts:
- `Oli.GenAI.Router.route(request_ctx, resolved_service_config) :: {:ok, routing_plan} | {:error, reason}`
 - `routing_plan` includes `selected_registered_model_id`, `tier`, `pool_name`, `reason`, `admission_decision`.
- LiveView event handlers call router before issuing provider requests.

Permissions Matrix:
| Role | View policy | Edit policy | Use router | Override for section |
|---|---|---|---|---|
| Admin | Yes | Yes | Yes | Yes |
| Author | Yes | No | Yes | Yes (via ServiceConfig override) |
| Instructor | No | No | Yes | No |
| Student | No | No | Yes | No |

## 10. Integrations & Platform Considerations
LTI 1.3:
- No change to launch flows or role mapping; routing occurs post-auth.

GenAI:
- Must respect RegisteredModel and ServiceConfig model routing.
- Use existing provider abstraction; no adapter changes required.
- Pool assignment is based on RegisteredModel.pool_class (`fast`/`slow`).
- Admission control is per model and per pool (no stream/generate distinction).
- Breaker thresholds are configured per RegisteredModel to avoid cross-config mismatch.

Caching/Perf:
- Store counters in ETS; use atomic updates.
- Avoid N+1 queries by preloading ServiceConfig and RegisteredModel in request context.

Multi-Tenancy:
- Policies apply per ServiceConfig; section overrides resolve to a ServiceConfig as usual.
 - Admission counters and breaker state are per-node and scoped by model/pool (not section/institution).

## 11. Feature Flagging, Rollout & Migration
Flagging:
- No new feature flag integration in this phase. Rollout is controlled via ServiceConfig model selection and deployment sequencing.

Environments:
- Dev/stage enabled by default through ServiceConfig updates; prod rollout via staged ServiceConfig edits.

Data Migrations:
- Forward: add `secondary_model_id` to `completions_service_configs`; add routing fields to `registered_models`.
- Rollback: remove added fields, fall back to static routing.

Rollout Plan:
- Phase 1: enable via ServiceConfig updates for internal testing sections; monitor errors and latency.
- Phase 2: enable for a small cohort of sections with high-traffic GenAI features by updating their ServiceConfig model selection.
- Phase 3: broader enablement after 1 week of stable metrics; rollback by restoring prior ServiceConfig values.

Telemetry for Rollout:
- Track `router.decision.count`, `router.rejection.count`, `breaker.open.count`, `provider.429.rate`, `request.latency.p95`.

## 12. Analytics & Success Metrics
North Star / KPIs:
- 50% reduction in p95 GenAI request latency under load.
- Zero hackney pool exhaustion incidents during peak.
- <1% rejection rate under normal traffic.

Event Spec:
- `genai_router_decision` with properties: `service_config_id`, `registered_model_id`, `tier`, `pool_class`, `pool_name`, `reason`, `request_type`, `admission_decision` (internal IDs only).
- `genai_provider_stop` with properties: `outcome`, `latency_ms`, `provider`, `model`.

## 13. Risks & Mitigations
- Risk: False positives open breakers too often → Mitigation: conservative defaults, half_open probing, telemetry tuning.
- Risk: Over-aggressive shedding causes user-visible failures → Mitigation: conservative hard caps with backup routing; fast failures with clear messaging.
- Risk: Complexity makes debugging harder → Mitigation: structured logs, explicit reason codes, introspection endpoints.

## 14. Open Questions & Assumptions
Assumptions:
- ServiceConfig persists Primary/Secondary/Backup selection directly; defaults are created by migration and visible/editable in the ServiceConfig editor.
- In-memory breaker state reset on node restart is acceptable for initial release.
- Per-node counters and breaker state are acceptable for v1 (no cluster-wide coordination).
- Features can surface standardized “try again” responses using existing UX patterns.

Open Questions:
- What default max_concurrent values should be set for slow vs fast models?
- What default pool sizes (fast/slow) should be used per environment?
- Should breaker windows be per node or coordinated across the cluster?
- Do we need per-user admission control (rate limiting) in this phase?

## 15. Timeline & Milestones (Draft)
- Week 1: Router design, policy schema, ETS counters, unit tests (Owner: Backend).
- Week 2: Circuit breaker implementation and integration with GenAI entry points (Owner: Backend).
- Week 3: Telemetry, rollout sequencing, and staging validation (Owner: Backend/Infra).
- Week 4: Production canary and tuning (Owner: Backend/Infra).

## 16. QA Plan
Automated:
- Unit tests for router policy decisions (boundary thresholds, fallback logic).
- Property tests for breaker state transitions.
- LiveView tests to ensure no blocking waits on admission control.
  - Migration tests for secondary model defaults and registered model fields.

Manual:
- Simulate provider 429s and timeouts; verify routing to backup.
- Load test with high concurrency to ensure no pool exhaustion.
- Accessibility check for any surfaced error messaging.

Load/Perf:
- Run staged load test to validate p95 routing decision time and rejection behavior under high concurrency.

## 17. Definition of Done
- [ ] Docs updated
- [ ] Telemetry & alerts live
- [ ] Migrations & rollback tested
- [ ] Accessibility checks passed
- [ ] Default model selection documented
- [ ] Staging load test results captured
