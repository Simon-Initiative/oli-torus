# Online Project Repair Tool - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/features/online-project-fix/prd.md`
- FDD: `docs/exec-plans/current/features/online-project-fix/fdd.md`
- Canonical requirements: `docs/exec-plans/current/features/online-project-fix/requirements.yml`
- Supplemental technical detail: `docs/exec-plans/current/features/online-project-fix/informal.md`

## Scope
Deliver a synchronous, project-scoped system-administrator tool that streams current unpublished Basic-page revisions, reports missing and cross-page shared activity references, and repairs only shared activities that resolve through the project's authoring resolver. Repair must clone through existing activity-duplication behavior, preserve one deterministic keeper page, update normal authoring revisions, respect durable authoring locks, report partial failures, and leave Adaptive pages, missing references, published content, delivery state, and learner data unchanged.

The implementation is limited to a focused `Oli.Authoring.ProjectRepair` context, its typed report/result contracts, a thin Phoenix LiveView and route, targeted ExUnit coverage, bounded telemetry/logging, and documentation/comments needed to make the safety-critical behavior easy to review.

Mandatory source-commenting standard: all new or modified source code must be commented liberally. Every module must have useful module documentation; public functions and structured contracts must have documentation and typespecs; and streaming assumptions, Basic/Adaptive classification, map inversion, deterministic keeper selection, stale-plan fingerprints, lock ordering/cleanup, per-page transaction boundaries, activity-copy reuse, missing-reference preservation, and failure normalization must have clear inline comments explaining intent and safety invariants. Tests and LiveView code must also comment non-obvious fixture construction, authorization setup, and why assertions protect production safety. Comments should explain behavior and reasoning rather than restating syntax.

## Clarifications & Default Assumptions
- `advancedDelivery == true` is the sole Adaptive-page exclusion. Missing and boolean `false` are Basic.
- Missing activities are report-only in every phase; no code path removes their references.
- `Oli.Authoring.Editing.Utils.activity_references/1` and `Oli.Resources.PageContent` remain the nested traversal primitives.
- Use `Oli.Authoring.Editing.ContainerEditor.deep_copy_activity/3` directly unless implementation proves that a behavior-preserving helper extraction is necessary. Do not create alternate copy semantics.
- Use `Oli.Publishing.ChangeTracker.track_revision/3`, not `PageEditor.edit/4`, for server-owned page rewrites, and explicitly recompute `activity_refs`.
- Repair is fail-fast across pages and transactional within one page. Earlier committed pages remain valid; the failed page rolls back its clones and page revision; the after-report identifies remaining work.
- The browser preview is never accepted as a mutation plan. Repair performs fresh analysis, locks all participant pages/source activities, and validates a revision-bearing fingerprint before writing.
- The proposed telemetry prefix is `[:oli, :authoring, :project_repair]`; reconcile it with nearby authoring telemetry during implementation without changing event payload constraints.
- No feature flag, migration, background job, cache, project picker, or detailed LiveView interaction test suite is planned. Add one focused route authorization test because access control is an automated requirement.
- Jira is the execution system of record. The missing issue key does not block local implementation planning, but it must be linked before final delivery.
- Liberal source comments are a release requirement. Each phase gate includes a comment/documentation review, and uncommented safety-critical logic fails the gate.

## Phase 1: Domain Contracts, Authorization, and Test Foundation
- Goal: Establish the smallest compilable domain boundary, stable result contracts, test fixtures, and defense-in-depth authorization before implementing analysis or mutation.
- Tasks:
  - [ ] Create `Oli.Authoring.ProjectRepair` with documented public `analyze_project/3` and `repair_project/3` contracts that require the authenticated `%Author{}` actor.
  - [ ] Add documented/typespecified structs for `Report`, `Summary`, `PageSummary`, `MissingActivityReference`, `SharedActivityReference`, `RepairResult`, and `RepairFailure`; keep web URLs and HEEx concerns out of these structs.
  - [ ] Implement common actor authorization, project/project-slug normalization, working-publication resolution, deterministic error normalization, and safe option defaults for stream and resolution batch sizes.
  - [ ] Reject non-system-admin actors before project content is queried (`FR-001`, `AC-001`, `AC-002`).
  - [ ] Establish `test/oli/authoring/project_repair_test.exs` with reusable fixtures/helpers for Basic pages, Adaptive pages, nested references, shared activities, and intentionally missing ids.
  - [ ] Add liberal `@moduledoc`, `@doc`, `@spec`, struct field documentation, and inline comments explaining why authorization exists in both the context and eventual route and why report structs contain revision ids but no page content.
