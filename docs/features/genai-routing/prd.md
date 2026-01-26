# Backpressure-Aware GenAI Routing & Circuit Breakers — PRD

## 1. Overview

Summary: Introduce a centralized, backpressure-aware routing layer and per-model circuit breakers for GenAI requests so the system can proactively shed load, route to backups, and avoid pool exhaustion during peak usage and provider degradation.

Links: Informal PRD in this feature folder; no external links provided.

## 2. Background & Problem Statement
Current GenAI routing is static: a Primary model is used until error/timeout, then Backup is used. This reactive behavior fails under sustained load and provider degradation, causing hackney pool exhaustion, long blocking waits (30s+), and poor UX for streaming features (e.g., DOT chatbot).

Who is affected: Students and Instructors experience stalled or failed GenAI interactions; Authors and Admins cannot reliably trial models; Platform operations faces cascading failures during provider throttling.

Why now: GenAI usage and streaming workloads are increasing; without proactive admission control and health-aware routing, availability and responsiveness will degrade further.

## 3. Goals & Non-Goals
Goals:
- Provide dynamic routing between Primary and Backup models based on system backpressure and provider health.
- Apply explicit admission control to prevent pool exhaustion and long waits.
- Enable graceful degradation (route to faster/cheaper models) under load.
- Centralize routing logic for consistent behavior across features.
- Make routing decisions observable and explainable.

Non-Goals:
- No new dashboards for breaker health beyond targeted indicators in existing GenAI admin UIs.
- No new standalone routing policy screen; routing parameters are edited within Service Configs.
- No major UI redesigns; changes must mirror existing GenAI admin views (Registered Models, Service Configs).
- No redesign of provider adapters.
- No token-level cost optimization.
- No multi-provider traffic balancing beyond Primary/Backup.

## 4. Users & Use Cases
Primary Users / Roles:
- Students (LTI Learner): consume GenAI features in delivery.
- Instructors (LTI Instructor): use GenAI features for course delivery support.
- Authors (Torus Author): configure features using existing admin flows.
- Admins (Torus Admin): manage service configs and operational policies.

Use Cases / Scenarios:
- A DOT chatbot session starts during a peak period. The router detects high streaming concurrency for the configured ServiceConfig and routes new streaming requests to Backup or rejects fast, avoiding a 30s stall.
- A provider begins returning 429s. The Primary breaker opens and new requests route immediately to Backup until health recovers.
- A section configured to trial an experimental model uses stricter backpressure thresholds. Requests route to the Backup model when soft limits are reached, preventing a cascade in that section.

## 5. UX / UI Requirements
Key Screens/States:
- Extend the existing ServiceConfig editor to include routing policy parameters (editable).
- Minimal, targeted additions within existing ServiceConfig screens to surface read-only health signals.

Navigation & Entry Points:
- GenAI Admin area: Service Configs editor is the entry point for routing policy parameters.

Accessibility:
- Any UI additions must meet WCAG 2.1 AA. Health indicators and error messages must be accessible when displayed in existing UI.

Screenshots/Mocks:
- None provided.

