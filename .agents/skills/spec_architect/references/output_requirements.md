# Output Requirements (FDD)

Produce `<feature_dir>/fdd.md` using the template, with these required sections always present:

1. Executive Summary
2. Requirements & Assumptions
3. Torus Context Summary
4. Proposed Design

Use expert judgment for depth in later sections, but cover all relevant technical surface area for implementation safety.

## Section Guidance

1. Executive Summary
- 8-10 plain-English sentences describing what is delivered, impacted users/systems, design rationale, top risks, and performance posture.

2. Requirements & Assumptions
- Functional requirements summary mapped to PRD FR IDs.
- Non-functional targets (latency/reliability/security/operability).
- Explicit assumptions with impact/risk.

3. Torus Context Summary
- Findings from local docs and code reconnaissance.
- Current boundaries, supervision touchpoints, and telemetry anchors.

4. Proposed Design
4.1 Component Roles & Interactions
- Describe responsibilities and interactions in prose.
4.2 State & Message Flow
- Identify state ownership, message paths, and backpressure points.
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

9. Performance and Scalability Plan
9.1 Budgets
- p50/p95/p99 targets, throughput/capacity limits, pool sizing, memory posture.
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

14. Backwards Compatibility
- Compatibility and migration posture for existing content, activities, and APIs.

15. Risks & Mitigations
- Top technical, performance, data, and operational risks plus concrete mitigations.

16. Open Questions & Follow-ups
- Product/infrastructure decisions needed, with recommended defaults where possible.

17. References
- External research citations formatted as `Title | URL | Accessed YYYY-MM-DD`.

Do not add dedicated traffic-simulation test plans or tooling scenarios in this skill output.