- Testing Tasks:
  - [ ] Test system-admin access with both `%Project{}` and project slug inputs and deterministic not-found/working-publication failures (`AC-001`).
  - [ ] Test non-system-admin denial occurs before page analysis or mutation entry points (`AC-002`).
  - [ ] Compile the new modules with warnings treated as actionable and verify fixture helpers produce current unpublished project revisions.
  - Command(s): `mix test test/oli/authoring/project_repair_test.exs`; `mix format --check-formatted lib/oli/authoring/project_repair.ex lib/oli/authoring/project_repair test/oli/authoring/project_repair_test.exs`
- Definition of Done:
  - Public contracts compile, authorization/project normalization tests pass, typed results are sufficient for later context and LiveView phases, and no analysis or repair behavior is prematurely implemented in the web layer.
  - Every created source/test module and non-obvious contract is liberally documented and commented according to the mandatory standard.
- Gate:
  - Gate A: domain contracts are approved, system-admin denial is proven, targeted tests pass, formatting passes, and comment review finds no undocumented public API or safety assumption.
- Dependencies:
  - Validated PRD, FDD, and `requirements.yml`; no code dependency on later phases.
- Parallelizable Work:
  - Struct/type documentation and test fixture helpers may be developed in parallel after public field names are agreed. Changes to the main context file should remain serialized.

## Phase 2: Streamed Read-Only Analysis and Reporting
- Goal: Implement and fully test the non-mutating analysis path before any repair writes are introduced.
- Tasks:
  - [ ] Add a parameterized Ecto query over the selected project's unpublished `PublishedResource` page mappings and current non-deleted project `Revision` rows; select only revision id, resource id, slug, title, and content.
  - [ ] Enumerate the query with `Repo.stream/2` inside the required transaction and a bounded `max_rows`; do not call `AuthoringResolver.all_pages/1` or retain all page content (`FR-002`, `FR-004`, `AC-003`, `AC-007`).
  - [ ] Centralize the Basic-page predicate so top-level boolean `advancedDelivery: true` increments the skipped count and is excluded from both relationship maps, while missing/false is included (`FR-003`, `AC-004`, `AC-005`).
  - [ ] Extract all nested activity ids through `Utils.activity_references/1`, store one `MapSet` per Basic page, and build the inverted activity-to-page `MapSet` during the same reduce (`AC-006`, `AC-008`, `AC-009`).
  - [ ] Resolve unique activity ids through the project-scoped `AuthoringResolver.existing_activity_resource_ids/2` projection in bounded chunks, retaining only validated activity ids, selecting no activity JSON, and avoiding N+1 queries.
  - [ ] Produce deterministic missing-reference records and shared groups, mark shared missing ids non-repairable, and compute every preview summary count (`FR-005`, `FR-006`, `FR-007`, `FR-010`, `AC-010`, `AC-012`, `AC-013`, `AC-014`).
  - [ ] Treat malformed traversable page content as an explicit page-scoped analysis failure rather than returning an incomplete report.
  - [ ] Add liberal comments around stream lifetime, why content is discarded, relationship-map memory complexity, nested traversal reuse, MapSet deduplication, resolver batching, and the absolute exclusion of Adaptive pages.