## 6. Functional Requirements
| ID | Description | Priority | Owner |
|---|---|---|---|
| FR-001 | Introduce a centralized GenAI router that consumes resolved ServiceConfig and produces a RoutingPlan per request (selected model, fallback order, reason codes, timeouts). | P0 | Backend |
| FR-002 | Implement admission control using ETS-backed counters for active requests and active streams per ServiceConfig (and optionally per feature). | P0 | Backend |
| FR-003 | Implement per-RegisteredModel circuit breakers with closed/open/half_open states, tracking error rate, 429 rate, and latency spikes. | P0 | Backend |
| FR-004 | Apply routing policies based on request type (streaming vs non-streaming) with different thresholds. | P0 | Backend |
| FR-005 | If Primary breaker is open, route to Backup immediately; if both are unhealthy, return a fast, explicit error response (no long wait). | P0 | Backend |
| FR-006 | Emit telemetry for routing decisions, reasons, queue/wait time, and outcomes. | P0 | Backend |
| FR-007 | Preserve existing FeatureServiceConfig resolution and section overrides; routing uses the resolved ServiceConfig. | P0 | Backend |
| FR-008 | Each ServiceConfig must own an editable set of routing policy parameters (no shared policies) with safe defaults. Suggested starting parameters: `soft_limit`, `hard_limit`, `stream_soft_limit`, `stream_hard_limit`, `breaker_error_rate_threshold`, `breaker_429_threshold`, `breaker_latency_p95_ms`, `open_cooldown_ms`, `half_open_probe_count`, request timeout overrides. | P0 | Backend |
| FR-011 | Expose read-only routing health (breaker state, recent error/429/latency signals, and backpressure counters) within existing ServiceConfig UI without adding a new dashboard. | P1 | Backend |
| FR-012 | Extend the ServiceConfig editor UI to allow editing routing policy parameters, matching the look/feel and workflows of existing GenAI admin views. | P1 | Backend |
| FR-009 | Provide operational introspection endpoints or logs to inspect current breaker states and counters for debugging. | P1 | Backend |
| FR-010 | Provide graceful degradation behavior for features that opt-in (e.g., swap to backup or return a standard “try again” response). | P1 | Backend |

## 7. Acceptance Criteria
- AC-001 (FR-001) — Given a resolved ServiceConfig with Primary and Backup models, When a GenAI request is initiated, Then the router produces a RoutingPlan that includes selected model, fallback order, and reason codes within 5ms p95.
- AC-002 (FR-002) — Given active streaming sessions exceed the soft limit for a ServiceConfig, When a new streaming request arrives, Then the router selects Backup (if healthy) and records reason `backup_due_to_load`.
- AC-003 (FR-002, FR-005) — Given active requests exceed the hard limit, When a new request arrives, Then the request is rejected within 200ms with a standard error and no pool wait.
- AC-004 (FR-003) — Given the Primary model returns 429s above the breaker threshold within the rolling window, When subsequent requests arrive, Then the breaker transitions to open and the router avoids Primary.
- AC-005 (FR-003) — Given a breaker in open state reaches its cooldown period, When a request arrives, Then the router enters half_open for a probe request and transitions to closed on success or re-opens on failure.
- AC-006 (FR-004) — Given streaming and non-streaming requests for the same ServiceConfig, When concurrency is high, Then streaming requests shed earlier than non-streaming per policy thresholds.
- AC-007 (FR-006) — Given any GenAI request, When it completes (success/failure), Then a telemetry event is emitted with selected model, routing reason, duration, outcome, and error category.
- AC-008 (FR-007) — Given a section with a FeatureServiceConfig override, When a request is issued from that section, Then the router uses the resolved ServiceConfig for that section.
- AC-009 (FR-011) — Given an Admin views an existing ServiceConfig screen, When routing health data is available, Then read-only health indicators are shown inline and no new top-level navigation item is introduced.
- AC-010 (FR-012) — Given an Admin edits a ServiceConfig, When they update routing policy parameters, Then the changes are saved and used by the router on subsequent requests.

## 8. Non-Functional Requirements
Performance & Scale:
- Routing decision p95 < 5ms and p50 < 2ms under 2,000 concurrent requests.
- Admission control and counter checks must be O(1), ETS-based.
- For rejected requests, end-to-end response within 200ms.
- LiveView responsiveness unaffected: any GenAI-triggering LV events must respond within 150ms for routing decision.

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
- AppSignal counters for routing decisions, breaker state changes, rejection count, and latency distribution.
- Structured logs for routing plan summary with reason codes.

## 9. Data Model & APIs
Ecto Schemas & Migrations:
- Each ServiceConfig must persist its own routing policy parameters (no shared policies). Suggested starting parameter set for the architect: `soft_limit`, `hard_limit`, `stream_soft_limit`, `stream_hard_limit`, `breaker_error_rate_threshold`, `breaker_429_threshold`, `breaker_latency_p95_ms`, `open_cooldown_ms`, `half_open_probe_count`, request timeout overrides. Exact schema/migration details are defined in `fdd.md`.

