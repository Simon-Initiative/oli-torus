# RemixSection LiveView Refactor — PRD

## 1. Overview

Feature Name

Refactor RemixSection LiveView (extract business logic to context).

Summary: Streamline the RemixSection LiveView by moving non-UI business logic into a dedicated non-UI context to improve testability, maintainability, observability, and performance without changing user-visible behavior.

Links: docs/features/refactor_remix/fdd.md

## 2. Background & Problem Statement

The current RemixSection LiveView contains significant business logic (authorization checks, data loading/mutations, branching decisions). This violates separation of concerns, makes testing and reuse difficult, and increases regression risk. Instructors and Admins using RemixSection are directly affected by bugs and performance issues; Authors may also access Remix functions in some orgs. We should refactor now to stabilize a hotspot, reduce complexity, and enable future enhancements.

## 3. Goals & Non-Goals

Goals:
- Extract non-UI business logic to a dedicated context with clear APIs.
- Maintain feature parity and user experience (no UX changes).
- Increase unit-test coverage for business rules; reduce LiveView surface area.
- Keep authorization at LiveView mount; make the new module auth-agnostic while validating inputs and invariants.
- Preserve/standardize telemetry and error handling.

Non-Goals:
- Changing workflows, UI layout, or adding new features.
- Schema changes beyond minor indexes (if any) or telemetry renaming.
- Rewriting unrelated LiveViews or global state management.

## 4. Users & Use Cases

Primary Users / Roles: Instructor (LTI Instructor/TA), Admin, (possibly Author in admin context). Students are unaffected.

Use Cases / Scenarios:
- Instructors/Admins open RemixSection and perform actions (load data, preview changes, apply remix operations). After refactor, all flows behave identically, but logic executes in the context, improving reliability and traceability.

## 5. UX / UI Requirements

Key Screens/States: No visual changes; same loading/empty/error/success states and toasts.

Navigation & Entry Points: Same menu entries and routes as today.

Accessibility: Preserve WCAG 2.1 AA behavior, landmarks, focus order, and ARIA live-region announcements.

Internationalization: No copy changes; all strings remain externalized; RTL remains supported.

Screenshots/Mocks: Not applicable (behavior-preserving refactor).

## 6. Functional Requirements

| ID | Description | Priority | Owner |
|---|---|---|---|
| FR-001 | Extract all non-UI business logic from `RemixSection` LiveView into a new/expanded context (e.g., `Oli.Delivery.Remix`), exposing pure functions and side-effecting commands. | P0 | Eng |
| FR-002 | LiveView makes no direct DB calls or ad-hoc authorization; it only invokes context APIs and manages assigns/events. | P0 | Eng |
| FR-003 | Preserve feature parity: inputs, outputs, and UI behavior remain unchanged for all supported roles and tenants. | P0 | Eng |
| FR-004 | Authorization remains in LiveView `mount`; the new module assumes authorized inputs and performs no ad-hoc auth checks. | P0 | Eng |


## 7. Acceptance Criteria (Testable)

- AC-001 (FR-001, FR-002)
  Given an Instructor launches RemixSection,
  When the user triggers each supported action,
  Then the LiveView delegates to context functions only (no `Repo`/query modules in the LiveView per code audit).

- AC-002 (FR-003)
  Given parity test fixtures from current implementation,
  When run against the refactored path,
  Then outputs, UI messages, and state transitions match baseline snapshots.

- AC-003 (FR-004)
  Given an unauthorized user reaches the LiveView route,
  When `mount/3` runs,
  Then authorization checks at mount deny access; the `Oli.Delivery.Remix` module is never invoked.

- AC-004 (FR-006)
  Given unit and LiveView tests,
  When CI runs,
  Then coverage for the new context functions ≥ 80% and critical paths have LiveView test coverage.

- AC-005 (FR-005)
  Given AppSignal subscribers,
  When actions execute via the context,
  Then telemetry events fire with expected names and properties and appear on the dashboard.

- AC-006 (FR-001, FR-002)
  Given a save operation with a non-trivial hierarchy,
  When the user triggers Save,
  Then `Oli.Delivery.Remix.save/1` delegates to `Oli.Delivery.Sections.rebuild_section_curriculum/3` and completes within 1–2s server-side.

## 8. Non-Functional Requirements