- Testing Tasks:
  - [ ] Prove analysis creates no resources, revisions, mappings, publication changes, delivery changes, or learner changes (`AC-003`).
  - [ ] Cover no-issue projects, no-reference pages, nested references, repeated same-page references, missing/false/true `advancedDelivery`, missing activity ids, one shared group, shared missing ids, and multiple independent groups (`AC-004` through `AC-014`).
  - [ ] Run analysis with small configured stream/resolver batch sizes to exercise multiple batches and assert deterministic output ordering (`AC-007`).
  - [ ] Assert report structs contain compact metadata and ids but never full page content.
  - Command(s): `mix test test/oli/authoring/project_repair_test.exs`; `mix format --check-formatted lib/oli/authoring/project_repair.ex lib/oli/authoring/project_repair test/oli/authoring/project_repair_test.exs`
- Definition of Done:
  - Analysis returns a complete, deterministic report for all required Basic-page cases, reports but never changes missing references, excludes Adaptive pages entirely, performs bounded activity resolution, and has no mutation side effects.
  - Streaming and classification implementation is liberally commented enough for a reviewer to verify why full JSON cannot accumulate and why Adaptive content cannot enter repair maps.
- Gate:
  - Gate B: all Phase 2 analysis portions of `AC-003`–`AC-014` pass; `AC-011`'s post-repair assertion remains for Gate C. A query/performance inspection finds no page/activity N+1 path, formatting passes, and source-comment review approves all memory and classification invariants.
- Dependencies:
  - Gate A.
- Parallelizable Work:
  - Report summary tests and malformed-content tests may proceed alongside the stream reducer once the report contract is fixed. Query and reducer changes should remain coordinated because they share memory assumptions.

## Phase 3: Lock-Aware Deterministic Repair
- Goal: Add the only mutation path, deriving it exclusively from fresh analysis and preserving safe, retryable authoring history.
- Tasks:
  - [ ] Build a deterministic repair fingerprint from repairable shared activity ids and sorted participant page resource/revision ids; select the lowest page resource id as keeper (`FR-008`, `AC-016`, `AC-017`).
  - [ ] Invert non-keeper work into `page_resource_id -> MapSet<source_activity_resource_id>` so a page involved in multiple groups receives one page revision.
  - [ ] Acquire `Oli.Authoring.Locks` for every participant page, keeper page, and source activity in deterministic order; release all acquired locks on acquisition failure and refresh locks between long-running page transactions.
  - [ ] Rerun analysis after complete lock acquisition and abort with `:stale_project_state` and zero writes when the repair fingerprint differs (`AC-016`).
  - [ ] For each non-keeper page in ascending id order, open one transaction, re-resolve and validate the current Basic page revision, clone each assigned source once through `ContainerEditor.deep_copy_activity/3`, and reuse the returned new id for every matching reference on that page (`FR-009`, `AC-018`).
  - [ ] Rewire nested references with `PageContent.map/2` while preserving all unrelated node fields and every missing activity reference; recompute `activity_refs`; create the new page revision through `ChangeTracker.track_revision/3`; broadcast only after commit (`AC-011`, `AC-019`, `AC-020`).
  - [ ] Stop on the first page failure, roll back that page's clones/revision, preserve earlier committed pages, release all locks, rerun analysis, and return `:completed`, `:partial`, or `:failed` structured results with counts/failures/warnings (`FR-011`, `AC-021`, `AC-022`, `AC-023`).
  - [ ] Ensure no repair plan is generated for shared ids whose authoring resolution is `nil` and no code attempts to copy them (`FR-010`, `AC-020`).
  - [ ] Add liberal comments explaining keeper determinism, lock membership/order/refresh/reverse release, fingerprint contents, why the browser report is ignored, why `PageEditor.edit/4` is not used, page transaction scope, same-page clone reuse, missing-reference preservation, and safe retry after partial completion.
