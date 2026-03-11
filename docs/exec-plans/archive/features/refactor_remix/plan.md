# RemixSection LiveView Refactor — Delivery Plan

References: docs/features/refactor_remix/prd.md, docs/features/refactor_remix/fdd.md

## Scope
- Extract non-UI business logic from `OliWeb.Delivery.RemixSection` into `Oli.Delivery.Remix` (and `Oli.Delivery.Remix.State`).
- Preserve UX, routes, and persistence path via `Oli.Delivery.Sections.rebuild_section_curriculum/3`.
- Keep authorization in LiveView `mount`; new module is auth-agnostic.
- No new custom telemetry; rely on default Phoenix/Ecto/AppSignal.
- No schema changes; performance and behavior parity required.

## Non-Functional Guardrails
- Interactive operations: p95 ≤ 50 ms server-side; Save: ≤ 2 s.
- No new N+1 queries; reuse batched resolvers and caches (SectionResourceDepot).
- Multi-tenant safety: scope by section/institution; no cross-tenant joins.
- Accessibility unchanged; LiveView remains responsive (no extra renders).
- Observability: rely on existing Phoenix/Ecto/AppSignal; no new dashboards.

## Clarifications & Assumptions
- Auth remains at `mount/3`; `Oli.Delivery.Remix` validates inputs/invariants only.
- Pinned publications semantics unchanged and consumed via Sections APIs.
- Default page size for listing pages remains 5 (FDD).
- No feature flag; optional app-config gate for emergency disable.

---

## Phase 0: Baseline & Characterization
Goal Capture current behavior and performance as a reference.

Tasks
- [ ] Identify all Remix LiveView events/handlers in `lib/oli_web/live/delivery/remix_section.ex`.
- [ ] Add/confirm LiveView characterization tests covering: load/init, select, reorder, move, add, remove, toggle hidden, pagination/filter/sort, and save.
- [ ] Snapshot DOM states where applicable and record expected assigns.
- [ ] Optionally capture baseline AppSignal metrics (error rate, p95) for Remix actions (dev/stage).
- [ ] Document invariants (e.g., multiset of resource_ids preserved; ordering determinism).

Definition of Done
- LiveView tests pass and cover all current actions (≥ critical paths).
- Baseline metrics recorded and linked in the PR.
- Known invariants listed in test notes.

Gate Criteria
- No failing tests in the baseline suite (`mix test test/oli_web/live/remix_section_test.exs`).

Parallelization
- Tests and invariants documentation can proceed in parallel.

---

## Phase 1: Context Skeleton & State Model
Goal Introduce `Oli.Delivery.Remix` and `%Oli.Delivery.Remix.State{}` with types/specs and stubs.

Tasks
- [ ] Create module and struct with fields required by FDD (active selection, hierarchy nodes, pinned/publications maps, pagination/filter/sort state).
- [ ] Implement `init/2` (pure) to build initial State from section + actor data using existing resolvers.
- [ ] Spec and dialyzer annotations; no persistence or side effects yet.
- [ ] Unit tests for `init/2` with fixtures.

Definition of Done
- `Oli.Delivery.Remix` compiles with types/specs; `init/2` returns deterministic state.
- Unit tests pass: `mix test test/oli/delivery/remix/*_test.exs`.

Gate Criteria
- Dialyzer (if enabled) clean for new modules; unit tests green.

Parallelization
- Test fixture work in parallel with type/spec authoring.

---

## Phase 2: Operation Implementations (Pure)
Goal Implement pure state transitions per FDD.

Tasks
- [ ] `select_active/2` sets focused node; ensures visibility rules.
- [ ] `reorder/3` reorders siblings; preserves multiset; property tests.
- [ ] `move/3` moves node across parents; preserves invariants; property tests.
- [ ] `remove/2` removes node; validates constraints.
- [ ] `toggle_hidden/2` flips visibility; respects pinned/publication rules.
- [ ] `add_materials/2` inserts items in canonical order from publication.
- [ ] Filtering/sorting/pagination helpers for pages/publications (stable ordering, deterministic tiebreaks).
- [ ] Unit + property tests for all operations; YAML scenario-driven tests if available per FDD note.
- [ ] Update `Oli.Scenarios` remix directive handler to call `Oli.Delivery.Remix.*` for state transitions and to rely on `save/1` for persistence (keep directive semantics identical). Add/adjust scenario YAML and tests.

