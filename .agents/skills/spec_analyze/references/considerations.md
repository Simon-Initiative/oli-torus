# Considerations

Use these Torus-specific considerations while drafting the PRD:

- Multi-tenancy: scope all behavior to institution, project, and section boundaries as appropriate.
- Roles and permissions: include Torus and LTI role expectations for each critical action.
- Accessibility: WCAG 2.1 AA, keyboard-only flows, focus order, screen-reader compatibility, and contrast expectations.
- Internationalization: externalized strings, RTL readiness, date/number localization expectations.
- Performance and scale: expected concurrency, latency targets (p50/p95), responsive LiveView behavior, pagination/streaming for large datasets.
- Reliability: timeout and retry expectations, graceful degradation behavior, and error budget posture where relevant.
- Security and privacy: authentication/authorization, PII handling and redaction, abuse controls, and auditability.
- Observability: telemetry events, metrics, logs, traces, and AppSignal dashboard/alert implications.
- Data and API boundaries: schemas/migrations/indexes, context boundaries, API and LiveView contracts, and permission matrix expectations.
- Integrations: LTI flows, external service contracts, and GenAI-specific concerns when applicable (routing, fallback, rate limits, cost controls).
- Rollout and migration: include rollout/rollback/canary/runbook posture only when feature flags are explicitly required; otherwise limit to data migration/backfill implications and operational safety checks that are independently necessary.
- Delivery and QA readiness: test strategy across automated and manual coverage, plus explicit Definition of Done criteria.