- Testing Tasks:
  - [ ] Verify lowest-id keeper behavior, distinct clones for every non-keeper page, full existing duplication semantics, nested rewiring, and aligned persisted `activity_refs` (`AC-017`–`AC-019`).
  - [ ] Verify a missing shared id creates no new resource, revision, project-resource row, or mapping and remains present in page JSON (`AC-011`, `AC-020`).
  - [ ] Verify multiple groups and several groups affecting one page are not conflated and produce one page revision per changed page (`AC-021`).
  - [ ] Change project state between preview and repair and during pre-lock planning to prove fresh analysis/fingerprint rejection (`AC-016`).
  - [ ] Hold a participant lock with another author and prove zero repair writes; force copy/page-update failures and prove active-page rollback, fail-fast behavior, structured partial results, lock cleanup, and safe rerun (`AC-023`).
  - [ ] Rerun analysis after successful and partial repair to prove repaired relationships disappear while missing references remain (`AC-022`).
  - Command(s): `mix test test/oli/authoring/project_repair_test.exs`; `mix test test/oli/authoring/editing/container_editor_test.exs`; `mix format --check-formatted lib/oli/authoring/project_repair.ex lib/oli/authoring/project_repair test/oli/authoring/project_repair_test.exs`
- Definition of Done:
  - Repair is deterministic, lock-aware, stale-safe, page-transactional, fail-fast, idempotent on rerun, and incapable of mutating missing references or Adaptive pages.
  - All mutation and cleanup paths have liberal intent/safety comments, including rollback and partial-failure semantics.
- Gate:
  - Gate C: repair acceptance criteria (`AC-011`, `AC-016`–`AC-023`) pass, existing duplication tests remain green, lock cleanup is proven for every failure path, formatting passes, and comment review can trace every write to a documented invariant.
- Dependencies:
  - Gate B; activity-copy behavior and report contracts must be stable.
- Parallelizable Work:
  - Failure-injection test cases may be prepared while the happy-path transaction is implemented. Lock orchestration, fingerprinting, and transaction code should be integrated serially to avoid competing safety assumptions.

## Phase 4: Operational Instrumentation and Performance Hardening
- Goal: Make analysis and repair observable without leaking content, and verify the streaming/query posture under representative project sizes.
- Tasks:
  - [ ] Add analysis/repair telemetry spans using the reconciled authoring prefix and bounded metadata for operation, project/actor ids, counts, status, failure category, and duration (`AC-025`).
  - [ ] Add one bounded structured completion log and warning/error logs for lock conflicts, stale state, partial repair, and fatal failures; exclude page/activity content, titles, author emails, and full reports.
  - [ ] Ensure telemetry/logging failures cannot alter analysis or repair results.
  - [ ] Review query plans/index use for the working-publication page stream and confirm activity resolution is chunked rather than N+1.
  - [ ] Exercise a larger generated project and record qualitative memory/query behavior for the implementation handoff; do not introduce an arbitrary latency SLA or an all-project benchmark.
  - [ ] Add liberal comments documenting telemetry privacy boundaries, why metadata is bounded, configured stream/resolver batch defaults, and why multiple analysis passes are an intentional safety tradeoff.
- Testing Tasks:
  - [ ] Attach a telemetry handler and use `capture_log`/`@tag capture_log: true` to assert required operation/count/outcome fields and absence of authored content (`AC-025`).
  - [ ] Exercise multiple stream/resolver batches and inspect query counts to guard against page/activity N+1 regressions (`AC-007`).
  - [ ] Verify instrumentation on successful, stale, lock-conflict, partial, and fatal outcomes without changing returned values.
  - Command(s): `mix test test/oli/authoring/project_repair_test.exs`; `mix format --check-formatted lib/oli/authoring/project_repair.ex lib/oli/authoring/project_repair test/oli/authoring/project_repair_test.exs`
- Definition of Done:
  - AppSignal-compatible telemetry/logging captures bounded operational outcomes, content is not logged, representative batching is verified, and instrumentation does not affect correctness.
  - Performance and privacy decisions are liberally documented in source next to the relevant code.
- Gate:
  - Gate D: `AC-007` and `AC-025` verification passes, no sensitive/full-content fields appear in instrumentation, query review finds no unbounded/N+1 path, formatting passes, and comments explain every tuning and privacy decision.
- Dependencies:
  - Gates B and C so final result shapes and failure categories are stable.
- Parallelizable Work:
  - Telemetry test-handler work and representative-project fixture generation can proceed in parallel. Instrumentation wrappers should land after context return shapes stabilize.

