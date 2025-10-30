# Canary Feature Rollout – Delivery Plan

Scope references: PRD (`docs/features/canary/prd.md`), FDD (`docs/features/canary/fdd.md`). This plan sequences implementation work for the canary rollout layer atop scoped feature flags.

## Non-Functional Guardrails
- Decision latency: P95 ≤ 5 ms (local), ≤ 15 ms (cross-node); P99 ≤ 10 ms.
- Repo load: ≤ 1 query/table/decision on cache miss; cache hit rate target ≥ 95%.
- Migration safety: zero-downtime additive migrations with rollback scripts.
- Security: admin-only mutation paths, tenant/publisher validation, full auditing.
- Observability: telemetry events `[:torus, :feature_flag, :decision]` and `[:torus, :feature_flag, :rollout_stage_changed]` emitted with bounded cardinality.
- Accessibility: Admin UI changes meet WCAG AA (contrast, keyboard nav).
- Operational readiness: cache invalidation and rollback procedures documented before launch.

## Clarifications & Assumptions
1. `force_enable` exemptions do **not** override a stage set to `off`. (Assumption; confirm with product.)
2. Stage scheduling (`starts_at`/`ends_at`) is out of scope for MVP despite schema placeholders. (Assumption.)
3. Callers of `can_access?/3` will provide preloaded project/section structs with `publisher_id`; fallback Repo query acceptable if absent. (Assumption; minor perf risk.)
4. Multi-region deployment not required; PubSub invalidation per Erlang cluster is sufficient. (Assumption.)

## Phase 1: Schema & Data Foundations
- **Goal:** Introduce schema changes and data plumbing required for canary states and internal actors.
- **Tasks**
- [ ] Add `is_internal` boolean columns to `authors` and `users` with migrations (default `false`, not null).
  - [ ] Create `scoped_feature_rollouts` table per FDD (enums, indexes, FKs, updated_by).
  - [ ] Create `scoped_feature_exemptions` table with uniqueness and audit fields.
  - [ ] Update Ecto schemas (`Oli.Accounts.Author`, `Oli.Accounts.User`, new rollout/exemption schemas) plus changesets.
  - [ ] Write migration unit tests (schema assertions via `assert table/column` helpers) and repo tests for new changesets.
  - [ ] Run `mix test test/oli/scoped_feature_flags/* --include migration` (or equivalent) and `mix ecto.migrate` on dev DB.
- **Definition of Done:** Migrations compile, run forward/backward without data loss; schemas reflect new fields; tests green.

Dependencies: None (start here). This phase blocks all others.

## Phase 2: Core Backend Logic & Caching
- **Goal:** Build rollout evaluation pipeline, caching, and telemetry per FDD.
- **Tasks**
  - [ ] Implement new context functions in `Oli.ScopedFeatureFlags.Rollouts` for CRUD on rollouts/exemptions (with audits).
  - [ ] Extend `Oli.ScopedFeatureFlags` with `can_access?/3-4`, stage resolution, cache integration, and deterministic hashing (`@cohort_hash_version` constant).
  - [ ] Wire Cachex tables (`:feature_flag_stage`, `:feature_flag_cohorts`) and PubSub invalidation (`"feature_rollouts"` topic).
  - [ ] Emit telemetry events for decisions and stage transitions; ensure metadata adheres to FDD cardinality guardrails.
  - [ ] Add unit/property tests covering stage logic, exemptions, internal flags, caching (via Mox/fakes), and PubSub invalidation.
  - [ ] Update auditing flows to capture stage/exemption mutations.
  - [ ] Run `mix test test/oli/scoped_feature_flags` and property suites; ensure coverage for failure paths (Repo errors fail closed).
- **Definition of Done:** New APIs documented with dialyzer specs; tests cover all stage permutations; telemetry fires in test; Cachex + PubSub integrated; lint/dialyzer clean.