Performance & Scale: Interactive operations p95 < 50 ms server-side; save persists within 1–2 s including post-processing; no added renders; avoid N+1 via context queries; paginate/stream large lists if present; works across Phoenix cluster nodes.

Reliability: Idempotent context commands where applicable; timeouts and retries for external calls; LiveView degrades gracefully on errors.

Security & Privacy: AuthN via existing session/LTI; AuthZ enforced at LiveView `mount`; the module is auth-agnostic and validates inputs/invariants; no new PII surfaces.

Compliance: Preserve WCAG AA and audit logs; keep existing retention policies.

Observability: Add spans/metrics around context calls; structured logs with correlation IDs; AppSignal dashboards/alerts updated if event names change.

## 9. Data Model & APIs

Ecto Schemas & Migrations: No schema changes expected. Add indexes only if new query paths require them (per FDD), with reversible migrations.

Context Boundaries: Introduce/expand `Oli.Delivery.Remix` and `Oli.Delivery.Remix.State` with functions such as `init/2`, `save/1`, `select_active/2`, `reorder/3`, `move/3`, `remove/2`, `toggle_hidden/2`, `add_materials/2`, plus filtering/sorting/pagination helpers for publications/pages.

APIs / Contracts: LiveView delegates events (e.g., reorder/move/add/remove/toggle/select/save) to `Oli.Delivery.Remix.*` functions and assigns the returned `%State{}`. Save calls `Remix.save/1` which delegates to `Sections.rebuild_section_curriculum/3`.

Permissions Matrix:
- Instructor/Admin: read and apply remix operations for owned sections.
- Author: allowed only when acting as course staff in the section (per Torus policy).
- Student: no access.

## 10. Integrations & Platform Considerations

LTI 1.3: Respect LTI roles from launch; deep-linking unchanged.

Caching/Perf: Use existing section/resource caches (e.g., SectionResourceDepot) in context; define invalidation on write paths.

Multi-Tenancy: All reads/writes scoped by `institution_id` and section ownership; no cross-tenant joins from LiveView.

GenAI: Not applicable.

## 11. Feature Flagging, Rollout & Migration

Flagging: No runtime feature flag by default (aligns with FDD). If needed, use an application config gate to switch delegation at boot.

Environments: Ship to dev/stage; validate with existing integration tests; deploy to prod with close monitoring.

Data Migrations: None expected.

Rollout Plan: Incremental—introduce module, delegate handlers, remove duplicate logic after stability. Rollback via deploy revert.

Telemetry for Rollout: Monitor Remix operation error rates and latency p95 in AppSignal.

## 12. Analytics & Success Metrics

- 0 user-facing regressions reported in first 14 days after 100% rollout.
- AppSignal error rate for Remix operations does not increase over baseline.
- Interactive operation p95 ≤ 50 ms; save ≤ 2 s server-side.
- LiveView file LOC and cyclomatic complexity reduced ≥ 30%.

## 13. Risks & Mitigations

- Regression risk → Canary flag, snapshot tests, and fallbacks.
- Hidden coupling in LiveView → Incremental extraction with integration tests.
- Authorization drift → Keep auth in LiveView mount; module consumes authorized inputs; add negative mount tests.

## 14. Open Questions & Assumptions

Assumptions:
- No schema changes required; context can compose existing queries.
- Existing telemetry names are retained; only location moves.
- RemixSection functionality scope matches current production behavior.

Open Questions:
- Do we want an app-config gate for emergency disable, or rely solely on revert?
- Any institution-specific exceptions to authorization at mount?

## 15. Timeline & Milestones (Draft)

- Week 1: Extract context APIs, add unit tests, wire LiveView delegation.
- Week 2: Integration tests, telemetry checks, staging verification.
- Week 3: Production deploy, monitoring, remove old code paths when stable.

## 16. QA Plan

Automated: Context unit tests; LiveView tests for critical flows; migration tests if indexes added; property tests for idempotent actions.

Manual: Exploratory passes across roles; accessibility regression checks; canary sections validation.

Load/Perf: Bench critical actions under concurrency; verify p95 targets; AppSignal dashboards.

## 17. Definition of Done

- [ ] Docs updated (PRD/FDD synced)
- [ ] Telemetry & dashboards verified
- [ ] Tests passing with coverage targets
- [ ] Rollback path documented
- [ ] Accessibility checks passed