## Phase 5: System-Admin Route and Thin LiveView
- Goal: Expose the validated context through an accessible, project-scoped LiveView without moving domain logic into `OliWeb`.
- Tasks:
  - [ ] Add a dedicated workspace route/live session for `/workspaces/course_author/:project_id/repair_tool` behind `:browser`, `:authoring_protected`, and `:require_authenticated_system_admin`, retaining standard project assignment and authorization hooks (`FR-001`, `AC-001`, `AC-002`).
  - [ ] Implement `OliWeb.Workspaces.CourseAuthor.ProjectRepairLive` mount to call `analyze_project/3` with server assigns and render fatal errors without exposing a repair action.
  - [ ] Render summary counts, missing references, repairable shared groups, and non-repairable shared missing groups from context structs only; build page editor links with the verified route `/workspaces/course_author/:project_slug/curriculum/:revision_slug/edit` (`FR-007`, `AC-010`, `AC-012`–`AC-015`, `AC-024`).
  - [ ] Render `Make Changes` only when repairable groups exist, disable it while running, send no page/activity ids or serialized plan from the browser, call `repair_project/3`, and replace the preview with the returned after-report and explicit success/partial/failure status (`AC-015`, `AC-023`, `AC-024`).
  - [ ] Use semantic headings/lists/tables as appropriate, descriptive page links, visible focus, text status labels, and live-region behavior for operation results; reuse existing Torus components and avoid a React application.
  - [ ] Add liberal comments documenting the defense-in-depth route choice, why the event carries no repair plan, why links are built in the web layer, and why the LiveView contains no detection/transformation logic.
- Testing Tasks:
  - [ ] Add `test/oli_web/project_repair_route_test.exs` as a focused route/pipeline smoke test for system-admin access and non-system-admin redirect/denial (`AC-001`, `AC-002`); do not expand into a detailed LiveView behavior suite.
  - [ ] Manually verify missing-only, no-issue, repairable, successful, partial, and fatal states; verify page-title links, button visibility, keyboard navigation, focus, and text status (`AC-015`, `AC-024`).
  - [ ] Confirm the LiveView never retains page content and sends no client-controlled resource ids to the repair context.
  - Command(s): `mix test test/oli_web/project_repair_route_test.exs test/oli/authoring/project_repair_test.exs`; `mix format --check-formatted lib/oli_web/router.ex lib/oli_web/live/workspaces/course_author/project_repair_live.ex test/oli_web/project_repair_route_test.exs`
- Definition of Done:
  - The direct route is usable only by system admins, preview and result states accurately render context data, editor links work, the repair action is appropriately gated, and the LiveView remains accessible and domain-logic-free.
  - Route and LiveView source is liberally commented at every security or orchestration boundary.
- Gate:
  - Gate E: route authorization automation passes, manual `AC-015`/`AC-024` checks pass, context tests remain green, formatting passes, and review confirms both thin-LiveView separation and liberal comments.
- Dependencies:
  - Gates A–D; the LiveView depends on stable `Report` and `RepairResult` contracts.
- Parallelizable Work:
  - Static HEEx rendering and route-guard test setup may begin after report/result structs stabilize, in parallel with late Phase 4 instrumentation. Event wiring waits for Gate C.

## Phase 6: Integrated Verification, Review, and Delivery Readiness
- Goal: Prove the complete feature meets safety, performance, security, traceability, documentation, and operational expectations before handoff.
- Tasks:
  - [ ] Run targeted and broader authoring tests affected by resolver, duplication, locks, publication mapping, and routing changes.
  - [ ] Run `mix format` and compile with warnings reviewed; remove dead options, stale assigns, duplicated helpers, and speculative abstractions.
  - [ ] Audit every new/modified source and test file against the mandatory liberal-commenting standard. Add missing module/function/typespec documentation and inline rationale for every safety-critical branch; remove comments that merely paraphrase syntax or have become inaccurate.
  - [ ] Perform repository-required reviews: security and performance always, plus Elixir, UI, and requirements reviews for the affected files. Address concrete findings before completion.
  - [ ] Manually exercise a prepared project containing valid Basic pages, Adaptive pages, nested references, missing-only references, repairable shared groups, shared missing ids, and multiple independent groups.
  - [ ] Confirm initial analysis performs no writes, Adaptive and published/delivery state remain unchanged, repair counts match persisted changes, post-repair analysis removes repaired groups, and missing references remain (`AC-003`, `AC-004`, `AC-011`, `AC-020`, `AC-022`).
  - [ ] Confirm operational events are visible through local telemetry/logging conventions without authored content (`AC-025`).
  - [ ] Link the Jira implementation issue and ensure PRD/FDD/plan references remain repository-relative.
  - [ ] Rerun Harness requirement and work-item validation if implementation causes any documented contract change.