Definition of Done
- 100% of operations implemented with ≥ 80% coverage and property tests for ordering/multiset invariants.

Gate Criteria
- `mix test test/oli/delivery/remix/*_test.exs` green; property tests stable under seed sweep.

Parallelization
- Different operations and their tests can be split across developers once shared types are stable.

---

## Phase 3: Persistence Path
Goal Implement save flow delegating to Sections API.

Tasks
- [ ] `save/1` assembles finalized hierarchy and calls `Oli.Delivery.Sections.rebuild_section_curriculum/3` inside a transaction.
- [ ] Map and surface errors to the caller (typed results).
- [ ] Failure injection tests: transaction rollback, partial failure, retry policy if any.

Definition of Done
- Save works end-to-end in unit/integration tests; leaves hierarchy consistent.

Gate Criteria
- Integration test exercising `save/1` passes: `mix test --only remix_save` (tag new tests accordingly).

Parallelization
- Error mapping and integration test scaffolding can proceed parallel to implementation once function contract is stable.

---

## Phase 4: LiveView Delegation Refactor
Goal Replace direct logic in LiveView with context calls; keep DOM/events unchanged.

Tasks
- [ ] In `remix_section.ex`, refactor `mount/3` to call `Remix.init/2` (auth remains at mount).
- [ ] Update each `handle_event` to delegate to `Remix.*` and assign returned `%State{}`; remove direct DB calls.
- [ ] Ensure assigns and components receive identical data shapes.
- [ ] Update/extend LiveView tests to use the new path (no DOM diffs vs. baseline).

Definition of Done
- No direct DB or ad-hoc auth in LiveView; all tests from Phase 0 pass unchanged.

Gate Criteria
- `mix test test/oli_web/live/remix_section_test.exs` green with snapshot comparisons.

Parallelization
- Individual handler refactors can be parallelized if they don’t touch shared assigns; coordinate via code owners.

---

## Phase 5: Telemetry & Observability (Removed)
This feature does not add custom telemetry or AppSignal dashboards beyond the default Phoenix/Ecto instrumentation. Skip this phase.

---

## Phase 6: Performance, Caching, and N+1 Audit
Goal Verify NFRs and ensure caching usage.

Tasks
- [ ] Audit queries for N+1; ensure bulk calls are used (`Publishing.get_published_resources_for_publications/1`); eliminate duplicate `Sections.published_resources_map/1` calls during add flow (DONE).
- [ ] Microbenchmarks for operations; measure p50/p95; confirm ≤ 50 ms server-side.
- [ ] Load test save path; confirm ≤ 2 s under representative data.
- [ ] Verify SectionResourceDepot cache usage and invalidation post-save.

Definition of Done
- Benchmarks and load tests meet targets; no N+1 detected; caches behave correctly.

Gate Criteria
- Perf report attached; `mix test` green; optional `benchee` results stored.

Parallelization
- Query audit, microbench, and load test can run in parallel.

---

## Phase 7: Cleanup & Rollout
Goal Remove dead code, document rollback, and ship.

Tasks
- [ ] Delete duplicated logic from LiveView after parity confirmed.
- [ ] Update module docs and architecture comments; link PRD/FDD in moduledoc.

Definition of Done
- Only context-backed path remains; docs updated; rollout notes captured.

Gate Criteria
- Sign-off from QA and code owners; AppSignal error rate non-increasing post-deploy.

Parallelization
- Docs and cleanup can proceed in parallel after tests are green.

---

## Test Commands (per Phase)
- Phase 0/4 LiveView: `mix test test/oli_web/live/remix_section_test.exs`
- Phase 1–3 Unit/Property: `mix test test/oli/delivery/remix/*_test.exs`
- Telemetry: `mix test --only telemetry`
- Save path: `mix test --only remix_save`

## Overall Definition of Done
- All phases’ gates met; `mix test` green in CI.
- Observability in place with dashboards and alerts.
- Documentation updated and linked; rollback path documented.
- Performance targets verified in stage and after production deploy.
