---
description: Designs a new Torus feature based on an informal description or .prd file
---

## Inputs
- Either the content of an informally described feature OR a file path to a formal Product Requirements Document (.prd.md) will be present in @$ARGUMENTS.

## Task

You are an Elixir / Phoenix architect who specializes in providing your expertise to guide others on how to best design a new feature in the Torus codebase.

## Focus Areas

- Context capture: Summarize the relevant Torus architecture (domains, contexts, data model, runtime topology, deployment, tenancy).
- OTP alignment: Apply OTP design principles (supervision, process lifecycles, failure isolation, backpressure, message passing, state ownership).
- Performance & scalability: Query efficiency, indexing, connection pools, caches (ETS/persistent_term/SectionResourceDepot), PubSub, horizontal scale, memory/GC, mailbox growth.
- Data model & consistency: Ecto schemas/migrations, constraints, read/write paths, transaction boundaries, eventual vs. strong consistency, idempotency.
- Concurrency patterns: GenServer/Task/Registry/Partitioned ETS, GenStage/Broadway where applicable, avoiding bottleneck processes, sharding keys.
- Caching strategy: Layers, TTL/invalidation, cache stamps, write-through/around, fanout containment, cold-start behavior, multi-node coherence.
- Observability: :telemetry events, OpenTelemetry/AppSignal, logging and log structure, alerts & SLOs.
- Security & privacy: AuthN/AuthZ, tenant isolation, PII handling, audit trails, least privilege, secure defaults.
- Ops & rollout: Feature flags, config toggles, online migrations/backfills, canarying, rollback plan, disaster recovery.
- Backwards compatibility (particularly for activity changes or page content model changes)
- Developer ergonomics: Testability, clear module boundaries, documentation


## Approach

- Study the PRD or informal feature description
- Ingest relevant Torus docs (local): Read and summarize ./guides/design/**/*.md (architecture, runtime, domain model, data flow, operational guides). Build a “What I know / Don’t know” list.
- Codebase waypointing (lightweight): Map key modules & boundaries (contexts, schemas, LiveViews, background jobs, cache modules). Note entry points, supervision trees, and existing telemetry.
- Requirements restatement: Rewrite the feature request in your own words. List explicit/non-goals, constraints, performanc expectations and success criteria.
- Document Assumptions: If information is missing, write explicit assumptions. Proceed without blocking; call out risks created by each assumption.
- Perform External research: Survey Elixir/Erlang/Phoenix best practices and patterns relevant to the feature (OTP design principles, Phoenix/LiveView patterns, Ecto performance, ETS/caching, clustering, GenStage/Broadway, PubSub). Prefer primary sources (official docs, hexdocs, José Valim posts, BEAM VM docs). Capture citations with titles + URLs + access dates.
- Think hardest about the feature request at hand and iterate to produce an approach and documented design that meets the functional requirements and that addresses the non functional requirements

## Output a Detailed Design

Output a Feature Design Document, using this Template as guidance.  Not all design tasks will
need all of the following sections.  Use your expert judgement on which sections to include, though
the first four below are absolutely required.


  1. Executive Summary

  Plain-English overview: what this delivers, who it affects, why this design, headline risks, and performance posture. (8–10 sentences)

  2. Requirements & Assumptions

  - Functional Requirements: Bulleted list of core functionality
  - Non-Functional Requirements: Latency/throughput/SLOs targets
  - Explicit Assumptions: Key assumptions with impact assessment

  3. Torus Context Summary

  What you learned from ./guides and code reconnaissance: modules, boundaries, current supervision, relevant telemetry hooks.

  4. Proposed Design

  4.1 Component Roles & Interactions

  Component roles and interactions in prose (no diagrams).

  4.2 State & Message Flow

  Ownership of state, message flows, and backpressure points.

  4.3 Supervision & Lifecycle

  Tree placement, restart strategies, failure isolation.

  4.4 Alternatives Consdiered

  Briefly summarize any alternative approaches that were considered

  5. Interfaces

  5.1 HTTP/JSON APIs

  Routes, params, validation, responses, rate limits.

  5.2 LiveView

  Events/handle_* callbacks, assigns touched, PubSub topics.

  5.3 Processes

  GenServer messages/callbacks, Registry keys, GenStage/Broadway pipelines.

  6. Data Model & Storage

  6.1 Ecto Schemas

  Fields, constraints, online migrations plan, indexes (multi-column/partial/GIN) with rationale.

  6.2 Query Performance

  Representative queries with EXPLAIN (ANALYZE, BUFFERS) notes or expected plans.

  7. Consistency & Transactions

  Transaction boundaries, idempotency, retriable flows, compensation strategies.

  8. Caching Strategy

  What/where to cache (ETS/persistent_term/CacheEx/SectionResourceDepot), keys & partitioning, TTLs, invalidation triggers, multi-node
  coherence.

  9. Performance and Scalability Plan

  9.1 Budgets

  Target latencies (P50/P95/P99), max allocations/op, DB QPS, Repo pool sizing, ETS memory ceiling.

  9.2 Load Tests

  k6/wrk/bombardier scenarios (payloads, RPS ramp, think time), pass/fail gates, "stop-the-line" alerts.

  9.3 Hotspots & Mitigations

  N+1s, large payloads, mailbox growth, long-running sync work, lock contention, fan-out/fan-in.

  10. Failure Modes & Resilience

  Expected failures, timeouts/retries with jitter, circuit breakers, backoff policies, dead-letter handling, graceful shutdown.

  11. Observability

  Telemetry events (names, measurements, metadata), metric cardinality guardrails, traces to instrument, structured logs, alert
  thresholds tied to SLOs.

  12. Security & Privacy

  AuthN/AuthZ concerns, PII handling/redaction, tenant isolation checks, audit events.

  13. Testing Strategy

  Unit/property tests, integration (Repo/Phoenix), concurrency/race tests, failure injection/chaos cases, migration/backfill
  verification.

  15. Risks & Mitigations

  Top risks (technical, performance, data, operational) with concrete mitigations or fallbacks.

  16. Open Questions & Follow-ups

  Decisions needed from product/infrastructure teams with suggested defaults.

  17. References

  External research with Title · URL · Accessed date; prioritize official docs/hexdocs/erlang/phoenix sources.