- Testing Tasks:
  - [ ] Run the full targeted context and route suites and any existing tests touched by helper extraction.
  - [ ] Run broader `mix test` according to risk/time available; any unexplained failure blocks delivery.
  - [ ] Complete the manual production-like safety checklist and retain concise evidence in the implementation handoff/PR.
  - Command(s): `mix test test/oli/authoring/project_repair_test.exs test/oli_web/project_repair_route_test.exs`; `mix test test/oli/authoring/editing/container_editor_test.exs test/oli/publishing/authoring_resolver_test.exs`; `mix format --check-formatted`; `mix compile --warnings-as-errors`
- Definition of Done:
  - Every functional requirement (`FR-001`–`FR-011`) and acceptance criterion (`AC-001`–`AC-025`) has automated or recorded manual evidence; targeted tests, formatting, compilation, and required reviews pass; no feature flag/migration is introduced; Jira is linked; and the source is liberally, accurately commented throughout.
- Gate:
  - Gate F: all implementation evidence is green, no unresolved high/medium review finding remains, manual safety verification is complete, all locks/content/privacy invariants are confirmed, and the final comment/documentation audit passes.
- Dependencies:
  - Gates A–E.
- Parallelizable Work:
  - Security, performance, Elixir, UI, and requirements reviews can run in parallel after the implementation diff stabilizes. Manual validation can run alongside review but must be repeated for any behavior-changing fix.

## Parallelization Notes
- The core context is intentionally small and safety-sensitive; avoid concurrent edits to the same orchestration module. Parallelize fixtures, typed structs, focused tests, telemetry handlers, and static LiveView markup only after their contracts are fixed.
- Phase 2 analysis must gate Phase 3 repair because mutation correctness depends on complete Basic-page filtering, missing classification, and deterministic relationship maps.
- After Gate C, Phase 4 instrumentation and the non-event portions of Phase 5 can proceed concurrently. LiveView mutation wiring depends on stable repair results.
- Required review lenses can run concurrently in Phase 6, then findings should be merged and resolved before final verification.
- Liberal commenting is continuous work, not a final documentation pass. Every parallel workstream owns comments and docs for the code it changes; phase owners enforce consistency at each gate.

## Phase Gate Summary
- Gate A: context contracts, system-admin authorization, fixtures, formatting, and liberal API/safety documentation are approved.
- Gate B: streamed read-only analysis satisfies the Phase 2 analysis portions of `AC-003`–`AC-014`, with `AC-011` post-repair verification deferred to Gate C; analysis has bounded query/memory behavior and clearly comments all classification and streaming invariants.
- Gate C: deterministic lock-aware repair satisfies `AC-011` and `AC-016`–`AC-023`, safely rolls back/stops/retries, and comments every mutation and cleanup invariant.
- Gate D: telemetry, privacy, and performance verification satisfy `AC-007`/`AC-025`, with bounded metadata and documented tuning decisions.
- Gate E: system-admin route and accessible thin LiveView satisfy `AC-001`, `AC-002`, `AC-015`, and `AC-024`, with commented security/orchestration boundaries.
- Gate F: all `FR-001`–`FR-011` and `AC-001`–`AC-025` evidence, required reviews, manual safety checks, Jira linkage, formatting, compilation, and final liberal-comment audit pass.
