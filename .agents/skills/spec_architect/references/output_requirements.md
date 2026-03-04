# Output Requirements (FDD)

Produce `<feature_dir>/fdd.md` using the template, with these required sections always present:

1. Executive Summary
2. Requirements & Assumptions
3. Torus Context Summary
4. Proposed Design

Use expert judgment for depth in later sections, but cover all relevant technical surface area for implementation safety.

## Section Guidance

Diagram requirements (global):
- All diagrams in FDDs MUST use Mermaid syntax.
- Prefer `sequenceDiagram` for runtime/message flows.
- Use `stateDiagram-v2` when state-transition semantics are central to the design.

1. Executive Summary
- 8-10 plain-English sentences describing what is delivered, impacted users/systems, design rationale, top risks, and telemetry/AppSignal-based performance posture.

2. Requirements & Assumptions
- Functional requirements summary mapped to PRD FR IDs.
- Non-functional targets (latency/reliability/security/operability), with performance expressed as telemetry/AppSignal monitoring expectations.
- Explicit assumptions with impact/risk.

3. Torus Context Summary
- Findings from local docs and code reconnaissance.
- Current boundaries, supervision touchpoints, and telemetry anchors.

4. Proposed Design
4.1 Component Roles & Interactions
- Describe responsibilities and interactions in prose.
4.2 State & Message Flow
- Identify state ownership, message paths, and backpressure points.
- When message exchange, async coordination, or boundary handoffs are non-trivial, you MUST include at least one Mermaid `sequenceDiagram`.
4.3 Supervision & Lifecycle
- Define placement, restart strategy, and failure isolation behavior.
4.4 Alternatives Considered
- Briefly document rejected options and tradeoffs.

5. Interfaces
5.1 HTTP/JSON APIs
- Routes, params, validation, responses, and rate limits as applicable.
5.2 LiveView
- Event/callback contracts, assigns touched, PubSub topic interactions.
5.3 Processes
- GenServer/Task/Registry contracts and message patterns.

6. Data Model & Storage
6.1 Ecto Schemas
- Fields, constraints, migrations, and index rationale.
6.2 Query Performance
- Representative query shape and expected plan characteristics.

7. Consistency & Transactions
- Transaction boundaries, idempotency, retriable flows, and compensations.

8. Caching Strategy
- Cache layers, keys/partitioning, TTL/invalidation, multi-node coherence.

9. Performance and Scalability Posture (Telemetry/AppSignal Only)
9.1 Budgets
- p50/p95/p99 targets, throughput/capacity limits, pool sizing, memory posture.
- Specify how these are observed via telemetry/AppSignal; do not define benchmark/load/performance tests.
9.2 Hotspots & Mitigations
- N+1, large payloads, mailbox growth, lock contention, fanout risk, sync bottlenecks.

10. Failure Modes & Resilience
- Timeouts/retries/backoff/jitter, crash handling, graceful shutdown behavior.

11. Observability
- Telemetry events, measurements/metadata, trace coverage, structured logs, alert thresholds.

12. Security & Privacy
- AuthN/AuthZ, tenant isolation controls, PII handling/redaction, audit events.

13. Testing Strategy
- Unit/integration/system coverage, race/concurrency cases, migration/backfill verification.
- Exclude dedicated performance/load/benchmark tests; use telemetry/AppSignal coverage and alerting checks for performance posture.
- Include a Scenario Coverage Plan subsection that mirrors PRD `Oli.Scenarios Recommendation` contract:
  - PRD status (`Required`/`Suggested`/`Not applicable`)
  - AC/workflow mapping
  - planned scenario artifacts
  - validation loop commands
- Include a LiveView Coverage Plan subsection that mirrors PRD `LiveView Testing Recommendation` contract:
  - PRD status (`Required`/`Suggested`/`Not applicable`)
  - UI event/state mapping
  - planned LiveView test artifacts
  - validation commands

14. Backwards Compatibility
- Compatibility and migration posture for existing content, activities, and APIs.

15. Risks & Mitigations
- Top technical, performance, data, and operational risks plus concrete mitigations.

16. Open Questions & Follow-ups
- Product/infrastructure decisions needed, with recommended defaults where possible.

17. References
- External research citations formatted as `Title | URL | Accessed YYYY-MM-DD`.

Do not add dedicated traffic-simulation test plans or tooling scenarios in this skill output.
