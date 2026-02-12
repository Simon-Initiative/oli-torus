# Focus Areas

Evaluate and address these areas in every FDD unless a section is truly not applicable:

- Context capture: relevant Torus domains, contexts, data model, runtime topology, deployment assumptions, tenancy model.
- OTP alignment: supervision strategy, process lifecycle, failure isolation, backpressure, state ownership, message paths.
- Performance and scalability: query efficiency, indexes, connection pools, caching layers (ETS, persistent_term, SectionResourceDepot), PubSub fanout, memory and mailbox growth.
- Data model and consistency: Ecto schemas/migrations, constraints, read/write paths, transaction boundaries, consistency model, idempotency.
- Concurrency patterns: GenServer/Task/Registry/partitioned ETS, plus GenStage/Broadway where appropriate; avoid central bottlenecks.
- Caching strategy: cache layers, keys, partitioning, TTLs, invalidation triggers, cold-start behavior, multi-node coherence.
- Observability: telemetry events, AppSignal/OpenTelemetry instrumentation, structured logs, alerts, and SLO alignment.
- Security and privacy: authentication/authorization, tenant isolation, least privilege, PII handling, auditability.
- Operations and rollout: feature flags/config toggles, online migrations/backfills, canary strategy, rollback and recovery.
- Backwards compatibility: especially for activity contracts and page/content model changes.
- Developer ergonomics: testability, clear module boundaries, maintainability, and documentation quality.

Do not include dedicated traffic-simulation test planning in this skill.