Context Boundaries:
- `Oli.GenAI`: Router and breaker runtime.
- `Oli.GenAI.ServiceConfig`: policy resolution.
- `Oli.Delivery` or entry-point contexts: call router for requests.

APIs / Contracts:
- `Oli.GenAI.Router.route(request_ctx, resolved_service_config) :: {:ok, routing_plan} | {:error, reason}`
- `routing_plan` includes `selected_registered_model_id`, `fallbacks`, `reason`, `timeouts`, `admission_decision`.
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
- Ensure Dialogue.Server (if used) increments/decrements counters for streams.

Caching/Perf:
- Store counters in ETS; use atomic updates.
- Avoid N+1 queries by preloading ServiceConfig and RegisteredModel in request context.

Multi-Tenancy:
- Policies apply per ServiceConfig, which is scoped to institution/project/section via existing mappings.
- Counters and breaker states should include institution/section scoping in keys to avoid cross-tenant bleed.

## 11. Feature Flagging, Rollout & Migration
Flagging:
- No new feature flag integration in this phase. Rollout is controlled via ServiceConfig routing parameters and deployment sequencing.

Environments:
- Dev/stage enabled by default through ServiceConfig updates; prod rollout via staged ServiceConfig edits.

Data Migrations:
- Forward: add routing policy fields to `completions_service_configs`, backfill existing rows with conservative defaults.
- Rollback: remove added fields, fall back to static routing.

Rollout Plan:
- Phase 1: enable via ServiceConfig updates for internal testing sections; monitor errors and latency.
- Phase 2: enable for a small cohort of sections with streaming features by updating their ServiceConfig routing parameters.
- Phase 3: broader enablement after 1 week of stable metrics; rollback by restoring prior ServiceConfig values.

Telemetry for Rollout:
- Track `router.decision.count`, `router.rejection.count`, `breaker.open.count`, `provider.429.rate`, `request.latency.p95`.

## 12. Analytics & Success Metrics
North Star / KPIs:
- 50% reduction in p95 GenAI request latency under load.
- Zero hackney pool exhaustion incidents during peak.
- <1% rejection rate under normal traffic.

Event Spec:
- `genai_router_decision` with properties: `service_config_id`, `registered_model_id`, `reason`, `request_type`, `admission_decision`, `queue_ms`, `institution_id`, `section_id` (internal IDs only).
- `genai_router_outcome` with properties: `outcome`, `error_category`, `latency_ms`, `breaker_state`.

## 13. Risks & Mitigations
- Risk: False positives open breakers too often → Mitigation: conservative defaults, half_open probing, telemetry tuning.
- Risk: Over-aggressive shedding causes user-visible failures → Mitigation: soft limits with backup routing; fast failures with clear messaging.
- Risk: Per-tenant counters cause memory growth → Mitigation: TTL/cleanup on inactive sections.
- Risk: Complexity makes debugging harder → Mitigation: structured logs, explicit reason codes, introspection endpoints.

## 14. Open Questions & Assumptions
Assumptions:
- ServiceConfig persists routing policy parameters directly; a default policy is created by migration and visible/editable in the ServiceConfig editor.
- In-memory breaker state reset on node restart is acceptable for initial release.
- Per-node counters and breaker state are acceptable for v1 (no cluster-wide coordination).
- Features can surface standardized “try again” responses using existing UX patterns.

Open Questions:
- Which routing policy fields are exposed in the ServiceConfig editor vs. kept fixed as system defaults?
- What exact concurrency thresholds should be the default policy for streaming vs non-streaming?
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
- Migration tests for policy backfill.

Manual:
- Simulate provider 429s and timeouts; verify routing to backup.
- Load test with streaming sessions to ensure no pool exhaustion.
- Accessibility check for any surfaced error messaging.

Load/Perf:
- Run staged load test to validate p95 routing decision time and rejection behavior under high concurrency.

## 17. Definition of Done
- [ ] Docs updated
- [ ] Telemetry & alerts live
- [ ] Migrations & rollback tested
- [ ] Accessibility checks passed
- [ ] Routing policy defaults documented
- [ ] Staging load test results captured