Dependencies: Phase 1 migrations (schemas) must be complete.
Parallelism: Within the phase, telemetry wiring can follow core logic but requires cache + API skeleton first.

## Phase 3: Admin UI & LiveView Integration
- **Goal:** Update administrative UX to manage canary rollouts, exemptions, and display inherited states.
- **Tasks**
  - [ ] Enhance `OliWeb.Components.ScopedFeatureFlagsComponent` (and related LiveViews) with stage controls (`Off → Internal → 5% → 50% → Full`) respecting sequential progression.
  - [ ] Add publisher exemption management UI (lists, toggle buttons, note input).
  - [ ] Hook UI actions to backend context calls; subscribe to PubSub for live updates.
  - [ ] Add system-admin-only checkbox to Author/User admin detail pages to toggle `is_internal`, wiring through existing contexts and audit logging.
  - [ ] Add LiveView tests using `Phoenix.LiveViewTest` covering stage transitions, permission enforcement, and broadcaster refresh.
  - [ ] Run `mix test test/oli_web/components/scoped_feature_flags_component_test.exs test/oli_web/live/features/*`.
- **Definition of Done:** UI reflects new stages, handles error states gracefully, meets accessibility guidelines (focus order, labels), `is_internal` toggle is restricted to system admins with audit trail, LiveView tests pass, manual UX review recorded.

Dependencies: Phase 2 backend logic available.
Parallelism: UI styling and test writing can proceed concurrently once API signatures settled.

## Phase 4: Observability, Ops & Performance Readiness
- **Goal:** Validate non-functional aspects (telemetry, cache behavior, performance, rollout procedures).
- **Tasks**
  - [ ] Configure AppSignal metrics dashboards for new telemetry events; document alert thresholds (error rate >1%, cache hit <80%).
  - [ ] Implement load test harness (k6/bombardier) exercising `can_access?/3` via representative endpoint; capture latency/QPS.
  - [ ] Draft runbook covering stage change process, cache invalidation behavior, rollback
  - [ ] Validate PubSub invalidation across multi-node dev cluster (simulate second node or use ExUnit cluster tests).
  - [ ] Document hashing contract (`@cohort_hash_version`) and policy for future changes.
  - [ ] Run load/perf tests and compile report; ensure telemetry events observed in staging/AppSignal sandbox.
- **Definition of Done:** Performance metrics meet guardrails; runbook stored (e.g., `docs/features/canary/runbook.md` or ops wiki); telemetry verified; no outstanding alerts.

Dependencies: Phases 2–3 must be functionally complete (observability needs full stack).
Parallelism: Load testing and telemetry dashboard setup can run simultaneously once decision pipeline is stable.

## Phase 5: QA, Rollout & Launch Prep
- **Goal:** Final verification, documentation, and deployment readiness.
- **Tasks**
  - [ ] Execute full test suite `mix test` (including umbrella if applicable)
  - [ ] Conduct exploratory testing in staging with staged rollouts, publisher exemptions, and fallback scenarios (Repo outage simulation).
  - [ ] Validate migration on sanitized production snapshot (dry run).
  - [ ] Update release notes, changelog, and internal comms (support, product).
- [ ] Confirm `is_internal` flag rollout plan with product/ops (manual updates or future tooling).
  - [ ] Secure product sign-off on open questions (force_enable behavior, scheduling, telemetry reporting).
- **Definition of Done:** All tests green, staging sign-off completed, migrations rehearsed, documentation published, approvals captured; ready for deploy guard gate.

Dependencies: All prior phases completed.
Parallelism: Dry-run migration and exploratory testing can proceed in parallel with documentation once staging build available.

---

**Parallel Execution Notes**
- Phase 2 and Phase 3 may overlap partially once Phase 1 delivers schemas; coordinate API contracts early.
- Phase 4 tasks can start (telemetry planning, runbook drafting) during late Phase 3 but require stable backend to finalize.
- Ensure cross-functional checkpoints (product, ops) scheduled at end of Phases 2, 3, and 4 before advancing.
