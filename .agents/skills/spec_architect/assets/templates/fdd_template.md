# <Feature Name> — Functional Design Document

## 1. Executive Summary
<architecture summary and why this design>

## 2. Requirements & Assumptions
- Functional Requirements:
  - <FR linkage>
- Non-Functional Requirements:
  - <budgets>
- Explicit Assumptions:
  - <assumptions>

## 3. Torus Context Summary
- What we know:
  - <existing modules/workflows>
- Unknowns to confirm:
  - <open items>

## 4. Proposed Design
### 4.1 Component Roles & Interactions
<components and responsibilities>

### 4.2 State & Message Flow
<request/response lifecycle>

### 4.3 Supervision & Lifecycle
<OTP, process ownership, startup/teardown>

### 4.4 Alternatives Considered
<alternatives and tradeoffs>

## 5. Interfaces
### 5.1 HTTP/JSON APIs
<contracts>

### 5.2 LiveView
<events/assigns/messages>

### 5.3 Processes
<GenServer/Task/API signatures>

## 6. Data Model & Storage
### 6.1 Ecto Schemas
<migrations, constraints>

### 6.2 Query Performance
<query shape/index needs>

## 7. Consistency & Transactions
<transaction boundaries, failure atomicity>

## 8. Caching Strategy
<cache ownership/invalidations>

## 9. Performance and Scalability Posture (Telemetry/AppSignal Only)
### 9.1 Budgets
<latency, throughput, memory budgets monitored by telemetry/AppSignal; no dedicated performance/load/benchmark tests>

### 9.3 Hotspots & Mitigations
<risk items>

## 10. Failure Modes & Resilience
<failure table and fallback behavior>

## 11. Observability
<telemetry, logs, dashboards, alerts>

## 12. Security & Privacy
<authz, tenancy, data handling>

## 13. Testing Strategy
<unit/integration/liveview/manual; exclude dedicated performance/load/benchmark tests>
### 13.1 Scenario Coverage Plan
- PRD Scenario Status: <Required | Suggested | Not applicable>
- AC/Workflow Mapping: <AC/workflow -> planned scenario coverage, or `N/A`>
- Planned Scenario Artifacts: <`.scenario.yaml` files + runner modules, or `N/A`>
- Validation Loop: <schema + parser/test commands, or `N/A`>
### 13.2 LiveView Coverage Plan
- PRD LiveView Status: <Required | Suggested | Not applicable>
- UI Mapping: <event/state -> test coverage, or `N/A`>
- Planned LiveView Test Artifacts: <test modules, or `N/A`>
- Validation Commands: <targeted `mix test ...`, or `N/A`>

## 14. Backwards Compatibility
<compatibility strategy or `N/A`>

## 15. Risks & Mitigations
<risk list>

## 16. Open Questions & Follow-ups
<questions>

## 17. References
- <source>
